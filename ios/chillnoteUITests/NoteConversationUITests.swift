import XCTest

final class NoteConversationUITests: XCTestCase {
    @MainActor
    func testBrandVoiceExamplesAddEditDeleteWithoutSummaries() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["note-chat-menu"].waitForExistence(timeout: 15))
        app.buttons["note-chat-menu"].tap()
        app.buttons["note-chat-menu-skills"].tap()
        let configure = app.buttons["skills-configure-style_match"]
        for _ in 0..<8 {
            if configure.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(configure.isHittable)
        configure.tap()
        let add = app.buttons["Add writing example"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        while app.buttons["Example 1"].exists {
            app.buttons["Example 1"].tap()
            app.buttons["Delete"].tap()
            XCTAssertTrue(add.waitForExistence(timeout: 3))
        }
        for content in ["First original writing", "Second original writing"] {
            add.tap()
            XCTAssertFalse(app.buttons["Save"].isEnabled)
            let editor = app.descendants(matching: .any)["brand-voice-example-text"].firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 3))
            editor.tap()
            editor.typeText(content)
            app.buttons["Save"].tap()
            XCTAssertTrue(add.waitForExistence(timeout: 3))
        }
        XCTAssertTrue(app.buttons["Example 2"].exists)
        XCTAssertFalse(app.staticTexts["First original writing"].exists)
        app.buttons["Example 1"].tap()
        let editor = app.descendants(matching: .any)["brand-voice-example-text"].firstMatch
        XCTAssertEqual(editor.value as? String, "First original writing")
        editor.tap()
        editor.typeText(" updated")
        app.buttons["Save"].tap()
        app.buttons["Example 1"].tap()
        XCTAssertTrue((editor.value as? String)?.contains("updated") == true)
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Example 1"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Example 2"].exists)
        app.buttons["Example 1"].tap()
        XCTAssertEqual(editor.value as? String, "Second original writing")
        app.buttons["Delete"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        attach(app, "Brand Voice - examples only")
    }

    @MainActor
    func testRepurposeSettingsShowVideoPlatformsAndMorePlatforms() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let menu = app.descendants(matching: .any)["note-chat-menu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        let manage = app.descendants(matching: .any)["note-chat-menu-skills"].firstMatch
        for _ in 0..<3 {
            menu.tap()
            if manage.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(manage.waitForExistence(timeout: 3))
        manage.tap()
        let configure = app.buttons["skills-configure-repurpose_pack"]
        for _ in 0..<8 {
            if configure.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        attach(app, "Repurpose - management entry")
        XCTAssertTrue(configure.isHittable)
        configure.tap()
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatTikTok"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatInstagramReels"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatYouTubeShorts"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatYouTubeVideo"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatNewsletter"].exists)
        XCTAssertFalse(app.staticTexts["Instagram Carousel Outline"].exists)
        XCTAssertFalse(app.staticTexts["Pinterest Pin"].exists)
        XCTAssertFalse(app.staticTexts["Short video length"].exists)
        XCTAssertFalse(app.staticTexts["Tone"].exists)
        XCTAssertFalse(app.switches["Include call to action"].exists)
        // Additional formats are always listed, without a disclosure button.
        XCTAssertFalse(app.buttons["More platforms"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatXPost"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatThreads"].exists)
        XCTAssertTrue(app.switches["repurpose-format-repurposePackFormatLinkedIn"].exists)
        attach(app, "Repurpose - video and additional platforms")
    }

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
        XCTAssertTrue(app.buttons["note-chat-menu"].isHittable)
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
        XCTAssertFalse(app.buttons["note-applied-undo"].exists)
        app.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["note-chat-undo"].waitForExistence(timeout: 3))
        let appliedResult = replacements.element(boundBy: 1)
        XCTAssertEqual(app.buttons["note-chat-undo"].frame.midY, appliedResult.frame.midY, accuracy: 3)
        app.buttons["note-chat-undo"].tap()
        app.buttons["Note"].tap()
        XCTAssertTrue((app.textViews.firstMatch.value as? String)?.contains("Tier three") == true)
    }

    @MainActor
    func testCopyReplyShowsFeedbackAndCanBePasted() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 15))
        rewrite.tap()
        let copy = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-copy-")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 8))
        copy.tap()
        XCTAssertEqual(copy.value as? String, "Copied")
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        input.press(forDuration: 1)
        let pasteMenuItem = app.menuItems["Paste"]
        let paste = pasteMenuItem.waitForExistence(timeout: 1) ? pasteMenuItem : app.buttons["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3))
        paste.tap()
        XCTAssertTrue((input.value as? String)?.contains("Great ideas rarely arrive on schedule.") == true)
    }

    @MainActor
    func testPromptSuggestionsFillComposerWithoutSending() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let scriptPrompt = app.buttons["note-chat-prompt-script"]
        XCTAssertTrue(scriptPrompt.waitForExistence(timeout: 15))
        XCTAssertTrue(scriptPrompt.isHittable)
        XCTAssertTrue(app.buttons["note-chat-prompt-hooks"].isHittable)
        let initialInput = app.descendants(matching: .any)["note-chat-input"].firstMatch
        XCTAssertLessThanOrEqual(scriptPrompt.frame.maxY, initialInput.frame.minY)
        XCTAssertTrue(app.staticTexts["Try creator skills"].exists)
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        let hooks = app.buttons["note-chat-skill-hook_generator"]
        XCTAssertGreaterThan(hooks.frame.minY, rewrite.frame.maxY)
        attach(app, "Create - vertical skills and suggestions")
        scriptPrompt.tap()
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        XCTAssertEqual(input.value as? String, "Make this a 30-second script")
        XCTAssertTrue(app.buttons["note-chat-send"].isEnabled)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).count, 0)
        input.typeText(" for beginners")
        XCTAssertTrue((input.value as? String)?.hasSuffix(" for beginners") == true)
    }

    @MainActor
    func testWorkspaceTabsStayInPlaceWithVideoSource() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-note-detail-design-preview-long",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["note-chat-menu"].waitForExistence(timeout: 15))
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
        XCTAssertTrue(app.buttons["note-chat-menu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["note-chat-skill-rewrite"].exists)
        XCTAssertLessThan(app.buttons["note-chat-menu"].frame.midX, input.frame.minX)
        XCTAssertEqual(app.buttons["note-chat-menu"].frame.midY, app.buttons["note-chat-send"].frame.midY, accuracy: 3)
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
        XCTAssertTrue(rewrite.exists)
        XCTAssertFalse(app.buttons["note-chat-quick-skill-rewrite"].exists)
        let skills = app.buttons["note-chat-menu"]
        XCTAssertTrue(skills.isHittable)
        attach(app, "Create - compact skills entry")
        skills.tap()
        app.buttons["note-chat-menu-skills"].tap()
        XCTAssertTrue(app.navigationBars["Manage Skills"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["skills-run-rewrite"].exists)
        app.buttons["Close"].tap()
        rewrite.tap()
        XCTAssertTrue(replacements.element(boundBy: 1).waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["Manage Skills"].exists)
        XCTAssertTrue(skills.isHittable)

    }

    @MainActor
    func testSkillsManagementConfiguresAndSelectsFavoritesWithoutRunning() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let menu = app.buttons["note-chat-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["note-chat-menu-skills"].tap()
        let panel = app.navigationBars["Manage Skills"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["skills-run-rewrite"].exists)
        let configure = app.buttons["skills-configure-caption_pack"]
        XCTAssertTrue(configure.isHittable)
        configure.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        app.buttons["skills-remove-rewrite"].tap()
        let add = app.buttons["skills-add-rewrite"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        for _ in 0..<6 {
            if add.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        add.tap()
        XCTAssertTrue(panel.exists)
        XCTAssertFalse(app.buttons["skills-run-rewrite"].exists)
        app.buttons["Close"].tap()
        let run = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()
        let reply = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 8))
        XCTAssertFalse(panel.exists)
    }

    @MainActor
    func testCannotRemoveLastFavoriteSkill() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let menu = app.buttons["note-chat-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["note-chat-menu-skills"].tap()
        let removedIDs = ["hook_generator", "caption_pack", "repurpose_pack"]
        for id in removedIDs {
            app.buttons["skills-remove-\(id)"].tap()
        }
        app.buttons["skills-remove-rewrite"].tap()
        let alert = app.alerts["Keep at least one favorite Skill."]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["skills-remove-rewrite"].exists)
        XCTAssertFalse(app.buttons["skills-add-rewrite"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["note-chat-skill-rewrite"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-skill-")).count, 1)
        menu.tap()
        app.buttons["note-chat-menu-skills"].tap()
        for id in removedIDs {
            let add = app.buttons["skills-add-\(id)"]
            for _ in 0..<8 {
                if add.isHittable { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            add.tap()
        }
        app.buttons["Close"].tap()
    }

    @MainActor
    func testFavoriteReplacementPersistsWithoutSortingControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let menu = app.buttons["note-chat-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["note-chat-menu-skills"].tap()
        let add = app.buttons["skills-add-translate"]
        for _ in 0..<8 {
            if add.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(add.isHittable)
        add.tap()
        let dialog = app.sheets.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        dialog.buttons["Write Captions"].tap()
        XCTAssertFalse(app.buttons["skills-move-up-translate"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["note-chat-skill-translate"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["note-chat-skill-caption_pack"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["note-chat-skill-translate"].waitForExistence(timeout: 15))
        menu.tap()
        app.buttons["note-chat-menu-skills"].tap()
        let restore = app.buttons["skills-add-caption_pack"]
        for _ in 0..<8 {
            if restore.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        restore.tap()
        app.sheets.firstMatch.buttons["Translate"].tap()
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["note-chat-skill-caption_pack"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testConversationKeepsWorkspaceNavigationWithoutFullscreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-note-detail-design-preview-video", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let rewrite = app.buttons["note-chat-skill-rewrite"]
        XCTAssertTrue(rewrite.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["note-chat-expand"].exists)
        XCTAssertTrue(app.buttons["Create"].exists)
        rewrite.tap()
        let answer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["note-chat-expand"].exists)
        XCTAssertTrue(app.buttons["Create"].exists)
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        input.tap()
        input.typeText("Keep this unsent")
        XCTAssertEqual(input.value as? String, "Keep this unsent")
        attach(app, "Create - embedded conversation without fullscreen")
    }

    @MainActor
    func testClearConversationRequiresConfirmationAndReturnsToSkills() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-note-detail-design-preview", "-note-chat-design-preview",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let menu = app.buttons["note-chat-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        let input = app.descendants(matching: .any)["note-chat-input"].firstMatch
        let menuCount = app.buttons.matching(identifier: "note-chat-menu").count
        XCTAssertEqual(menuCount, 1)
        XCTAssertLessThan(menu.frame.midX, input.frame.minX)
        XCTAssertEqual(menu.frame.midY, app.buttons["note-chat-send"].frame.midY, accuracy: 3)
        menu.tap()
        XCTAssertFalse(app.buttons["note-chat-clear"].exists)
        app.buttons["note-chat-menu-skills"].tap()
        XCTAssertTrue(app.navigationBars["Manage Skills"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["skills-run-rewrite"].exists)
        app.buttons["Close"].tap()
        app.buttons["note-chat-skill-rewrite"].tap()
        let answer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "note-chat-replace-")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(identifier: "note-chat-menu").count, 1)
        XCTAssertLessThan(menu.frame.midX, input.frame.minX)
        XCTAssertEqual(menu.frame.midY, app.buttons["note-chat-send"].frame.midY, accuracy: 3)
        menu.tap()
        app.buttons["note-chat-clear"].tap()
        let confirmation = app.alerts["Clear this conversation?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(answer.exists)
        menu.tap()
        app.buttons["note-chat-clear"].tap()
        confirmation.buttons["Clear conversation"].tap()
        XCTAssertTrue(app.buttons["note-chat-skill-rewrite"].waitForExistence(timeout: 5))
        XCTAssertFalse(answer.exists)
        XCTAssertTrue(app.buttons["Note"].exists)
        XCTAssertTrue(app.buttons["Create"].exists)
        attach(app, "Create - cleared conversation")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
