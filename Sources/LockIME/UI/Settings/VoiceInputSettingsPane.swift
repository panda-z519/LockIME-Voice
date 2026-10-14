import AppKit
import KeyboardShortcuts
import LockIMEKit
import SwiftUI

/// The voice-input workflow's configuration.
///
/// The model here is the *split* one: LockIME owns a global trigger shortcut of
/// its own (`KeyboardShortcuts.Name.voiceInput`) and synthesizes the selected
/// input method's own voice key. The two must be different combinations — when
/// they were one and the same, each press was handled twice (once by the input
/// method, once by LockIME's synthetic copy) and macOS reported a shortcut
/// conflict.
struct VoiceInputSettingsPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let workflowMode = state.voiceInputConfig.workflowMode(
            defaultSourceID: state.config.defaultSourceID
        )
        let errors = state.voiceInputConfig.validationErrors(
            defaultSourceID: state.config.defaultSourceID,
            installedSources: state.availableSources
        )
        let settingsLocked = state.voiceInputSessionInProgress
        Form {
            Section {
                Toggle("Enable Voice Input Workflow", isOn: Binding(
                    get: { state.voiceInputConfig.isEnabled },
                    set: { newValue in state.updateVoiceInputConfig { $0.isEnabled = newValue } }
                ))
                .disabled(settingsLocked)

                if settingsLocked {
                    VoiceInputStatusNote(
                        "Voice input is active. End the current session before changing these settings.",
                        systemImage: "waveform"
                    )
                }
            } header: {
                Text("Voice Input")
            } footer: {
                SectionFooter("LockIME takes over your voice shortcut so the input method never sees the press, and sends it back to start and stop recording. It never listens for your typing.")
            }

            Section {
                // ONE shortcut, and it is the input method's own voice key. The
                // user records the same key they already configured inside the
                // input method; LockIME owns that key (consuming the press so the
                // input method never sees it) and echoes it back to start and end
                // the recording. Recording it here is what lets LockIME know which
                // key to own — there is no second shortcut to keep in sync.
                KeyboardShortcuts.Recorder(
                    LocalizedStringKey("Voice shortcut"),
                    name: .voiceInput
                )
                // No bookkeeping needed here: the consuming tap yields the key
                // by itself whenever this window holds focus (see
                // `AppState.isSettingsWindowFocused`), so the recorder can read a
                // press while the tap stays active the rest of the time.

                if !state.voiceKeyConfigured {
                    VoiceInputStatusNote(
                        "Record your input method's voice shortcut here. It must be the same shortcut that starts voice input inside your input method.",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                // A consuming tap needs Accessibility: it is what lets LockIME
                // take the key away from the input method. Saying so is not
                // optional — without the grant the tap cannot install and the key
                // falls through to the input method, which is the conflict again.
                if !state.accessibilityGranted {
                    AccessibilityRequiredNote("Voice input needs Accessibility to take over the voice shortcut so macOS stops reporting a shortcut conflict")
                } else if !canSendShortcut {
                    AccessibilityRequiredNote("Voice input requires permission to send keyboard events")
                }

                if state.voiceInputRuntimeError != nil {
                    VoiceInputStatusNote(
                        "The last voice input workflow failed. Check that the configured input source is still available and that the shortcut matches your input method.",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            } header: {
                Text("Voice Trigger")
            } footer: {
                SectionFooter("Set this to the same shortcut you use for voice input inside your input method. LockIME takes over that key, so macOS no longer reports a shortcut conflict, and pressing it starts or ends voice input.")
            }

            Section {
                Toggle("Switch input source automatically", isOn: Binding(
                    get: { state.voiceInputConfig.switchesVoiceSourceAutomatically },
                    set: { newValue in
                        state.updateVoiceInputConfig { $0.switchesVoiceSourceAutomatically = newValue }
                    }
                ))
                .disabled(settingsLocked)

                if state.voiceInputConfig.switchesVoiceSourceAutomatically {
                    Picker("Voice input source", selection: Binding(
                        get: { state.voiceInputConfig.voiceSourceID },
                        set: { newValue in state.updateVoiceInputConfig { $0.voiceSourceID = newValue } }
                    )) {
                        Text("None").tag(InputSourceID?.none)
                        if let id = state.voiceInputConfig.voiceSourceID,
                           !state.availableSources.contains(where: { $0.id == id }) {
                            Text(verbatim: "\(id.rawValue) — \(state.loc("Unavailable"))")
                                .tag(Optional(id))
                        }
                        ForEach(state.availableSources) { source in
                            Text(verbatim: source.localizedName).tag(Optional(source.id))
                        }
                    }
                    .disabled(settingsLocked)

                    LabeledContent("Restore input source") {
                        Text(verbatim: restoreSourceName)
                    }

                    if workflowMode == .direct {
                        VoiceInputStatusNote(
                            "The voice input source is already the global default, so no switch is needed and its shortcut is sent directly.",
                            systemImage: "info.circle"
                        )
                    }
                } else {
                    VoiceInputStatusNote(
                        "Off: the shortcut alone starts voice input in whichever input method is active, and your input source is never changed.",
                        systemImage: "info.circle"
                    )
                }

                ForEach(sourceProblems) { problem in
                    VoiceInputStatusNote(problem.message, systemImage: "exclamationmark.triangle")
                }

                if state.voiceInputConfig.switchesVoiceSourceAutomatically {
                    Picker("Automatic restore timeout", selection: Binding(
                        get: { state.voiceInputConfig.restoreTimeout },
                        set: { newValue in state.updateVoiceInputConfig { $0.restoreTimeout = newValue } }
                    )) {
                        Text("60 seconds").tag(VoiceRestoreTimeout.seconds(60))
                        Text("120 seconds").tag(VoiceRestoreTimeout.seconds(120))
                        Text("300 seconds").tag(VoiceRestoreTimeout.seconds(300))
                    }
                    .disabled(settingsLocked)
                }
            } header: {
                Text("Input Sources")
            } footer: {
                if state.voiceInputConfig.switchesVoiceSourceAutomatically {
                    SectionFooter("After voice input ends, LockIME restores the global default input source from App Rules. Set that default rule before turning this on.")
                } else {
                    SectionFooter("Turn this on only when the voice input method is not the one you normally type in: LockIME then switches to it and restores your global default afterwards.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(state.loc("Voice Input"))
    }

    private var canSendShortcut: Bool {
VoiceInputConfiguration.hasRequiredSystemPermissions(eventPostingGranted: state.eventPostingGranted)
    }

    /// Source-related validation problems, in user-facing form and stable order.
    private var sourceProblems: [VoiceInputSourceProblem] {
        let errors = state.voiceInputConfig.validationErrors(
            defaultSourceID: state.config.defaultSourceID,
            installedSources: state.availableSources
        )
        var problems: [VoiceInputSourceProblem] = []
        if errors.contains(.missingVoiceSource) {
            problems.append(VoiceInputSourceProblem(id: 0, message: "Select a voice input source before using voice input."))
        }
        if errors.contains(.missingDefaultSource) {
            problems.append(VoiceInputSourceProblem(id: 1, message: "Set a global default input source in App Rules before using voice input."))
        }
        if errors.contains(where: { if case .voiceSourceUnavailable = $0 { true } else { false } }) {
            problems.append(VoiceInputSourceProblem(id: 2, message: "The configured voice input source is unavailable."))
        }
        if errors.contains(where: { if case .defaultSourceUnavailable = $0 { true } else { false } }) {
            problems.append(VoiceInputSourceProblem(id: 3, message: "The configured global default input source is unavailable."))
        }
        return problems
    }

    private var restoreSourceName: String {
        guard let id = state.config.defaultSourceID else { return state.loc("Not set") }
        return state.availableSources.first { $0.id == id }?.localizedName
            ?? "\(id.rawValue) — \(state.loc("Unavailable"))"
    }
}

/// One source-validation note. The `id` keeps the `ForEach` order stable and
/// gives the list an identity SwiftUI can diff.
private struct VoiceInputSourceProblem: Identifiable {
    let id: Int
    let message: LocalizedStringKey
}

private struct VoiceInputStatusNote: View {
    private let message: LocalizedStringKey
    private let systemImage: String

    init(_ message: LocalizedStringKey, systemImage: String) {
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(DS.Font.sectionFooter)
            .foregroundStyle(.secondary)
            .padding(.vertical, DS.Spacing.xxs)
    }
}
