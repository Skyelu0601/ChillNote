import Foundation

struct OnboardingPreferences: Codable {
    var contentType: ContentCreatorType?
    var goals: Set<CreatorGoal> = []

    enum ContentCreatorType: String, Codable, CaseIterable {
        case shortFormVideo
        case longFormVideo
        case written
        case mixed

        var emoji: String {
            switch self {
            case .shortFormVideo: return "🎬"
            case .longFormVideo: return "📹"
            case .written: return "✍️"
            case .mixed: return "🎨"
            }
        }

        var titleKey: String {
            switch self {
            case .shortFormVideo: return "onboarding.survey.content_type.short_form"
            case .longFormVideo: return "onboarding.survey.content_type.long_form"
            case .written: return "onboarding.survey.content_type.written"
            case .mixed: return "onboarding.survey.content_type.mixed"
            }
        }

        var detailKey: String {
            switch self {
            case .shortFormVideo: return "onboarding.survey.content_type.short_form.detail"
            case .longFormVideo: return "onboarding.survey.content_type.long_form.detail"
            case .written: return "onboarding.survey.content_type.written.detail"
            case .mixed: return "onboarding.survey.content_type.mixed.detail"
            }
        }
    }

    enum CreatorGoal: String, Codable, CaseIterable, Hashable {
        case captureIdeas
        case planCalendar
        case repurpose
        case improveQuality

        var emoji: String {
            switch self {
            case .captureIdeas: return "💡"
            case .planCalendar: return "📅"
            case .repurpose: return "🔄"
            case .improveQuality: return "✨"
            }
        }

        var titleKey: String {
            switch self {
            case .captureIdeas: return "onboarding.survey.goals.capture_ideas"
            case .planCalendar: return "onboarding.survey.goals.plan_calendar"
            case .repurpose: return "onboarding.survey.goals.repurpose"
            case .improveQuality: return "onboarding.survey.goals.improve_quality"
            }
        }
    }
}
