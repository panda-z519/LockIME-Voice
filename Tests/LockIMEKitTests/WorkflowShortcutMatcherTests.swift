import CoreGraphics
import Testing

@testable import LockIMEKit

@Suite("WorkflowShortcutMatcher")
struct WorkflowShortcutMatcherTests {
    @Test("right Option release triggers every complete press")
    func rightOptionReleaseTriggersEveryPress() {
        var matcher = WorkflowShortcutMatcher(
            shortcut: VoiceShortcut(keyCode: 61, modifiers: [.option]),
            triggersModifierShortcutOnRelease: true
        )

        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: [.option]) == nil)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: []) == .workflowKeyDown)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: [.option]) == nil)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: []) == .workflowKeyDown)
    }

    @Test("external right Control may release with the generic left key code")
    func externalRightControlReleaseUsesModifierIdentity() {
        var matcher = WorkflowShortcutMatcher(
            shortcut: VoiceShortcut(keyCode: 62, modifiers: [.control]),
            triggersModifierShortcutOnRelease: true
        )
        let downCode = VoiceShortcut.canonicalModifierKeyCode(
            eventKeyCode: 59,
            deviceFlagsRawValue: 0x0000_2000
        )
        let releaseCode = VoiceShortcut.canonicalModifierKeyCode(
            eventKeyCode: 59,
            deviceFlagsRawValue: 0
        )

        #expect(matcher.handle(
            type: .flagsChanged,
            keyCode: downCode,
            modifiers: [.control]
        ) == nil)
        #expect(matcher.handle(
            type: .flagsChanged,
            keyCode: releaseCode,
            modifiers: []
        ) == .workflowKeyDown)
    }

    @Test("multi-button shortcut emits one down and one up per press")
    func multiButtonShortcutEmitsDownAndUp() {
        var matcher = WorkflowShortcutMatcher(
            shortcut: VoiceShortcut(keyCode: 49, modifiers: [.control, .shift]),
            triggersModifierShortcutOnRelease: false
        )

        #expect(matcher.handle(
            type: .keyDown,
            keyCode: 49,
            modifiers: [.control, .shift]
        ) == .workflowKeyDown)
        #expect(matcher.handle(
            type: .keyDown,
            keyCode: 49,
            modifiers: [.control, .shift]
        ) == nil)
        #expect(matcher.handle(
            type: .keyUp,
            keyCode: 49,
            modifiers: [.control, .shift]
        ) == .workflowKeyUp)
    }

    @Test("marked synthetic events never change physical shortcut state")
    func markedEventsAreIgnored() {
        var matcher = WorkflowShortcutMatcher(
            shortcut: VoiceShortcut(keyCode: 61, modifiers: [.option]),
            triggersModifierShortcutOnRelease: true
        )

        #expect(matcher.handle(
            type: .flagsChanged,
            keyCode: 61,
            modifiers: [.option],
            isMarked: true
        ) == nil)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: []) == nil)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: [.option]) == nil)
        #expect(matcher.handle(type: .flagsChanged, keyCode: 61, modifiers: []) == .workflowKeyDown)
    }
}
