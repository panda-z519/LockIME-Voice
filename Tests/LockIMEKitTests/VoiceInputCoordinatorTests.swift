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

    @Test("without switching the key is mirrored and no session is kept")
    func nonSwitchingSessionLeavesTheInputSourceAlone() throws {
        // The conflict-free setup: each press only re-sends the input method's
        // own voice key. No override, no switching, nothing to restore — and no
        // session state that could drift from what the input method is doing.
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
        #expect(coordinator.state == .idle)
        #expect(sender.events == [.keyDown(shortcut)])
        coordinator.handleWorkflowShortcutReleased()
        #expect(sender.events == [.keyDown(shortcut), .keyUp(shortcut)])

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        coordinator.handleWorkflowShortcutReleased()
        #expect(coordinator.state == .idle)
        #expect(sender.events == [
            .keyDown(shortcut), .keyUp(shortcut), .keyDown(shortcut), .keyUp(shortcut),
        ])

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

        #expect(coordinator.state == .idle)
        #expect(sender.events == [.keyDown(shortcut)])
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
        let config = makeSwitchingConfig(shortcut: shortcut)

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
        let config = makeSwitchingConfig(shortcut: shortcut)

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

        #expect(states == [
            .preparingVoice, .voiceActive, .endingVoice, .restoringDefaultInput, .idle,
        ])
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

    @Test("macOS refusing to post our key is reported as a permission problem")
    func postingUnavailableIsReportedAsPermission() throws {
        // Not interchangeable with a generic send failure: only this one is fixed
        // by granting Accessibility, so a user told "the workflow failed" cannot
        // act on it. `CGEvent.post` returns no error, which is why the sender
        // preflights the grant instead.
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeSwitchingConfig(shortcut: shortcut)
        sender.shouldFail = true
        sender.failure = .postingUnavailable

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .failed(.eventPostingUnavailable))
        // The source is still handed back: the session never reached the input
        // method, so leaving the user on the voice source would strand them.
        #expect(engine.switches == [voice, daily])
    }

    @Test("typing during a session hands the input source back without sending a key")
    func typingInterruptRestoresWithoutKey() throws {
        // The escape hatch when the input method never started recording (no
        // microphone, or its mic permission denied): the user types, and has to be
        // back on their text input instead of waiting for the safety timeout.
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

        try coordinator.handleTypingInterrupt()

        #expect(coordinator.state == .idle)
        // No end tap: a blind toggle would RESTART a recording the input method
        // may have already stopped, and there is nothing to stop when it never
        // started at all.
        #expect(sender.events == [.tap(shortcut)])
        #expect(engine.switches == [voice, daily])
    }

    @Test("a typing interrupt without a live session does nothing")
    func typingInterruptIsInertWhenIdle() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)

        try coordinator.handleTypingInterrupt()

        #expect(coordinator.state == .idle)
        #expect(sender.events.isEmpty)
        #expect(engine.switches.isEmpty)
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
        #expect(coordinator.state == .idle)
        #expect(sender.events == [.keyDown(shortcut)])
    }

    @Test("a lost release never leaves the mirrored key stuck down")
    func lostReleaseIsLiftedBeforeTheNextPress() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)
        let installed: [InputSource] = [.stub(daily.rawValue)]

        try coordinator.handleWorkflowShortcutPressed(
            config: config, restoreSourceID: daily, installedSources: installed
        )
        try coordinator.handleWorkflowShortcutPressed(
            config: config, restoreSourceID: daily, installedSources: installed
        )
        #expect(sender.events == [.keyDown(shortcut), .keyUp(shortcut), .keyDown(shortcut)])

        coordinator.stopActiveSession()
        #expect(sender.events.last == .keyUp(shortcut))
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

    @Test("without switching no safety timeout is armed, so nothing fires later")
    func nonSwitchingPressArmsNoTimeout() throws {
        // A blind toggle 60 s later would switch the microphone back on whenever
        // the input method had already stopped by itself.
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
        #expect(scheduler.delays.isEmpty)
        #expect(sender.events == [.keyDown(shortcut)])
    }

    @Test("the switching timeout restores the source without sending a key")
    func switchingTimeoutSendsNoKey() throws {
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
        try scheduler.fire(at: 0)
        #expect(coordinator.state == .idle)
        #expect(sender.events == [.tap(shortcut)])
        #expect(engine.switches == [voice, daily])
    }

    @Test("ending a switching session waits the restore delay before switching back")
    func endingWaitsRestoreDelay() throws {
        // The input method needs a moment to commit the recognized text; taking
        // the source away at once can drop it or deliver the end key elsewhere.
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        var config = makeSwitchingConfig(shortcut: shortcut)
        config.restoreDelay = .seconds(2)
        let installed: [InputSource] = [.stub(daily.rawValue), .stub(voice.rawValue)]

        try coordinator.handleWorkflowShortcutPressed(
            config: config, restoreSourceID: daily, installedSources: installed
        )
        try coordinator.handleWorkflowShortcutPressed(
            config: config, restoreSourceID: daily, installedSources: installed
        )
        #expect(sender.events == [.tap(shortcut), .tap(shortcut)])
        #expect(coordinator.state == .restoringDefaultInput)
        #expect(engine.switches == [voice])
        #expect(engine.endCount == 0)
        #expect(scheduler.delays == [60, 2])

        // The stale safety timeout (index 0) must not act on the ending session.
        try scheduler.fire(at: 0)
        #expect(engine.switches == [voice])

        try scheduler.fire(at: 0)
        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
    }

    @Test("a press during the restore delay starts a fresh session")
    func pressDuringRestoreDelayRestarts() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        var config = makeSwitchingConfig(shortcut: shortcut)
        config.restoreDelay = .seconds(2)
        let installed: [InputSource] = [.stub(daily.rawValue), .stub(voice.rawValue)]

        for _ in 0..<3 {
            try coordinator.handleWorkflowShortcutPressed(
                config: config, restoreSourceID: daily, installedSources: installed
            )
        }
        #expect(coordinator.state == .voiceActive)
        #expect(sender.events.count == 3)

        // The delayed restore from the previous session is now stale.
        try scheduler.fire(at: 1)
        #expect(coordinator.state == .voiceActive)
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
            switchesVoiceSourceAutomatically: true,
            restoreDelay: .seconds(0)
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
