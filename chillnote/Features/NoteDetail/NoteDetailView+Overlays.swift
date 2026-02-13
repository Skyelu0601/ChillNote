import SwiftUI

struct NoteDetailOverlaysView: View {
    @ObservedObject var viewModel: NoteDetailViewModel
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @ObservedObject private var voiceService = VoiceProcessingService.shared

    var body: some View {
        ZStack {
            if let stage = viewModel.processingStage {
                VStack {
                    Spacer()
                    VoiceProcessingWorkflowView(
                        currentStage: stage,
                        style: .detailed,
                        showPersistentHint: true
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(50)
            }

            if viewModel.completedOriginalText != nil {
                refinedOverlay
            }

            if let message = viewModel.recordingErrorMessage {
                recordingErrorOverlay(message: message)
                    .zIndex(100)
            }

            if viewModel.showAIToolbar {
                aiToolbarOverlay
            }
        }
    }

    private var refinedOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentPrimary, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Refined")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                ContainerRelativeShape()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 4)

                Button(action: viewModel.restoreOriginalVoiceResultIfAvailable) {
                    Text("Show Original")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.accentPrimary.opacity(0.4), Color.purple.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                viewModel.triggerVoiceRefinedHaptic()
            }
        }
    }

    private func recordingErrorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .symbolEffect(.pulse, isActive: true)

                Text(viewModel.recordingErrorTitle(from: message))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    viewModel.triggerRetryHaptic()
                    viewModel.send(.retryTranscriptionTapped)
                }) {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.accentPrimary))
                }

                Button(action: {
                    viewModel.send(.dismissRecordingErrorTapped)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSub)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.bgSecondary))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .overlay(
                Capsule()
                    .strokeBorder(Color.red.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var aiToolbarOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                AIActionToolbar(
                    onRetry: {
                        viewModel.send(.aiRetryTapped)
                    },
                    onUndo: {
                        viewModel.send(.aiUndoTapped)
                    },
                    onSave: {
                        viewModel.send(.aiSaveTapped)
                    }
                )
                .frame(maxWidth: 360)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
