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
        case safetyTimeout
        case sourceSelectionFailed
        case shortcutSendFailed
    }

    private static let log = Logger(subsystem: LogSubsystem.current, category: "VoiceInput")
    /// How long to wait for the system to confirm the switch into the voice
    /// input source before declaring the session failed.
    private static let sourceSelectionDeadline: TimeInterval = 0.5

    private let overrideEngine: any VoiceInputSourceOverriding
    private let sender: any ShortcutEventSending
    private let fallbackRestoreSourceID: @MainActor () -> InputSourceID?
    private let timeoutScheduler: any VoiceTimeoutScheduling
    /// Extra settle time between confirming the voice input source and sending
    /// its voice shortcut. Only used by the automatic-switch path; synthetic
    /// sending needs no wait, so the default is zero.
    private let sourceActivationDelay: TimeInterval
    private var token: TemporaryInputSourceOverrideToken?
    private var restoreSourceID: InputSourceID?
    /// Whether *this* session took over the input source and therefore has to
    /// hand it back. False in the no-switch path, where ending the session must
    /// leave the user's input source exactly where it was.
    private var ownsInputSource = false
    private var generation = 0
    private var didSendVoiceShortcut = false
    private var didScheduleVoiceShortcut = false
    private var sessionShortcut: VoiceShortcut?
    private var sessionBehavior: VoiceInputBehavior?

    public private(set) var state: VoiceInputSessionState = .idle {
        didSet {
            guard state != oldValue else { return }
            onStateChange?(state)
        }
    }
    public var onSessionCleanup: (@MainActor () -> Void)?
    public var onStateChange: (@MainActor (VoiceInputSessionState) -> Void)?

    public var isSessionInProgress: Bool {
        state.isInProgress
    }

    public init(
        overrideEngine: any VoiceInputSourceOverriding,
        sender: any ShortcutEventSending,
        fallbackRestoreSourceID: @escaping @MainActor () -> InputSourceID? = { nil },
        timeoutScheduler: any VoiceTimeoutScheduling = TaskVoiceTimeoutScheduler(),
        sourceActivationDelay: TimeInterval = 0
    ) {
        self.overrideEngine = overrideEngine
        self.sender = sender
        self.fallbackRestoreSourceID = fallbackRestoreSourceID
        self.timeoutScheduler = timeoutScheduler
        self.sourceActivationDelay = sourceActivationDelay
    }

    /// A trigger press, from LockIME's own global shortcut (`voiceInput`). It is
    /// a *separate* combination from the input method's own voice shortcut, so
    /// each key is handled exactly once: LockIME acts on this one and the input
    /// method acts on the synthesized one. Sharing a single combination is what
    /// made macOS report a shortcut conflict.
    public func handleWorkflowShortcutPressed(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        // A switched-off workflow must never act — in *any* state. Checked before
        // the switch so a stale live session can't be ended either: the user
        // turned the feature off, so LockIME stops synthesizing keys. The session
        // is torn down locally (no further key is sent) and the state reset.
        guard config.isEnabled else {
            cleanupOverride()
            state = .idle
            return
        }
        switch state {
        case .idle, .failed, .endingVoice, .restoringDefaultInput:
            // A stale/abandoned session (a failure, an interrupted restore) is
            // cleared first so the next press always starts from a clean slate.
            cleanupOverride()
            try start(
                config: config,
                restoreSourceID: restoreSourceID,
                installedSources: installedSources
            )
        case .preparingVoice:
            break
        case .voiceActive:
            // Ending is a press-again tap. A session left over from a behavior
            // this build no longer offers (a `holdToSpeak` configuration carried
            // over from v0.1.2) must still be endable, so fall back to the tap
            // rather than stranding the session with no way out.
            try end(sendEndShortcut: true)
        }
    }

    /// The safety timeout. In a switching session it hands the input source back;
    /// in a shortcut-only session there is nothing to hand back, but the input
    /// method may still be recording, so the timeout must also *end* the session
    /// the same way a second press would — otherwise LockIME reports idle while
    /// the microphone is still live, and the next press would start a fresh
    /// session instead of ending the running one.
    public func handleRestoreTimeout(config: VoiceInputConfiguration) throws {
        guard state == .voiceActive else { return }
        if ownsInputSource {
            try restoreDefault(reason: .safetyTimeout)
            return
        }
        guard let sessionShortcut else {
            failAndRestore(.shortcutSendFailed, reason: .safetyTimeout)
            throw VoiceInputCoordinatorError.shortcutSendFailed
        }
        do {
            try sender.sendTap(sessionShortcut)
        } catch {
            failAndRestore(.shortcutSendFailed, reason: .safetyTimeout)
            throw VoiceInputCoordinatorError.shortcutSendFailed
        }
        cleanupOverride()
        state = .idle
    }
    /// Begin a session. Two shapes:
    ///  * **automatic switching** — take over the input source, wait for the
    ///    switch to land, then send the input method's voice shortcut;
    ///  * **shortcut only** (automatic switching off, or the voice input method
    ///    being the global default) — send the voice shortcut straight away, and
    ///    never touch the input source, so nothing has to be restored.
    private func start(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        guard let voiceShortcut = config.voiceShortcut else {
            state = .failed(.validationFailed([.missingVoiceShortcut]))
            throw VoiceInputCoordinatorError.validationFailed([.missingVoiceShortcut])
        }
        // Validate against the *configuration*, not against the resolved mode: a
        // mode of `.direct` also covers "automatic switching is on but its
        // sources are missing", and skipping validation there would let a
        // half-configured workflow synthesize a key into whatever input method
        // happens to be active.
        let errors = config.validationErrors(
            defaultSourceID: restoreSourceID,
            installedSources: installedSources
        )
        guard errors.isEmpty else {
            state = .failed(.validationFailed(errors))
            throw VoiceInputCoordinatorError.validationFailed(errors)
        }
        let switchesSource = config.workflowMode(defaultSourceID: restoreSourceID) == .bridged
        Self.log.notice(
            "Voice workflow starting: switchesSource=\(switchesSource) source=\(config.voiceSourceID?.rawValue ?? "-", privacy: .public) keyCode=\(voiceShortcut.keyCode) modifiers=\(voiceShortcut.modifiers.rawValue)"
        )
        generation += 1
        let currentGeneration = generation
        didSendVoiceShortcut = false
        didScheduleVoiceShortcut = true
        ownsInputSource = false
        sessionShortcut = voiceShortcut
        sessionBehavior = config.behavior
        guard switchesSource, let voiceSourceID = config.voiceSourceID else {
            self.restoreSourceID = nil
            state = .preparingVoice
            activateVoiceShortcut(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: currentGeneration
            )
            return
        }
        state = .preparingVoice
        didScheduleVoiceShortcut = false
        token = overrideEngine.beginTemporaryInputSourceOverride { [weak self] sourceID in
            guard sourceID == voiceSourceID else { return }
            self?.scheduleVoiceShortcutActivation(
                config: config,
                voiceShortcut: voiceShortcut,
                generation: currentGeneration
            )
        }
        ownsInputSource = true
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
            // Only press-once / press-again is reachable: the other two
            // behaviors need a key-up or any-key listener (the removed
            // shared-key monitor) and are no longer offered.
            try sender.sendTap(voiceShortcut)
            armRestoreTimeout(config: config, generation: generation)
            state = .voiceActive
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
                // The end tap failing must not strand the session in the voice
                // input method: hand the source back anyway (the opponent in a
                // `holdToSpeak`-style config can't be ended, but the user's
                // typing source still has to be restored).
                failAndRestore(.shortcutSendFailed, reason: .shortcutSendFailed)
                throw VoiceInputCoordinatorError.shortcutSendFailed
            }
        }
        try restoreDefault(reason: .workflowShortcut)
    }

    /// Hand the input source back and end the session. In the shortcut-only path
    /// nothing was taken over, so there is no restore — the user's input source
    /// is left exactly where it was.
    private func restoreDefault(reason: RestoreReason) throws {
        guard ownsInputSource else {
            cleanupOverride()
            state = .idle
            return
        }
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
            if let fallbackSourceID = fallbackRestoreSourceID(),
               fallbackSourceID != restoreSourceID,
               overrideEngine.temporaryOverrideSwitch(to: fallbackSourceID) {
                Self.log.notice(
                    "Restore source unavailable; restored latest default: \(fallbackSourceID.rawValue, privacy: .public)"
                )
                cleanupOverride()
                state = .idle
                return
            }
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
        if let token {
            overrideEngine.endTemporaryInputSourceOverride(token)
            self.token = nil
        }
        restoreSourceID = nil
        ownsInputSource = false
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
    /// Abandon any in-flight session without restoring the input source. Used on
    /// app shutdown, where the override hand-back would race the process exit.
    public func stopActiveSession() {
        cleanupOverride()
        state = .idle
    }

    private func failAndRestore(
        _ failure: VoiceInputCoordinatorError,
        reason: RestoreReason
    ) {
        state = .failed(failure)
        guard ownsInputSource else {
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

}
