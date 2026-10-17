import AppKit
import Foundation

/// Tracks the frontmost application via `NSWorkspace`, debouncing rapid
/// activations (e.g. Cmd-Tab) so we don't thrash the lock target.
@MainActor
public final class AppActivationMonitor: FrontmostAppMonitoring {
    private var task: Task<Void, Never>?
    private let debounce: Duration

    public init(debounce: Duration = .milliseconds(40)) {
        self.debounce = debounce
    }

    public func currentBundleID() -> String? {
        // `ruleIdentity`, not `bundleIdentifier`: a bundle-less process (e.g.
        // Minecraft's `java`) reports its synthetic `process:<name>` identity,
        // the same string the picker offers — otherwise it could never be
        // matched by a rule (and the log would show "—" for it).
        NSWorkspace.shared.frontmostApplication?.ruleIdentity
    }

    public func start(onChange: @escaping @MainActor (String?) -> Void) {
        guard task == nil else { return }
        let debouncer = Debouncer(delay: debounce)
        task = Task { @MainActor in
            let activations = NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didActivateApplicationNotification
            )
            for await _ in activations {
                // A Cmd-Tab burst reports once, for the app it settles on —
                // each report costs a full re-evaluation (and, for a browser,
                // Accessibility queries), so the skipped ones are pure waste.
                debouncer.schedule {
                    onChange(NSWorkspace.shared.frontmostApplication?.ruleIdentity)
                }
            }
            debouncer.cancel()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

/// Runs only the last of a burst of calls, `delay` after it arrived.
@MainActor
final class Debouncer {
    private let delay: Duration
    private var pending: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    func schedule(_ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        let delay = self.delay
        pending = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
