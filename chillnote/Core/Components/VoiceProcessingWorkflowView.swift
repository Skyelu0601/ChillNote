import SwiftUI

enum VoiceProcessingStage: String, CaseIterable, Equatable {
    case transcribing
    case refining

    var title: String {
        switch self {
        case .transcribing:
            return "Transcribing"
        case .refining:
            return "Refining"
        }
    }

    var subtitle: String {
        switch self {
        case .transcribing:
            return "Converting your voice into text..."
        case .refining:
            return "Cleaning and structuring your note..."
        }
    }

    var systemImage: String {
        switch self {
        case .transcribing:
            return "waveform"
        case .refining:
            return "wand.and.stars"
        }
    }

    var stepIndex: Int {
        switch self {
        case .transcribing:
            return 0
        case .refining:
            return 1
        }
    }
}

struct VoiceProcessingWorkflowView: View {
    enum Style {
        case compact
        case detailed
    }

    let currentStage: VoiceProcessingStage
    var style: Style = .compact
    var showPersistentHint: Bool = true

    var body: some View {
        Group {
            switch style {
            case .compact:
                compactView
            case .detailed:
                detailedView
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStage)
    }

    // MARK: - Compact View
    private var compactView: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Image(systemName: currentStage.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentPrimary)
                    .symbolEffect(.pulse, isActive: true)
            }

            Text(currentStage.title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .contentTransition(.numericText())
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    // MARK: - Detailed View
    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Processing Note")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if currentStage == .refining {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Steps
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(VoiceProcessingStage.allCases.enumerated()), id: \.element) { index, stage in
                     TimelineRow(
                        stage: stage,
                        currentStage: currentStage,
                        isLast: index == VoiceProcessingStage.allCases.count - 1
                     )
                     .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 16)
            
            // Footer Hint
            if showPersistentHint {
                Divider()
                    .overlay(Color.primary.opacity(0.05))
                
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce, value: currentStage)
                    
                    Text("You can keep using ChillNote while we work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.primary.opacity(0.02))
            }
        }
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.bgSecondary.opacity(0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Helper Views
private struct TimelineRow: View {
    let stage: VoiceProcessingStage
    let currentStage: VoiceProcessingStage
    let isLast: Bool
    
    var isActive: Bool { stage == currentStage }
    var isCompleted: Bool { stage.stepIndex < currentStage.stepIndex }
    var isFuture: Bool { stage.stepIndex > currentStage.stepIndex }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                        .shadow(color: .green.opacity(0.3), radius: 4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else if isActive {
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 24, height: 24)
                        .shadow(color: .accentPrimary.opacity(0.4), radius: 6)
                    Image(systemName: stage.systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse.byLayer, isActive: true)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 24, height: 24)
                    Image(systemName: stage.systemImage)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }
            .frame(width: 24, height: 24)
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(isActive ? .semibold : .medium)
                    .foregroundStyle(isFuture ? Color.secondary.opacity(0.6) : Color.primary)
                    .frame(minHeight: 24, alignment: .leading) // Align height with Icon
                    .animation(nil, value: isActive)
                
                if isActive {
                    Text(stage.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, isActive ? 16 : 12)
        }
        .background(alignment: .leading) {
            if !isLast {
                Capsule()
                    .fill(isCompleted ? Color.green : Color.secondary.opacity(0.1))
                    .frame(width: 2)
                    .padding(.top, 24) // Start below the 24pt icon
                    .frame(maxHeight: .infinity) // Fill the rest of the row height
                    .offset(x: 11) // Center horizontally (12 - 1)
            }
        }
    }
}
