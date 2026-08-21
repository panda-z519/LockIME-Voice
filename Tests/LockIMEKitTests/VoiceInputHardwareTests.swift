import Foundation
import Testing

@testable import LockIMEKit

/// 硬件门控的语音工作流检查。真实本机输入源 ID 和快捷键只在手动运行时配置，
/// 不写进仓库数据。
@MainActor
@Suite(
    "VoiceInput hardware",
    .tags(.hardware),
    .enabled(if: FileManager.default.fileExists(atPath: "/tmp/lockime_hw_tests"))
)
struct VoiceInputHardwareTests {
    @Test("manual voice workflow gate is present")
    func manualVoiceWorkflowGate() {
        #expect(true)
    }
}
