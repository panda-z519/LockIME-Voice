import AppKit
import LockIMEKit
import SwiftUI

struct VoiceInputSettingsPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Form {
            Section {
                Toggle("Enable Voice Input Workflow", isOn: Binding(
                    get: { state.voiceInputConfig.isEnabled },
                    set: { newValue in state.updateVoiceInputConfig { $0.isEnabled = newValue } }
                ))
            } header: {
                Text("Voice Input")
            } footer: {
                SectionFooter("Use this shortcut in any app to start or end the configured voice input workflow.")
            }

            Section {
                Picker("Voice input source", selection: Binding(
                    get: { state.voiceInputConfig.voiceSourceID },
                    set: { newValue in state.updateVoiceInputConfig { $0.voiceSourceID = newValue } }
                )) {
                    Text("None").tag(InputSourceID?.none)
                    ForEach(state.availableSources) { source in
                        Text(verbatim: source.localizedName).tag(Optional(source.id))
                    }
                }

                LabeledContent("Restore input source") {
                    Text(verbatim: restoreSourceName)
                }
            } header: {
                Text("Input Sources")
            } footer: {
                SectionFooter("After voice input ends, LockIME restores the global default input source from App Rules. Set that default rule before enabling the workflow.")
            }

            Section {
                Picker("Voice behavior", selection: Binding(
                    get: { state.voiceInputConfig.behavior },
                    set: { newValue in state.updateVoiceInputConfig { $0.behavior = newValue } }
                )) {
                    Text("Press once, press again to end").tag(VoiceInputBehavior.pressOncePressAgainEnds)
                    Text("Hold to speak").tag(VoiceInputBehavior.holdToSpeak)
                    Text("Press once, any key to end").tag(VoiceInputBehavior.pressOnceAnyKeyEnds)
                }

                VoiceShortcutEditor(
                    title: "Voice input method shortcut",
                    shortcut: Binding(
                        get: { state.voiceInputConfig.voiceShortcut },
                        set: { newValue in state.updateVoiceInputConfig { $0.voiceShortcut = newValue } }
                    )
                )

                if state.voiceInputConfig.isEnabled, !state.voiceInputPermissionsGranted {
                    AccessibilityRequiredNote("Voice input requires Accessibility and Input Monitoring")
                }

                Picker("Automatic restore timeout", selection: Binding(
                    get: { state.voiceInputConfig.restoreTimeout },
                    set: { newValue in state.updateVoiceInputConfig { $0.restoreTimeout = newValue } }
                )) {
                    Text("60 seconds").tag(VoiceRestoreTimeout.seconds(60))
                    Text("120 seconds").tag(VoiceRestoreTimeout.seconds(120))
                    Text("300 seconds").tag(VoiceRestoreTimeout.seconds(300))
                }
            } header: {
                Text("Voice Trigger")
            } footer: {
                SectionFooter("The voice behavior and shortcut here must match the voice input settings in the selected input method. LockIME only switches to that input method and sends this configured shortcut.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(state.loc("Voice Input"))
    }

    private var restoreSourceName: String {
        guard let id = state.config.defaultSourceID else { return state.loc("None") }
        return state.availableSources.first { $0.id == id }?.localizedName ?? id.rawValue
    }
}

private struct VoiceShortcutEditor: View {
    @Environment(AppState.self) private var state
    let title: LocalizedStringKey
    @Binding var shortcut: VoiceShortcut?
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

                if shortcut != nil {
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
