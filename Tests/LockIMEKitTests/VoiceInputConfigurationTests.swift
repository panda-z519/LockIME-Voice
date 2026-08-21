import Foundation
import Testing

@testable import LockIMEKit

@Suite("VoiceInputConfiguration")
struct VoiceInputConfigurationTests {
    private let voice: InputSourceID = "voice.source"

    @Test("disabled configuration is valid without sources or shortcuts")
    func disabledConfigurationIsValid() {
        let config = VoiceInputConfiguration(isEnabled: false)
        #expect(config.validationErrors(defaultSourceID: nil, installedSources: []).isEmpty)
    }

    @Test("enabled configuration requires voice source and voice shortcut")
    func enabledConfigurationRequiresCoreFields() {
        let config = VoiceInputConfiguration(isEnabled: true)
        #expect(config.validationErrors(defaultSourceID: nil, installedSources: []) == [
            .missingVoiceSource,
            .missingVoiceShortcut,
            .missingDefaultSource
        ])
    }

    @Test("workflow mode distinguishes disabled direct and bridged operation")
    func workflowModeUsesDefaultAndVoiceSources() {
        #expect(VoiceInputConfiguration(isEnabled: false).workflowMode(defaultSourceID: voice) == .disabled)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice
        ).workflowMode(defaultSourceID: voice) == .direct)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice
        ).workflowMode(defaultSourceID: "daily.source") == .bridged)
    }

    @Test("direct mode requires no shortcut and installs no workflow monitor")
    func directModeRequiresNoShortcutOrMonitor() {
        let config = VoiceInputConfiguration(isEnabled: true, voiceSourceID: voice)
        let sources: [InputSource] = [.stub(voice.rawValue)]

        #expect(config.validationErrors(defaultSourceID: voice, installedSources: sources).isEmpty)
        #expect(config.shortcutForMonitoring(
            defaultSourceID: voice,
            installedSources: sources,
            hasInputMonitoringAccess: true,
            hasEventPostingAccess: true
        ) == nil)
    }

    @Test("invalid or removed sources prevent global shortcut monitoring")
    func unavailableSourcesPreventMonitoring() {
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 61, modifiers: [.option])
        )

        #expect(config.shortcutForMonitoring(
            defaultSourceID: "daily.source",
            installedSources: [.stub("daily.source")],
            hasInputMonitoringAccess: true,
            hasEventPostingAccess: true
        ) == nil)
    }

    @Test("monitoring requires enabled configuration and both keyboard permissions")
    func monitoringRequiresEnabledConfigurationAndKeyboardPermissions() {
        let shortcut = VoiceShortcut(keyCode: 61, modifiers: [.option])
        let daily: InputSourceID = "daily.source"
        let sources: [InputSource] = [.stub(daily.rawValue), .stub(voice.rawValue)]

        #expect(VoiceInputConfiguration(
            isEnabled: false,
            voiceSourceID: voice,
            voiceShortcut: shortcut
        ).shortcutForMonitoring(
            defaultSourceID: daily,
            installedSources: sources,
            hasInputMonitoringAccess: true,
            hasEventPostingAccess: true
        ) == nil)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut
        ).shortcutForMonitoring(
            defaultSourceID: daily,
            installedSources: sources,
            hasInputMonitoringAccess: false,
            hasEventPostingAccess: true
        ) == nil)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut
        ).shortcutForMonitoring(
            defaultSourceID: daily,
            installedSources: sources,
            hasInputMonitoringAccess: true,
            hasEventPostingAccess: false
        ) == nil)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: shortcut
        ).shortcutForMonitoring(
            defaultSourceID: daily,
            installedSources: sources,
            hasInputMonitoringAccess: true,
            hasEventPostingAccess: true
        ) == shortcut)
    }

    @Test("voice workflow permission status uses the same two permissions as monitoring")
    func voiceWorkflowPermissionStatusMatchesMonitoring() {
        #expect(!VoiceInputConfiguration.hasRequiredSystemPermissions(
            inputMonitoringGranted: false,
            eventPostingGranted: true
        ))
        #expect(!VoiceInputConfiguration.hasRequiredSystemPermissions(
            inputMonitoringGranted: true,
            eventPostingGranted: false
        ))
        #expect(VoiceInputConfiguration.hasRequiredSystemPermissions(
            inputMonitoringGranted: true,
            eventPostingGranted: true
        ))
    }

    @Test("enabled configuration rejects missing installed sources")
    func enabledConfigurationRejectsMissingSources() {
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 49, modifiers: [.control])
        )
        let daily: InputSourceID = "daily.source"
        #expect(config.validationErrors(defaultSourceID: daily, installedSources: []) == [
            .voiceSourceUnavailable(voice),
            .defaultSourceUnavailable(daily)
        ])
    }

    @Test("default timeout is a sixty-second safety fallback")
    func defaultTimeoutIsSixtySeconds() {
        #expect(VoiceInputConfiguration.default.restoreTimeout == .seconds(60))
    }

    @Test("short restore timeouts are upgraded to the safety minimum")
    func shortRestoreTimeoutsAreUpgraded() throws {
        #expect(VoiceInputConfiguration(
            restoreTimeout: .seconds(10)
        ).restoreTimeout == .seconds(60))

        let legacy = LegacyVoiceInputConfiguration(
            isEnabled: false,
            workflowShortcut: nil,
            voiceSourceID: nil,
            voiceShortcut: nil,
            behavior: .pressOnceAnyKeyEnds,
            restoreTimeout: .seconds(20),
            restoreDelay: .seconds(2)
        )
        let decoded = try JSONDecoder().decode(
            VoiceInputConfiguration.self,
            from: JSONEncoder().encode(legacy)
        )
        #expect(decoded.restoreTimeout == .seconds(60))
    }

    @Test("default restore delay is two seconds")
    func defaultRestoreDelayIsTwoSeconds() {
        #expect(VoiceInputConfiguration.default.restoreDelay == .seconds(2))
    }

    @Test("conservative capabilities expose only press once behavior")
    func conservativeCapabilitiesExposeOnlyPressOnceBehavior() {
        #expect(VoiceInputBehavior.available(capabilities: .conservativeDefault) == [
            .pressOncePressAgainEnds
        ])
    }

    @Test("hold capabilities expose hold to speak behavior")
    func holdCapabilitiesExposeHoldToSpeakBehavior() {
        let capabilities = VoiceInputCapabilities(supportsHoldToSpeak: true)
        #expect(VoiceInputBehavior.available(capabilities: capabilities) == [
            .pressOncePressAgainEnds,
            .holdToSpeak
        ])
    }

    @Test("any key capabilities expose any key termination behavior")
    func anyKeyCapabilitiesExposeAnyKeyTerminationBehavior() {
        #expect(VoiceInputBehavior.available(capabilities: .anyKeyTerminationValidated) == [
            .pressOncePressAgainEnds,
            .pressOnceAnyKeyEnds
        ])
    }

    @Test("disabled configuration has no required notices")
    func disabledConfigurationHasNoRequiredNotices() {
        let config = VoiceInputConfiguration(isEnabled: false)
        #expect(config.requiredNotices().isEmpty)
    }

    @Test("enabled configuration requires matching input method settings notice")
    func enabledConfigurationRequiresMatchingSettingsNotice() {
        let config = VoiceInputConfiguration(isEnabled: true)
        #expect(config.requiredNotices() == [.settingsMustMatchInputMethod])
    }

    @Test("all voice behaviors are codable by stable raw value")
    func behaviorsAreCodable() throws {
        let encoded = try JSONEncoder().encode(VoiceInputBehavior.pressOnceAnyKeyEnds)
        let decoded = try JSONDecoder().decode(VoiceInputBehavior.self, from: encoded)
        #expect(decoded == .pressOnceAnyKeyEnds)
    }

    @Test("full configuration round-trips through Codable")
    func fullConfigurationCodableRoundTrip() throws {
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 62, modifiers: [.control, .shift]),
            behavior: .pressOnceAnyKeyEnds,
            restoreTimeout: .seconds(120),
            restoreDelay: .seconds(3)
        )
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VoiceInputConfiguration.self, from: encoded)
        #expect(decoded == config)
    }

    @Test("legacy workflow shortcut migrates into the single voice shortcut")
    func legacyWorkflowShortcutMigratesIntoVoiceShortcut() throws {
        let legacy = LegacyVoiceInputConfiguration(
            isEnabled: true,
            workflowShortcut: VoiceShortcut(keyCode: 62, modifiers: [.control]),
            voiceSourceID: voice,
            voiceShortcut: nil,
            behavior: .pressOnceAnyKeyEnds,
            restoreTimeout: .seconds(30),
            restoreDelay: .seconds(3)
        )
        let encoded = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(VoiceInputConfiguration.self, from: encoded)
        #expect(decoded.voiceShortcut == legacy.workflowShortcut)
        let daily: InputSourceID = "daily.source"
        #expect(decoded.validationErrors(
            defaultSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        ).isEmpty)
    }
}

private struct LegacyVoiceInputConfiguration: Encodable {
    var isEnabled: Bool
    var workflowShortcut: VoiceShortcut?
    var voiceSourceID: InputSourceID?
    var voiceShortcut: VoiceShortcut?
    var behavior: VoiceInputBehavior
    var restoreTimeout: VoiceRestoreTimeout
    var restoreDelay: VoiceRestoreDelay
}
