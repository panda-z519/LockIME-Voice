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
    func start(shortcut: VoiceShortcut, _ handler: @escaping @MainActor (VoiceKeyEvent) -> Void) throws
    func stop()
}

/// The tap's per-event decision, kept free of CoreGraphics so it can be tested
/// directly (the tap itself needs a live window server and the Accessibility
/// grant).
///
/// Rules:
/// * LockIME's own synthesized key is never touched, or it would loop.
/// * A key-down is owned only when the key code **and the exact modifier set**
///   match — `⌃⌥V` must not swallow plain `V`, nor `⌃⌥⇧V` (a different shortcut).
/// * Auto-repeat of an owned key is swallowed; a *fresh* key-down always starts a
///   new press, so a key-up lost while the tap was disabled can't leave the key
///   dead for the next press.
/// * A key-up is owned only if its key-down was. It is matched on the key code
///   alone: releasing a modifier before the key must still close the press.
/// * While LockIME's own recorder is reading the key (`yield`), nothing is owned.
public struct VoiceKeyMatcher: Sendable {
    public enum EventKind: Sendable {
        case keyDown
        case keyUp
        case flagsChanged
    }

    public struct Decision: Equatable, Sendable {
        public var consume: Bool
        public var event: VoiceKeyEvent?

        public static let pass = Decision(consume: false, event: nil)
        public static let swallow = Decision(consume: true, event: nil)
    }

    public let shortcut: VoiceShortcut
    public private(set) var isDown = false

    public init(shortcut: VoiceShortcut) {
        self.shortcut = shortcut
    }

    /// Forget any press in flight — used when the tap was re-enabled after macOS
    /// disabled it, since the matching key-up may have been missed.
    public mutating func reset() {
        isDown = false
    }

    public mutating func decide(
        kind: EventKind,
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers,
        isAutorepeat: Bool,
        isMarked: Bool,
        yield: () -> Bool
    ) -> Decision {
        // Our own synthesized key: let it through untouched, or LockIME would
        // treat its own output as a new press and loop.
        guard !isMarked else { return .pass }

        if shortcut.isModifierKey {
            // A bare modifier key arrives as flagsChanged; match on the modifier
            // this shortcut stands for, not on the raw key code, so both the left
            // and right variants macOS reports are recognized.
            guard kind == .flagsChanged else { return .pass }
            let changed = VoiceShortcut(keyCode: keyCode).modifierKey
            guard !changed.isEmpty, changed == shortcut.modifierKey else { return .pass }
            let isPressed = modifiers.contains(shortcut.modifierKey)
            if isPressed, !isDown {
                if yield() { return .pass }
                isDown = true
                return Decision(consume: true, event: .pressed)
            }
            if !isPressed, isDown {
                isDown = false
                return Decision(consume: true, event: .released)
            }
            return .pass
        }

        guard keyCode == shortcut.keyCode else { return .pass }
        switch kind {
        case .keyDown:
            guard modifiers == shortcut.modifiers else { return .pass }
            if isAutorepeat {
                // Swallow the repeats of a press we own; a repeat of a press we
                // let through (recorder) stays with whoever got the key-down.
                return isDown ? .swallow : .pass
            }
            // The recorder is reading this very key: yield it so the press can be
            // recorded instead of swallowed. Checked only after the key matched,
            // so ordinary typing never pays for the lookup.
            if yield() { return .pass }
            isDown = true
            return Decision(consume: true, event: .pressed)
        case .keyUp:
            guard isDown else { return .pass }
            isDown = false
            return Decision(consume: true, event: .released)
        case .flagsChanged:
            return .pass
        }
    }
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
///   every other shortcut) is unaffected — see `VoiceKeyMatcher`.
///
/// A consuming tap needs the Accessibility grant. Without it the tap cannot be
/// created and the caller surfaces that as a failure rather than silently doing
/// nothing.
@MainActor
public final class CGConsumingVoiceKeyMonitor: VoiceKeyMonitoring {
    private var context: VoiceKeyTapContext?
    private var handler: (@MainActor (VoiceKeyEvent) -> Void)?
    /// The shortcut the running tap owns, or nil when stopped — lets the caller
    /// skip tearing down and recreating an identical tap.
    public private(set) var activeShortcut: VoiceShortcut?
    /// Whether LockIME's own voice-key editor is capturing a key right now. The
    /// tap then lets the key through so the editor can read it. Pushed from the
    /// main thread (the tap thread must not touch AppKit) and kept across
    /// restarts of the tap.
    public var yieldsKey = false {
        didSet { context?.yieldsKey = yieldsKey }
    }

    public init() {}

    deinit {
        MainActor.assumeIsolated { stop() }
    }

    /// Install the tap on its own thread. The tap sits in front of *every* key
    /// event on the system, so it must never wait behind LockIME's main thread
    /// (synchronous Accessibility queries, SwiftData saves, SwiftUI updates):
    /// that would delay typing in every app, and a long enough stall gets the tap
    /// disabled by macOS — the voice key then leaks to the input method.
    public func start(
        shortcut: VoiceShortcut,
        _ handler: @escaping @MainActor (VoiceKeyEvent) -> Void
    ) throws {
        stop()
        let context = VoiceKeyTapContext(
            shortcut: shortcut,
            yieldsKey: yieldsKey,
            deliver: { [weak self] event in
                Task { @MainActor in self?.handler?(event) }
            }
        )
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let context = Unmanaged<VoiceKeyTapContext>.fromOpaque(refcon).takeUnretainedValue()
            // `nil` means "consume": the event is not delivered to anyone else,
            // including the input method that would otherwise claim the key.
            return context.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
        }
        // Created here, not on the tap thread, so a missing Accessibility grant
        // surfaces synchronously as a thrown error.
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(context).toOpaque()
        ) else {
            throw VoiceKeyMonitorError.eventTapCreateFailed
        }
        context.run(tap: tap)
        self.context = context
        self.handler = handler
        activeShortcut = shortcut
    }

    public func stop() {
        context?.invalidate()
        context = nil
        handler = nil
        activeShortcut = nil
    }
}

/// Everything the tap callback touches. It lives on the tap thread: `matcher`
/// and `tap` are only used there (the thread's closure keeps the context alive
/// until the run loop exits), and the one value the main thread writes,
/// `yieldsKey`, is lock-protected.
final class VoiceKeyTapContext: @unchecked Sendable {
    private var matcher: VoiceKeyMatcher
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private let state = NSLock()
    private var yieldsKeyStorage: Bool
    private let deliver: @Sendable (VoiceKeyEvent) -> Void

    init(
        shortcut: VoiceShortcut,
        yieldsKey: Bool,
        deliver: @escaping @Sendable (VoiceKeyEvent) -> Void
    ) {
        matcher = VoiceKeyMatcher(shortcut: shortcut)
        yieldsKeyStorage = yieldsKey
        self.deliver = deliver
    }

    var yieldsKey: Bool {
        get { state.withLock { yieldsKeyStorage } }
        set { state.withLock { yieldsKeyStorage = newValue } }
    }

    /// Start the tap thread and return once its run loop is serving the tap.
    func run(tap: CFMachPort) {
        self.tap = tap
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            guard let tap = self.tap else { ready.signal(); return }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let loop = CFRunLoopGetCurrent()
            state.withLock { runLoop = loop }
            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            // Returns once `invalidate` stops the loop; the thread then exits.
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        thread.name = "LockIME voice-key tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
    }

    func invalidate() {
        if let tap { CFMachPortInvalidate(tap) }
        if let loop = state.withLock({ runLoop }) { CFRunLoopStop(loop) }
    }

    /// Tap thread. Returns whether the event must be consumed.
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        let kind: VoiceKeyMatcher.EventKind
        switch type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disabled the tap. Turn it back on, and drop any press in
            // flight: its key-up may have gone by while the tap was off, and a
            // stale "down" would swallow the next real press.
            matcher.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        default:
            return false
        }
        let decision = matcher.decide(
            kind: kind,
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            modifiers: VoiceShortcut.Modifiers(event.flags),
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            isMarked: ShortcutEventMarker.isMarked(event),
            yield: { yieldsKey }
        )
        if let voiceEvent = decision.event {
            deliver(voiceEvent)
        }
        return decision.consume
    }
}
