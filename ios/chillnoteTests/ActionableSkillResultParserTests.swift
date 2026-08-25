import XCTest
@testable import chillnote

final class ActionableSkillResultParserTests: XCTestCase {
    func testParsesLabeledHookParagraphs() {
        let result = """
        Pain Point: Tired of spending hours on repetitive work?

        Contrarian: Stop doing everything yourself.

        Curiosity Gap: The last tool changed how I create.
        """

        let blocks = ActionableSkillResultParser.hookBlocks(from: result)

        XCTAssertEqual(blocks.map(\.label), ["Pain Point", "Contrarian", "Curiosity Gap"])
        XCTAssertEqual(blocks[1].content, "Stop doing everything yourself.")
    }

    func testParsesNumberedMarkdownHookLines() {
        let result = """
        1. **Pain Point:** Tired of spending hours on repetitive work?
        2. **Contrarian:** Stop doing everything yourself.
        3. **How-to:** Build a lean creator workflow.
        """

        let blocks = ActionableSkillResultParser.hookBlocks(from: result)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].label, "Pain Point")
        XCTAssertEqual(blocks[2].content, "Build a lean creator workflow.")
    }

    func testParsesCaptionPackByPlatformSection() {
        let result = """
        ## TikTok

        Caption:
        A ready-to-post caption.

        Hashtags:
        #creator #workflow

        ## YouTube Shorts

        Title:
        A useful title

        Description:
        A useful description
        """

        let blocks = ActionableSkillResultParser.sectionBlocks(from: result)

        XCTAssertEqual(blocks.map(\.label), ["TikTok", "YouTube Shorts"])
        XCTAssertTrue(blocks[0].content.contains("A ready-to-post caption."))
        XCTAssertTrue(blocks[1].content.contains("A useful description"))
    }

    func testDoesNotTurnSinglePlainParagraphIntoAFalseHookBlock() {
        let blocks = ActionableSkillResultParser.hookBlocks(from: "One plain generated paragraph.")

        XCTAssertTrue(blocks.isEmpty)
    }
}
