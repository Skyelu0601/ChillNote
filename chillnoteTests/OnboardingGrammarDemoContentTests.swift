import XCTest
@testable import chillnote

final class OnboardingGrammarDemoContentTests: XCTestCase {

    func testFixedTextMatchesApprovedCopy() {
        XCTAssertEqual(
            OnboardingGrammarDemoContent.fixedText,
            """
            Chill Recipes turns your notes into instant actions, so instead of writing prompts from scratch, you can just choose what you want and run it in one tap. From quick summary to social post generation, Chill Recipes helps you move from rough thoughts to finished output faster, with less friction and more flow.
            """
        )
    }

    func testTypoWordsExistInTypoText() {
        let typoText = OnboardingGrammarDemoContent.typoText
        XCTAssertFalse(OnboardingGrammarDemoContent.typoWords.isEmpty)

        for typoWord in OnboardingGrammarDemoContent.typoWords {
            XCTAssertTrue(
                typoText.contains(typoWord),
                "Typo text should include typo word: \(typoWord)"
            )
        }
    }
}
