import XCTest
@testable import chillnote

final class RefinePostProcessorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "useImplicitStructuringInVoiceRefine")
        UserDefaults.standard.removeObject(forKey: "useImplicitChecklistInVoiceRefine")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "useImplicitStructuringInVoiceRefine")
        UserDefaults.standard.removeObject(forKey: "useImplicitChecklistInVoiceRefine")
        super.tearDown()
    }

    func testImplicitTodoConvertsBulletsToChecklistWithoutKeywords() {
        let refined = """
        - 联系设计确认首页改版
        - 提交测试包给 QA
        """
        let original = "联系设计确认首页改版，然后提交测试包给 QA。"

        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: original,
            isShortInput: false
        )

        XCTAssertTrue(output.contains("- [ ] 联系设计确认首页改版"))
        XCTAssertTrue(output.contains("- [ ] 提交测试包给 QA"))
    }

    func testInformationalParagraphDoesNotConvertToChecklist() {
        let refined = "今天我们复盘了上线质量，主要问题是监控告警延迟。"
        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: refined,
            isShortInput: false
        )

        XCTAssertFalse(output.contains("- [ ]"))
        XCTAssertEqual(output, refined)
    }

    func testMixedNotesAndTaskBulletsPreservesNotesThenChecklist() {
        let refined = """
        这个版本的目标是稳定性优先。
        - 跟进崩溃日志
        - 安排补丁发布
        """
        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: refined,
            isShortInput: false
        )

        XCTAssertTrue(output.contains("这个版本的目标是稳定性优先。"))
        XCTAssertTrue(output.contains("- [ ] 跟进崩溃日志"))
        XCTAssertTrue(output.contains("- [ ] 安排补丁发布"))
    }

    func testExistingChecklistStateIsPreserved() {
        let refined = """
        - [x] 已完成回归测试
        - [ ] 提交上线申请
        """
        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: refined,
            isShortInput: false
        )

        XCTAssertTrue(output.contains("- [x] 已完成回归测试"))
        XCTAssertTrue(output.contains("- [ ] 提交上线申请"))
    }

    func testShortInputStaysMinimalWithoutForcedChecklist() {
        let refined = "联系小王"
        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: refined,
            isShortInput: true
        )

        XCTAssertEqual(output, "联系小王")
        XCTAssertFalse(output.contains("- [ ]"))
    }

    func testMixedLanguageTasksStillConvert() {
        let refined = """
        - review onboarding copy
        - 更新 API 文档
        """
        let original = "review onboarding copy, 更新 API 文档"

        let output = RefinePostProcessor.process(
            refinedText: refined,
            originalTranscript: original,
            isShortInput: false
        )

        XCTAssertTrue(output.contains("- [ ] review onboarding copy"))
        XCTAssertTrue(output.contains("- [ ] 更新 API 文档"))
    }
}
