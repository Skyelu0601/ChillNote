import CoreGraphics
import Foundation

enum PaywallContext: String, Identifiable {
    case recordingTimeLimit
    case dailyVoiceLimit
    case dailyTidyLimit
    case dailyRecipeLimit
    case dailyChatLimit
    case firstVoiceSuccess

    var id: String { rawValue }

    var content: PaywallContent {
        switch self {
        case .recordingTimeLimit:
            return PaywallContent(
                titleKey: "paywall.recording_time_limit.title",
                messageKey: "paywall.recording_time_limit.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.later",
                showsMessage: false,
                benefitKeys: [
                    "paywall.recording_time_limit.benefit.long_recording",
                    "paywall.recording_time_limit.benefit.deep_sessions",
                    "paywall.recording_time_limit.benefit.keep_flow"
                ]
            )
        case .dailyVoiceLimit:
            return PaywallContent(
                titleKey: "paywall.daily_voice_limit.title",
                messageKey: "paywall.daily_voice_limit.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.later",
                showsMessage: false,
                benefitKeys: [
                    "paywall.daily_voice_limit.benefit.keep_recording",
                    "paywall.recording_time_limit.benefit.long_recording",
                    "paywall.daily_voice_limit.benefit.more_processing"
                ]
            )
        case .dailyTidyLimit:
            return PaywallContent(
                titleKey: "paywall.daily_tidy_limit.title",
                messageKey: "paywall.daily_tidy_limit.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.later",
                showsMessage: false,
                benefitKeys: [
                    "paywall.daily_tidy_limit.benefit.more_refines",
                    "paywall.daily_tidy_limit.benefit.keep_structure"
                ]
            )
        case .dailyRecipeLimit:
            return PaywallContent(
                titleKey: "paywall.daily_recipe_limit.title",
                messageKey: "paywall.daily_recipe_limit.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.later",
                showsMessage: false,
                benefitKeys: [
                    "paywall.daily_recipe_limit.benefit.more_recipes",
                    "paywall.daily_recipe_limit.benefit.custom_recipes"
                ]
            )
        case .dailyChatLimit:
            return PaywallContent(
                titleKey: "paywall.daily_chat_limit.title",
                messageKey: "paywall.daily_chat_limit.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.later",
                showsMessage: false,
                benefitKeys: [
                    "paywall.daily_chat_limit.benefit.more_chat",
                    "paywall.daily_chat_limit.benefit.deeper_followups"
                ]
            )
        case .firstVoiceSuccess:
            return PaywallContent(
                titleKey: "paywall.first_voice_success.title",
                messageKey: "paywall.first_voice_success.message",
                primaryButtonKey: "paywall.cta.upgrade",
                secondaryButtonKey: "paywall.cta.keep_free",
                benefitKeys: [
                    "paywall.recording_time_limit.benefit.long_recording",
                    "paywall.daily_tidy_limit.benefit.more_refines",
                    "paywall.first_voice_success.benefit.more_recipes"
                ]
            )
        }
    }
}

struct PaywallContent {
    let titleKey: String
    let messageKey: String
    let primaryButtonKey: String
    let secondaryButtonKey: String
    let benefitKeys: [String]
    let showsMessage: Bool

    init(
        titleKey: String,
        messageKey: String,
        primaryButtonKey: String,
        secondaryButtonKey: String,
        showsMessage: Bool = true,
        benefitKeys: [String]
    ) {
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.primaryButtonKey = primaryButtonKey
        self.secondaryButtonKey = secondaryButtonKey
        self.showsMessage = showsMessage
        self.benefitKeys = benefitKeys
    }

    var title: String { L10n.text(titleKey) }
    var message: String { L10n.text(messageKey) }
    var primaryButtonTitle: String { L10n.text(primaryButtonKey) }
    var secondaryButtonTitle: String { L10n.text(secondaryButtonKey) }
    var benefits: [String] { benefitKeys.map(L10n.text) }
    var hasMessage: Bool { showsMessage && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var preferredSheetHeight: CGFloat {
        let totalCharacterCount =
            title.count +
            (hasMessage ? message.count : 0) +
            primaryButtonTitle.count +
            secondaryButtonTitle.count +
            benefits.reduce(0) { $0 + $1.count }

        let messageBonus: CGFloat
        switch hasMessage ? message.count : 0 {
        case 0..<70:
            messageBonus = 0
        case 70..<110:
            messageBonus = 16
        case 110..<150:
            messageBonus = 32
        default:
            messageBonus = 52
        }

        let contentBonus: CGFloat
        switch totalCharacterCount {
        case 0..<180:
            contentBonus = 0
        case 180..<240:
            contentBonus = 16
        case 240..<320:
            contentBonus = 32
        default:
            contentBonus = 48
        }

        let benefitBonus = CGFloat(max(0, benefits.count - 2)) * 18
        let estimatedHeight = 372 + messageBonus + contentBonus + benefitBonus
        return min(max(estimatedHeight, 372), 500)
    }
}

enum PaywallStateStore {
    private static let defaults = UserDefaults.standard
    private static let hasShownFirstVoiceSuccessPaywallKey = "paywall.has_shown_first_voice_success"

    static var hasShownFirstVoiceSuccessPaywall: Bool {
        get { defaults.bool(forKey: hasShownFirstVoiceSuccessPaywallKey) }
        set { defaults.set(newValue, forKey: hasShownFirstVoiceSuccessPaywallKey) }
    }
}
