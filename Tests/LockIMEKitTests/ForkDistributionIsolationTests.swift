import Foundation
import Testing

@Suite("Fork distribution isolation")
struct ForkDistributionIsolationTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    @Test("app identity is independent from the upstream installation")
    func appIdentityIsIndependent() throws {
        let project = try Self.read("project.yml")
        let makefile = try Self.read("Makefile")

        #expect(project.contains("name: LockIMEVoice"))
        #expect(project.contains("LockIMEVoice:"))
        #expect(project.contains("PRODUCT_NAME: LockIME Voice"))
        #expect(project.contains("PRODUCT_NAME: LockIME Voice Dev"))
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.zhangsiqiang519.LockIMEVoice"))
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.zhangsiqiang519.LockIMEVoice.dev"))
        #expect(project.contains("LOCKIME_URL_SCHEME: lockime-voice"))
        #expect(project.contains("LOCKIME_URL_SCHEME: lockime-voice-dev"))
        #expect(!project.contains("PWJ9VF7HHT"))
        #expect(makefile.contains("SCHEME      := LockIMEVoice"))
        #expect(makefile.contains("PROJECT     := LockIMEVoice.xcodeproj"))
    }

    @Test("normal builds cannot contact the upstream update feed")
    func upstreamUpdatesAreDisabled() throws {
        let info = try Self.read("Sources/LockIME/Info.plist")
        let controller = try Self.read("Sources/LockIME/Updates/UpdateController.swift")

        #expect(!info.contains("SUFeedURL"))
        #expect(!info.contains("SUPublicEDKey"))
        #expect(!info.contains("SUEnableAutomaticChecks"))
        #expect(!controller.contains("oomol-lab.github.io/LockIME"))
        #expect(!FileManager.default.fileExists(atPath: Self.path(".github/workflows/release.yml")))
        #expect(!FileManager.default.fileExists(atPath: Self.path(".github/workflows/nightly.yml")))
        #expect(!FileManager.default.fileExists(atPath: Self.path(".github/workflows/build-publish.yml")))
        #expect(!(try Self.read("docs/RELEASING.md")).contains("oomol-lab"))
        #expect(!(try Self.read("SECURITY.md")).contains("Sparkle auto-update"))
        #expect(!(try Self.read("Makefile")).contains("Release archive (Developer ID)"))
    }

    @Test("user-facing repository links point to the maintained fork")
    func repositoryLinksPointToFork() throws {
        let fork = "https://github.com/zhangsiqiang519/LockIME-Voice"
        let readme = try Self.read("README.md")

        #expect(try Self.read("Sources/LockIME/UI/AboutView.swift").contains(fork))
        #expect(try Self.read("Sources/LockIME/AppState.swift").contains(fork))
        #expect(readme.contains(fork))
        #expect(readme.contains("# LockIME Voice"))
        #expect(readme.contains("## Voice Input Workflow"))
        #expect(readme.contains("Settings ▸ Voice Input"))
    }

    private static func read(_ relativePath: String) throws -> String {
        try String(contentsOfFile: path(relativePath), encoding: .utf8)
    }

    private static func path(_ relativePath: String) -> String {
        repoRoot.appending(path: relativePath).path
    }
}
