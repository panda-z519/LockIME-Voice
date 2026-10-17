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

        // No production feed or key is configured, so a Release build has
        // nothing to poll and no in-app auto-update: publishing is automated,
        // installing an update is not yet. Adding either key requires updating
        // this guard deliberately (see docs/RELEASING.md).
        #expect(!info.contains("SUFeedURL"))
        #expect(!info.contains("SUPublicEDKey"))
        #expect(!info.contains("SUEnableAutomaticChecks"))
        #expect(!controller.contains("oomol-lab.github.io/LockIME"))
        // Upstream's bespoke publishing workflows must never be restored...
        #expect(!FileManager.default.fileExists(atPath: Self.path(".github/workflows/nightly.yml")))
        #expect(!FileManager.default.fileExists(atPath: Self.path(".github/workflows/build-publish.yml")))
        // ...while the fork's own automated release workflow is the one that
        // exists, and it must publish only to the fork.
        #expect(FileManager.default.fileExists(atPath: Self.path(".github/workflows/release.yml")))
        let release = try Self.read(".github/workflows/release.yml")
        #expect(release.contains("tags:"))
        #expect(!release.contains("oomol-lab"))
        #expect(!release.contains("PWJ9VF7HHT"))
        #expect(!release.contains("blacksmith-6vcpu-macos-latest"))
        // Reusing upstream's appcast would let their release install over this
        // fork's build, so its host can appear only as a warning, never a URL.
        #expect(!release.contains("oomol-lab.github.io"))
        #expect(!(try Self.read("docs/RELEASING.md")).contains("oomol-lab.github.io"))
        #expect(!(try Self.read("SECURITY.md")).contains("Sparkle auto-update"))
        #expect(!(try Self.read("Makefile")).contains("Release archive (Developer ID)"))
    }

    @Test("user-facing repository links point to the maintained fork")
    func repositoryLinksPointToFork() throws {
        let fork = "https://github.com/panda-z519/LockIME-Voice"
        let readme = try Self.read("README.md")

        #expect(try Self.read("Sources/LockIME/UI/AboutView.swift").contains(fork))
        #expect(try Self.read("Sources/LockIME/AppState.swift").contains(fork))
        #expect(readme.contains(fork))
        #expect(readme.contains("# LockIME Voice"))
        #expect(readme.contains("## Voice Input Workflow"))
        #expect(readme.contains("Settings ▸ Voice Input"))
    }

    @Test("release documentation matches the version in project.yml")
    func releaseDocumentationIsComplete() throws {
        let project = try Self.read("project.yml")
        let readme = try Self.read("README.md")
        let screenshot = Self.path("docs/images/settings-voice-input-zh-CN.png")

        // Read the version instead of pinning it, so a release only bumps
        // project.yml — and this test then demands the docs follow.
        let match = try #require(project.firstMatch(of: /MARKETING_VERSION: "([0-9.]+)"/))
        let version = String(match.1)
        #expect(readme.contains("## Changes in LockIME Voice"))
        #expect(readme.contains("docs/images/settings-voice-input-zh-CN.png"))
        #expect(readme.contains("LockIME-Voice-\(version)-arm64.dmg"))
        #expect(readme.contains("LockIME-Voice-\(version)-x86_64.dmg"))
        #expect(FileManager.default.fileExists(atPath: screenshot))
        #expect(
            FileManager.default.fileExists(atPath: Self.path("docs/release-notes/\(version).md")),
            "the release workflow refuses to publish without docs/release-notes/\(version).md"
        )

        let translations = try FileManager.default.contentsOfDirectory(
            atPath: Self.path("docs/README")
        ).filter { $0.hasPrefix("README.") && $0.hasSuffix(".md") }
        #expect(translations.count == 8)
        for file in translations {
            let translated = try Self.read("docs/README/\(file)")
            #expect(translated.contains("## Changes in LockIME Voice"), "\(file) missing changes section")
            #expect(translated.contains("../images/settings-voice-input-zh-CN.png"), "\(file) missing screenshot")
            #expect(translated.contains("LockIME-Voice-\(version)-arm64.dmg"), "\(file) links an old installer")
        }
    }

    private static func read(_ relativePath: String) throws -> String {
        try String(contentsOfFile: path(relativePath), encoding: .utf8)
    }

    private static func path(_ relativePath: String) -> String {
        repoRoot.appending(path: relativePath).path
    }
}
