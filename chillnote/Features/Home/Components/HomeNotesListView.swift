import SwiftUI
import SwiftData
import UIKit

struct HomeNotesListView: View {
    let cachedVisibleNotes: [Note]
    let searchQuery: String
    let isLoading: Bool
    let isInitialSyncing: Bool
    let hasLoadedAtLeastOnce: Bool
    let isTrashSelected: Bool
    let selectedSection: NoteSection
    let isSelectionMode: Bool
    let selectedNotes: Set<UUID>
    let showDefaultEmptyStateMessage: Bool
    let onReachBottom: (Note) -> Void
    let onToggleNoteSelection: (Note) -> Void
    let onEnterSelectionMode: () -> Void
    let onRestoreNote: (Note) -> Void
    let onDeleteNotePermanently: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onManageTags: (Note) -> Void
    let onMoveNote: (Note, NoteSection) -> Void
    let onDeleteNote: (Note) -> Void
    var guideTargetNoteID: UUID? = nil
    var onGuideTargetNoteOpened: (UUID) -> Void = { _ in }

    private var shouldShowInitialLoadingState: Bool {
        cachedVisibleNotes.isEmpty && (isLoading || !hasLoadedAtLeastOnce)
    }

    private var shouldShowSyncingState: Bool {
        cachedVisibleNotes.isEmpty
            && isInitialSyncing
            && hasLoadedAtLeastOnce
            && !isLoading
    }

    private var usePlainPreviewForCurrentList: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyStateLocalizationKeys: (title: String, message: String) {
        if isTrashSelected {
            return (
                title: "home.notes.empty.trash.title",
                message: "home.notes.empty.trash.message"
            )
        }

        switch selectedSection {
        case .inbox:
            return (
                title: "home.notes.empty.inbox.title",
                message: "home.notes.empty.inbox.message"
            )
        case .drafts:
            return (
                title: "home.notes.empty.drafts.title",
                message: "home.notes.empty.drafts.message"
            )
        case .published:
            return (
                title: "home.notes.empty.published.title",
                message: "home.notes.empty.published.message"
            )
        }
    }

    var body: some View {
        if cachedVisibleNotes.isEmpty {
            if shouldShowInitialLoadingState {
                HomeNotesLoadingView()
            } else if shouldShowSyncingState {
                HomeNotesSyncingView()
            } else if !isTrashSelected && !showDefaultEmptyStateMessage {
                Color.clear
                    .frame(height: 1)
            } else {
                HomeNotesEmptyStateView(
                    selectedSection: selectedSection,
                    isTrashSelected: isTrashSelected,
                    titleKey: emptyStateLocalizationKeys.title,
                    messageKey: emptyStateLocalizationKeys.message
                )
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(cachedVisibleNotes) { note in
                    let item = NoteListItemViewData(
                        note: note,
                        searchQuery: searchQuery,
                        usePlainPreview: usePlainPreviewForCurrentList
                    )
                    Group {
                        if isTrashSelected {
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: note) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        NoteCard(item: item)
                                        TrashNoteFooterView(note: note)
                                    }
                                }
                                .buttonStyle(.tactile)

                                NoteOverflowMenu {
                                    Button {
                                        onRestoreNote(note)
                                    } label: {
                                        Label(
                                            L10n.text("home.notes.action.restore"),
                                            systemImage: "arrow.uturn.left"
                                        )
                                    }

                                    Button(role: .destructive) {
                                        onDeleteNotePermanently(note)
                                    } label: {
                                        Label(
                                            L10n.text("home.notes.action.delete_permanently"),
                                            systemImage: "trash.slash"
                                        )
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                            }
                        } else if isSelectionMode {
                            NoteCard(
                                item: item,
                                isSelectionMode: true,
                                isSelected: selectedNotes.contains(note.id),
                                onSelectionToggle: {
                                    onToggleNoteSelection(note)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onToggleNoteSelection(note)
                            }
                        } else {
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: note) {
                                    NoteCard(item: item)
                                        .firstActionGuideTarget(
                                            guideTargetNoteID == note.id
                                                ? .importedNote(note.id)
                                                : nil
                                        )
                                }
                                .buttonStyle(.tactile)
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        guard guideTargetNoteID == note.id else { return }
                                        onGuideTargetNoteOpened(note.id)
                                    }
                                )

                                NoteOverflowMenu {
                                    Button(action: onEnterSelectionMode) {
                                        Label(
                                            L10n.text("home.header.title_menu.select_notes"),
                                            systemImage: "checkmark.circle"
                                        )
                                    }

                                    Button {
                                        onManageTags(note)
                                    } label: {
                                        Label(
                                            L10n.text("home.note_tag.title"),
                                            systemImage: "tag"
                                        )
                                    }

                                    Button {
                                        onTogglePin(note)
                                    } label: {
                                        Label(
                                            note.pinnedAt == nil
                                            ? L10n.text("home.notes.action.pin")
                                            : L10n.text("home.notes.action.unpin"),
                                            systemImage: note.pinnedAt == nil ? "pin" : "pin.slash"
                                        )
                                    }

                                    ForEach(NoteSection.allCases) { section in
                                        if note.section != section {
                                            Button {
                                                onMoveNote(note, section)
                                            } label: {
                                                Label(section.moveActionTitle, systemImage: section.systemImage)
                                            }
                                        }
                                    }

                                    Button(role: .destructive) {
                                        onDeleteNote(note)
                                    } label: {
                                        Label(L10n.text("common.delete"), systemImage: "trash")
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                            }
                        }
                    }
                    .onAppear {
                        onReachBottom(note)
                    }
                }

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.text("common.loading"))
                            .font(.chillCaption)
                            .foregroundColor(.textSub)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isTrashSelected ? 24 : 100)
        }
    }
}

private struct HomeNotesEmptyStateView: View {
    let selectedSection: NoteSection
    let isTrashSelected: Bool
    let titleKey: String
    let messageKey: String

    private var emptyStateSystemImage: String {
        if isTrashSelected {
            return "trash"
        }

        return selectedSection == .published ? "paperplane.fill" : selectedSection.systemImage
    }

    private var emptyStateTint: Color {
        if isTrashSelected {
            return .textTertiary
        }

        switch selectedSection {
        case .inbox:
            return Color(hex: "6E7F91")
        case .drafts:
            return Color(hex: "8A766D")
        case .published:
            return Color(hex: "6F8778")
        }
    }

    var body: some View {
        VStack(spacing: BrandTokens.Space.s4) {
            emptyStateSymbol

            VStack(spacing: BrandTokens.Space.s2) {
                Text(L10n.text(titleKey))
                    .font(.displaySmall)
                    .foregroundStyle(Color.textMain)

                Text(L10n.text(messageKey))
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 290)
            }
        }
        .padding(.horizontal, BrandTokens.Space.s4)
        .frame(maxWidth: .infinity)
        .padding(.top, 92)
        .padding(.bottom, 180)
    }

    private var emptyStateSymbol: some View {
        Image(systemName: emptyStateSystemImage)
            .font(.system(size: 44, weight: .semibold))
            .foregroundStyle(emptyStateTint)
            .frame(width: 112, height: 112)
            .background(
                Circle()
                    .fill(
                        isTrashSelected
                        ? Color.cardBackground
                        : emptyStateTint.opacity(0.07)
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        isTrashSelected
                            ? Color.borderSubtle
                            : emptyStateTint.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.shadowColor.opacity(isTrashSelected ? 0 : 0.50),
                radius: 18
            )
            .accessibilityHidden(true)
    }
}

#if DEBUG
struct HomeEmptyStateDesignPreview: View {
    var showsFirstActionPrompt = false
    @State private var selectedSection: NoteSection = .inbox
    @State private var isVoiceMode = false
    @State private var isFirstActionPromptDismissed = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HomeHeaderView(
                    isSelectionMode: false,
                    isTrashSelected: false,
                    isSearchVisible: false,
                    isRecording: false,
                    headerTitle: "ChillScript",
                    selectedNotesCount: 0,
                    visibleNotesCount: 0,
                    hasPendingRecordings: false,
                    highlightSelectionEntry: false,
                    onToggleSidebar: {},
                    onCreateBlankNote: {},
                    onToggleSearch: {},
                    onExitSelectionMode: {},
                    onSelectAll: {},
                    onDeselectAll: {},
                    onShowDeleteConfirmation: {},
                    onShowEmptyTrashConfirmation: {}
                )

                HomeSectionPicker(
                    selectedSection: selectedSection,
                    onSelect: { selectedSection = $0 }
                )
                .padding(.horizontal, BrandTokens.Space.s4)
                .padding(.top, BrandTokens.Space.s3)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HomeQuickActionsView(
                            showsUnreadIndicator: false,
                            onPostIdeasTap: {},
                            onCreatorSkillsTap: {}
                        )
                        .padding(.horizontal, BrandTokens.Space.s4)
                        .padding(.top, 10)

                        HomeNotesListView(
                            cachedVisibleNotes: [],
                            searchQuery: "",
                            isLoading: false,
                            isInitialSyncing: false,
                            hasLoadedAtLeastOnce: true,
                            isTrashSelected: false,
                            selectedSection: selectedSection,
                            isSelectionMode: false,
                            selectedNotes: [],
                            showDefaultEmptyStateMessage: !showsFirstActionPrompt
                                || isFirstActionPromptDismissed,
                            onReachBottom: { _ in },
                            onToggleNoteSelection: { _ in },
                            onEnterSelectionMode: {},
                            onRestoreNote: { _ in },
                            onDeleteNotePermanently: { _ in },
                            onTogglePin: { _ in },
                            onManageTags: { _ in },
                            onMoveNote: { _, _ in },
                            onDeleteNote: { _ in }
                        )
                    }
                }
            }

            ChatInputBar(
                isVoiceMode: $isVoiceMode,
                speechRecognizer: speechRecognizer,
                onCancelVoice: {},
                onConfirmVoice: {},
                onPasteLink: { _ in },
                onCreateBlankNote: {},
                enforceVoiceQuota: false
            )
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if showsFirstActionPrompt && !isFirstActionPromptDismissed {
                FirstActionSharePromptView(
                    onStart: { isFirstActionPromptDismissed = true },
                    onSkip: { isFirstActionPromptDismissed = true }
                )
                    .padding(.horizontal, BrandTokens.Space.s3)
                    .padding(.bottom, 104)
            }
        }
    }
}
#endif

private struct NoteOverflowMenu<Actions: View>: View {
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        actionsMenu
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("note_detail.header.accessibility.more_actions"))
    }

    private var actionsMenu: some View {
        Menu(content: actions) {
            NoteOverflowMenuLabel()
        }
    }
}

private struct NoteOverflowMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.textSub)
            .frame(width: 36, height: 36)
            .contentShape(Circle())
    }
}

private struct HomeNotesLoadingView: View {
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 90, height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 14)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.16))
                        .frame(height: 14)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 140, height: 14)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 100)
    }
}

private struct HomeNotesSyncingView: View {
    var body: some View {
        VStack(spacing: BrandTokens.Space.s2) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color.accentPrimary)

            Text(L10n.text("home.notes.syncing"))
                .font(.bodyMedium)
                .foregroundStyle(Color.textSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 92)
        .padding(.bottom, 180)
        .accessibilityElement(children: .combine)
    }
}

struct TrashNoteFooterView: View {
    let note: Note

    var body: some View {
        if let deletedAt = note.deletedAt {
            let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.textSub)
                Text(
                    String(
                        format: L10n.text("home.notes.trash.deleted_format"),
                        deletedAt.relativeFormatted()
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text(
                    daysRemaining == 0
                    ? L10n.text("home.notes.trash.expires_today")
                    : String(
                        format: L10n.text("home.notes.trash.days_left"),
                        Int64(daysRemaining)
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct NoteListTagViewData: Identifiable {
    let id: UUID
    let name: String
    let highlightedName: AttributedString
    let textColor: Color
    let backgroundColor: Color
}

struct NoteListItemViewData: Identifiable {
    let id: UUID
    let createdAt: Date
    let createdAtRelativeText: String
    let pinnedAt: Date?
    let previewText: String
    let highlightedPreviewText: AttributedString
    let markdownPreviewText: String
    let usePlainPreview: Bool
    let isEmpty: Bool
    let firstImageURL: URL?
    let tags: [NoteListTagViewData]
    let hiddenTagCount: Int
    let source: NoteSourceMetadata?
    let importStatus: NoteImportStatus

    init(note: Note, searchQuery: String, usePlainPreview: Bool = true) {
        id = note.id
        createdAt = note.createdAt
        createdAtRelativeText = note.createdAt.relativeFormatted()
        pinnedAt = note.pinnedAt

        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        isEmpty = trimmed.isEmpty
        self.usePlainPreview = usePlainPreview
        let preview = SearchHighlightFormatter.makePreviewText(
            content: note.displayText,
            query: searchQuery
        )
        previewText = preview
        highlightedPreviewText = SearchHighlightFormatter.makeHighlightedText(
            text: preview,
            query: searchQuery,
            baseColor: .textMain,
            highlightColor: .textMain,
            highlightBackground: Color.accentPrimary.opacity(0.18),
            highlightFont: .bodyMedium.weight(.semibold)
        )
        markdownPreviewText = NoteImageStorage.removingMarkdownImages(from: trimmed)
        firstImageURL = NoteImageStorage.markdownImageFileURLs(in: note.content).first

        let prefixTags = Array(note.tags.prefix(3))
        tags = prefixTags.map { tag in
            NoteListTagViewData(
                id: tag.id,
                name: tag.name,
                highlightedName: SearchHighlightFormatter.makeHighlightedText(
                    text: tag.name,
                    query: searchQuery,
                    baseColor: tag.labelColor,
                    highlightColor: tag.labelColor,
                    highlightBackground: Color.white.opacity(0.45),
                    highlightFont: .chillCaption.weight(.semibold)
                ),
                textColor: tag.labelColor,
                backgroundColor: tag.badgeBackgroundColor
            )
        }
        hiddenTagCount = max(0, note.tags.count - prefixTags.count)
        source = note.sourceMetadata
        importStatus = note.importStatus
    }
}

struct NoteCard: View {
    let item: NoteListItemViewData
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    private var processingStage: VoiceProcessingStage? {
        guard let state = VoiceProcessingService.shared.processingStates[item.id],
              case .processing(let stage) = state else {
            return nil
        }
        return stage
    }

    private var processingFailureMessage: String? {
        guard let state = VoiceProcessingService.shared.processingStates[item.id],
              case .failed(let message) = state else {
            return nil
        }
        return message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .accentPrimary : .textSub)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: isSelected)
                }
                .buttonStyle(.bouncy)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.createdAtRelativeText)
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                    if item.pinnedAt != nil {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                            .padding(.leading, 4)
                            .accessibilityLabel(Text(L10n.text("home.notes.accessibility.pinned")))
                    }
                    Spacer()
                }

                if item.importStatus == .queued || item.importStatus == .processing {
                    LinkImportPreparingView()
                        .padding(.top, 2)
                } else {
                    if let stage = processingStage {
                        VoiceProcessingWorkflowView(currentStage: stage, style: .compact)
                            .padding(.top, 2)
                    } else if let failure = processingFailureMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(failure)
                                .font(.chillCaption)
                                .foregroundColor(.textSub)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.top, 2)
                    } else {
                        if let firstImageURL = item.firstImageURL {
                            NoteCardImagePreview(url: firstImageURL)
                        }

                        if !item.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !item.markdownPreviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Group {
                                if item.usePlainPreview {
                                    Text(item.highlightedPreviewText)
                                        .font(.bodyMedium)
                                        .lineLimit(5)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    RichTextPreview(
                                        content: item.markdownPreviewText,
                                        lineLimit: 5,
                                        font: .bodyMedium,
                                        textColor: .textMain
                                    )
                                }
                            }
                        }

                        if !item.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(item.tags) { tag in
                                    Text(tag.highlightedName)
                                        .font(.chillCaption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(tag.backgroundColor)
                                        .clipShape(Capsule())
                                }
                                if item.hiddenTagCount > 0 {
                                    Text("+\(item.hiddenTagCount)")
                                        .font(.chillCaption)
                                        .foregroundColor(.textSub)
                                }
                            }
                        }

                        if let source = item.source {
                            NoteSourceCard(source: source, compact: true)
                                .padding(.top, item.tags.isEmpty ? 2 : 4)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.shadowColor, radius: 8, y: 4)
    }
}

private struct LinkImportPreparingView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.accentPrimary.opacity(0.12), lineWidth: 2.5)

                Circle()
                    .trim(from: 0.08, to: 0.82)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.accentPrimary.opacity(0.32),
                                Color.accentPrimary,
                                Color.accentPrimary
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 0.9).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
                .frame(width: 20, height: 20)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("quick_capture.link_import.card.title"))
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundColor(.textMain)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("quick_capture.link_import.card.body"))
                    .font(.chillCaption)
                    .foregroundColor(.textSub)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 5, height: 5)
                            .scaleEffect(isAnimating ? 1 : 0.72)
                            .opacity(isAnimating ? 0.32 : 0.9)
                            .animation(
                                .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.16),
                                value: isAnimating
                            )
                    }
                }
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            isAnimating = true
        }
    }
}

private struct NoteCardImagePreview: View {
    let url: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipped()
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

enum SearchHighlightFormatter {
    static func makePreviewText(content: String, query: String, radius: Int = 48) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty, !trimmedQuery.isEmpty else {
            return trimmedContent
        }

        guard let firstRange = firstMatchRange(in: trimmedContent, query: trimmedQuery) else {
            return trimmedContent
        }

        let lowerBound = trimmedContent.index(
            firstRange.lowerBound,
            offsetBy: -radius,
            limitedBy: trimmedContent.startIndex
        ) ?? trimmedContent.startIndex
        let upperBound = trimmedContent.index(
            firstRange.upperBound,
            offsetBy: radius,
            limitedBy: trimmedContent.endIndex
        ) ?? trimmedContent.endIndex

        var excerpt = String(trimmedContent[lowerBound..<upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerBound > trimmedContent.startIndex {
            excerpt = "…" + excerpt
        }
        if upperBound < trimmedContent.endIndex {
            excerpt += "…"
        }
        return excerpt
    }

    static func makeHighlightedText(
        text: String,
        query: String,
        baseColor: Color,
        highlightColor: Color,
        highlightBackground: Color,
        highlightFont: Font? = nil
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor

        let tokens = normalizedTokens(from: query)
        guard !tokens.isEmpty else {
            return attributed
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var matchedRanges: [Range<String.Index>] = []

        for token in tokens {
            var searchRange = fullRange
            while let found = nsText.range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                range: searchRange
            ).toOptional(), let swiftRange = Range(found, in: text) {
                matchedRanges.append(swiftRange)
                let nextLocation = found.location + max(found.length, 1)
                guard nextLocation < nsText.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
            }
        }

        for range in merged(matchedRanges) {
            guard let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].foregroundColor = highlightColor
            attributed[attributedRange].backgroundColor = highlightBackground
            if let highlightFont {
                attributed[attributedRange].font = highlightFont
            }
        }

        return attributed
    }

    static func firstMatchRange(in text: String, query: String) -> Range<String.Index>? {
        for token in normalizedTokens(from: query) {
            if let range = text.range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            ) {
                return range
            }
        }
        return nil
    }

    private static func normalizedTokens(from query: String) -> [String] {
        let normalized = NoteTextNormalizer.normalizeQuery(query)
        return normalized
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    private static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        guard var current = sorted.first else { return [] }

        var result: [Range<String.Index>] = []
        for range in sorted.dropFirst() {
            if range.lowerBound <= current.upperBound {
                current = current.lowerBound..<max(current.upperBound, range.upperBound)
            } else {
                result.append(current)
                current = range
            }
        }
        result.append(current)
        return result
    }
}

private extension NSRange {
    func toOptional() -> NSRange? {
        location == NSNotFound ? nil : self
    }
}
