import CoreGraphics
import Foundation

/// What a consumed voice-key tap reports to the session.
public enum VoiceKeyEvent: Equatable, Sendable {
    /// The configured voice key went down. LockIME owns it now.
    case pressed
    /// The voice key came back up.
    case released
}

public enum VoiceKeyMonitorError: Error, Equatable, Sendable {
    case eventTapCreateFailed
}

@MainActor
public protocol VoiceKeyMonitoring: AnyObject {
    func start(keyCode: UInt16, _ handler: @escaping @MainActor (VoiceKeyEvent) -> Void) throws
    func stop()
}

/// Owns the voice key so the input method never sees it.
///
/// This is the whole point of the single-shortcut design, and the reason the
/// previous implementation conflicted: it used a `.listenOnly` tap that observed
/// the key while still passing it through, so the input method **also** reacted
/// and LockIME then synthesized a duplicate — one press handled twice, reported
/// by macOS/the input method as a shortcut conflict.
///
/// Here the tap is an *active* `.defaultTap` and the matching events are
/// swallowed (`return nil`), so exactly one handler acts on a press:
///
/// ```
/// user presses ⌃⌥V
///   ├─ LockIME's tap consumes it (this file)      → session starts/ends
///   └─ the input method never receives it          → no conflict, no double handling
///                                │
///                                └─ LockIME synthesizes the key it consumed,
///                                   marked so its own tap ignores it
/// ```
///
/// Two details make that loop safe:
/// * synthesized events carry `ShortcutEventMarker`, and the tap returns marked
///   events untouched — otherwise LockIME would react to its own output forever;
/// * only the exact configured combination is consumed, so ordinary typing (and
///   every other shortcut) is unaffected.
///
/// A consuming tap needs the Accessibility grant. Without it the tap cannot be
/// created and the caller surfaces that as a failure rather than silently doing
/// nothing.
@MainActor
public final class CGConsumingVoiceKeyMonitor: VoiceKeyMonitoring {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (@MainActor (VoiceKeyEvent) -> Void)?
    private var shortcut: VoiceShortcut?
    /// Tracks the down/up phase so a press is reported once, however macOS
    /// repeats the event while the key is held.
    private var isDown = false

    public init() {}

    deinit {
        MainActor.assumeIsolated { stop() }
    }

    public func start(
        keyCode: UInt16,
        _ handler: @escaping @MainActor (VoiceKeyEvent) -> Void
    ) throws {
        stop()
        shortcut = VoiceShortcut(keyCode: keyCode)
        self.handler = handler
        isDown = false

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CGConsumingVoiceKeyMonitor>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated { monitor.enableTap() }
                return Unmanaged.passUnretained(event)
            }
            // `nil` means "consume": the event is not delivered to anyone else,
            // including the input method that would otherwise claim the key.
            let consume = MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
            return consume ? nil : Unmanaged.passUnretained(event)
        }
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            self.handler = nil
            self.shortcut = nil
            throw VoiceKeyMonitorError.eventTapCreateFailed
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        eventTap = tap
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        handler = nil
        shortcut = nil
        isDown = false
    }

    /// Returns whether the event must be consumed.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard let shortcut else { return false }
        // Our own synthesized key: let it through untouched, or LockIME would
        // treat its own output as a new press and loop.
        guard !ShortcutEventMarker.isMarked(event) else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = VoiceShortcut.Modifiers(event.flags)

        if shortcut.isModifierKey {
            // A bare modifier key arrives as flagsChanged; match on the modifier
            // this shortcut stands for, not on the raw key code, so both the left
            // and right variants macOS reports are recognized.
            guard type == .flagsChanged else { return false }
            let changed = VoiceShortcut(keyCode: keyCode).modifierKey
            guard !changed.isEmpty, changed == shortcut.modifierKey else { return false }
            let isPressed = modifiers.contains(shortcut.modifierKey)
            if isPressed, !isDown {
                isDown = true
                emit(.pressed)
            } else if !isPressed, isDown {
                isDown = false
                emit(.released)
            }
            return true
        }

        guard keyCode == shortcut.keyCode, modifiers.isSuperset(of: shortcut.modifiers) else {
            return false
        }
        switch type {
        case .keyDown:
            guard !isDown else { return true }  // swallow auto-repeat
            isDown = true
            emit(.pressed)
        case .keyUp:
            guard isDown else { return true }
            isDown = false
            emit(.released)
        default:
            return false
        }
        return true
    }

    private func emit(_ event: VoiceKeyEvent) {
        Task { @MainActor in
            handler?(event)
        }
    }

    private func enableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
}
