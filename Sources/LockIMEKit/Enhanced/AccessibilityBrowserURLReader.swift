import AppKit
import ApplicationServices

/// Reads the frontmost browser's active-tab URL via the Accessibility API.
///
/// Best-effort and browser-dependent: it walks the focused window looking for an
/// element exposing `kAXURLAttribute` (the `AXWebArea`). Requires Accessibility
/// to be granted; returns `nil` otherwise. Node visits are budget-capped so a
/// large page can't make traversal expensive.
@MainActor
public final class AccessibilityBrowserURLReader: BrowserURLProviding {
    private let visitBudget: Int
    /// Re-walk the tree at least this often even when the cache looks valid, so
    /// a tab switch between two equally titled tabs can't pin a stale URL.
    private let maxCacheHits: Int

    /// The web area found by the last walk, and what it was found under. A walk
    /// costs up to `visitBudget` × 2 cross-process calls — and the engine polls
    /// every 1.5 s — while re-reading a known web area costs one; its `AXURL`
    /// stays live across in-page navigation. A different window or window title
    /// (which follows the active tab) invalidates it.
    private struct Cache {
        let pid: pid_t
        let window: AXUIElement
        let title: String?
        let webArea: AXUIElement
        var hits: Int
    }
    private var cache: Cache?
    /// Browsers already sent the accessibility wake attribute. Setting it is
    /// idempotent but still a cross-process call, so do it once per process.
    private var wokenPIDs: Set<pid_t> = []

    public init(visitBudget: Int = 4000, maxCacheHits: Int = 10) {
        self.visitBudget = visitBudget
        self.maxCacheHits = maxCacheHits
    }

    public func currentURL(forBundleID bundleID: String?) -> String? {
        guard BrowserBundleIDs.isBrowser(bundleID),
              AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == bundleID
        else { return nil }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        // Chromium and Gecko build their accessibility tree lazily; Safari keeps
        // it live and needs no opt-in. Each lazy engine exposes the
        // `AXWebArea`/`AXURL` only after the right wake signal is set on the app
        // element.
        if !wokenPIDs.contains(pid), BrowserBundleIDs.isChromium(bundleID) {
            wokenPIDs.insert(pid)
            AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        } else if !wokenPIDs.contains(pid), BrowserBundleIDs.isGecko(bundleID) {
            wokenPIDs.insert(pid)
            // Gecko (Firefox and forks) wakes on `AXEnhancedUserInterface` and
            // does not implement `AXManualAccessibility`. The set is idempotent;
            // the tree is built asynchronously, so the first read after a cold
            // wake can be nil — the engine's URL poll retries on its next tick.
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }

        guard let window = element(axApp, kAXFocusedWindowAttribute) else {
            cache = nil
            return nil
        }
        let title = string(window, kAXTitleAttribute)
        if var hit = cache, hit.pid == pid, hit.hits < maxCacheHits,
           CFEqual(hit.window, window), hit.title == title,
           let url = url(of: hit.webArea) {
            hit.hits += 1
            cache = hit
            return url
        }
        cache = nil
        var budget = visitBudget
        guard let (webArea, url) = findURL(in: window, budget: &budget) else { return nil }
        cache = Cache(pid: pid, window: window, title: title, webArea: webArea, hits: 0)
        return url
    }

    private func findURL(in element: AXUIElement, budget: inout Int) -> (AXUIElement, String)? {
        guard budget > 0 else { return nil }
        budget -= 1

        if let url = url(of: element) { return (element, url) }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement]
        else { return nil }

        for child in children {
            if let url = findURL(in: child, budget: &budget) { return url }
        }
        return nil
    }

    private func url(of element: AXUIElement) -> String? {
        var urlValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlValue) == .success
        else { return nil }
        if let url = urlValue as? URL { return url.absoluteString }
        if let string = urlValue as? String, !string.isEmpty { return string }
        return nil
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        // Safe: the CFGetTypeID check above guarantees this is an AXUIElement.
        return (value as! AXUIElement)
    }
}
