import AppKit
import LockIMEKit
import SwiftUI

/// The single home for LockIME's optional system permissions.
struct PermissionsSettingsPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section {
                if state.accessibilityGranted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Grant once to unlock three optional features:")
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            FeatureBullet("Per-URL rules in your browser")
                            FeatureBullet("Targeting launchers like Spotlight in app rules")
                            FeatureBullet("Sending the voice input shortcut")
                        }
                    }
                    GrantAccessibilityButton()
                }
            } header: {
                Text("Accessibility")
            } footer: {
                SectionFooter("The core lock needs no permissions.")
            }

            Section {
                if state.inputMonitoringGranted {
                    Label("Input Monitoring access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Keyboard event monitoring may be required for:")
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            FeatureBullet("Voice workflow shortcut and any-key ending")
                        }
                    }
                    GrantInputMonitoringButton()
                }
            } header: {
                Text("Input Monitoring")
            } footer: {
                SectionFooter("macOS may ask for Input Monitoring when LockIME listens for the key that ends a voice input session. The listener is pass-through and does not consume the key.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(state.loc("Permissions"))
        // The watcher's abandon-stop lives on SettingsRootView (window close), so
        // switching tabs mid-grant doesn't kill detection; panes only reconcile
        // the shared status, which also recovers a grant the watcher missed.
        .onAppear {
            state.refreshAccessibilityStatus()
            state.refreshVoiceInputPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshAccessibilityStatus()
            state.refreshVoiceInputPermissionStatus()
        }
    }
}

/// One unlocked-feature line in the Accessibility section's rationale.
private struct FeatureBullet: View {
    private let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
