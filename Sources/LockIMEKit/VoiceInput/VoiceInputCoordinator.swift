import Foundation
import OSLog

@MainActor
public protocol VoiceInputSourceOverriding: AnyObject {
    func beginTemporaryInputSourceOverride(
        sourceDidChange: @escaping @MainActor (InputSourceID?) -> Void
    ) -> TemporaryInputSourceOverrideToken
    func temporaryOverrideSwitch(to id: InputSourceID) -> Bool
    func endTemporaryInputSourceOverride(_ token: TemporaryInputSourceOverrideToken)
    func currentInputSourceID() -> InputSourceID?
}

@MainActor
public protocol VoiceTimeoutScheduling: AnyObject {
    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void)
}

@MainActor
public final class TaskVoiceTimeoutScheduler: VoiceTimeoutScheduling {
    public init() {}

    public func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            work()
        }
    }
}

@MainActor
public final class VoiceInputCoordinator {
    private enum RestoreReason: String {
        case workflowShortcut
        case holdRelease
        case anyKey
        case safetyTimeout
        case sourceSelectionFailed
        case shortcutSendFailed
        case eventMonitorFailed
    }

    private static let log = Logger(subsystem: LogSubsystem.current, category: "VoiceInput")
    private static let activationGraceDelay: TimeInterval = 0.8
    private static let sourceSelectionDeadline: TimeInterval = 0.5

    private let overrideEngine: any VoiceInputSourceOverriding
    private let sender: any ShortcutEventSending
    private let timeoutScheduler: any VoiceTimeoutScheduling
    private let eventMonitor: (any ShortcutEventMonitoring)?
    private let sourceActivationDelay: TimeInterval
    private var token: TemporaryInputSourceOverrideToken?
    private var restoreSourceID: InputSourceID?
    private var generation = 0
    private var didSendVoiceShortcut = false
    private var didScheduleVoiceShortcut = false
    private var sessionShortcut: VoiceShortcut?
    private var sessionBehavior: VoiceInputBehavior?

    public private(set) var state: VoiceInputSessionState = .idle
    public var onSessionCleanup: (@MainActor () -> Void)?

    public var isSessionInProgress: Bool {
        switch state {
        case .preparingVoice, .voiceActive, .endingVoice, .restoringDefaultInput:
            true
        case .idle, .failed:
            false
        }
    }

    public init(
        overrideEngine: any VoiceInputSourceOverriding,
        sender: any ShortcutEventSending,
        timeoutScheduler: any VoiceTimeoutScheduling = TaskVoiceTimeoutScheduler(),
        eventMonitor: (any ShortcutEventMonitoring)? = nil,
        sourceActivationDelay: TimeInterval = 0
    ) {
        self.overrideEngine = overrideEngine
        self.sender = sender
        self.timeoutScheduler = timeoutScheduler
        self.eventMonitor = eventMonitor
        self.sourceActivationDelay = sourceActivationDelay
    }

    public func handleWorkflowShortcutPressed(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        guard config.isEnabled else { return }
        switch state {
        case .idle:
            try start(
                config: config,
                restoreSourceID: restoreSourceID,
                installedSources: installedSources
            )
        case .failed, .endingVoice, .restoringDefaultInput:
            cleanupOverride()
            try start(
                config: config,
                restoreSourceID: restoreSourceID,
                installedSources: installedSources
            )
        case .preparingVoice:
            break
        case .voiceActive:
            switch sessionBehavior {
            case .pressOncePressAgainEnds:
                try end(sendEndShortcut: true)
            case .pressOnceAnyKeyEnds:
                try end(sendEndShortcut: false)
            default:
                break
            }
        }
    }

    public func handleWorkflowShortcutReleased(config: VoiceInputConfiguration) throws {
        guard sessionBehavior == .holdToSpeak else { return }
        switch state {
        case .preparingVoice:
            try restoreDefault(reason: .holdRelease)
        case .voiceActive:
            guard let sessionShortcut else { return }
            try sender.sendKeyUp(sessionShortcut)
            try restoreDefault(reason: .holdRelease)
        default:
            return
        }
    }

    public func handleAnyKeyDuringVoice(config: VoiceInputConfiguration) throws {
        guard state == .voiceActive, sessionBehavior == .pressOnceAnyKeyEnds else { return }
        try restoreDefault(reason: .anyKey)
    }

    public func handleRestoreTimeout(config: VoiceInputConfiguration) throws {
        guard state == .voiceActive else { return }
        try restoreDefault(reason: .safetyTimeout)
    }

    private func start(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        var errors = config.validationErrors(installedSources: installedSources)
        let installed = Set(installedSources.map(\.id))
        if let restoreSourceID {
            if !installed.contains(restoreSourceID) {
                errors.append(.defaultSourceUnavailable(restoreSourceID))
            }
        } else {
            errors.append(.missingDefaultSource)
        }
        guard errors.isEmpty else {
            state = .failed(.validationFailed(errors))
            throw VoiceInputCoordinatorError.validationFailed(errors)
        }
        guard let voiceSourceID = config.voiceSourceID else {
            state = .failed(.validationFailed([.missingVoiceSource]))
            throw VoiceInputCoordinatorError.validationFailed([.missingVoiceSource])
        }
        guard let voiceShortcut = config.voiceShortcut else {
            state = .failed(.validationFailed([.missingVoiceShortcut]))
            throw VoiceInputCoordinatorError.validationFailed([.missingVoiceShortcut])
        }
        Self.log.notice(
            "Voice workflow starting: source=\(voiceSourceID.rawValue, privacy: .public) keyCode=\(voiceShortcut.keyCode) modifiers=\(voiceShortcut.modifiers.rawValue)"
        )
        state = .preparingVoice
        generation += 1
        let currentGeneration = generation
        didSendVoiceShortcut = false
        didScheduleVoiceShortcut = false
        sessionShortcut = voiceShortcut
        sessionBehavior = config.behavior
        token = overrideEngine.beginTemporaryInputSourceOverride { [weak self] sourceID in
            guard sourceID == voiceSourceID else { return }
            self?.scheduleVoiceShortcutActivation(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: currentGeneration
            )
        }
        self.restoreSourceID = restoreSourceID
        guard overrideEngine.temporaryOverrideSwitch(to: voiceSourceID) else {
            Self.log.error("Voice input source switch failed: \(voiceSourceID.rawValue, privacy: .public)")
            state = .failed(.switchToVoiceFailed(voiceSourceID))
            cleanupOverride()
            throw VoiceInputCoordinatorError.switchToVoiceFailed(voiceSourceID)
        }
        if overrideEngine.currentInputSourceID() == voiceSourceID {
            scheduleVoiceShortcutActivation(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: currentGeneration
            )
        }
        guard state == .preparingVoice, !didScheduleVoiceShortcut else { return }
        timeoutScheduler.schedule(after: Self.sourceSelectionDeadline) { [weak self] in
            guard let self,
                  self.generation == currentGeneration,
                  self.state == .preparingVoice,
                  !self.didScheduleVoiceShortcut
            else { return }
            Self.log.error(
                "Voice input source was not confirmed before deadline: \(voiceSourceID.rawValue, privacy: .public)"
            )
            self.failAndRestore(
                .switchToVoiceFailed(voiceSourceID),
                reason: .sourceSelectionFailed
            )
        }
    }

    private func scheduleVoiceShortcutActivation(
        config: VoiceInputConfiguration,
        voiceShortcut: VoiceShortcut,
        generation: Int
    ) {
        guard self.generation == generation,
              state == .preparingVoice,
              !didScheduleVoiceShortcut
        else { return }
        didScheduleVoiceShortcut = true
        guard sourceActivationDelay > 0 else {
            activateVoiceShortcut(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: generation
            )
            return
        }
        timeoutScheduler.schedule(after: sourceActivationDelay) { [weak self] in
            self?.activateVoiceShortcut(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: generation
            )
        }
    }

    private func activateVoiceShortcut(
        config: VoiceInputConfiguration,
        voiceShortcut: VoiceShortcut,
        generation: Int
    ) {
        guard self.generation == generation,
              state == .preparingVoice,
              !didSendVoiceShortcut
        else { return }
        didSendVoiceShortcut = true
        do {
            Self.log.notice(
                "Sending voice shortcut: keyCode=\(voiceShortcut.keyCode) modifiers=\(voiceShortcut.modifiers.rawValue)"
            )
            switch config.behavior {
            case .pressOncePressAgainEnds, .pressOnceAnyKeyEnds:
                try sender.sendTap(voiceShortcut)
            case .holdToSpeak:
                try sender.sendKeyDown(voiceShortcut)
            }
            armRestoreTimeout(config: config, generation: generation)
            if config.behavior == .pressOnceAnyKeyEnds {
                armActivationGrace(config: config, generation: generation)
            } else {
                state = .voiceActive
            }
        } catch {
            failAndRestore(.shortcutSendFailed, reason: .shortcutSendFailed)
        }
    }

    private func end(sendEndShortcut: Bool) throws {
        state = .endingVoice
        if sendEndShortcut {
            guard let sessionShortcut else {
                failAndRestore(.shortcutSendFailed, reason: .shortcutSendFailed)
                throw VoiceInputCoordinatorError.shortcutSendFailed
            }
            do {
                try sender.sendTap(sessionShortcut)
            } catch {
                state = .failed(.shortcutSendFailed)
                cleanupOverride()
                throw VoiceInputCoordinatorError.shortcutSendFailed
            }
        }
        try restoreDefault(reason: .workflowShortcut)
    }

    private func restoreDefault(reason: RestoreReason) throws {
        guard let restoreSourceID else {
            state = .failed(.validationFailed([.missingDefaultSource]))
            cleanupOverride()
            throw VoiceInputCoordinatorError.validationFailed([.missingDefaultSource])
        }
        state = .restoringDefaultInput
        Self.log.notice(
            "Restoring input source: \(restoreSourceID.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public)"
        )
        guard overrideEngine.temporaryOverrideSwitch(to: restoreSourceID) else {
            state = .failed(.restoreDefaultFailed(restoreSourceID))
            cleanupOverride()
            throw VoiceInputCoordinatorError.restoreDefaultFailed(restoreSourceID)
        }
        cleanupOverride()
        state = .idle
    }

    private func cleanupOverride() {
        let hadSession = token != nil || sessionBehavior != nil
        generation += 1
        eventMonitor?.stop()
        if let token {
            overrideEngine.endTemporaryInputSourceOverride(token)
            self.token = nil
        }
        restoreSourceID = nil
        didSendVoiceShortcut = false
        didScheduleVoiceShortcut = false
        sessionShortcut = nil
        sessionBehavior = nil
        if hadSession {
            onSessionCleanup?()
        }
    }

    private func armRestoreTimeout(config: VoiceInputConfiguration, generation: Int) {
        timeoutScheduler.schedule(after: config.restoreTimeout.interval) { [weak self] in
            guard let self, self.generation == generation, self.state == .voiceActive else { return }
            try? self.handleRestoreTimeout(config: config)
        }
    }

    private func armActivationGrace(config: VoiceInputConfiguration, generation: Int) {
        timeoutScheduler.schedule(after: Self.activationGraceDelay) { [weak self] in
            guard let self, self.generation == generation, self.state == .preparingVoice else { return }
            self.state = .voiceActive
            do {
                try self.armAnyKeyMonitorIfNeeded(config: config, generation: generation)
            } catch {
                self.failAndRestore(
                    .eventMonitorStartFailed,
                    reason: .eventMonitorFailed
                )
            }
        }
    }

    private func failAndRestore(
        _ failure: VoiceInputCoordinatorError,
        reason: RestoreReason
    ) {
        state = .failed(failure)
        guard token != nil, restoreSourceID != nil else {
            cleanupOverride()
            return
        }
        do {
            try restoreDefault(reason: reason)
            state = .failed(failure)
        } catch {
            // restoreDefault preserves the more actionable restore failure state.
        }
    }

    private func armAnyKeyMonitorIfNeeded(
        config: VoiceInputConfiguration,
        generation: Int
    ) throws {
        guard config.behavior == .pressOnceAnyKeyEnds, let eventMonitor else { return }
        try eventMonitor.start { [weak self] event in
            guard event == .anyKey else { return }
            self?.handleAnyKeyEvent(config: config, generation: generation)
        }
    }

    private func handleAnyKeyEvent(config: VoiceInputConfiguration, generation: Int) {
        guard self.generation == generation, state == .voiceActive else { return }
        eventMonitor?.stop()
        timeoutScheduler.schedule(after: config.restoreDelay.interval) { [weak self] in
            guard let self, self.generation == generation, self.state == .voiceActive else { return }
            try? self.handleAnyKeyDuringVoice(config: config)
        }
    }

}
