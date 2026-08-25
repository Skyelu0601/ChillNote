import XCTest
@testable import chillnote

final class AIContextChatParsingTests: XCTestCase {
    func testParseAssistantSegmentsCreatesCitationForValidNoteNumber() {
        let notes = [
            Note(content: "First", userId: "u1"),
            Note(content: "Second", userId: "u1")
        ]

        let segments = ChatContentParser.parseAssistantSegments(
            "This idea came from your planning note [2].",
            contextNotes: notes
        )

        XCTAssertEqual(
            segments,
            [
                .text("This idea came from your planning note "),
                .citation(MessageCitation(number: 2, noteID: notes[1].id, noteIndex: 1)),
                .text(".")
            ]
        )
    }

    func testParseAssistantSegmentsKeepsInvalidCitationAsPlainText() {
        let notes = [
            Note(content: "Only", userId: "u1")
        ]

        let segments = ChatContentParser.parseAssistantSegments(
            "Unknown source [99]",
            contextNotes: notes
        )

        XCTAssertEqual(segments, [.text("Unknown source [99]")])
    }

    func testDetectSlashCommandMatchesSavedRecipes() {
        let match = ChatContentParser.detectSlashCommand(
            in: "/sum",
            recipes: [AgentRecipe.allRecipes.first { $0.id == "summarize" }!]
        )

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.query, "sum")
        XCTAssertEqual(match?.matchedRecipes.map(\.id), ["summarize"])
    }

    func testParseChatModeRecognizesRecipeCommandAndExtraInstruction() {
        let mode = ChatContentParser.parseChatMode(
            for: "/summarize keep action items",
            recipes: [AgentRecipe.allRecipes.first { $0.id == "summarize" }!]
        )

        switch mode {
        case .recipeCommand(let recipe, let extraInstruction):
            XCTAssertEqual(recipe.id, "summarize")
            XCTAssertEqual(extraInstruction, "keep action items")
        case .defaultChat:
            XCTFail("Expected recipe command mode")
        }
    }
}
