import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut that toggles LockIME ("Enable LockIME") on/off.
    /// `KeyboardShortcuts.Name` is an immutable name wrapper; safe as a constant.
    nonisolated(unsafe) static let toggleLock = Self("toggleLock")

    /// Global: lock to the previous / next entry in the input-source list,
    /// wrapping around the ends. Always lands on a valid source (never "none").
    nonisolated(unsafe) static let globalPreviousSource = Self("globalPreviousSource")
    nonisolated(unsafe) static let globalNextSource = Self("globalNextSource")

    /// Frontmost-app scoped: cycle *that app's* rule to the previous / next
    /// input source. A no-op when the frontmost app has no rule of its own.
    nonisolated(unsafe) static let appPreviousSource = Self("appPreviousSource")
    nonisolated(unsafe) static let appNextSource = Self("appNextSource")

    /// Frontmost-app scoped: remove that app's rule entirely. A no-op when the
    /// frontmost app has no rule.
    nonisolated(unsafe) static let removeFrontmostAppRule = Self("removeFrontmostAppRule")

    /// Global: start or end the voice input workflow. This is LockIME's *own*
    /// trigger key — deliberately a **different** combination from the selected
    /// input method's voice shortcut (see `VoiceInputConfiguration.voiceShortcut`).
    /// One key, handled once by LockIME, which then synthesizes the other; sharing
    /// a single combination is what made macOS and the input methods report a
    /// shortcut conflict.
    nonisolated(unsafe) static let voiceInput = Self("voiceInput")
}
