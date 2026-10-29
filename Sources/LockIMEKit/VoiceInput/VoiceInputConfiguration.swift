import Foundation

public enum VoiceInputBehavior: String, Codable, Sendable, CaseIterable, Identifiable {
    case pressOncePressAgainEnds
    case holdToSpeak
    case pressOnceAnyKeyEnds

    public var id: String { rawValue }
}

public enum VoiceInputWorkflowMode: Equatable, Sendable {
    case disabled
    case direct
    case bridged
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

public struct VoiceInputConfiguration: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var voiceSourceID: InputSourceID?
    /// The voice key: the input method's own voice shortcut, which LockIME takes
    /// over and echoes back. The single place it is stored, so the key shown in
    /// Settings is always the key the tap owns.
    public var voiceShortcut: VoiceShortcut?
    public var behavior: VoiceInputBehavior
    /// Whether a trigger switches the Mac to `voiceSourceID` for the session and
    /// switches back afterwards. **Off by default**: the synthesized shortcut
    /// alone already starts voice input in whatever input method is active, so
    /// turning this off is the zero-configuration, conflict-free setup. On, the
    /// session owns the input source (daily typing resumes automatically).
    public var switchesVoiceSourceAutomatically: Bool
    public var restoreTimeout: VoiceRestoreTimeout
    public var restoreDelay: VoiceRestoreDelay

    public init(
        isEnabled: Bool = false,
        voiceSourceID: InputSourceID? = nil,
        voiceShortcut: VoiceShortcut? = nil,
        behavior: VoiceInputBehavior = .pressOncePressAgainEnds,
        switchesVoiceSourceAutomatically: Bool = false,
        restoreTimeout: VoiceRestoreTimeout = .seconds(60),
        restoreDelay: VoiceRestoreDelay = .seconds(2)
    ) {
        self.isEnabled = isEnabled
        self.voiceSourceID = voiceSourceID
        self.voiceShortcut = voiceShortcut
        self.behavior = behavior
        self.switchesVoiceSourceAutomatically = switchesVoiceSourceAutomatically
        self.restoreTimeout = restoreTimeout.normalizedForSafety
        self.restoreDelay = restoreDelay
    }

    public static let `default` = VoiceInputConfiguration()

    /// `.direct` means the workflow must *not* switch input sources: either
    /// automatic switching is off (the shortcut alone does the job), or the
    /// selected voice input method is already the global default. `.bridged`
    /// means the session has to switch to `voiceSourceID` first.
    public func workflowMode(defaultSourceID: InputSourceID?) -> VoiceInputWorkflowMode {
        guard isEnabled else { return .disabled }
        guard switchesVoiceSourceAutomatically, let voiceSourceID else { return .direct }
        guard let defaultSourceID, voiceSourceID != defaultSourceID else { return .direct }
        return .bridged
    }

    public func validationErrors(
        defaultSourceID: InputSourceID?,
        installedSources: [InputSource]
    ) -> [VoiceInputValidationError] {
        guard isEnabled else { return [] }
        let installed = Set(installedSources.map(\.id))
        var errors: [VoiceInputValidationError] = []
        // Source problems only block the workflow when it actually has to touch
        // the input source: automatic switching is on, or the selected voice
        // input method is the global default (the workflow then still needs that
        // default to be real). Otherwise the synthesized shortcut alone is a
        // complete configuration, so a missing source must not block it.
        if requiresInstalledSources(defaultSourceID: defaultSourceID) {
            if let voiceSourceID {
                if !installed.contains(voiceSourceID) {
                    errors.append(.voiceSourceUnavailable(voiceSourceID))
                }
            } else {
                errors.append(.missingVoiceSource)
            }
            if let defaultSourceID {
                if !installed.contains(defaultSourceID) {
                    errors.append(.defaultSourceUnavailable(defaultSourceID))
                }
            } else {
                errors.append(.missingDefaultSource)
            }
        }
        return errors
    }

    /// Whether this configuration must resolve real installed input sources —
    /// true when automatic switching is on (a source to switch to) or the
    /// selected voice input method is the global default (a source to stay on).
    private func requiresInstalledSources(defaultSourceID: InputSourceID?) -> Bool {
        if switchesVoiceSourceAutomatically { return true }
        guard let voiceSourceID, let defaultSourceID else { return false }
        return voiceSourceID == defaultSourceID
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case workflowShortcut
        case voiceSourceID
        case voiceShortcut
        case behavior
        case switchesVoiceSourceAutomatically
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
        // Absent in a configuration written before automatic switching existed
        // (v0.1.2 and earlier): those builds always switched the input source as
        // part of the workflow, so an upgraded configuration keeps doing exactly
        // what it did — the flag defaults to "on" for stored data, while a fresh
        // `VoiceInputConfiguration()` starts at the conflict-free "off".
        if container.contains(.switchesVoiceSourceAutomatically) {
            switchesVoiceSourceAutomatically = try container.decode(
                Bool.self,
                forKey: .switchesVoiceSourceAutomatically
            )
        } else {
            switchesVoiceSourceAutomatically = voiceSourceID != nil
        }
        restoreDelay = try container.decodeIfPresent(VoiceRestoreDelay.self, forKey: .restoreDelay)
            ?? .seconds(2)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(voiceSourceID, forKey: .voiceSourceID)
        try container.encodeIfPresent(voiceShortcut, forKey: .voiceShortcut)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(
            switchesVoiceSourceAutomatically,
            forKey: .switchesVoiceSourceAutomatically
        )
        try container.encode(restoreTimeout, forKey: .restoreTimeout)
        try container.encode(restoreDelay, forKey: .restoreDelay)
    }
}
