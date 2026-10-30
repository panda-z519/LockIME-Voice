import CoreGraphics
import Testing

@testable import LockIMEKit

/// The consuming voice-key tap is what removes the conflict: it *takes* the key
/// so the input method never sees the physical press, and LockIME then echoes the
/// same key back. These tests drive the tap's real decision (`VoiceKeyMatcher`)
/// and pin the properties that make that safe — anything else would reintroduce
/// the conflict (letting the key through), an infinite loop (reacting to our own
/// output), or swallow ordinary typing.
@Suite("Voice key consumption")
struct VoiceKeyMonitoringTests {
    private enum Step {
        case down(UInt16, VoiceShortcut.Modifiers = [], repeat: Bool = false, marked: Bool = false)
        case up(UInt16, VoiceShortcut.Modifiers = [])
        case flags(UInt16, VoiceShortcut.Modifiers)
    }

    /// Feeds `steps` through one matcher and returns each decision.
    private func run(
        _ shortcut: VoiceShortcut,
        _ steps: [Step],
        yield: Bool = false,
        interruptsOnTyping: Bool = false
    ) -> [VoiceKeyMatcher.Decision] {
        var matcher = VoiceKeyMatcher(shortcut: shortcut)
        return steps.map { step in
            switch step {
            case let .down(key, modifiers, isRepeat, marked):
                matcher.decide(
                    kind: .keyDown, keyCode: key, modifiers: modifiers,
                    isAutorepeat: isRepeat, isMarked: marked, yield: { yield },
                    interruptsOnTyping: interruptsOnTyping
                )
            case let .up(key, modifiers):
                matcher.decide(
                    kind: .keyUp, keyCode: key, modifiers: modifiers,
                    isAutorepeat: false, isMarked: false, yield: { yield },
                    interruptsOnTyping: interruptsOnTyping
                )
            case let .flags(key, modifiers):
                matcher.decide(
                    kind: .flagsChanged, keyCode: key, modifiers: modifiers,
                    isAutorepeat: false, isMarked: false, yield: { yield }
                )
            }
        }
    }

    private let pressed = VoiceKeyMatcher.Decision(consume: true, event: .pressed)
    private let released = VoiceKeyMatcher.Decision(consume: true, event: .released)

    @Test("the physical voice key is consumed so the input method cannot react")
    func voiceKeyIsConsumed() {
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(105), .up(105)]) == [pressed, released])
    }

    @Test("LockIME's own synthesized key is never consumed")
    func synthesizedKeyPassesThrough() {
        // If this failed, LockIME would treat its own echoed key as a new press
        // and the session would toggle forever.
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(105, marked: true)]) == [.pass])
    }

    @Test("ordinary typing and other shortcuts are untouched")
    func otherKeysPassThrough() {
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(0), .up(0), .down(49, [.command])]) == [.pass, .pass, .pass])
    }

    @Test("a modified voice key needs exactly its own modifiers")
    func modifiersMustMatchExactly() {
        let controlOptionV = VoiceShortcut(keyCode: 9, modifiers: [.control, .option])
        #expect(run(controlOptionV, [.down(9, [.control, .option])]) == [pressed])
        // Plain "V" — the bug where every typed v was swallowed.
        #expect(run(controlOptionV, [.down(9)]) == [.pass])
        #expect(run(controlOptionV, [.down(9, [.control])]) == [.pass])
        // ⌃⌥⇧V is a different shortcut; it belongs to whoever registered it.
        #expect(run(controlOptionV, [.down(9, [.control, .option, .shift])]) == [.pass])
    }

    @Test("auto-repeat is swallowed but reports no extra press")
    func autoRepeatIsSwallowed() {
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(105), .down(105, repeat: true), .up(105)]) == [
            pressed, .swallow, released,
        ])
    }

    @Test("a lost key-up never leaves the next press dead")
    func freshPressAfterLostKeyUp() {
        // The tap can miss a key-up (disabled by timeout, Secure Input). The next
        // real key-down is not an auto-repeat, so it must still start a press.
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(105), .down(105)]) == [pressed, pressed])
    }

    @Test("releasing a modifier before the key still closes the press")
    func keyUpMatchesOnKeyCodeAlone() {
        let controlOptionV = VoiceShortcut(keyCode: 9, modifiers: [.control, .option])
        #expect(run(controlOptionV, [.down(9, [.control, .option]), .up(9, [.option])]) == [
            pressed, released,
        ])
    }

    @Test("a key-up whose key-down was not taken is left alone")
    func unownedKeyUpPassesThrough() {
        // Otherwise the input method would get a key-down with no key-up.
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.up(105)]) == [.pass])
    }

    @Test("while the recorder is reading keys nothing is taken")
    func recorderGetsTheKey() {
        let f13 = VoiceShortcut(keyCode: 105)
        #expect(run(f13, [.down(105), .up(105)], yield: true) == [.pass, .pass])
    }

    @Test("reset forgets a press in flight")
    func resetForgetsPress() {
        var matcher = VoiceKeyMatcher(shortcut: VoiceShortcut(keyCode: 105))
        _ = matcher.decide(
            kind: .keyDown, keyCode: 105, modifiers: [],
            isAutorepeat: false, isMarked: false, yield: { false }
        )
        #expect(matcher.isDown)
        matcher.reset()
        #expect(!matcher.isDown)
    }

    @Test("a bare modifier voice key matches only its own side")
    func bareModifierMatchesItsOwnSideOnly() {
        // macOS reports left/right as different key codes (58/61). The user
        // recorded one of them; the other is an ordinary modifier they type
        // shortcuts with, and taking it as the voice key was the reported bug.
        let rightOption = VoiceShortcut(keyCode: 61, modifiers: [.option])
        #expect(rightOption.isModifierKey)
        #expect(run(rightOption, [.flags(61, [.option]), .flags(61, [])]) == [pressed, released])
        #expect(run(rightOption, [.flags(58, [.option]), .flags(58, [])]) == [.pass, .pass])
        #expect(run(rightOption, [.flags(59, [.control])]) == [.pass])

        let leftCommand = VoiceShortcut(keyCode: 55, modifiers: [.command])
        #expect(run(leftCommand, [.flags(54, [.command]), .flags(54, [])]) == [.pass, .pass])
        #expect(run(leftCommand, [.flags(55, [.command]), .flags(55, [])]) == [pressed, released])
    }

    @Test("releasing the voice side is seen even while the other side is held")
    func ownSideReleaseUsesDeviceBits() {
        // Left ⌘ is the voice key; right ⌘ goes down meanwhile and stays down.
        // The device-independent ⌘ flag never clears, so only the side's own
        // device bit tells that left ⌘ came back up.
        var matcher = VoiceKeyMatcher(shortcut: VoiceShortcut(keyCode: 55, modifiers: [.command]))
        func flags(_ key: UInt16, _ device: UInt64) -> VoiceKeyMatcher.Decision {
            matcher.decide(
                kind: .flagsChanged, keyCode: key, modifiers: [.command],
                isAutorepeat: false, isMarked: false, yield: { false },
                deviceFlags: device
            )
        }
        #expect(flags(55, 0x08) == pressed)
        #expect(flags(54, 0x18) == .pass)
        #expect(flags(55, 0x10) == released)
    }

/// While a session owns the input source, any other key ends voice input. The
/// tap is the only thing that sees those keystrokes, so it reports them — and
/// consumes them, or they would overwrite the text still being recognized.
@Suite("Typing interrupts a voice session")
struct VoiceTypingInterruptTests {
    private let voiceKey = VoiceShortcut(keyCode: 49, modifiers: [.option])

    @Test("a key pressed during a session is reported and consumed")
    func typingIsReportedAndConsumed() {
        var matcher = VoiceKeyMatcher(shortcut: voiceKey)
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 0, modifiers: [],
            isAutorepeat: false, isMarked: false,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == .otherKeyDown)
        // Passed on, it would land in the voice input method mid-recognition
        // and replace the recognized text.
        #expect(decision.consume)
    }

    @Test("the same letter without the voice modifiers counts as typing")
    func plainLetterIsTyping() {
        var matcher = VoiceKeyMatcher(shortcut: VoiceShortcut(keyCode: 9, modifiers: [.control, .option]))
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 9, modifiers: [],
            isAutorepeat: false, isMarked: false,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == .otherKeyDown)
        #expect(decision.consume)
    }

    @Test("a bare-modifier voice key still sees typing")
    func bareModifierShortcutSeesTyping() {
        // The regression that mattered in practice: right ⌘ is a *modifier* key,
        // so its branch in the matcher only handled flagsChanged and returned
        // early for key-downs — ordinary typing was never reported and the
        // session ran until the safety timeout instead of ending on the first
        // keystroke.
        var matcher = VoiceKeyMatcher(shortcut: VoiceShortcut(keyCode: 54, modifiers: [.command]))
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 0, modifiers: [.command],
            isAutorepeat: false, isMarked: false,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == .otherKeyDown)
        #expect(decision.consume)
    }

    @Test("the voice key itself is never reported as typing")
    func voiceKeyIsNotTyping() {
        var matcher = VoiceKeyMatcher(shortcut: voiceKey)
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 49, modifiers: [.option],
            isAutorepeat: false, isMarked: false,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == .pressed)
        #expect(decision.consume)
    }

    @Test("our own echoed key is never reported as typing")
    func echoIsNotTyping() {
        var matcher = VoiceKeyMatcher(shortcut: voiceKey)
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 0, modifiers: [],
            isAutorepeat: false, isMarked: true,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == nil)
        #expect(!decision.consume)
    }

    @Test("modifier presses are not typing")
    func modifierChangesAreNotTyping() {
        var matcher = VoiceKeyMatcher(shortcut: voiceKey)
        let decision = matcher.decide(
            kind: .flagsChanged, keyCode: 56, modifiers: [.shift],
            isAutorepeat: false, isMarked: false,
            yield: { false }, interruptsOnTyping: true
        )
        #expect(decision.event == nil)
    }

    @Test("with no session active nothing is reported")
    func noSessionReportsNothing() {
        var matcher = VoiceKeyMatcher(shortcut: voiceKey)
        let decision = matcher.decide(
            kind: .keyDown, keyCode: 0, modifiers: [],
            isAutorepeat: false, isMarked: false,
            yield: { false }
        )
        #expect(decision.event == nil)
        #expect(!decision.consume)
    }
}

}
