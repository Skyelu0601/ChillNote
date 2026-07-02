import SwiftUI

struct CreatorSkillIcon: View {
    let recipe: AgentRecipe
    var size: CGFloat = 18
    var container: CGFloat = 38

    private var style: CreatorSkillIconStyle {
        CreatorSkillIconStyle(recipeID: recipe.id)
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

    init(recipeID: String) {
        switch recipeID {
        case "hook_generator":
            tint = .brandBlue
            symbolName = "link"
        case "caption_pack":
            tint = Color(hex: "D59B16")
            symbolName = "captions.bubble"
        case "rewrite":
            tint = Color(hex: "15966E")
            symbolName = "pencil.and.scribble"
        case "repurpose_pack":
            tint = Color(hex: "E05F4F")
            symbolName = "square.stack.3d.up"
        case "style_match":
            tint = Color(hex: "8B6CFF")
            symbolName = "waveform"
        case "timed_script":
            tint = Color(hex: "6B7A90")
            symbolName = "timer"
        default:
            tint = .accentPrimary
            symbolName = nil
        }
    }
}
