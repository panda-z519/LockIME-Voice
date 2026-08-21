import Testing

@testable import LockIMEKit

@Suite("InputSourceOrdering")
struct InputSourceOrderingTests {
    @Test("default source moves to the front while other sources stay stable")
    func defaultSourceMovesToFront() {
        let first = InputSource.stub("first")
        let preferred = InputSource.stub("preferred")
        let last = InputSource.stub("last")

        #expect(InputSourceOrdering.defaultFirst(
            [first, preferred, last],
            defaultSourceID: preferred.id
        ) == [preferred, first, last])
    }

    @Test("missing default source leaves system order unchanged")
    func missingDefaultSourceLeavesOrderUnchanged() {
        let sources = [InputSource.stub("first"), InputSource.stub("last")]

        #expect(InputSourceOrdering.defaultFirst(
            sources,
            defaultSourceID: nil
        ) == sources)
        #expect(InputSourceOrdering.defaultFirst(
            sources,
            defaultSourceID: "missing"
        ) == sources)
    }
}
