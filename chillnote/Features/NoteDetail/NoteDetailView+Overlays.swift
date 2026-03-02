import SwiftUI

struct NoteDetailOverlaysView: View {
    @ObservedObject var viewModel: NoteDetailViewModel
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

    private var aiToolbarOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                AIPreviewCard(
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
