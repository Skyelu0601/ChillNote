//
//  chillnoteTests.swift
//  chillnoteTests
//
//  Created by 陆文婷 on 2026/1/5.
//

import XCTest
@testable import chillnote

final class chillnoteTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testChecklistMarkdownParsesEmptyItem() throws {
        let parsed = ChecklistMarkdown.parse("- [ ]")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, false)
        XCTAssertEqual(parsed?.items.first?.text, "")
    }

    func testLanguageDetectionReturnsChineseForChineseText() throws {
        let text = """
        今天天气很好，我们计划下午去公园散步，然后一起喝咖啡聊聊天。这是一段用于语言识别的较长中文文本。
        """
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("zh") == true)
    }

    func testLanguageDetectionReturnsEnglishForEnglishText() throws {
        let text = """
        This is a longer piece of English text used for language identification. It should be reliably detected as English by the language recognizer.
        """
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("en") == true)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
