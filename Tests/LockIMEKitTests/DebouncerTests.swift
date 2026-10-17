import Testing

@testable import LockIMEKit

@MainActor
@Suite("Debouncer")
struct DebouncerTests {
    @Test("a burst runs once, for the last call")
    func burstRunsOnce() async throws {
        let debouncer = Debouncer(delay: .milliseconds(30))
        var runs: [Int] = []
        for value in 1...5 {
            debouncer.schedule { runs.append(value) }
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(runs == [5])
    }

    @Test("calls far enough apart each run")
    func spacedCallsEachRun() async throws {
        let debouncer = Debouncer(delay: .milliseconds(10))
        var runs = 0
        debouncer.schedule { runs += 1 }
        try await Task.sleep(for: .milliseconds(150))
        debouncer.schedule { runs += 1 }
        try await Task.sleep(for: .milliseconds(150))
        #expect(runs == 2)
    }

    @Test("cancel drops the pending call")
    func cancelDrops() async throws {
        let debouncer = Debouncer(delay: .milliseconds(20))
        var ran = false
        debouncer.schedule { ran = true }
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(120))
        #expect(!ran)
    }
}
