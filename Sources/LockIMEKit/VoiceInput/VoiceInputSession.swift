import Foundation

public enum VoiceInputSessionState: Equatable, Sendable {
    case idle
    case preparingVoice
    case voiceActive
    case endingVoice
    case restoringDefaultInput
    case failed(VoiceInputCoordinatorError)

    public var isInProgress: Bool {
        switch self {
        case .preparingVoice, .voiceActive, .endingVoice, .restoringDefaultInput:
            true
        case .idle, .failed:
            false
        }
    }
}

public enum VoiceInputCoordinatorError: Error, Equatable, Sendable {
    case validationFailed([VoiceInputValidationError])
    case switchToVoiceFailed(InputSourceID)
    case restoreDefaultFailed(InputSourceID)
    case shortcutSendFailed
    /// macOS would not accept our synthetic key, so the input method was never
    /// woken. Kept apart from `shortcutSendFailed` because only this one is
    /// fixed by granting (or re-granting) Accessibility.
    case eventPostingUnavailable
    /// The consuming voice-key tap could not be installed (missing Accessibility
    /// grant), so the key cannot be owned and the workflow cannot run.
    case eventTapUnavailable
}
