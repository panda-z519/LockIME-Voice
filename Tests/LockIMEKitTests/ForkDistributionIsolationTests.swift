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
        let ci = try Self.read(".github/workflows/ci.yml")

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
        #expect(ci.contains("workflow_dispatch:"))
        #expect(ci.contains("runs-on: macos-26"))
        #expect(!ci.contains("blacksmith-6vcpu-macos-latest"))
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

    @Test("v0.1.2 release documentation includes changes screenshot and installers")
    func releaseDocumentationIsComplete() throws {
        let project = try Self.read("project.yml")
        let readme = try Self.read("README.md")
        let screenshot = Self.path("docs/images/settings-voice-input-zh-CN.png")

        #expect(project.contains(#"MARKETING_VERSION: "0.1.2""#))
        #expect(readme.contains("## Changes in LockIME Voice"))
        #expect(readme.contains("docs/images/settings-voice-input-zh-CN.png"))
        #expect(readme.contains("LockIME-Voice-0.1.2-arm64.dmg"))
        #expect(readme.contains("LockIME-Voice-0.1.2-x86_64.dmg"))
        #expect(FileManager.default.fileExists(atPath: screenshot))

        let translations = try FileManager.default.contentsOfDirectory(
            atPath: Self.path("docs/README")
        ).filter { $0.hasPrefix("README.") && $0.hasSuffix(".md") }
        #expect(translations.count == 8)
        for file in translations {
            let translated = try Self.read("docs/README/\(file)")
            #expect(translated.contains("## Changes in LockIME Voice"), "\(file) missing changes section")
            #expect(translated.contains("../images/settings-voice-input-zh-CN.png"), "\(file) missing screenshot")
        }
    }

    private static func read(_ relativePath: String) throws -> String {
        try String(contentsOfFile: path(relativePath), encoding: .utf8)
    }

    private static func path(_ relativePath: String) -> String {
        repoRoot.appending(path: relativePath).path
    }
}
