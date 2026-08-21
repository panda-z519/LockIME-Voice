import CoreGraphics
import Foundation

enum ShortcutEventMarker {
    static let lockIMEVoiceInput: Int64 = 0x4C_49_4D_45_56_4F_49_43

    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: lockIMEVoiceInput)
    }

    static func isMarked(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == lockIMEVoiceInput
    }
}
