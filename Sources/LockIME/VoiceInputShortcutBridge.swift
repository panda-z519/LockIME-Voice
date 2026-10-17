import KeyboardShortcuts
import LockIMEKit

/// Bridges the two shortcut representations.
///
/// `KeyboardShortcuts` stores what its in-app recorder captures (a Carbon key
/// code plus a Carbon modifier mask); the voice session sends CGEvent-based
/// shortcuts. Carbon and CoreGraphics share the same virtual key codes, so only
/// the modifier representation needs translating — and getting it wrong would
/// silently drop a modifier from a synthesized voice key.
extension VoiceShortcut {
    /// Build the CGEvent form from a recorded `KeyboardShortcuts.Shortcut`.
    init(recorded shortcut: KeyboardShortcuts.Shortcut) {
        var converted: Modifiers = []
        if shortcut.modifiers.contains(.command) { converted.insert(.command) }
        if shortcut.modifiers.contains(.control) { converted.insert(.control) }
        if shortcut.modifiers.contains(.option) { converted.insert(.option) }
        if shortcut.modifiers.contains(.shift) { converted.insert(.shift) }
        self.init(keyCode: UInt16(shortcut.carbonKeyCode), modifiers: converted)
    }
}
