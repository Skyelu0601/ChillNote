import SwiftUI

/// Alert view for recovering crashed recordings
struct RecordingRecoveryAlert: View {
    let pendingRecordings: [PendingRecording]
    let onRecover: (PendingRecording) -> Void
    let onDiscard: (PendingRecording) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.1))
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "waveform.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.accentPrimary)
                }
                .padding(.bottom, 4)
                
                Text("Recovery Found")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)
                
                Text("We found an unfinished recording from a previous session.")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // List of pending recordings
            VStack(spacing: 16) {
                ForEach(pendingRecordings) { recording in
                    VStack(spacing: 0) {
                        // Info Row
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.bodyMedium)
                                .foregroundColor(.textSub)
                                .padding(10)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voice Memo")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textMain)
                                
                                Text(recording.durationText)
                                    .font(.bodySmall)
                                    .foregroundColor(.textSub)
                            }
                            Spacer()
                        }
                        .padding(16)
                        
                        Divider()
                        
                        // Action Row
                        HStack(spacing: 0) {
                            Button(action: {
                                onDiscard(recording)
                            }) {
                                Text("Discard")
                                    .font(.bodyMedium)
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            
                            Divider()
                                .frame(height: 20)
                            
                            Button(action: {
                                onRecover(recording)
                            }) {
                                Text("Process")
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                    }
                    .background(Color.bgSecondary)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            
            // Dismiss button (only shown if empty processing)
            if pendingRecordings.isEmpty {
                Button(action: onDismiss) {
                    Text("Close")
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.textSub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                }
            }
        }
        .padding(24)
        .background(Color.bgPrimary) // Use app background color
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
        .padding(.horizontal, 32)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        RecordingRecoveryAlert(
            pendingRecordings: [
                PendingRecording(
                    fileURL: URL(fileURLWithPath: "/tmp/test.wav"),
                    createdAt: Date().addingTimeInterval(-3600)
                )
            ],
            onRecover: { _ in },
            onDiscard: { _ in },
            onDismiss: {}
        )
    }
}
