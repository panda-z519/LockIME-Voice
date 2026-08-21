import CoreGraphics
import Foundation

public enum ShortcutEventSenderError: Error, Equatable {
    case eventCreationFailed
}

@MainActor
public protocol ShortcutEventSending: AnyObject {
    func sendTap(_ shortcut: VoiceShortcut) throws
    func sendKeyDown(_ shortcut: VoiceShortcut) throws
    func sendKeyUp(_ shortcut: VoiceShortcut) throws
}

@MainActor
public final class CGShortcutEventSender: ShortcutEventSending {
    public init() {}

    public func sendTap(_ shortcut: VoiceShortcut) throws {
        try sendKeyDown(shortcut)
        usleep(Self.tapDelayMicroseconds(for: shortcut))
        try sendKeyUp(shortcut)
    }

    public func sendKeyDown(_ shortcut: VoiceShortcut) throws {
        let event = try makeEvent(shortcut, keyDown: true)
        event.post(tap: .cghidEventTap)
    }

    public func sendKeyUp(_ shortcut: VoiceShortcut) throws {
        let event = try makeEvent(shortcut, keyDown: false)
        event.post(tap: .cghidEventTap)
    }

    static func tapDelayMicroseconds(for shortcut: VoiceShortcut) -> useconds_t {
        shortcut.isModifierKey ? 80_000 : 20_000
    }

    func makeEvent(_ shortcut: VoiceShortcut, keyDown: Bool) throws -> CGEvent {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shortcut.cgKeyCode,
            keyDown: keyDown
        ) else {
            throw ShortcutEventSenderError.eventCreationFailed
        }
        if shortcut.isModifierKey {
            event.type = .flagsChanged
        }
        event.flags = shortcut.cgFlags(keyDown: keyDown)
        ShortcutEventMarker.mark(event)
        return event
    }
}
