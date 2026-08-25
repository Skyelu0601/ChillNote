import SwiftUI

struct CreatorSkillIcon: View {
    let recipe: AgentRecipe
    var size: CGFloat = 18
    var container: CGFloat = 38

    private var style: CreatorSkillIconStyle {
        CreatorSkillIconStyle(recipe: recipe)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, container * 0.22), style: .continuous)
                .fill(style.tint.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: min(8, container * 0.22), style: .continuous)
                        .stroke(style.tint.opacity(0.22), lineWidth: 1)
                )

            Image(systemName: style.symbolName ?? recipe.systemIcon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(style.tint)
        }
        .frame(width: container, height: container)
    }
}

private struct CreatorSkillIconStyle {
    let tint: Color
    let symbolName: String?

    init(recipe: AgentRecipe) {
        tint = CreatorSkillPalette.tint(for: recipe)

        switch recipe.id {
        case "hook_generator":
            symbolName = "link"
        case "caption_pack":
            symbolName = "captions.bubble"
        case "rewrite":
            symbolName = "pencil.and.scribble"
        case "repurpose_pack":
            symbolName = "square.stack.3d.up"
        case "style_match":
            symbolName = "waveform"
        case "timed_script":
            symbolName = "timer"
        default:
            symbolName = nil
        }
    }
}

/// A restrained multi-color palette for identifying individual AI Skills.
/// Color identifies the Skill only; teal remains the broader AI feature color.
enum CreatorSkillPalette {
    static let customCreationTint = Color(hex: "8069B0")

    private static let customTints: [Color] = [
        .brandBlue,
        Color(hex: "A06B9A"),
        Color(hex: "B77A2D"),
        Color(hex: "3F8174"),
        Color(hex: "B86655"),
        Color(hex: "63758F")
    ]

    static func tint(for recipe: AgentRecipe) -> Color {
        switch recipe.id {
        case "why_viral":
            return Color(hex: "C46B54")
        case "summarize":
            return Color(hex: "5F7394")
        case "translate":
            return Color(hex: "7866AD")
        case "humanizer":
            return Color(hex: "B56C82")
        case "rewrite":
            return Color(hex: "38886F")
        case "style_match":
            return Color(hex: "8A69A5")
        case "hook_generator":
            return .brandBlue
        case "caption_pack":
            return Color(hex: "B77A2D")
        case "timed_script":
            return Color(hex: "68758A")
        case "repurpose_pack":
            return Color(hex: "C76655")
        default:
            return customTint(for: recipe.id)
        }
    }

    private static func customTint(for recipeID: String) -> Color {
        let stableIndex = recipeID.utf8.reduce(0) { partialResult, byte in
            (partialResult &* 31 &+ Int(byte)) % customTints.count
        }
        return customTints[stableIndex]
    }
}
