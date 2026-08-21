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
}
