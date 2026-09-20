import Foundation

// Parser retained for legacy-content compatibility tests; the old chat UI has been removed.
enum ChatInlineSegment: Equatable {
    case text(String)
    case citation(MessageCitation)
}

struct MessageCitation: Equatable, Hashable {
    let number: Int
    let noteID: UUID
    let noteIndex: Int
}

struct SlashCommandMatch: Equatable {
    let range: Range<String.Index>
    let query: String
    let matchedRecipes: [AgentRecipe]
}

enum AIChatMode {
    case defaultChat
    case recipeCommand(recipe: AgentRecipe, extraInstruction: String?)
}

struct ChatContentParser {
    private static let citationPattern = #"\[(\d+)\]"#

    static func parseAssistantSegments(_ text: String, contextNotes: [Note]) -> [ChatInlineSegment] {
        guard !text.isEmpty else { return [] }
        guard let regex = try? NSRegularExpression(pattern: citationPattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [.text(text)] }

        var segments: [ChatInlineSegment] = []
        var currentLocation = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > currentLocation {
                let prefix = nsText.substring(with: NSRange(location: currentLocation, length: matchRange.location - currentLocation))
                if !prefix.isEmpty {
                    segments.append(.text(prefix))
                }
            }

            if match.numberOfRanges > 1,
               let numberRange = Range(match.range(at: 1), in: text),
               let number = Int(text[numberRange]),
               let note = contextNotes[safe: number - 1] {
                segments.append(.citation(MessageCitation(number: number, noteID: note.id, noteIndex: number - 1)))
            } else {
                segments.append(.text(nsText.substring(with: matchRange)))
            }

            currentLocation = matchRange.location + matchRange.length
        }

        if currentLocation < nsText.length {
            let suffix = nsText.substring(from: currentLocation)
            if !suffix.isEmpty {
                segments.append(.text(suffix))
            }
        }

        return mergeAdjacentTextSegments(segments)
    }

    static func detectSlashCommand(in input: String, recipes: [AgentRecipe]) -> SlashCommandMatch? {
        guard let tokenRange = slashTokenRange(in: input) else { return nil }
        let token = String(input[tokenRange])
        guard token.hasPrefix("/") else { return nil }

        let query = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let matches = recipes.filter { recipe in
            guard !query.isEmpty else { return true }
            let id = recipe.id.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let name = recipe.localizedName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return id.contains(normalizedQuery) || name.contains(normalizedQuery)
        }

        return SlashCommandMatch(range: tokenRange, query: query, matchedRecipes: matches)
    }

    static func parseChatMode(for input: String, recipes: [AgentRecipe]) -> AIChatMode {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .defaultChat }

        let body = String(trimmed.dropFirst())
        let command = body.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard let rawID = command.first else { return .defaultChat }
        guard let recipe = recipes.first(where: { $0.id == rawID }) else { return .defaultChat }

        let extraInstruction: String?
        if command.count > 1 {
            let trailing = String(command[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            extraInstruction = trailing.isEmpty ? nil : trailing
        } else {
            extraInstruction = nil
        }

        return .recipeCommand(recipe: recipe, extraInstruction: extraInstruction)
    }

    private static func slashTokenRange(in input: String) -> Range<String.Index>? {
        guard !input.isEmpty else { return nil }
        let cursor = input.endIndex
        let prefix = input[..<cursor]
        let slashIndex = prefix.lastIndex(of: "/")
        guard let slashIndex else { return nil }

        if slashIndex > input.startIndex {
            let previous = input[input.index(before: slashIndex)]
            if !previous.isWhitespace && previous != "\n" {
                return nil
            }
        }

        let token = input[slashIndex..<cursor]
        if token.contains(where: \.isNewline) || token.contains(where: \.isWhitespace) {
            return nil
        }

        return slashIndex..<cursor
    }

    private static func mergeAdjacentTextSegments(_ segments: [ChatInlineSegment]) -> [ChatInlineSegment] {
        var merged: [ChatInlineSegment] = []
        for segment in segments {
            switch segment {
            case .text(let text):
                if case .text(let previous)? = merged.last {
                    merged[merged.count - 1] = .text(previous + text)
                } else {
                    merged.append(.text(text))
                }
            case .citation:
                merged.append(segment)
            }
        }
        return merged
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
