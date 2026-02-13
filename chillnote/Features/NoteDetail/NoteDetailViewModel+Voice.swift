import Foundation
import SwiftUI
import UIKit

@MainActor
extension NoteDetailViewModel {
    func restoreOriginalVoiceResultIfAvailable() {
        guard let originalText = completedOriginalText else { return }
        withAnimation {
            note.content = originalText
            voiceService.processingStates.removeValue(forKey: note.id)
        }
    }

    func triggerVoiceRefinedHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func triggerRetryHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
