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
                SectionFooter("LockIME sends the voice shortcut for you; it never listens for your keys. Keep the two shortcuts below different from each other.")
            }

            Section {
                // LockIME's own trigger — a real global shortcut, recorded and
                // dispatched by KeyboardShortcuts. This is the key the user presses.
                KeyboardShortcuts.Recorder(
                    LocalizedStringKey("LockIME voice shortcut"),
                    name: .voiceInput
                )

                // The input method's own voice key — only ever synthesized, so
                // LockIME never also receives it. Pointing both at one
                // combination is exactly what produced the conflict prompt.
                VoiceShortcutEditor(
                    title: "Input method voice shortcut",
                    shortcut: Binding(
                        get: { state.voiceInputConfig.voiceShortcut },
                        set: { newValue in state.updateVoiceInputConfig { $0.voiceShortcut = newValue } }
                    ),
                    isDisabled: settingsLocked
                )
                .id(state.voiceInputConfig.voiceSourceID)

                if clashesWithTriggerShortcut {
                    VoiceInputStatusNote(
                        "This is the same combination as LockIME's voice shortcut. Use two different shortcuts, or the key is handled twice and macOS reports a shortcut conflict.",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                // The trigger is LockIME's own key and has no legacy value to
                // carry over, so an upgraded user arrives here with it unset.
                if KeyboardShortcuts.getShortcut(for: .voiceInput) == nil {
                    VoiceInputStatusNote(
                        "Record a shortcut here first. It is LockIME's own trigger and must differ from the input method's voice shortcut below.",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                if errors.contains(.missingVoiceShortcut) {
                    VoiceInputStatusNote(
                        "Record the selected input method's voice shortcut here. It must match the shortcut configured inside that input method.",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                if !canSendShortcut {
                    AccessibilityRequiredNote("Voice input requires permission to send keyboard events")
                }

                if state.voiceInputRuntimeError != nil {
                    VoiceInputStatusNote(
                        "The last voice input workflow failed. Check that the configured input sources are still available.",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            } header: {
                Text("Voice Trigger")
            } footer: {
                SectionFooter("The upper shortcut is LockIME's own trigger; the lower one is the shortcut configured inside the selected input method. Set that one in the input method first, and never bind both to the same combination.")
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

    /// Whether both shortcuts are bound to the same combination — the exact
    /// configuration that made a single press count twice.
    private var clashesWithTriggerShortcut: Bool {
        guard let configured = state.voiceInputConfig.voiceShortcut,
              let trigger = KeyboardShortcuts.getShortcut(for: .voiceInput)
        else { return false }
        return configured.recordedShortcut == trigger
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

                if shortcut != nil, !isDisabled {
                    HStack {
                        Spacer()
                        Button {
                            shortcut = nil
                            stopRecording()
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
                    .stroke(.separator.opacity(0.45), lineWidth: 0.5)
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .onChange(of: isDisabled) { _, disabled in
            if disabled { stopRecording() }
        }
        .onDisappear(perform: stopRecording)
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown, event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let modifiers = VoiceShortcut.Modifiers(event.modifierFlags)
            let recorded: VoiceShortcut? = switch event.type {
            case .keyDown:
                Optional(recorder.handleKeyDown(keyCode: event.keyCode, modifiers: modifiers))
            case .flagsChanged:
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

