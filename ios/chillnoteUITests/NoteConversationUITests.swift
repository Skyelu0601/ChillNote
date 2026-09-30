import XCTest

final class NoteConversationUITests: XCTestCase {
    @MainActor
    func testSkillFollowUpReplaceAndUndoInCreate() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Create"].exists)
        XCTAssertTrue(app.buttons["Note"].exists)
        XCTAssertTrue(app.buttons["Record"].exists)
        XCTAssertFalse(app.staticTexts["Current note"].exists)
        XCTAssertFalse(app.buttons["note-chat-quick-skill-rewrite"].exists)
        XCTAssertFalse(app.staticTexts["All Skills"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-skill-")).count, 4)
        attach(app, "Create - empty state")
        rewrite.tap()
        let replace = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(replace.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["note-chat-quick-skill-rewrite"].exists)
        XCTAssertTrue(app.buttons["note-chat-skills"].isHittable)
        XCTAssertFalse(app.staticTexts["What would you like to do?"].exists)
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        input.tap()
        input.typeText("Make it shorter")
        app.buttons["note-chat-send"].tap()
        let answer = app.staticTexts["Capture your idea now. Shape it into a script later."]
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        attach(app, "Create - skill and follow-up")
        let replacements = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-"))
        replacements.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["note-chat-undo"].waitForExistence(timeout: 3))
        app.buttons["Note"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue((app.textViews.firstMatch.value as? String)?.contains("Capture your idea now") == true)
        app.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["note-chat-undo"].waitForExistence(timeout: 3))
        app.buttons["note-chat-undo"].tap()
        app.buttons["Note"].tap()
        XCTAssertTrue((app.textViews.firstMatch.value as? String)?.contains("Tier three") == true)
    }

    @MainActor
    func testWorkspaceTabsStayInPlaceWithVideoSource() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-note-detail-design-preview-long",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["note-chat-skills"].waitForExistence(timeout: 15))
        let create = app.buttons["Create"]
        let tabY = create.frame.midY
        let sourceTitle = app.staticTexts["I Built a $10K/Month App With Only Apple Ads"]
        XCTAssertTrue(sourceTitle.exists)
        let sourceY = sourceTitle.frame.midY
        app.buttons["Note"].tap()
        XCTAssertEqual(create.frame.midY, tabY, accuracy: 1)
        app.textViews.firstMatch.swipeUp()
        XCTAssertEqual(create.frame.midY, tabY, accuracy: 1)
        create.tap()
        XCTAssertEqual(create.frame.midY, tabY, accuracy: 1)
        XCTAssertEqual(sourceTitle.frame.midY, sourceY, accuracy: 1)
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        XCTAssertFalse(app.buttons["note-chat-quick-skill-rewrite"].exists)
        XCTAssertTrue(app.buttons["note-chat-skill-rewrite"].isHittable)
        attach(app, "Create - stable source and compact composer")
        input.tap()
        input.typeText("Hello")
        XCTAssertTrue(app.buttons["note-chat-send"].isHittable)
        XCTAssertEqual(create.frame.midY, tabY, accuracy: 1)
        app.buttons["note-chat-send"].tap()
        XCTAssertTrue(app.buttons["note-chat-skills"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["note-chat-skill-rewrite"].exists)
        XCTAssertLessThan(app.buttons["note-chat-skills"].frame.midX, input.frame.minX)
        XCTAssertEqual(app.buttons["note-chat-skills"].frame.midY, app.buttons["note-chat-send"].frame.midY, accuracy: 3)
        app.buttons["Record"].tap()
        XCTAssertEqual(create.frame.midY, tabY, accuracy: 1)
    }

    @MainActor
    func testGuideContinuesToRecordWithoutChattingOrReplacing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-chat-guide-preview", "-note-detail-design-preview-video",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let continueButton = app.buttons["note-guide-review-continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 15))
        continueButton.tap()
        app.buttons["Create"].tap()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 5))
        attach(app, "Guide - send a skill in Create")
        rewrite.tap()
        let replace = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(replace.waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["note-chat-guide-review"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Step 6 of 7"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Record"].isEnabled)
        attach(app, "Guide - proceed directly to Record")
        app.buttons["Record"].tap()
        XCTAssertTrue(app.staticTexts["Step 7 of 7"].waitForExistence(timeout: 5))
        attach(app, "Guide - open teleprompter")
    }

    @MainActor
    func testSkillsOpenFromComposerDuringConversation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 15))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: rewrite)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        attach(app, "Create - ready skill shortcuts")
        rewrite.tap()
        let replacements = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-"))
        XCTAssertTrue(replacements.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(rewrite.exists)
        XCTAssertFalse(app.buttons["note-chat-quick-skill-rewrite"].exists)
        let skills = app.buttons["note-chat-skills"]
        XCTAssertTrue(skills.isHittable)
        attach(app, "Create - compact skills entry")
        skills.tap()
        XCTAssertTrue(app.navigationBars["AI Skills"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "Rewrite").firstMatch.tap()
        XCTAssertTrue(replacements.element(boundBy: 1).waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["AI Skills"].exists)
        XCTAssertTrue(skills.isHittable)

    }

    @MainActor
    func testUnifiedSkillsPanelCanConfigureRemoveAddAndRun() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let skills = app.buttons["note-chat-skills"]
        XCTAssertTrue(skills.waitForExistence(timeout: 15))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: skills
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        attach(app, "Create - ready unified skills entry")
        skills.tap()
        let panel = app.navigationBars["AI Skills"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["skills-run-rewrite"].exists)
        XCTAssertFalse(app.buttons["skills-remove-rewrite"].exists)

        // Settings are directly accessible without first opening a library page.
        let configure = app.buttons["skills-configure-caption_pack"]
        XCTAssertTrue(configure.isHittable)
        configure.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["skills-run-rewrite"].exists)

        app.buttons["skills-manage"].tap()
        XCTAssertFalse(app.buttons["skills-run-rewrite"].exists)
        let remove = app.buttons["skills-remove-rewrite"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        remove.tap()
        let add = app.buttons["skills-add-rewrite"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        for _ in 0..<6 {
            if add.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(add.isHittable)
        add.tap()
        XCTAssertTrue(panel.exists)
        app.buttons["skills-manage"].tap()
        let run = app.buttons["skills-run-rewrite"]
        for _ in 0..<6 {
            if run.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(run.isHittable)
        attach(app, "AI Skills - combined run and management panel")
        run.tap()
        let reply = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 8))
        XCTAssertFalse(panel.exists)
    }

    @MainActor
    func testExpandAndCollapseKeepConversationAndUnsentInput() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let expand = app.buttons["note-chat-expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 15))
        let embeddedY = expand.frame.minY
        XCTAssertGreaterThanOrEqual(embeddedY, app.scrollViews.firstMatch.frame.minY + 8)
        XCTAssertLessThanOrEqual(expand.frame.maxY, app.scrollViews.firstMatch.frame.minY + 52)
        expand.tap()
        XCTAssertFalse(app.buttons["Create"].exists)
        XCTAssertTrue(app.buttons["note-chat-skill-rewrite"].isHittable)
        XCTAssertLessThan(expand.frame.minY, embeddedY - 100)
        attach(app, "Create - fullscreen empty state")
        app.buttons["note-chat-skill-rewrite"].tap()
        let answer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        input.tap()
        input.typeText("Keep this unsent")
        expand.tap()
        XCTAssertTrue(app.buttons["Create"].exists)
        XCTAssertEqual(input.value as? String, "Keep this unsent")
        expand.tap()
        XCTAssertFalse(app.buttons["Create"].exists)
        XCTAssertEqual(input.value as? String, "Keep this unsent")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).count, 1)
        attach(app, "Create - fullscreen same conversation")
        expand.tap()
        XCTAssertTrue(app.buttons["Create"].exists)
    }

    @MainActor
    func testScrolledLongReplyKeepsMarginsAcrossFullscreenChanges() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-note-chat-long-reply-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 15))
        rewrite.tap()
        let reply = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-answer-")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 8))
        let scroll = app.scrollViews.firstMatch
        let expand = app.buttons["note-chat-expand"]
        for _ in 0..<3 {
            scroll.swipeDown()
            expand.tap()
            XCTAssertFalse(app.buttons["Create"].exists)
            XCTAssertEqual(reply.frame.minX, scroll.frame.minX + 20, accuracy: 1)
            XCTAssertLessThanOrEqual(reply.frame.maxX, scroll.frame.maxX - 19)
            scroll.swipeUp()
            expand.tap()
            XCTAssertTrue(app.buttons["Create"].exists)
            XCTAssertEqual(reply.frame.minX, scroll.frame.minX + 20, accuracy: 1)
            XCTAssertLessThanOrEqual(reply.frame.maxX, scroll.frame.maxX - 19)
        }
        attach(app, "Create - scrolled long reply after fullscreen changes")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
