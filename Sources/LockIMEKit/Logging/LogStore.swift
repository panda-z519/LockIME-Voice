import Foundation
import OSLog
import SwiftData

/// Disk-backed store for activation log entries with 24-hour retention.
@MainActor
public final class LogStore {
    public static let retention: TimeInterval = 24 * 60 * 60

    private static let log = Logger(subsystem: LogSubsystem.current, category: "LogStore")
    static func defaultDirectory(for bundleIdentifier: String?) -> URL {
        if bundleIdentifier == "com.zhangsiqiang519.LockIMEVoice" {
            return URL.applicationSupportDirectory.appending(path: "LockIME Voice", directoryHint: .isDirectory)
        }
        if let bundleID = bundleIdentifier, !bundleID.isEmpty {
            return URL.applicationSupportDirectory.appending(path: bundleID, directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory.appending(path: "LockIME", directoryHint: .isDirectory)
    }

    public let container: ModelContainer
    /// Saves are coalesced: a forced switch can come in quick bursts (app hops,
    /// a tug-of-war), and each save is a synchronous SQLite write on the main
    /// thread. Unsaved inserts are still visible to every fetch on the main
    /// context (the log pane, the `list-log` API); `flush()` persists them.
    private let saveDebouncer = Debouncer(delay: .seconds(2))
    private var hasUnsavedEntries = false

    public init(inMemory: Bool = false, directoryOverride: URL? = nil) {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            // Use a dedicated subdirectory — the default store lands directly in
            // ~/Library/Application Support and would collide across apps.
            let directory = directoryOverride ?? Self.defaultDirectory(for: Bundle.main.bundleIdentifier)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: directory.appending(path: "ActivationLog.store"))
        }
        if let container = try? ModelContainer(for: ActivationLogEntry.self, configurations: configuration) {
            self.container = container
        } else {
            // Last-resort fallback so the app still runs if the disk store fails.
            self.container = try! ModelContainer(
                for: ActivationLogEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    /// Persist an event. `triggeringAppName` is the display name the caller
    /// resolved from `event.triggeringBundleID` (resolution needs `NSWorkspace`,
    /// which the non-UI kit avoids).
    public func record(_ event: ActivationEvent, triggeringAppName: String? = nil) {
        container.mainContext.insert(ActivationLogEntry(event, triggeringAppName: triggeringAppName))
        hasUnsavedEntries = true
        saveDebouncer.schedule { [weak self] in self?.flush() }
    }

    /// Persist any recorded entries now. Called on shutdown, and by the
    /// coalescing timer.
    public func flush() {
        saveDebouncer.cancel()
        guard hasUnsavedEntries else { return }
        hasUnsavedEntries = false
        do {
            try container.mainContext.save()
        } catch {
            Self.log.error("Failed to save activation log entries: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Delete entries older than `retention` relative to `now`.
    public func purgeExpired(now: Date = .now, retention: TimeInterval = LogStore.retention) {
        let cutoff = now.addingTimeInterval(-retention)
        // The batch delete runs against the store, so entries still pending in
        // the context would escape it: persist them first.
        flush()
        do {
            try container.mainContext.delete(
                model: ActivationLogEntry.self,
                where: #Predicate { $0.timestamp < cutoff }
            )
            try container.mainContext.save()
        } catch {
            Self.log.error("Failed to purge expired log entries: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func count() -> Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<ActivationLogEntry>())) ?? 0
    }

    /// The activation entries within the retention window, newest first — the
    /// same set the Activation Log pane shows. Used by the `lockime-voice://list-log`
    /// query. `limit` caps the returned count (most recent kept) when set.
    public func recent(
        now: Date = .now,
        retention: TimeInterval = LogStore.retention,
        limit: Int? = nil
    ) -> [ActivationLogEntry] {
        let cutoff = now.addingTimeInterval(-retention)
        var descriptor = FetchDescriptor<ActivationLogEntry>(
            predicate: #Predicate { $0.timestamp > cutoff },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }
}
