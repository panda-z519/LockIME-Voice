import CoreGraphics
import Foundation

public struct VoiceShortcut: Codable, Sendable, Equatable, Hashable {
    public struct Modifiers: OptionSet, Codable, Sendable, Equatable, Hashable {
        public let rawValue: Int

        public static let command = Self(rawValue: 1 << 0)
        public static let control = Self(rawValue: 1 << 1)
        public static let option = Self(rawValue: 1 << 2)
        public static let shift = Self(rawValue: 1 << 3)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var cgKeyCode: CGKeyCode {
        CGKeyCode(keyCode)
    }

    public var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }

    var modifierKey: Modifiers {
        switch keyCode {
        case 54, 55:
            .command
        case 56, 60:
            .shift
        case 58, 61:
            .option
        case 59, 62:
            .control
        default:
            []
        }
    }

    func cgFlags(keyDown: Bool) -> CGEventFlags {
        guard !keyDown, !modifierKey.isEmpty else { return cgFlags }
        var releaseModifiers = modifiers
        releaseModifiers.remove(modifierKey)
        return VoiceShortcut(keyCode: keyCode, modifiers: releaseModifiers).cgFlags
    }

    public var isModifierKey: Bool {
        !modifierKey.isEmpty
    }

    /// The device-dependent flag bits a real keyboard sets alongside the
    /// device-independent ones: which *side* each held modifier is on. Input
    /// methods that bind "right ⌥" tell it apart from left ⌥ only by these bits,
    /// so an echo without them is not recognized as the voice key at all.
    /// Modifiers held together with the key are reported as their left-hand
    /// keys, as a keyboard would for the common case.
    func deviceFlagBits(keyDown: Bool) -> UInt64 {
        var bits: UInt64 = 0
        var others = modifiers
        if isModifierKey {
            others.remove(modifierKey)
            if keyDown { bits |= Self.deviceBit(forModifierKeyCode: keyCode) }
        }
        if others.contains(.control) { bits |= 0x0000_0001 }
        if others.contains(.shift) { bits |= 0x0000_0002 }
        if others.contains(.command) { bits |= 0x0000_0008 }
        if others.contains(.option) { bits |= 0x0000_0020 }
        return bits
    }

    private static func deviceBit(forModifierKeyCode keyCode: UInt16) -> UInt64 {
        switch keyCode {
        case 59: 0x0000_0001  // left ⌃
        case 62: 0x0000_2000  // right ⌃
        case 56: 0x0000_0002  // left ⇧
        case 60: 0x0000_0004  // right ⇧
        case 55: 0x0000_0008  // left ⌘
        case 54: 0x0000_0010  // right ⌘
        case 58: 0x0000_0020  // left ⌥
        case 61: 0x0000_0040  // right ⌥
        default: 0
        }
    }

    /// Keys the hardware reports with the secondary-Fn flag set: F1–F20, the
    /// arrows, and the Home/End/Page/Forward-Delete/Help block.
    var isFunctionRowKey: Bool {
        Self.functionRowKeyCodes.contains(keyCode)
    }

    private static let functionRowKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,  // F1–F12
        105, 107, 113, 106, 64, 79, 80, 90,                      // F13–F20
        123, 124, 125, 126,                                      // arrows
        115, 119, 116, 121, 117, 114,                            // Home End PgUp PgDn ⌦ Help
    ]

    public static func canonicalModifierKeyCode(
        eventKeyCode: UInt16,
        deviceFlagsRawValue: UInt64
    ) -> UInt16 {
        switch eventKeyCode {
        case 59, 62:
            if deviceFlagsRawValue & 0x0000_2000 != 0 { return 62 }
            if deviceFlagsRawValue & 0x0000_0001 != 0 { return 59 }
        case 56, 60:
            if deviceFlagsRawValue & 0x0000_0004 != 0 { return 60 }
            if deviceFlagsRawValue & 0x0000_0002 != 0 { return 56 }
        case 54, 55:
            if deviceFlagsRawValue & 0x0000_0010 != 0 { return 54 }
            if deviceFlagsRawValue & 0x0000_0008 != 0 { return 55 }
        case 58, 61:
            if deviceFlagsRawValue & 0x0000_0040 != 0 { return 61 }
            if deviceFlagsRawValue & 0x0000_0020 != 0 { return 58 }
        default:
            break
        }
        return eventKeyCode
    }

    public func displayText(leftLabel: String, rightLabel: String) -> String {
        if let modifierKeyText = modifierKeyText(
            leftLabel: leftLabel,
            rightLabel: rightLabel
        ) {
            return modifierKeyText
        }
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyText(keyCode)
    }

    private func modifierKeyText(leftLabel: String, rightLabel: String) -> String? {
        switch keyCode {
        case 54: rightLabel + "⌘"
        case 55: leftLabel + "⌘"
        case 56: leftLabel + "⇧"
        case 60: rightLabel + "⇧"
        case 58: leftLabel + "⌥"
        case 61: rightLabel + "⌥"
        case 59: leftLabel + "⌃"
        case 62: rightLabel + "⌃"
        default: nil
        }
    }

    private static func keyText(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 30: "]"
        case 31: "O"
        case 32: "U"
        case 33: "["
        case 34: "I"
        case 35: "P"
        case 36: "↩"
        case 37: "L"
        case 38: "J"
        case 39: "'"
        case 40: "K"
        case 41: ";"
        case 42: "\\"
        case 43: ","
        case 44: "/"
        case 45: "N"
        case 46: "M"
        case 47: "."
        case 48: "⇥"
        case 49: "␣"
        case 50: "`"
        case 51: "⌫"
        case 53: "⎋"
        case 63: "fn"
        case 179: "fn"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: "#\(keyCode)"
        }
    }
}

public struct VoiceShortcutRecorder {
    private var pendingModifierShortcut: VoiceShortcut?

    public init() {}

    public mutating func handleKeyDown(
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers
    ) -> VoiceShortcut {
        pendingModifierShortcut = nil
        return VoiceShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    public mutating func handleModifierChange(
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers
    ) -> VoiceShortcut? {
        let changedModifier = VoiceShortcut(keyCode: keyCode).modifierKey
        guard !changedModifier.isEmpty else { return nil }
        if modifiers.contains(changedModifier) {
            pendingModifierShortcut = VoiceShortcut(keyCode: keyCode, modifiers: modifiers)
            return nil
        }
        defer { pendingModifierShortcut = nil }
        return pendingModifierShortcut
    }

    public mutating func reset() {
        pendingModifierShortcut = nil
    }
}

public extension VoiceShortcut.Modifiers {
    init(_ flags: CGEventFlags) {
        self.init()
        if flags.contains(.maskCommand) { insert(.command) }
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
    }

    /// The Carbon modifier mask (`cmdKey` / `controlKey` / `optionKey` /
    /// `shiftKey`) for this set — the representation `KeyboardShortcuts` stores.
    var carbonFlags: Int {
        var flags = 0
        if contains(.command) { flags |= 1 << 8 }   // cmdKey
        if contains(.shift) { flags |= 1 << 9 }     // shiftKey
        if contains(.option) { flags |= 1 << 11 }   // optionKey
        if contains(.control) { flags |= 1 << 12 }  // controlKey
        return flags
    }
}

public extension VoiceShortcut {
    /// The Fn / 🌐 key. macOS reports it as key code 63 with no modifiers.
    static let functionKey = VoiceShortcut(keyCode: 63)

    /// Whether this shortcut is the Fn / 🌐 key — a key macOS reserves for
    /// itself, so binding it inside an input method both collides with the
    /// system's own handling and prompts about a shortcut conflict.
    var isFunctionKey: Bool {
        keyCode == 63 || keyCode == 179
    }
}
