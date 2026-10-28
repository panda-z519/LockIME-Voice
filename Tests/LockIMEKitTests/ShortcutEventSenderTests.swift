import CoreGraphics
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
@Suite("Echoed key fidelity")
struct EchoedKeyFidelityTests {
    @Test("a right-hand modifier echo carries the right-side device bit")
    func rightOptionCarriesItsSide() throws {
        // Input methods bind "right ⌥" by these bits; without them the echo is
        // just "⌥" and the voice key never fires.
        let rightOption = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let down = try CGShortcutEventSender().makeEvent(rightOption, keyDown: true)
        let up = try CGShortcutEventSender().makeEvent(rightOption, keyDown: false)
        #expect(down.flags.rawValue & 0x40 != 0)
        #expect(down.flags.contains(.maskAlternate))
        #expect(up.flags.rawValue & 0x40 == 0)
        #expect(!up.flags.contains(.maskAlternate))
    }

    @Test("each side maps to its own device bit")
    func deviceBitsPerSide() {
        #expect(VoiceShortcut(keyCode: 58, modifiers: [.option]).deviceFlagBits(keyDown: true) == 0x20)
        #expect(VoiceShortcut(keyCode: 54, modifiers: [.command]).deviceFlagBits(keyDown: true) == 0x10)
        #expect(VoiceShortcut(keyCode: 62, modifiers: [.control]).deviceFlagBits(keyDown: true) == 0x2000)
        #expect(VoiceShortcut(keyCode: 60, modifiers: [.shift]).deviceFlagBits(keyDown: true) == 0x04)
        // A combination reports its modifiers as left-hand keys, like a keyboard.
        #expect(VoiceShortcut(keyCode: 9, modifiers: [.control, .option]).deviceFlagBits(keyDown: true) == 0x21)
    }

    @Test("an F-key echo is tagged secondary-Fn like the hardware event")
    func functionKeyCarriesFnFlag() throws {
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(try CGShortcutEventSender().makeEvent(f13, keyDown: true).flags.contains(.maskSecondaryFn))
        let letter = VoiceShortcut(keyCode: 9, modifiers: [.control])
        #expect(try !CGShortcutEventSender().makeEvent(letter, keyDown: true).flags.contains(.maskSecondaryFn))
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
    /// Which failure to raise while `shouldFail` is set, so a test can pin how a
    /// permission problem is reported versus any other send failure.
    var failure: ShortcutEventSenderError = .eventCreationFailed

    func sendTap(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw failure }
        events.append(.tap(shortcut))
    }

    func sendKeyDown(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw failure }
        events.append(.keyDown(shortcut))
    }

    func sendKeyUp(_ shortcut: VoiceShortcut) throws {
        if shouldFail { throw failure }
        events.append(.keyUp(shortcut))
    }
}
