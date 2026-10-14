import Foundation
import Testing

@testable import LockIMEKit

@MainActor
@Suite("VoiceInputCoordinator")
struct VoiceInputCoordinatorTests {
    private let daily: InputSourceID = "daily.source"
    private let voice: InputSourceID = "voice.source"

    @Test("press once mode switches to the voice source and restores it on the second press")
    func pressOnceModeStartsAndEnds() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .voiceActive)
        #expect(engine.beginCount == 1)
        #expect(engine.endCount == 0)
        #expect(engine.switches == [voice])
        #expect(sender.events == [.tap(shortcut)])

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .idle)
        #expect(engine.endCount == 1)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events == [.tap(shortcut), .tap(shortcut)])
    }

    @Test("a session that does not switch sources never touches the input source")
    func nonSwitchingSessionLeavesTheInputSourceAlone() throws {
        // The conflict-free setup: the trigger shortcut only synthesizes the
        // input method's own voice key. No override, no switching, nothing to
        // restore — so the user's input source is untouched end to end.
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .idle)
        #expect(sender.events == [.tap(shortcut), .tap(shortcut)])

        // The whole point: not one override was taken, and nothing was switched.
        #expect(engine.beginCount == 0)
        #expect(engine.endCount == 0)
        #expect(engine.switches.isEmpty)
    }

    @Test("a non-switching session needs no installed sources at all")
    func nonSwitchingSessionNeedsNoSources() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: nil,
            installedSources: []
        )

        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("automatic switching without a voice source is refused, not silently degraded")
    func automaticSwitchingWithoutASourceIsRefused() {
        // A half-configured workflow must not synthesize the voice key into
        // whichever input method happens to be active.
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceShortcut: shortcut,
            switchesVoiceSourceAutomatically: true
        )

        #expect(throws: VoiceInputCoordinatorError.validationFailed([.missingVoiceSource])) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue)]
            )
        }
        #expect(sender.events.isEmpty)
        #expect(engine.switches.isEmpty)
    }

    @Test("a disabled workflow never sends anything")
    func disabledWorkflowIsInert() {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        var config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)
        config.isEnabled = false

        try? coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(sender.events.isEmpty)
        #expect(engine.beginCount == 0)
        #expect(engine.switches.isEmpty)
    }

    @Test("turning the workflow off mid-session makes the next press inert")
    func disablingMidSessionMakesTheNextPressInert() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(sender.events == [.tap(shortcut)])

        var disabled = config
        disabled.isEnabled = false
        try coordinator.handleWorkflowShortcutPressed(
            config: disabled,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(sender.events == [.tap(shortcut)])
        #expect(coordinator.state == .idle)
    }

    @Test("a switching session waits for the voice source before sending the shortcut")
    func switchingSessionWaitsForVoiceSource() throws {
        let engine = RecordingVoiceOverrideEngine()
        engine.updatesCurrentSourceOnSwitch = false
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler,
            sourceActivationDelay: 0.3
        )
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        // The switch was requested but the system has not confirmed the source
        // yet, so nothing is sent and the only pending work is the deadline.
        #expect(coordinator.state == .preparingVoice)
        #expect(sender.events.isEmpty)
        #expect(scheduler.delays == [0.5])

        // The source becoming current is what unlocks activation: the settle
        // delay is armed, and the shortcut goes out only when it fires.
        engine.emitSourceChange(voice)
        #expect(scheduler.delays == [0.5, 0.3])
        #expect(sender.events.isEmpty)

        try scheduler.fire(at: 1)
        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("a switching session fails when the voice source is never confirmed")
    func switchingSessionFailsWithoutConfirmation() throws {
        let engine = RecordingVoiceOverrideEngine()
        engine.updatesCurrentSourceOnSwitch = false
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        // The deadline is the last scheduled work item.
        try scheduler.fire(at: scheduler.delays.count - 1)

        #expect(coordinator.state == .failed(.switchToVoiceFailed(voice)))
        #expect(sender.events.isEmpty)
        #expect(engine.endCount == 1)
    }

    @Test("a repeat press while the voice source is being prepared is ignored")
    func repeatedShortcutIsIgnoredWhilePreparing() throws {
        let engine = RecordingVoiceOverrideEngine()
        engine.updatesCurrentSourceOnSwitch = false
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeSwitchingConfig(shortcut: shortcut)

        for _ in 0..<2 {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
        }

        #expect(coordinator.state == .preparingVoice)
        #expect(engine.beginCount == 1)
        #expect(engine.endCount == 0)
        #expect(engine.switches == [voice])
    }

    @Test("a restore failure falls back to the latest valid default source")
    func restoreFailureUsesFallbackDefault() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            fallbackRestoreSourceID: { "fallback.source" }
        )
        let config = makeSwitchingConfig(shortcut: shortcut)
        engine.failedSourceIDs = [daily]

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily, "fallback.source"])
    }

    @Test("session state changes are reported to the host")
    func stateChangesAreReported() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        var states: [VoiceInputSessionState] = []
        coordinator.onStateChange = { states.append($0) }
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        // Nothing interrupts a non-switching session, so it goes straight from
        // active to ending to idle — no restore phase to report.
        #expect(states == [.preparingVoice, .voiceActive, .endingVoice, .idle])
        #expect(!coordinator.isSessionInProgress)
    }

    @Test("a shortcut send failure ends the session and restores the source once")
    func shortcutSendFailureRestoresDefaultOnce() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)
        sender.shouldFail = true

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .failed(.shortcutSendFailed))
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
    }

    @Test("a missing voice shortcut fails before any override is taken")
    func missingVoiceShortcutDoesNotBeginOverride() {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            switchesVoiceSourceAutomatically: true
        )

        #expect(throws: VoiceInputCoordinatorError.validationFailed([.missingVoiceShortcut])) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
        }
        #expect(engine.beginCount == 0)
        #expect(engine.switches.isEmpty)
    }

    @Test("a switching session with unavailable sources fails before overriding")
    func unavailableSourcesDoNotBeginOverride() {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let config = makeSwitchingConfig(shortcut: shortcut)

        #expect(throws: VoiceInputCoordinatorError.validationFailed([
            .voiceSourceUnavailable(voice),
            .defaultSourceUnavailable(daily)
        ])) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: []
            )
        }
        #expect(engine.beginCount == 0)
    }

    @Test("a failed session recovers on the next shortcut press")
    func failedStateRecoversOnNextShortcut() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        sender.shouldFail = true
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .failed(.shortcutSendFailed))

        sender.shouldFail = false
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("a failed end tap still hands the input source back")
    func failedEndTapStillRestores() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        sender.shouldFail = true
        try? coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        // The voice input method may still be recording, but the user's typing
        // source must not be stranded there.
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
    }

    @Test("a switch failure cleans up the temporary override")
    func switchToVoiceFailureCleansUpOverride() {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)
        engine.failedSourceIDs = [voice]

        #expect(throws: VoiceInputCoordinatorError.switchToVoiceFailed(voice)) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
        }
        #expect(coordinator.state == .failed(.switchToVoiceFailed(voice)))
        #expect(engine.endCount == 1)
        #expect(sender.events.isEmpty)
    }

    @Test("ten consecutive switching sessions switch and restore exactly once each")
    func tenConsecutiveSessionsSendAndRestoreExactlyOnce() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)

        for _ in 0..<10 {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
            #expect(coordinator.state == .voiceActive)
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
            #expect(coordinator.state == .idle)
        }

        #expect(engine.beginCount == 10)
        #expect(engine.endCount == 10)
        #expect(sender.events.count == 20)
        #expect(engine.switches.count == 20)
    }

    @Test("an active session keeps using its own shortcut after the settings change")
    func activeSessionUsesShortcutSnapshotAfterSettingsClear() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler,
            sourceActivationDelay: 0.3
        )
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        // The user clears the shortcut mid-preparation; the session must still
        // send the key it started with.
        var cleared = config
        cleared.voiceShortcut = nil
        try scheduler.fire(at: 0)

        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("the restore timeout ends an active switching session")
    func restoreTimeoutEndsActiveVoiceSession() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .voiceActive)
        #expect(scheduler.delays == [60])

        try scheduler.fire(at: 0)
        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
    }

    @Test("a non-switching session still expires on the safety timeout")
    func nonSwitchingSessionExpiresOnTimeout() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(scheduler.delays == [60])

        // The timeout must also end the recording: there is no source to hand
        // back, so it sends the same end tap a second press would.
        try scheduler.fire(at: 0)
        #expect(coordinator.state == .idle)
        #expect(engine.switches.isEmpty)
        #expect(sender.events == [.tap(shortcut), .tap(shortcut)])
    }

    @Test("shutting down abandons the session without restoring the source")
    func stopActiveSessionDoesNotRestore() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        coordinator.stopActiveSession()

        #expect(engine.switches == [voice])
        #expect(engine.endCount == 1)
        #expect(!coordinator.isSessionInProgress)
    }

    private func makeConfig(
        shortcut: VoiceShortcut,
        behavior: VoiceInputBehavior
    ) -> VoiceInputConfiguration {
        VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut,
            behavior: behavior
        )
    }

    /// A configuration that *does* take over the input source.
    private func makeSwitchingConfig(shortcut: VoiceShortcut) -> VoiceInputConfiguration {
        VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut,
            behavior: .pressOncePressAgainEnds,
            switchesVoiceSourceAutomatically: true
        )
    }
}

@MainActor
final class RecordingVoiceOverrideEngine: VoiceInputSourceOverriding {
    private(set) var beginCount = 0
    private(set) var endCount = 0
    private(set) var switches: [InputSourceID] = []
    var switchResult = true
    var failedSourceIDs: Set<InputSourceID> = []
    var currentSourceID: InputSourceID?
    var updatesCurrentSourceOnSwitch = true
    private var nextToken = 0
    private var sourceDidChange: (@MainActor (InputSourceID?) -> Void)?

    init(currentSourceID: InputSourceID? = "daily.source") {
        self.currentSourceID = currentSourceID
    }

    func beginTemporaryInputSourceOverride(
        sourceDidChange: @escaping @MainActor (InputSourceID?) -> Void
    ) -> TemporaryInputSourceOverrideToken {
        beginCount += 1
        nextToken += 1
        self.sourceDidChange = sourceDidChange
        return TemporaryInputSourceOverrideToken(testGeneration: nextToken)
    }

    func temporaryOverrideSwitch(to id: InputSourceID) -> Bool {
        switches.append(id)
        let result = switchResult && !failedSourceIDs.contains(id)
        if result, updatesCurrentSourceOnSwitch {
            currentSourceID = id
        }
        return result
    }

    func endTemporaryInputSourceOverride(_ token: TemporaryInputSourceOverrideToken) {
        endCount += 1
        sourceDidChange = nil
    }

    func currentInputSourceID() -> InputSourceID? {
        currentSourceID
    }

    func emitSourceChange(_ sourceID: InputSourceID?) {
        currentSourceID = sourceID
        sourceDidChange?(sourceID)
    }
}

@MainActor
final class RecordingVoiceTimeoutScheduler: VoiceTimeoutScheduling {
    private(set) var delays: [TimeInterval] = []
    private var workItems: [@MainActor () -> Void] = []

    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        delays.append(seconds)
        workItems.append(work)
    }

    func fire(at index: Int = 0) throws {
        guard workItems.indices.contains(index) else { return }
        let work = workItems.remove(at: index)
        work()
    }
}
