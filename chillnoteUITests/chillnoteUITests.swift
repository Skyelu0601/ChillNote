//
//  chillnoteUITests.swift
//  chillnoteUITests
//
//  Created by 陆文婷 on 2026/1/5.
//

import XCTest

final class chillnoteUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testWeeklyTopicsExpandInPlace() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-weekly-topics-design-preview",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN"
        ]
        app.launch()

        let firstTopic = app.buttons["weekly-topic-row-topic-1"]
        XCTAssertTrue(firstTopic.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["YouTube"].exists)

        let secondTopic = app.buttons["weekly-topic-row-topic-2"]
        XCTAssertTrue(secondTopic.waitForExistence(timeout: 2))
        secondTopic.tap()

        XCTAssertTrue(app.staticTexts["TikTok"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["YouTube"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
