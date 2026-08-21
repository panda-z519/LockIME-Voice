import CoreGraphics
import Foundation

public enum ShortcutMonitorEvent: Equatable, Sendable {
    case workflowKeyDown
    case workflowKeyUp
    case anyKey
}

public enum ShortcutEventMonitorError: Error, Equatable, Sendable {
    case eventTapCreateFailed
}

struct WorkflowShortcutMatcher {
    let shortcut: VoiceShortcut
    let triggersModifierShortcutOnRelease: Bool
    private var isWorkflowKeyPressed = false

    init(shortcut: VoiceShortcut, triggersModifierShortcutOnRelease: Bool) {
        self.shortcut = shortcut
        self.triggersModifierShortcutOnRelease = triggersModifierShortcutOnRelease
    }

    mutating func handle(
        type: CGEventType,
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers,
        isMarked: Bool = false
    ) -> ShortcutMonitorEvent? {
        guard !isMarked else { return nil }
        switch type {
        case .keyDown where matches(keyCode: keyCode, modifiers: modifiers):
            guard !isWorkflowKeyPressed else { return nil }
            isWorkflowKeyPressed = true
            return .workflowKeyDown
        case .keyUp where keyCode == shortcut.keyCode:
            guard isWorkflowKeyPressed else { return nil }
            isWorkflowKeyPressed = false
            return .workflowKeyUp
        case .flagsChanged where isSameModifierKey(keyCode):
            let isPressed = matches(keyCode: keyCode, modifiers: modifiers)
            let modifierIsDown = modifiers.contains(shortcut.modifierKey)
            if triggersModifierShortcutOnRelease {
                if isPressed {
                    isWorkflowKeyPressed = true
                } else if isWorkflowKeyPressed && !modifierIsDown {
                    isWorkflowKeyPressed = false
                    return .workflowKeyDown
                }
            } else if isPressed && !isWorkflowKeyPressed {
                isWorkflowKeyPressed = true
                return .workflowKeyDown
            } else if isWorkflowKeyPressed && !modifierIsDown {
                isWorkflowKeyPressed = false
                return .workflowKeyUp
            }
        default:
            break
        }
        return nil
    }

    private func matches(
        keyCode: UInt16,
        modifiers: VoiceShortcut.Modifiers
    ) -> Bool {
        keyCode == shortcut.keyCode && modifiers.isSuperset(of: shortcut.modifiers)
    }

    private func isSameModifierKey(_ keyCode: UInt16) -> Bool {
        keyCode == shortcut.keyCode
            || (!shortcut.modifierKey.isEmpty
                && VoiceShortcut(keyCode: keyCode).modifierKey == shortcut.modifierKey)
    }
}

@MainActor
public protocol ShortcutEventMonitoring: AnyObject {
    func start(_ handler: @escaping @MainActor (ShortcutMonitorEvent) -> Void) throws
    func stop()
}

@MainActor
public final class CGShortcutEventMonitor: ShortcutEventMonitoring {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (@MainActor (ShortcutMonitorEvent) -> Void)?

    public init() {}

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    public func start(_ handler: @escaping @MainActor (ShortcutMonitorEvent) -> Void) throws {
        stop()
        self.handler = handler
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CGShortcutEventMonitor>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated {
                    monitor.enableTap()
                }
                return Unmanaged.passUnretained(event)
            }
            if (type == .keyDown || type == .keyUp), !ShortcutEventMarker.isMarked(event) {
                Task { @MainActor in
                    monitor.handler?(.anyKey)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            self.handler = nil
            throw ShortcutEventMonitorError.eventTapCreateFailed
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
    }

    private func enableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
}

@MainActor
public final class CGWorkflowShortcutEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var matcher: WorkflowShortcutMatcher?
    private var handler: (@MainActor (ShortcutMonitorEvent) -> Void)?

    public init() {}

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    public func start(
        shortcut: VoiceShortcut?,
        triggersModifierShortcutOnRelease: Bool = false,
        _ handler: @escaping @MainActor (ShortcutMonitorEvent) -> Void
    ) throws {
        stop()
        guard let shortcut else { return }
        matcher = WorkflowShortcutMatcher(
            shortcut: shortcut,
            triggersModifierShortcutOnRelease: triggersModifierShortcutOnRelease
        )
        self.handler = handler
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CGWorkflowShortcutEventMonitor>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated {
                    monitor.enableTap()
                }
                return Unmanaged.passUnretained(event)
            }
            MainActor.assumeIsolated {
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            matcher = nil
            self.handler = nil
            throw ShortcutEventMonitorError.eventTapCreateFailed
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
        matcher = nil
        handler = nil
    }

    private func enableTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard var matcher else { return }
        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let keyCode = type == .flagsChanged
            ? VoiceShortcut.canonicalModifierKeyCode(
                eventKeyCode: eventKeyCode,
                deviceFlagsRawValue: event.flags.rawValue
            )
            : eventKeyCode
        let modifiers = VoiceShortcut.Modifiers(event.flags)
        let output = matcher.handle(
            type: type,
            keyCode: keyCode,
            modifiers: modifiers,
            isMarked: ShortcutEventMarker.isMarked(event)
        )
        self.matcher = matcher
        if let output { emit(output) }
    }

    private func emit(_ event: ShortcutMonitorEvent) {
        Task { @MainActor in
            handler?(event)
        }
    }

}
