import Foundation
import Testing

@testable import LockIMEKit

@MainActor
@Suite("VoiceInputCoordinator")
struct VoiceInputCoordinatorTests {
    private let daily: InputSourceID = "daily.source"
    private let voice: InputSourceID = "voice.source"

    @Test("press once mode starts voice and second trigger restores daily source")
    func pressOnceModeStartsAndEnds() throws {
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

    @Test("direct mode performs no switch and sends no synthetic shortcut")
    func directModeIsNoOp() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = VoiceInputConfiguration(isEnabled: true, voiceSourceID: voice)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: voice,
            installedSources: [.stub(voice.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(engine.beginCount == 0)
        #expect(engine.switches.isEmpty)
        #expect(sender.events.isEmpty)
    }

    @Test("restore failure retries the latest valid default source")
    func restoreFailureUsesFallbackDefault() throws {
        let fallback: InputSourceID = "fallback.source"
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            fallbackRestoreSourceID: { fallback }
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue), .stub(fallback.rawValue)]
        )
        engine.failedSourceIDs.insert(daily)
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: fallback,
            installedSources: [.stub(voice.rawValue), .stub(fallback.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily, fallback])
        #expect(engine.endCount == 1)
    }

    @Test("state changes are reported to the host")
    func stateChangesAreReported() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)
        var states: [VoiceInputSessionState] = []
        coordinator.onStateChange = { states.append($0) }

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

        #expect(states.contains(.preparingVoice))
        #expect(states.contains(.voiceActive))
        #expect(states.last == .idle)
    }

    @Test("workflow waits until the voice source is current before sending shortcut")
    func workflowWaitsForVoiceSourceBeforeSendingShortcut() throws {
        let engine = RecordingVoiceOverrideEngine()
        engine.currentSourceID = daily
        engine.updatesCurrentSourceOnSwitch = false
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
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

        #expect(coordinator.state == .preparingVoice)
        #expect(engine.switches == [voice])
        #expect(sender.events.isEmpty)
        #expect(scheduler.delays == [0.5])

        engine.emitSourceChange(daily)
        #expect(coordinator.state == .preparingVoice)
        #expect(sender.events.isEmpty)

        engine.emitSourceChange(voice)

        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])

        engine.emitSourceChange(voice)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("workflow fails without sending when source selection is not confirmed")
    func workflowFailsWhenSourceSelectionIsNotConfirmed() throws {
        let engine = RecordingVoiceOverrideEngine()
        engine.currentSourceID = daily
        engine.updatesCurrentSourceOnSwitch = false
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
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
        #expect(scheduler.delays == [0.5])
        try scheduler.fire(at: 0)

        #expect(coordinator.state == .failed(.switchToVoiceFailed(voice)))
        #expect(engine.endCount == 1)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events.isEmpty)
    }

    @Test("shortcut send failure restores the default source once")
    func shortcutSendFailureRestoresDefaultOnce() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        sender.shouldFail = true
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .failed(.shortcutSendFailed))
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
    }

    @Test("any-key monitor failure restores the default source once")
    func anyKeyMonitorFailureRestoresDefaultOnce() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let monitor = RecordingShortcutEventMonitor()
        monitor.shouldFailStart = true
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler,
            eventMonitor: monitor
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try scheduler.fire(at: 1)

        #expect(coordinator.state == .failed(.eventMonitorStartFailed))
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
    }

    @Test("hold mode sends key down then key up and restores on release")
    func holdModeRestoresOnRelease() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .holdToSpeak)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try coordinator.handleWorkflowShortcutReleased(config: config)

        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events == [.keyDown(shortcut), .keyUp(shortcut)])
    }

    @Test("hold release during source preparation cancels activation and restores daily source")
    func holdReleaseDuringPreparationCancelsActivation() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        var cleanupCount = 0
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler,
            sourceActivationDelay: 0.3
        )
        coordinator.onSessionCleanup = { cleanupCount += 1 }
        let config = makeConfig(shortcut: shortcut, behavior: .holdToSpeak)

        #expect(!coordinator.isSessionInProgress)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .preparingVoice)
        #expect(coordinator.isSessionInProgress)

        try coordinator.handleWorkflowShortcutReleased(config: config)

        #expect(coordinator.state == .idle)
        #expect(!coordinator.isSessionInProgress)
        #expect(cleanupCount == 1)
        #expect(engine.switches == [voice, daily])
        #expect(engine.endCount == 1)
        #expect(sender.events.isEmpty)

        try scheduler.fire()
        #expect(sender.events.isEmpty)
    }

    @Test("any key mode restores daily source without sending the end shortcut")
    func anyKeyModeRestoresWithoutEndShortcut() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(coordinator.state == .preparingVoice)
        try scheduler.fire(at: 1)
        #expect(coordinator.state == .voiceActive)
        try coordinator.handleAnyKeyDuringVoice(config: config)

        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("any key mode ignores end events during activation grace")
    func anyKeyModeIgnoresEndEventsDuringActivationGrace() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try coordinator.handleAnyKeyDuringVoice(config: config)

        #expect(coordinator.state == .preparingVoice)
        #expect(engine.switches == [voice])
        #expect(engine.endCount == 0)
    }

    @Test("any key mode ends without restarting when the workflow shortcut is pressed again")
    func anyKeyModeEndsOnNextWorkflowShortcut() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler
        )
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try scheduler.fire(at: 1)
        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(engine.beginCount == 1)
        #expect(engine.endCount == 1)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("repeated workflow shortcut is ignored while voice source is preparing")
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
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

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

        #expect(coordinator.state == .preparingVoice)
        #expect(engine.beginCount == 1)
        #expect(engine.endCount == 0)
        #expect(engine.switches == [voice])

        engine.emitSourceChange(voice)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("production activation delay waits before sending the internal shortcut")
    func productionActivationDelayWaitsBeforeSending() throws {
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
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .preparingVoice)
        #expect(sender.events.isEmpty)
        #expect(scheduler.delays == [0.3])

        try scheduler.fire(at: 0)
        #expect(coordinator.state == .voiceActive)
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("restore timeout ends active voice session")
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
        let config = makeConfig(shortcut: shortcut, behavior: .pressOnceAnyKeyEnds)

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(scheduler.delays == [60, 0.8])

        try scheduler.fire(at: 1)
        #expect(coordinator.state == .voiceActive)

        try scheduler.fire(at: 0)
        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
    }

    @Test("any key event restores daily source after configured delay")
    func anyKeyEventRestoresAfterConfiguredDelay() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let scheduler = RecordingVoiceTimeoutScheduler()
        let monitor = RecordingShortcutEventMonitor()
        let shortcut = VoiceShortcut(keyCode: 62, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(
            overrideEngine: engine,
            sender: sender,
            timeoutScheduler: scheduler,
            eventMonitor: monitor
        )
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut,
            behavior: .pressOnceAnyKeyEnds,
            restoreDelay: .seconds(2)
        )

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        #expect(scheduler.delays == [60, 0.8])

        try scheduler.fire(at: 1)
        #expect(monitor.isStarted)
        monitor.emit(.anyKey)
        #expect(monitor.isStarted == false)
        #expect(scheduler.delays == [60, 0.8, 2])
        #expect(coordinator.state == .voiceActive)

        try scheduler.fire(at: 1)
        #expect(coordinator.state == .idle)
        #expect(engine.switches == [voice, daily])
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("validation failure does not begin temporary override")
    func validationFailureDoesNotBeginTemporaryOverride() {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = VoiceInputConfiguration(isEnabled: true)

        #expect(throws: VoiceInputCoordinatorError.validationFailed([
            .missingVoiceSource,
            .missingVoiceShortcut,
            .missingDefaultSource
        ])) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: nil,
                installedSources: []
            )
        }
        #expect(coordinator.state == .failed(.validationFailed([
            .missingVoiceSource,
            .missingVoiceShortcut,
            .missingDefaultSource
        ])))
        #expect(engine.beginCount == 0)
        #expect(engine.endCount == 0)
        #expect(sender.events.isEmpty)
    }

    @Test("disabled workflow does not begin temporary override")
    func disabledWorkflowDoesNotBeginTemporaryOverride() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = VoiceInputConfiguration(
            isEnabled: false,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 61, modifiers: [.option])
        )

        try coordinator.handleWorkflowShortcutPressed(
            config: config,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .idle)
        #expect(engine.beginCount == 0)
        #expect(engine.switches.isEmpty)
        #expect(sender.events.isEmpty)
    }

    @Test("failed state recovers on next workflow shortcut")
    func failedStateRecoversOnNextWorkflowShortcut() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)

        #expect(throws: VoiceInputCoordinatorError.validationFailed([
            .missingVoiceSource,
            .missingVoiceShortcut,
            .missingDefaultSource
        ])) {
            try coordinator.handleWorkflowShortcutPressed(
                config: VoiceInputConfiguration(isEnabled: true),
                restoreSourceID: nil,
                installedSources: []
            )
        }
        try coordinator.handleWorkflowShortcutPressed(
            config: makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds),
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )

        #expect(coordinator.state == .voiceActive)
        #expect(engine.switches == [voice])
        #expect(sender.events == [.tap(shortcut)])
    }

    @Test("switch to voice failure cleans up temporary override")
    func switchToVoiceFailureCleansUpTemporaryOverride() {
        let engine = RecordingVoiceOverrideEngine()
        engine.switchResult = false
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        #expect(throws: VoiceInputCoordinatorError.switchToVoiceFailed(voice)) {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
        }
        #expect(coordinator.state == .failed(.switchToVoiceFailed(voice)))
        #expect(engine.beginCount == 1)
        #expect(engine.endCount == 1)
        #expect(engine.switches == [voice])
        #expect(sender.events.isEmpty)
    }

    @Test("ten consecutive sessions each send and restore exactly once")
    func tenConsecutiveSessionsSendAndRestoreExactlyOnce() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let config = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)

        for _ in 0..<10 {
            try coordinator.handleWorkflowShortcutPressed(
                config: config,
                restoreSourceID: daily,
                installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
            )
            #expect(coordinator.state == .voiceActive)
            try coordinator.handleRestoreTimeout(config: config)
            #expect(coordinator.state == .idle)
        }

        #expect(engine.beginCount == 10)
        #expect(engine.endCount == 10)
        #expect(engine.switches == Array(repeating: [voice, daily], count: 10).flatMap { $0 })
        #expect(sender.events == Array(repeating: .tap(shortcut), count: 10))
    }

    @Test("active session uses its shortcut snapshot after settings are cleared")
    func activeSessionUsesShortcutSnapshotAfterSettingsClear() throws {
        let engine = RecordingVoiceOverrideEngine()
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let changedDefault: InputSourceID = "changed.default"
        let coordinator = VoiceInputCoordinator(overrideEngine: engine, sender: sender)
        let initial = makeConfig(shortcut: shortcut, behavior: .pressOncePressAgainEnds)
        let cleared = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: nil,
            behavior: .pressOncePressAgainEnds
        )

        try coordinator.handleWorkflowShortcutPressed(
            config: initial,
            restoreSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        )
        try coordinator.handleWorkflowShortcutPressed(
            config: cleared,
            restoreSourceID: changedDefault,
            installedSources: [
                .stub(daily.rawValue),
                .stub(voice.rawValue),
                .stub(changedDefault.rawValue)
            ]
        )

        #expect(coordinator.state == .idle)
        #expect(sender.events == [.tap(shortcut), .tap(shortcut)])
        #expect(engine.switches == [voice, daily])
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

@MainActor
final class RecordingShortcutEventMonitor: ShortcutEventMonitoring {
    private var handler: (@MainActor (ShortcutMonitorEvent) -> Void)?
    private(set) var isStarted = false
    var shouldFailStart = false

    func start(_ handler: @escaping @MainActor (ShortcutMonitorEvent) -> Void) throws {
        if shouldFailStart {
            throw ShortcutEventMonitorError.eventTapCreateFailed
        }
        self.handler = handler
        isStarted = true
    }

    func stop() {
        handler = nil
        isStarted = false
    }

    func emit(_ event: ShortcutMonitorEvent) {
        handler?(event)
    }
}
