import ApplicationServices
import CoreGraphics
import Foundation

public enum ShortcutEventSenderError: Error, Equatable {
    case eventCreationFailed
    /// macOS will not let this process post synthetic key events (the
    /// Accessibility / "post event" grant is missing), so `CGEvent.post` would
    /// silently drop the key. Reported instead of pretending the session
    /// started: a silent drop is indistinguishable from "the input method never
    /// woke up", which is exactly the bug users report.
    case postingUnavailable
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

    /// Press, then release after a human-length pause. The release is scheduled
    /// rather than slept for: the voice-key tap runs on the main run loop, and
    /// blocking it would hold our own key-down in the tap until the sleep ended,
    /// delivering down and up back to back — a zero-length press some input
    /// methods ignore.
    public func sendTap(_ shortcut: VoiceShortcut) throws {
        try Self.ensureCanPostEvents()
        // Build both events up front so a failure surfaces here, synchronously,
        // instead of as a stuck key-down.
        let down = try makeEvent(shortcut, keyDown: true)
        _ = try makeEvent(shortcut, keyDown: false)
        down.post(tap: .cghidEventTap)
        let delay = Double(Self.tapDelayMicroseconds(for: shortcut)) / 1_000_000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                try? self?.sendKeyUp(shortcut)
            }
        }
    }

    public func sendKeyDown(_ shortcut: VoiceShortcut) throws {
        try Self.ensureCanPostEvents()
        let event = try makeEvent(shortcut, keyDown: true)
        event.post(tap: .cghidEventTap)
    }

    public func sendKeyUp(_ shortcut: VoiceShortcut) throws {
        try Self.ensureCanPostEvents()
        let event = try makeEvent(shortcut, keyDown: false)
        event.post(tap: .cghidEventTap)
    }

    /// `CGEvent.post` has no return value: without the grant it silently does
    /// nothing, so the caller would report a running session that never reached
    /// the input method. Checked up front so the failure is reportable.
    private static func ensureCanPostEvents() throws {
        guard CGPreflightPostEventAccess() else {
            throw ShortcutEventSenderError.postingUnavailable
        }
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
        var flags = shortcut.cgFlags(keyDown: keyDown)
        // Match what the keyboard itself sends: macOS tags F-keys, arrows and the
        // navigation block with the secondary-Fn flag. An input method that
        // compares the full flag set would not recognize an echo without it.
        if shortcut.isFunctionRowKey {
            flags.insert(.maskSecondaryFn)
        }
        flags.insert(CGEventFlags(rawValue: shortcut.deviceFlagBits(keyDown: keyDown)))
        flags.insert(.maskNonCoalesced)
        event.flags = flags
        ShortcutEventMarker.mark(event)
        return event
    }
}
