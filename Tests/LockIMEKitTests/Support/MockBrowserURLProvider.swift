@testable import LockIMEKit

@MainActor
final class MockBrowserURLProvider: BrowserURLProviding {
    var url: String?
    private(set) var readCount = 0

    init(url: String? = nil) {
        self.url = url
    }

    func currentURL(forBundleID bundleID: String?) -> String? {
        readCount += 1
        return url
    }
}
