import Foundation
import SwiftUI

struct BrainDumpTemplate: Identifiable, Equatable {
    let id: String
    let nameKey: String
    let promptKey: String
    let iconName: String
    let accentColor: Color

    static let all: [BrainDumpTemplate] = [
        BrainDumpTemplate(
            id: "just_dump",
            nameKey: "recording.template.just_dump.name",
            promptKey: "recording.template.just_dump.prompt",
            iconName: "drop.fill",
            accentColor: Color.accentPrimary
        ),
        BrainDumpTemplate(
            id: "morning_clarity",
            nameKey: "recording.template.morning_clarity.name",
            promptKey: "recording.template.morning_clarity.prompt",
            iconName: "sun.max.fill",
            accentColor: Color.mellowOrange
        ),
        BrainDumpTemplate(
            id: "evening_shutdown",
            nameKey: "recording.template.evening_shutdown.name",
            promptKey: "recording.template.evening_shutdown.prompt",
            iconName: "moon.stars.fill",
            accentColor: Color.dustyBlue
        ),
        BrainDumpTemplate(
            id: "anxiety_safety_valve",
            nameKey: "recording.template.anxiety_safety_valve.name",
            promptKey: "recording.template.anxiety_safety_valve.prompt",
            iconName: "wind",
            accentColor: Color.sageGreen
        ),
        BrainDumpTemplate(
            id: "creative_spark",
            nameKey: "recording.template.creative_spark.name",
            promptKey: "recording.template.creative_spark.prompt",
            iconName: "sparkles",
            accentColor: Color(hex: "D78F5C")
        )
    ]
}
