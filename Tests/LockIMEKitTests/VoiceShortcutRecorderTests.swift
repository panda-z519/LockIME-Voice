import Testing

@testable import LockIMEKit

@Suite("VoiceShortcutRecorder")
struct VoiceShortcutRecorderTests {
    @Test("device-side flags correct external-keyboard modifier key codes")
    func deviceSideFlagsCorrectModifierKeyCodes() {
        #expect(VoiceShortcut.canonicalModifierKeyCode(
            eventKeyCode: 59,
            deviceFlagsRawValue: 0x0000_2000
        ) == 62)
        #expect(VoiceShortcut.canonicalModifierKeyCode(
            eventKeyCode: 58,
            deviceFlagsRawValue: 0x0000_0040
        ) == 61)
        #expect(VoiceShortcut.canonicalModifierKeyCode(
            eventKeyCode: 59,
            deviceFlagsRawValue: 0x0000_0001
        ) == 59)
    }

    @Test("shortcut display uses side-aware modifier glyphs")
    func shortcutDisplayUsesSideAwareModifierGlyphs() {
        #expect(VoiceShortcut(
            keyCode: 62,
            modifiers: [.control]
        ).displayText(leftLabel: "L", rightLabel: "R") == "R⌃")
        #expect(VoiceShortcut(
            keyCode: 58,
            modifiers: [.option]
        ).displayText(leftLabel: "L", rightLabel: "R") == "L⌥")
    }

    @Test("shortcut display compacts modifier combinations")
    func shortcutDisplayCompactsModifierCombinations() {
        #expect(VoiceShortcut(
            keyCode: 49,
            modifiers: [.control, .option]
        ).displayText(leftLabel: "L", rightLabel: "R") == "⌃⌥␣")
        #expect(VoiceShortcut(
            keyCode: 0,
            modifiers: [.command, .shift]
        ).displayText(leftLabel: "L", rightLabel: "R") == "⇧⌘A")
    }

    @Test("single modifier completes when the modifier is released")
    func singleModifierCompletesOnRelease() {
        var recorder = VoiceShortcutRecorder()

        #expect(recorder.handleModifierChange(keyCode: 61, modifiers: [.option]) == nil)
        #expect(recorder.handleModifierChange(keyCode: 61, modifiers: []) ==
            VoiceShortcut(keyCode: 61, modifiers: [.option]))
    }

    @Test("modifier followed by a regular key records the complete shortcut")
    func modifierAndRegularKeyRecordCompleteShortcut() {
        var recorder = VoiceShortcutRecorder()

        #expect(recorder.handleModifierChange(keyCode: 61, modifiers: [.option]) == nil)
        #expect(recorder.handleKeyDown(keyCode: 0, modifiers: [.option]) ==
            VoiceShortcut(keyCode: 0, modifiers: [.option]))
    }

    @Test("multiple modifiers wait for the regular key")
    func multipleModifiersWaitForRegularKey() {
        var recorder = VoiceShortcutRecorder()

        #expect(recorder.handleModifierChange(keyCode: 62, modifiers: [.control]) == nil)
        #expect(recorder.handleModifierChange(keyCode: 60, modifiers: [.control, .shift]) == nil)
        #expect(recorder.handleKeyDown(keyCode: 49, modifiers: [.control, .shift]) ==
            VoiceShortcut(keyCode: 49, modifiers: [.control, .shift]))
    }
}
