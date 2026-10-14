import Foundation

/// Defaults for *where the voice shortcut lives* — a known input method's own
/// voice key.
///
/// LockIME never reads or writes an input method's private settings, so these
/// are only seeds for the Settings field, and only for input methods whose
/// documented default is stable. Anything not listed here starts empty and the
/// user records the combination they see inside that input method.
public enum SystemVoiceShortcutPreset {
    /// Input methods with a known default voice key, keyed by input-method
    /// bundle ID. Matching is by bundle-ID *prefix*, so a helper or a future
    /// build (`…doubaoime.helper`) still resolves.
    private static let presetsByBundleIDPrefix: [String: VoiceShortcut] = [
        // Doubao IME: the Fn / 🌐 key by default.
        "com.bytedance.inputmethod.doubaoime": .functionKey,
    ]

    /// The preset for the input method that owns `bundleID`, if known.
    public static func shortcut(forInputMethodBundleID bundleID: String?) -> VoiceShortcut? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return presetsByBundleIDPrefix.first { bundleID.hasPrefix($0.key) }?.value
    }

    /// Every preset, for tests and future picker affordances.
    public static var all: [VoiceShortcut] {
        presetsByBundleIDPrefix.values.sorted { $0.keyCode < $1.keyCode }
    }
}
