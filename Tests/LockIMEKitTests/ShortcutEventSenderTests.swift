import Testing

@testable import LockIMEKit

@MainActor
@Suite("ShortcutEventSender")
struct ShortcutEventSenderTests {
    @Test("recording sender captures tap down and up")
    func recordingSenderCapturesEvents() throws {
        let sender = RecordingShortcutEventSender()
        let shortcut = VoiceShortcut(keyCode: 49, modifiers: [.control, .option])

        try sender.sendTap(shortcut)
        try sender.sendKeyDown(shortcut)
        try sender.sendKeyUp(shortcut)

        #expect(sender.events == [
            .tap(shortcut),
            .keyDown(shortcut),
            .keyUp(shortcut)
        ])
    }

    @Test("modifier key release removes its own flag")
    func modifierKeyReleaseRemovesItsOwnFlag() {
        let rightOption = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let rightControlWithShift = VoiceShortcut(keyCode: 62, modifiers: [.control, .shift])

        #expect(rightOption.cgFlags(keyDown: true).contains(.maskAlternate))
        #expect(rightOption.cgFlags(keyDown: false).isEmpty)
        #expect(rightControlWithShift.cgFlags(keyDown: true).contains(.maskControl))
        #expect(rightControlWithShift.cgFlags(keyDown: true).contains(.maskShift))
        #expect(!rightControlWithShift.cgFlags(keyDown: false).contains(.maskControl))
        #expect(rightControlWithShift.cgFlags(keyDown: false).contains(.maskShift))
    }

    @Test("modifier tap uses flags changed events and a human length press")
    func modifierTapUsesFlagsChangedAndLongerPress() throws {
        let sender = CGShortcutEventSender()
        let rightOption = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let regularKey = VoiceShortcut(keyCode: 0, modifiers: [.option])

        #expect(try sender.makeEvent(rightOption, keyDown: true).type == .flagsChanged)
        #expect(try sender.makeEvent(rightOption, keyDown: false).type == .flagsChanged)
        #expect(CGShortcutEventSender.tapDelayMicroseconds(for: rightOption) >= 80_000)
        #expect(CGShortcutEventSender.tapDelayMicroseconds(for: regularKey) == 20_000)
    }
}

@MainActor
final class RecordingShortcutEventSender: ShortcutEventSending {
    enum Event: Equatable {
        case tap(VoiceShortcut)
        case keyDown(VoiceShortcut)
        case keyUp(VoiceShortcut)
    }

    private(set) var events: [Event] = []
    var shouldFail = false

    func sendTap(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw ShortcutEventSenderError.eventCreationFailed }
        events.append(.tap(shortcut))
    }

    func sendKeyDown(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw ShortcutEventSenderError.eventCreationFailed }
        events.append(.keyDown(shortcut))
    }

    func sendKeyUp(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw ShortcutEventSenderError.eventCreationFailed }
        events.append(.keyUp(shortcut))
    }
}
