import UIKit

enum AppInteractionFeedback {
    enum Impact {
        case soft
        case light
        case medium
    }

    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        softImpact.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    static func impact(_ impact: Impact = .light, intensity: CGFloat = 1) {
        let generator = impactGenerator(for: impact)
        generator.impactOccurred(intensity: min(max(intensity, 0), 1))
        generator.prepare()
    }

    static func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    static func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    static func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    private static func impactGenerator(for impact: Impact) -> UIImpactFeedbackGenerator {
        switch impact {
        case .soft:
            return softImpact
        case .light:
            return lightImpact
        case .medium:
            return mediumImpact
        }
    }
}
