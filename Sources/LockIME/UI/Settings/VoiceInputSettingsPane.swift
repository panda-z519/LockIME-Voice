import AppKit
import KeyboardShortcuts
import LockIMEKit
import SwiftUI

/// The voice-input workflow's configuration.
///
/// One key: the input method's own voice shortcut. LockIME takes that key over
/// (the input method never sees the physical press) and sends it back itself,
/// so each press is handled exactly once and macOS reports no conflict.
struct VoiceInputSettingsPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let workflowMode = state.voiceInputConfig.workflowMode(
            defaultSourceID: state.config.defaultSourceID
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
                //
                // A custom editor rather than `KeyboardShortcuts.Recorder`: voice
                // keys are often a lone modifier (right ⌥, right ⌘), which that
                // recorder cannot capture. While it records, the consuming tap
                // yields the key (`AppState.isRecordingVoiceKey`).
                VoiceShortcutEditor(
                    title: "Voice shortcut",
                    shortcut: Binding(
                        get: { state.voiceInputConfig.voiceShortcut },
                        set: { newValue in state.updateVoiceInputConfig { $0.voiceShortcut = newValue } }
                    ),
                    isDisabled: settingsLocked
                )

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
                }

                // Name the actual failure. "The workflow failed" is useless when
                // the fix is a permission: macOS dropping our synthetic key looks
                // exactly like "the input method never woke up".
                if let failure = state.voiceInputRuntimeError {
                    switch failure {
                    case .eventTapUnavailable:
                        AccessibilityRequiredNote("Voice input needs Accessibility to take over the voice shortcut so macOS stops reporting a shortcut conflict")
                    case .eventPostingUnavailable:
                        AccessibilityRequiredNote("Voice input needs Accessibility to take over the voice shortcut so macOS stops reporting a shortcut conflict")
                    default:
                        VoiceInputStatusNote(
                            "The last voice input workflow failed. Check that the configured input sources are still available.",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
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
                    } else {
                        // The session hands the source back on the first keystroke,
                        // so a voice input method that never starts recording (no
                        // microphone, denied mic permission) can't strand the user
                        // on the voice source until the safety timeout.
                        VoiceInputStatusNote(
                            "Typing while voice input is active ends the session and returns you to your text input source.",
                            systemImage: "keyboard"
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
        // The grant is often given in System Settings while this pane is open;
        // pick it up on return so the tap is armed without a relaunch.
        .onAppear { state.refreshAccessibilityStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshAccessibilityStatus()
        }
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

/// Records the voice key, including a lone modifier such as right ⌥.
private struct VoiceShortcutEditor: View {
    @Environment(AppState.self) private var state
    let title: LocalizedStringKey
    @Binding var shortcut: VoiceShortcut?
    let isDisabled: Bool
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var recorder = VoiceShortcutRecorder()

    var body: some View {
        LabeledContent(title) {
            ZStack {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    Text(isRecording ? state.loc("Press shortcut…") : displayText)
                        .foregroundStyle(shortcut == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)

                if shortcut != nil, !isDisabled, !isRecording {
                    HStack {
                        Spacer()
                        Button {
                            shortcut = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear")
                        .accessibilityLabel("Clear")
                    }
                    .padding(.trailing, DS.Spacing.xs)
                }
            }
            .frame(width: 126, height: 28)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isRecording ? 1 : 0.5)
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .onChange(of: isDisabled) { _, disabled in
            if disabled { stopRecording() }
        }
        .onDisappear(perform: stopRecording)
        // While recording, the tap lets the key through. Leaving LockIME must end
        // that, or the voice key would reach the input method system-wide.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            stopRecording()
        }
    }

    private var displayText: String {
        guard let shortcut else { return state.loc("Click to set") }
        return shortcut.displayText(
            leftLabel: state.loc("Left"),
            rightLabel: state.loc("Right")
        )
    }

    private func startRecording() {
        guard !isDisabled else { return }
        stopRecording()
        recorder.reset()
        isRecording = true
        state.isRecordingVoiceKey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Esc cancels, keeping the previous key.
            if event.type == .keyDown, event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let modifiers = VoiceShortcut.Modifiers(event.modifierFlags)
            let recorded: VoiceShortcut? = switch event.type {
            case .keyDown:
                Optional(recorder.handleKeyDown(keyCode: event.keyCode, modifiers: modifiers))
            case .flagsChanged:
                // A lone modifier is recorded on its release, so ⌥ held on the
                // way to ⌥V doesn't end the recording early.
                recorder.handleModifierChange(
                    keyCode: VoiceShortcut.canonicalModifierKeyCode(
                        eventKeyCode: event.keyCode,
                        deviceFlagsRawValue: UInt64(event.modifierFlags.rawValue)
                    ),
                    modifiers: modifiers
                )
            default:
                nil
            }
            if let recorded {
                shortcut = recorded
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        state.isRecordingVoiceKey = false
        recorder.reset()
    }
}

private extension VoiceShortcut.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
    }
}
