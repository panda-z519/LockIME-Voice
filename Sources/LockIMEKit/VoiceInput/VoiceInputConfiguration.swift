import Foundation

public enum VoiceInputBehavior: String, Codable, Sendable, CaseIterable, Identifiable {
    case pressOncePressAgainEnds
    case holdToSpeak
    case pressOnceAnyKeyEnds

    public var id: String { rawValue }

    public static func available(capabilities: VoiceInputCapabilities) -> [VoiceInputBehavior] {
        var behaviors: [VoiceInputBehavior] = [.pressOncePressAgainEnds]
        if capabilities.supportsHoldToSpeak {
            behaviors.append(.holdToSpeak)
        }
        if capabilities.supportsAnyKeyTermination {
            behaviors.append(.pressOnceAnyKeyEnds)
        }
        return behaviors
    }
}

public enum VoiceInputWorkflowMode: Equatable, Sendable {
    case disabled
    case direct
    case bridged
}

public struct VoiceInputCapabilities: Codable, Sendable, Equatable {
    public var supportsHoldToSpeak: Bool
    public var supportsAnyKeyTermination: Bool

    public init(supportsHoldToSpeak: Bool = false, supportsAnyKeyTermination: Bool = false) {
        self.supportsHoldToSpeak = supportsHoldToSpeak
        self.supportsAnyKeyTermination = supportsAnyKeyTermination
    }

    public static let conservativeDefault = VoiceInputCapabilities()
    public static let anyKeyTerminationValidated = VoiceInputCapabilities(
        supportsAnyKeyTermination: true
    )
}

public enum VoiceRestoreTimeout: Codable, Sendable, Equatable, Hashable {
    case seconds(Int)

    public static let minimumSafetySeconds = 60

    public var interval: TimeInterval {
        switch self {
        case .seconds(let value): TimeInterval(value)
        }
    }

    var normalizedForSafety: Self {
        switch self {
        case .seconds(let value):
            .seconds(max(value, Self.minimumSafetySeconds))
        }
    }
}

public enum VoiceRestoreDelay: Codable, Sendable, Equatable, Hashable {
    case seconds(Int)

    public var interval: TimeInterval {
        switch self {
        case .seconds(let value): TimeInterval(value)
        }
    }
}

public enum VoiceInputValidationError: Equatable, Sendable {
    case missingDefaultSource
    case missingVoiceSource
    case missingVoiceShortcut
    case defaultSourceUnavailable(InputSourceID)
    case voiceSourceUnavailable(InputSourceID)
}

public enum VoiceInputConfigurationNotice: Equatable, Sendable {
    case settingsMustMatchInputMethod
}

public struct VoiceInputConfiguration: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var voiceSourceID: InputSourceID?
    public var voiceShortcut: VoiceShortcut?
    public var behavior: VoiceInputBehavior
    public var restoreTimeout: VoiceRestoreTimeout
    public var restoreDelay: VoiceRestoreDelay

    public init(
        isEnabled: Bool = false,
        voiceSourceID: InputSourceID? = nil,
        voiceShortcut: VoiceShortcut? = nil,
        behavior: VoiceInputBehavior = .pressOncePressAgainEnds,
        restoreTimeout: VoiceRestoreTimeout = .seconds(60),
        restoreDelay: VoiceRestoreDelay = .seconds(2)
    ) {
        self.isEnabled = isEnabled
        self.voiceSourceID = voiceSourceID
        self.voiceShortcut = voiceShortcut
        self.behavior = behavior
        self.restoreTimeout = restoreTimeout.normalizedForSafety
        self.restoreDelay = restoreDelay
    }

    public static let `default` = VoiceInputConfiguration()

    public func workflowMode(defaultSourceID: InputSourceID?) -> VoiceInputWorkflowMode {
        guard isEnabled else { return .disabled }
        guard let voiceSourceID, let defaultSourceID, voiceSourceID == defaultSourceID else {
            return .bridged
        }
        return .direct
    }

    public static func hasRequiredSystemPermissions(
        inputMonitoringGranted: Bool,
        eventPostingGranted: Bool
    ) -> Bool {
        inputMonitoringGranted && eventPostingGranted
    }

    public func shortcutForMonitoring(
        defaultSourceID: InputSourceID?,
        installedSources: [InputSource],
        hasInputMonitoringAccess: Bool,
        hasEventPostingAccess: Bool
    ) -> VoiceShortcut? {
        guard workflowMode(defaultSourceID: defaultSourceID) == .bridged,
              validationErrors(
                  defaultSourceID: defaultSourceID,
                  installedSources: installedSources
              ).isEmpty,
              Self.hasRequiredSystemPermissions(
            inputMonitoringGranted: hasInputMonitoringAccess,
            eventPostingGranted: hasEventPostingAccess
        ) else { return nil }
        return voiceShortcut
    }

    public func validationErrors(
        defaultSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) -> [VoiceInputValidationError] {
        guard isEnabled else { return [] }
        let installed = Set(installedSources.map(\.id))
        var errors: [VoiceInputValidationError] = []
        if let voiceSourceID {
            if !installed.contains(voiceSourceID) { errors.append(.voiceSourceUnavailable(voiceSourceID)) }
        } else {
            errors.append(.missingVoiceSource)
        }
        if workflowMode(defaultSourceID: defaultSourceID) == .bridged, voiceShortcut == nil {
            errors.append(.missingVoiceShortcut)
        }
        if let defaultSourceID {
            if !installed.contains(defaultSourceID) {
                errors.append(.defaultSourceUnavailable(defaultSourceID))
            }
        } else {
            errors.append(.missingDefaultSource)
        }
        return errors
    }

    public func requiredNotices() -> [VoiceInputConfigurationNotice] {
        isEnabled ? [.settingsMustMatchInputMethod] : []
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case workflowShortcut
        case voiceSourceID
        case voiceShortcut
        case behavior
        case restoreTimeout
        case restoreDelay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        voiceSourceID = try container.decodeIfPresent(InputSourceID.self, forKey: .voiceSourceID)
        let legacyWorkflowShortcut = try container.decodeIfPresent(
            VoiceShortcut.self,
            forKey: .workflowShortcut
        )
        voiceShortcut = try container.decodeIfPresent(VoiceShortcut.self, forKey: .voiceShortcut)
            ?? legacyWorkflowShortcut
        behavior = try container.decodeIfPresent(VoiceInputBehavior.self, forKey: .behavior)
            ?? .pressOncePressAgainEnds
        restoreTimeout = try container.decodeIfPresent(VoiceRestoreTimeout.self, forKey: .restoreTimeout)
            .map(\.normalizedForSafety)
            ?? .seconds(60)
        restoreDelay = try container.decodeIfPresent(VoiceRestoreDelay.self, forKey: .restoreDelay)
            ?? .seconds(2)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(voiceSourceID, forKey: .voiceSourceID)
        try container.encodeIfPresent(voiceShortcut, forKey: .voiceShortcut)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(restoreTimeout, forKey: .restoreTimeout)
        try container.encode(restoreDelay, forKey: .restoreDelay)
    }
}
