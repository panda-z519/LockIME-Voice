import Foundation

public enum VoiceInputSessionState: Equatable, Sendable {
    case idle
    case preparingVoice
    case voiceActive
    case endingVoice
    case restoringDefaultInput
    case failed(VoiceInputCoordinatorError)
}

public enum VoiceInputCoordinatorError: Error, Equatable, Sendable {
    case validationFailed([VoiceInputValidationError])
    case switchToVoiceFailed(InputSourceID)
    case restoreDefaultFailed(InputSourceID)
    case shortcutSendFailed
    case eventMonitorStartFailed
}
