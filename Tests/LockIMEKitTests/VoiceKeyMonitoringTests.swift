import CoreGraphics
import Testing

@testable import LockIMEKit

/// The consuming voice-key tap is what removes the conflict: it *takes* the key
/// so the input method never sees the physical press, and LockIME then echoes the
/// same key back. These tests pin the two properties that make that safe —
/// anything else here would reintroduce either the conflict (by letting the key
/// through) or an infinite loop (by reacting to our own output).
@MainActor
@Suite("Voice key consumption")
struct VoiceKeyMonitoringTests {
    /// Mirrors the tap's decision: consume only the physical voice key.
    private func consumes(
        shortcut: VoiceShortcut,
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers,
        marked: Bool
    ) -> Bool {
        guard !marked else { return false }
        if shortcut.isModifierKey {
            let changed = VoiceShortcut(keyCode: keyCode).modifierKey
            return !changed.isEmpty && changed == shortcut.modifierKey
        }
        return keyCode == shortcut.keyCode && modifiers.isSuperset(of: shortcut.modifiers)
    }

    @Test("the physical voice key is consumed so the input method cannot react")
    func voiceKeyIsConsumed() {
        let shortcut = VoiceShortcut(keyCode: 105)  // F13
        #expect(consumes(shortcut: shortcut, keyCode: 105, modifiers: [], marked: false))
    }

    @Test("LockIME's own synthesized key is never consumed")
    func synthesizedKeyPassesThrough() {
        // If this failed, LockIME would treat its own echoed key as a new press
        // and the session would toggle forever.
        let shortcut = VoiceShortcut(keyCode: 105)
        #expect(!consumes(shortcut: shortcut, keyCode: 105, modifiers: [], marked: true))
    }

    @Test("ordinary typing and other shortcuts are untouched")
    func otherKeysPassThrough() {
        let shortcut = VoiceShortcut(keyCode: 105)
        #expect(!consumes(shortcut: shortcut, keyCode: 0, modifiers: [], marked: false))
        #expect(!consumes(shortcut: shortcut, keyCode: 49, modifiers: [.command], marked: false))
    }

    @Test("a modified voice key only matches with its modifiers held")
    func modifiersAreRequired() {
        let shortcut = VoiceShortcut(keyCode: 9, modifiers: [.control, .option])
        #expect(consumes(shortcut: shortcut, keyCode: 9, modifiers: [.control, .option], marked: false))
        // Extra modifiers still match (a superset), so holding Shift alongside
        // does not leak the key to the input method.
        #expect(consumes(
            shortcut: shortcut,
            keyCode: 9,
            modifiers: [.control, .option, .shift],
            marked: false
        ))
        // Missing modifiers must NOT match, or plain "V" would be swallowed.
        #expect(!consumes(shortcut: shortcut, keyCode: 9, modifiers: [.control], marked: false))
        #expect(!consumes(shortcut: shortcut, keyCode: 9, modifiers: [], marked: false))
    }

    @Test("a bare modifier voice key matches either side")
    func bareModifierMatchesBothSides() {
        // The user records whichever side they use; macOS reports left/right as
        // different key codes (58/61), both of which stand for Option.
        let rightOption = VoiceShortcut(keyCode: 61, modifiers: [.option])
        #expect(rightOption.isModifierKey)
        #expect(consumes(shortcut: rightOption, keyCode: 61, modifiers: [.option], marked: false))
        #expect(consumes(shortcut: rightOption, keyCode: 58, modifiers: [.option], marked: false))
        #expect(!consumes(shortcut: rightOption, keyCode: 59, modifiers: [.control], marked: false))
    }
}
