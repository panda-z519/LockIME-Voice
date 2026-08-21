import Foundation

/// The unified-logging subsystem for every LockIME `os.Logger`.
///
/// It is the **running** bundle's identifier, so a Debug build logs under
/// `com.zhangsiqiang519.LockIMEVoice.dev` and a Release build under
/// `com.zhangsiqiang519.LockIMEVoice` —
/// matching how the app is actually installed, instead of a baked-in release id.
/// Falls back to the release id only when there is no bundle identifier at all
/// (e.g. a bare test host).
public enum LogSubsystem {
    public static let current = Bundle.main.bundleIdentifier ?? "com.zhangsiqiang519.LockIMEVoice"
}
