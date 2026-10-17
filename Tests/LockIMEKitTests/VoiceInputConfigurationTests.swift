import Foundation
import Testing

@testable import LockIMEKit

@Suite("VoiceInputConfiguration")
struct VoiceInputConfigurationTests {
    private let voice: InputSourceID = "voice.source"
    private let daily: InputSourceID = "daily.source"

    @Test("disabled configuration is valid without sources or shortcuts")
    func disabledConfigurationIsValid() {
        let config = VoiceInputConfiguration(isEnabled: false)
        #expect(config.validationErrors(defaultSourceID: nil, installedSources: []).isEmpty)
    }

    @Test("an enabled workflow validates no shortcut at all")
    func enabledConfigurationRequiresNoStoredShortcut() {
        // Since the single-key model moved the voice key out of the stored
        // configuration (it lives in KeyboardShortcuts, where the app both
        // consumes and echoes it), the config must never demand one — otherwise
        // the pane would show a permanent false "record a shortcut" warning.
        let config = VoiceInputConfiguration(isEnabled: true)
        #expect(config.validationErrors(defaultSourceID: nil, installedSources: []).isEmpty)

        // Validation of the shortcut belongs to the session, which is the only
        // thing that actually needs a key to send.
        #expect(config.voiceShortcut == nil)
    }

    @Test("automatic switching turns missing and unavailable sources into errors")
    func automaticSwitchingRequiresRealSources() {
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 49, modifiers: [.control]),
            switchesVoiceSourceAutomatically: true
        )

        #expect(config.validationErrors(defaultSourceID: daily, installedSources: []) == [
            .voiceSourceUnavailable(voice),
            .defaultSourceUnavailable(daily)
        ])
        #expect(config.validationErrors(
            defaultSourceID: daily,
            installedSources: [.stub(daily.rawValue), .stub(voice.rawValue)]
        ).isEmpty)
    }

    @Test("a source-less configuration with automatic switching on asks for the voice source")
    func automaticSwitchingRequiresAVoiceSource() {
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceShortcut: VoiceShortcut(keyCode: 49, modifiers: [.control]),
            switchesVoiceSourceAutomatically: true
        )
        #expect(config.validationErrors(
            defaultSourceID: daily,
            installedSources: [.stub(daily.rawValue)]
        ) == [.missingVoiceSource])
    }

    @Test("an unavailable voice input method that is the global default is still an error")
    func voiceSourceMatchingTheDefaultIsStillValidated() {
        // The workflow sends the shortcut straight into this input method, so it
        // has to be real even though nothing is switched.
        let config = VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            voiceShortcut: VoiceShortcut(keyCode: 49, modifiers: [.control])
        )
        #expect(config.validationErrors(defaultSourceID: voice, installedSources: []) == [
            .voiceSourceUnavailable(voice),
            .defaultSourceUnavailable(voice)
        ])
        #expect(config.validationErrors(
            defaultSourceID: voice,
            installedSources: [.stub(voice.rawValue)]
        ).isEmpty)
    }

    @Test("workflow mode is direct unless automatic switching leaves the default source")
    func workflowModeUsesAutomaticSwitching() {
        #expect(VoiceInputConfiguration(isEnabled: false).workflowMode(defaultSourceID: voice) == .disabled)

        // Off (the default): never switches, whatever the sources are.
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice
        ).workflowMode(defaultSourceID: daily) == .direct)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice
        ).workflowMode(defaultSourceID: nil) == .direct)

        // On: bridged only when there is somewhere else to go.
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            switchesVoiceSourceAutomatically: true
        ).workflowMode(defaultSourceID: daily) == .bridged)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            voiceSourceID: voice,
            switchesVoiceSourceAutomatically: true
        ).workflowMode(defaultSourceID: voice) == .direct)
        #expect(VoiceInputConfiguration(
            isEnabled: true,
            switchesVoiceSourceAutomatically: true
        ).workflowMode(defaultSourceID: daily) == .direct)
    }

    @Test("sending the voice shortcut needs only the event posting permission")
    func eventPostingIsTheOnlyRequiredPermission() {
        // Listening for the input method's key is gone, so Input Monitoring is
        // irrelevant — the workflow only posts one synthetic key.
        #expect(VoiceInputConfiguration.hasRequiredSystemPermissions(eventPostingGranted: true))
        #expect(!VoiceInputConfiguration.hasRequiredSystemPermissions(eventPostingGranted: false))
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
            switchesVoiceSourceAutomatically: true,
            restoreTimeout: .seconds(120),
            restoreDelay: .seconds(3)
        )
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VoiceInputConfiguration.self, from: encoded)
        #expect(decoded == config)
        #expect(decoded.switchesVoiceSourceAutomatically)
    }

    @Test("a configuration stored before automatic switching existed keeps switching")
    func legacyConfigurationKeepsSwitchingTheSource() throws {
        // v0.1.2 always switched the input source as part of the workflow, so an
        // upgraded configuration must keep behaving that way instead of silently
        // stopping the switch.
        let stored = """
        {"isEnabled":true,"voiceSourceID":"voice.source",
         "voiceShortcut":{"keyCode":49,"modifiers":4}}
        """
        let decoded = try JSONDecoder().decode(
            VoiceInputConfiguration.self,
            from: Data(stored.utf8)
        )
        #expect(decoded.switchesVoiceSourceAutomatically)
        #expect(decoded.workflowMode(defaultSourceID: daily) == .bridged)
        #expect(decoded.voiceShortcut == VoiceShortcut(keyCode: 49, modifiers: [.option]))
    }

    @Test("a configuration stored with no voice source does not switch the source")
    func legacyConfigurationWithoutAVoiceSourceDoesNotSwitch() throws {
        let stored = """
        {"isEnabled":true,"voiceShortcut":{"keyCode":49,"modifiers":4}}
        """
        let decoded = try JSONDecoder().decode(
            VoiceInputConfiguration.self,
            from: Data(stored.utf8)
        )
        #expect(!decoded.switchesVoiceSourceAutomatically)
        #expect(decoded.workflowMode(defaultSourceID: daily) == .direct)
    }

    @Test("a fresh configuration is conflict-free by default")
    func freshConfigurationDoesNotSwitchTheSource() {
        #expect(!VoiceInputConfiguration.default.switchesVoiceSourceAutomatically)
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
