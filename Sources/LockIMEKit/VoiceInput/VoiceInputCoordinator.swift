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
        case typingInterrupted
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
    /// How long a switching session keeps the voice input source after the end
    /// tap, so the input method can commit the recognized text before the source
    /// changes under it. Snapshotted at start, like the shortcut.
    private var sessionRestoreDelay: TimeInterval = 0
    /// Shortcut-only mode mirrors the physical key: the echo goes down when the
    /// user presses and up when they release. This is the key still held down,
    /// so a release (or a teardown) can lift exactly what was pressed.
    private var echoedKeyDown: VoiceShortcut?
    /// The voice key the session echoes back to the input method. In the
    /// single-shortcut model this is the key LockIME consumed, so it is known
    /// for the whole session and does not depend on a separately recorded value.
    public var voiceShortcutProvider: (@MainActor () -> VoiceShortcut?)?

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

    /// A press of the voice key, which LockIME consumed so the input method never
    /// saw it. Without automatic switching the key is mirrored to the input
    /// method — down now, up on release (`handleWorkflowShortcutReleased`) — and
    /// LockIME keeps no session: the input method alone knows whether it is
    /// recording (it may stop on silence by itself), any state kept here could
    /// only drift from it, and mirroring works the same whether the input method
    /// toggles on a tap or records while the key is held. With automatic
    /// switching the press starts or ends a session that owns the input source.
    public func handleWorkflowShortcutPressed(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        // A switched-off workflow must never act — in *any* state. Checked before
        // the switch so a stale live session can't be ended either: the user
        // turned the feature off, so LockIME stops synthesizing keys. The session
        // is torn down locally (no further key is sent) and the state reset.
        // A key-up lost in transit must not leave the echo stuck down.
        releaseEchoedKey()
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

    /// The voice key came back up: lift the mirrored key in shortcut-only mode.
    /// A switching session ends on the next press instead, so it ignores this.
    public func handleWorkflowShortcutReleased() {
        releaseEchoedKey()
    }

    /// The user started typing while a session owned the input source: hand the
    /// source back immediately so the keystrokes land in the text input they
    /// expect. Sends no key — a blind toggle would *restart* recording whenever
    /// the input method had already stopped by itself, and when it never started
    /// at all (no microphone, denied mic permission) there is nothing to stop.
    public func handleTypingInterrupt() throws {
        guard state == .voiceActive, ownsInputSource else { return }
        Self.log.notice("Voice session ended: the user started typing")
        try restoreDefault(reason: .typingInterrupted)
    }

    /// The safety timeout of a switching session: hand the input source back so
    /// the user is never stranded in the voice input method. It deliberately
    /// sends no key — a blind toggle would *start* recording again whenever the
    /// input method had already stopped by itself.
    public func handleRestoreTimeout(config: VoiceInputConfiguration) throws {
        guard state == .voiceActive, ownsInputSource else { return }
        try restoreDefault(reason: .safetyTimeout)
    }
    /// Handle a press from a clean slate. Two shapes:
    ///  * **automatic switching** — take over the input source, wait for the
    ///    switch to land, then send the input method's voice shortcut;
    ///  * **shortcut only** (automatic switching off, or the voice input method
    ///    being the global default) — echo the voice shortcut straight away and
    ///    keep no session: the input source is never touched, so there is nothing
    ///    to restore, time out, or keep in step with the input method.
    private func start(
        config: VoiceInputConfiguration,
        restoreSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) throws {
        // The key to echo is the one the user pressed (LockIME consumed it), so a
        // separate recording is no longer required — only a resolved value.
        guard let voiceShortcut = voiceShortcutProvider?() ?? config.voiceShortcut else {
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
        guard switchesSource, let voiceSourceID = config.voiceSourceID else {
            do {
                try sender.sendKeyDown(voiceShortcut)
                echoedKeyDown = voiceShortcut
                state = .idle
            } catch {
                state = .failed(Self.failure(for: error))
            }
            return
        }
        sessionShortcut = voiceShortcut
        sessionBehavior = config.behavior
        sessionRestoreDelay = config.restoreDelay.interval
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
            try sender.sendTap(voiceShortcut)
            state = .voiceActive
            armRestoreTimeout(config: config, generation: generation)
        } catch {
            failAndRestore(Self.failure(for: error), reason: .shortcutSendFailed)
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
                let failure = Self.failure(for: error)
                failAndRestore(failure, reason: .shortcutSendFailed)
                throw failure
            }
        }
        // Give the input method time to commit the recognized text before the
        // source changes under it. The override stays in place meanwhile, so the
        // lock engine doesn't snap the source back early either.
        guard ownsInputSource, sessionRestoreDelay > 0 else {
            try restoreDefault(reason: .workflowShortcut)
            return
        }
        state = .restoringDefaultInput
        let currentGeneration = generation
        timeoutScheduler.schedule(after: sessionRestoreDelay) { [weak self] in
            guard let self,
                  self.generation == currentGeneration,
                  self.state == .restoringDefaultInput
            else { return }
            try? self.restoreDefault(reason: .workflowShortcut)
        }
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
        sessionRestoreDelay = 0
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
        releaseEchoedKey()
        cleanupOverride()
        state = .idle
    }

    private func releaseEchoedKey() {
        guard let echoed = echoedKeyDown else { return }
        echoedKeyDown = nil
        do {
            try sender.sendKeyUp(echoed)
        } catch {
            state = .failed(Self.failure(for: error))
        }
    }

    /// Distinguish "macOS refused to post our key" from a generic send failure:
    /// only the former is fixed by granting (or re-granting) Accessibility, and a
    /// user told "the workflow failed" cannot act on it.
    private static func failure(for error: Error) -> VoiceInputCoordinatorError {
        if let senderError = error as? ShortcutEventSenderError,
           senderError == .postingUnavailable {
            Self.log.error("Voice shortcut not sent: macOS refused to post events")
            return .eventPostingUnavailable
        }
        return .shortcutSendFailed
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
