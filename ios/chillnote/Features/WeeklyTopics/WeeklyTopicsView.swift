import SwiftUI

struct WeeklyTopicsPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let onTry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            WeeklyTopicsIntroContent(
                actionTitleKey: "weekly_topics.preview.try_action",
                showsSecondaryAction: true,
                onAction: onTry,
                onSecondaryAction: { dismiss() }
            )
        }
        .background(Color.bgPrimary.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundColor(.textMain)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel(L10n.text("common.back"))

            Text(L10n.text("weekly_topics.preview.title"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textMain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 58)
    }

}

private struct WeeklyTopicsIntroContent: View {
    let actionTitleKey: String
    let showsSecondaryAction: Bool
    let onAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 38)

                        Text(headlineText)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.textMain)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)

                        Spacer(minLength: 22)

                        WeeklyTopicsPreviewIllustration()
                            .frame(maxWidth: 360)
                            .frame(height: 304)
                            .padding(.horizontal, 18)

                        Spacer(minLength: 22)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
            }

            actions
        }
        .background(Color.bgPrimary.ignoresSafeArea())
    }

    private var headlineText: AttributedString {
        var headline = AttributedString(L10n.text("weekly_topics.preview.headline"))
        let highlight = L10n.text("weekly_topics.preview.headline_highlight")

        if let range = headline.range(of: highlight) {
            headline[range].foregroundColor = .accentPrimary
        }

        return headline
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button(action: onAction) {
                Text(L10n.text(actionTitleKey))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Color.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if showsSecondaryAction {
                Button(action: onSecondaryAction) {
                    Text(L10n.text("weekly_topics.preview.skip_action"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.accentPrimary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.bgPrimary)
    }
}

private struct WeeklyTopicsPreviewIllustration: View {
    private let sourceCardHeight: CGFloat = 68
    private let sourceSpacing: CGFloat = 12
    private let resultCardHeight: CGFloat = 228

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let sourceWidth = min(132, width * 0.38)
            let resultWidth = min(148, width * 0.42)
            let sourceTrailing = sourceWidth - 4
            let resultLeading = width - resultWidth
            let joinX = sourceTrailing + ((resultLeading - sourceTrailing) * 0.62)
            let centerY: CGFloat = 122

            ZStack(alignment: .topLeading) {
                RadialGradient(
                    colors: [Color.selectionHighlight.opacity(0.82), .clear],
                    center: .center,
                    startRadius: 16,
                    endRadius: 178
                )
                .frame(width: width, height: 270)
                .offset(y: -8)

                connector(
                    sourceTrailing: sourceTrailing,
                    resultLeading: resultLeading,
                    joinX: joinX,
                    centerY: centerY
                )

                VStack(spacing: sourceSpacing) {
                    sourceCard(
                        icon: "text.bubble",
                        tint: .accentPrimary,
                        background: Color.selectionHighlight.opacity(0.72)
                    )
                    sourceCard(
                        icon: "link",
                        tint: .accentPrimary,
                        background: Color.brandBlueSoft.opacity(0.72)
                    )
                    sourceCard(
                        icon: "scribble.variable",
                        tint: .accentPrimary,
                        background: Color.selectionHighlight.opacity(0.72)
                    )
                }
                .frame(width: sourceWidth)
                .offset(y: 8)

                resultCard
                    .frame(width: resultWidth, height: resultCardHeight)
                    .offset(x: width - resultWidth, y: 8)

                Text(L10n.text("weekly_topics.preview.sources_label"))
                    .frame(width: sourceWidth)
                    .offset(y: 260)

                Text(L10n.text("weekly_topics.preview.result_label"))
                    .frame(width: resultWidth)
                    .offset(x: width - resultWidth, y: 260)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.textMain)
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.text("weekly_topics.preview.illustration_accessibility"))
        }
    }

    private func connector(
        sourceTrailing: CGFloat,
        resultLeading: CGFloat,
        joinX: CGFloat,
        centerY: CGFloat
    ) -> some View {
        Path { path in
            let sourceCenters: [CGFloat] = [42, 122, 202]

            for sourceY in sourceCenters {
                path.move(to: CGPoint(x: sourceTrailing, y: sourceY))
                path.addCurve(
                    to: CGPoint(x: joinX, y: centerY),
                    control1: CGPoint(x: sourceTrailing + 30, y: sourceY),
                    control2: CGPoint(x: joinX - 24, y: centerY)
                )
            }

            let arrowEnd = resultLeading - 5
            path.move(to: CGPoint(x: joinX, y: centerY))
            path.addLine(to: CGPoint(x: arrowEnd, y: centerY))
            path.move(to: CGPoint(x: arrowEnd - 10, y: centerY - 10))
            path.addLine(to: CGPoint(x: arrowEnd, y: centerY))
            path.addLine(to: CGPoint(x: arrowEnd - 10, y: centerY + 10))
        }
        .stroke(
            Color.accentPrimary.opacity(0.5),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private func sourceCard(icon: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 7) {
                Capsule()
                    .fill(Color.textSub.opacity(0.26))
                    .frame(height: 7)
                Capsule()
                    .fill(Color.textSub.opacity(0.17))
                    .frame(width: 54, height: 7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: sourceCardHeight)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Color.shadowColor, radius: 10, y: 5)
    }

    private var resultCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "lightbulb")
                .font(.system(size: 46, weight: .light))
                .foregroundColor(.accentPrimary)

            Text(L10n.text("weekly_topics.preview.illustration_label"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentPrimaryText)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 11) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.18))
                            .frame(width: 7, height: 7)
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.13))
                            .frame(width: index == 1 ? 68 : 86, height: 7)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.accentPrimary.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: Color.accentPrimary.opacity(0.13), radius: 18, y: 7)
    }
}

struct WeeklyTopicsView: View {
    @ObservedObject var store: WeeklyTopicsStore
    let onOpenSource: (UUID) -> Void

    @State private var isShowingSettings = false
    @State private var isShowingHistory = false
    @State private var isConfirmingRegeneration = false

    var body: some View {
        content
            .navigationTitle(L10n.text("weekly_topics.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.bgPrimary.ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.dashboard?.settings.enabled == true {
                        Button {
                            isShowingHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(L10n.text("weekly_topics.history.title"))
                    }

                    if store.dashboard?.settings.enabled == true {
                        Menu {
                            if let report = store.dashboard?.latestReport, report.canRegenerate {
                                Button(L10n.text("weekly_topics.regenerate.action")) {
                                    isConfirmingRegeneration = true
                                }
                            }
                            Button(L10n.text("weekly_topics.settings.title")) {
                                isShowingSettings = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel(L10n.text("weekly_topics.more_actions"))
                    }

                }
            }
            .sheet(isPresented: $isShowingSettings) {
                WeeklyTopicsSettingsView(store: store)
            }
            .sheet(isPresented: $isShowingHistory) {
                NavigationStack {
                    WeeklyTopicsHistoryView(store: store, onOpenSource: onOpenSource)
                }
            }
            .alert(
                L10n.text("weekly_topics.regenerate.confirm_title"),
                isPresented: $isConfirmingRegeneration
            ) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("weekly_topics.regenerate.action")) {
                    guard let report = store.dashboard?.latestReport else { return }
                    Task { _ = await store.regenerate(report) }
                }
            } message: {
                Text(L10n.text("weekly_topics.regenerate.confirm_message"))
            }
            .alert(
                L10n.text("weekly_topics.error.title"),
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )
            ) {
                Button(L10n.text("common.ok"), role: .cancel) { }
            } message: {
                Text(store.errorMessage ?? L10n.text("weekly_topics.error.load"))
            }
            .task {
                await store.reload()
                if let report = store.dashboard?.latestReport {
                    await store.markRead(report)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.dashboard == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.dashboard?.settings.enabled != true {
            WeeklyTopicsEnableView(store: store)
        } else if store.isRegenerating {
            VStack(spacing: 14) {
                ProgressView()
                Text(L10n.text("weekly_topics.regenerate.progress"))
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let report = store.dashboard?.latestReport {
            WeeklyTopicReportContent(report: report, onOpenSource: onOpenSource)
        } else if let dashboard = store.dashboard {
            WeeklyTopicsWaitingView(dashboard: dashboard)
        } else {
            WeeklyTopicsLoadFailureView {
                Task { await store.reload() }
            }
        }
    }
}

private struct WeeklyTopicsEnableView: View {
    @ObservedObject var store: WeeklyTopicsStore
    @State private var isShowingSchedule = false

    var body: some View {
        WeeklyTopicsIntroContent(
            actionTitleKey: "weekly_topics.schedule.action",
            showsSecondaryAction: false,
            onAction: { isShowingSchedule = true },
            onSecondaryAction: { }
        )
        .navigationDestination(isPresented: $isShowingSchedule) {
            WeeklyTopicsScheduleView(store: store)
        }
    }
}

private struct WeeklyTopicsScheduleView: View {
    @ObservedObject var store: WeeklyTopicsStore
    @Environment(\.dismiss) private var dismiss

    @State private var weekday = 1
    @State private var time = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)

                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundColor(.inspirationAccent)

                            Text(L10n.text("weekly_topics.schedule.message"))
                                .font(.bodyMedium)
                                .foregroundColor(.textSub)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Text(L10n.text("weekly_topics.settings.weekday"))
                                    .foregroundColor(.textMain)

                                Spacer(minLength: 12)

                                Picker(
                                    L10n.text("weekly_topics.settings.weekday"),
                                    selection: $weekday
                                ) {
                                    ForEach(1...7, id: \.self) { value in
                                        Text(weekdayName(value)).tag(value)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(.inspirationAccentText)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.leading, 18)

                            HStack(spacing: 16) {
                                Text(L10n.text("weekly_topics.settings.time"))
                                    .foregroundColor(.textMain)

                                Spacer(minLength: 12)

                                DatePicker(
                                    L10n.text("weekly_topics.settings.time"),
                                    selection: $time,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(.inspirationAccentText)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                        .frame(maxWidth: 360)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, 24)
                }
            }

            Button(action: schedule) {
                Group {
                    if store.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(L10n.text("weekly_topics.schedule.action"))
                    }
                }
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(store.isSaving)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color.bgPrimary)
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .navigationTitle(L10n.text("weekly_topics.schedule.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func schedule() {
        Task {
            let hasConsent = await AIConsentManager.shared.ensureConsentIfNeeded(for: .text)
            guard hasConsent else { return }

            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            let saved = await store.saveSettings(
                enabled: true,
                weekday: weekday,
                hour: components.hour ?? 9,
                minute: components.minute ?? 0
            )
            guard saved else { return }

            await PushNotificationManager.shared.refreshRegistration()
            await store.reload()
            dismiss()
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let calendarIndex = weekday == 7 ? 1 : weekday + 1
        return Calendar.current.weekdaySymbols[calendarIndex - 1]
    }
}

private struct WeeklyTopicsWaitingView: View {
    let dashboard: WeeklyTopicDashboard

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(.inspirationAccent)
            Text(L10n.text("weekly_topics.waiting.title"))
                .font(.displaySmall)
                .foregroundColor(.textMain)
            Text(waitingMessage)
                .font(.bodyMedium)
                .foregroundColor(.textSub)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var waitingMessage: String {
        if dashboard.currentSourceCount < dashboard.minimumSourceCount {
            return L10n.text("weekly_topics.waiting.no_sources")
        }
        return L10n.text("weekly_topics.waiting.ready")
    }
}

private struct WeeklyTopicsLoadFailureView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.text("weekly_topics.error.title"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        } description: {
            Text(L10n.text("weekly_topics.error.load"))
        } actions: {
            Button(L10n.text("common.retry"), action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct WeeklyTopicReportContent: View {
    let report: WeeklyTopicReport
    let onOpenSource: (UUID) -> Void

    @State private var expandedTopicIDs: Set<String>

    init(
        report: WeeklyTopicReport,
        initiallyExpandedTopicIDs: Set<String>? = nil,
        onOpenSource: @escaping (UUID) -> Void
    ) {
        self.report = report
        self.onOpenSource = onOpenSource
        let defaultExpandedIDs = Set(report.topics.first.map { [$0.id] } ?? [])
        _expandedTopicIDs = State(initialValue: initiallyExpandedTopicIDs ?? defaultExpandedIDs)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                WeeklyTopicReportHeader(report: report)

                VStack(spacing: 0) {
                    ForEach(Array(report.topics.enumerated()), id: \.element.id) { index, topic in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 24)
                        }

                        WeeklyTopicAccordionRow(
                            topic: topic,
                            index: index,
                            isExpanded: expandedTopicIDs.contains(topic.id),
                            onToggle: { toggle(topic) },
                            onOpenSource: onOpenSource
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.cardBackground)
    }

    private func toggle(_ topic: WeeklyTopicItem) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if expandedTopicIDs.contains(topic.id) {
                expandedTopicIDs.remove(topic.id)
            } else {
                expandedTopicIDs.insert(topic.id)
            }
        }
    }
}

private struct WeeklyTopicReportHeader: View {
    let report: WeeklyTopicReport

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 76, weight: .regular))
                .foregroundColor(.inspirationAccent.opacity(0.10))
                .padding(.trailing, 20)
                .padding(.bottom, 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("weekly_topics.report.inspiration_label"))
                    .font(.chillCaption)
                    .foregroundColor(.inspirationAccentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(summaryText)
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundColor(.textMain)
                    .fixedSize(horizontal: false, vertical: true)

                Text(dateRange)
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 32)
        .background(Color.inspirationHighlight)
        .accessibilityElement(children: .combine)
    }

    private var dateRange: String {
        let start = report.periodStart.formatted(.dateTime.month(.abbreviated).day())
        let end = report.periodEnd.formatted(.dateTime.month(.abbreviated).day())
        return L10n.text("weekly_topics.report.date_range", start, end)
    }

    private var summaryText: AttributedString {
        var summary = AttributedString(L10n.text(
            "weekly_topics.report.summary",
            report.topics.count,
            report.sourceNoteCount
        ))

        let topicsCount = String(format: "%lld", report.topics.count)
        let sourceCount = String(format: "%lld", report.sourceNoteCount)

        if let topicsRange = summary.range(of: topicsCount) {
            summary[topicsRange].foregroundColor = .inspirationAccentText

            if let sourceRange = summary[topicsRange.upperBound..<summary.endIndex]
                .range(of: sourceCount) {
                summary[sourceRange].foregroundColor = .inspirationAccentText
            }
        } else if let sourceRange = summary.range(of: sourceCount) {
            summary[sourceRange].foregroundColor = .inspirationAccentText
        }

        return summary
    }
}

private struct WeeklyTopicAccordionRow: View {
    let topic: WeeklyTopicItem
    let index: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onOpenSource: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(L10n.text("weekly_topics.topic.progress", index + 1))
                        .font(.system(size: 14, weight: .medium, design: .default).monospacedDigit())
                        .foregroundColor(.inspirationAccentText)
                        .frame(width: 40, alignment: .leading)

                    Text(topic.title)
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundColor(.textMain)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.text(
                isExpanded
                    ? "weekly_topics.topic.collapse_hint"
                    : "weekly_topics.topic.expand_hint"
            ))
            .accessibilityIdentifier("weekly-topic-row-\(topic.id)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.text("weekly_topics.topic.related_sources"))
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundColor(.textMain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(topic.sources.enumerated()), id: \.element.id) { sourceIndex, source in
                            if sourceIndex > 0 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                            WeeklyTopicSourceRow(source: source, onOpenSource: onOpenSource)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("weekly-topic-sources-\(topic.id)")
            }
        }
    }
}

private struct WeeklyTopicSourceRow: View {
    let source: WeeklyTopicSource
    let onOpenSource: (UUID) -> Void

    @ViewBuilder
    var body: some View {
        if source.resolvedAvailability == .deleted {
            rowContent(showsDisclosure: false)
        } else if let noteID = UUID(uuidString: source.noteId) {
            Button {
                onOpenSource(noteID)
            } label: {
                rowContent(showsDisclosure: true)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(showsDisclosure: false)
        }
    }

    private func rowContent(showsDisclosure: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            WeeklyTopicPlatformMark(
                platformName: source.platformName,
                isUnavailable: source.resolvedAvailability == .deleted
            )

            VStack(alignment: .leading, spacing: 4) {
                if source.resolvedAvailability == .deleted {
                    Text(L10n.text("weekly_topics.source.deleted"))
                        .font(.bodySmall)
                        .foregroundColor(.textTertiary)
                } else {
                    Text(source.noteTitle)
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                        .lineLimit(2)

                    Text(source.excerpt)
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                        .lineLimit(2)

                    if source.resolvedAvailability == .trashed {
                        Text(L10n.text("weekly_topics.source.in_trash"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.inspirationAccentText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct WeeklyTopicPlatformMark: View {
    let platformName: String?
    let isUnavailable: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)

            if isUnavailable {
                Image(systemName: "trash.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textTertiary)
            } else if let assetName {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(brandColor)
                    .padding(10)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentSecondary)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    private var normalizedName: String {
        platformName?.lowercased() ?? ""
    }

    private var assetName: String? {
        if normalizedName.contains("youtube") {
            return "YouTubeBrandLogo"
        }
        if normalizedName.contains("tiktok") {
            return "TikTokBrandLogo"
        }
        if normalizedName.contains("instagram") {
            return "InstagramBrandLogo"
        }
        return nil
    }

    private var brandColor: Color {
        Self.brandColor(for: normalizedName)
    }

    static func brandColor(for platformName: String) -> Color {
        let normalizedName = platformName.lowercased()
        if normalizedName.contains("youtube") {
            return Color(red: 1, green: 0, blue: 0)
        }
        if normalizedName.contains("tiktok") {
            return Color.primary
        }
        if normalizedName.contains("instagram") {
            return Color(red: 0.83, green: 0.20, blue: 0.55)
        }
        return .accentSecondary
    }
}

private struct WeeklyTopicsHistoryView: View {
    @ObservedObject var store: WeeklyTopicsStore
    let onOpenSource: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(store.reports) { report in
            NavigationLink {
                WeeklyTopicReportDetailView(
                    reportID: report.id,
                    store: store,
                    onOpenSource: onOpenSource
                )
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.periodEnd.formatted(date: .long, time: .omitted))
                        .font(.bodyLarge.weight(.semibold))
                    Text(L10n.text("weekly_topics.history.summary", report.topics.count, report.sourceNoteCount))
                        .font(.bodyMedium)
                        .foregroundColor(.textSub)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.reports.isEmpty {
                ContentUnavailableView(
                    L10n.text("weekly_topics.history.empty"),
                    systemImage: "calendar"
                )
            }
        }
        .navigationTitle(L10n.text("weekly_topics.history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("common.close")) { dismiss() }
            }
        }
        .task { await store.loadHistory() }
    }
}

private struct WeeklyTopicReportDetailView: View {
    let reportID: String
    @ObservedObject var store: WeeklyTopicsStore
    let onOpenSource: (UUID) -> Void

    var body: some View {
        Group {
            if let report = store.loadedReports[reportID] {
                WeeklyTopicReportContent(report: report, onOpenSource: onOpenSource)
                    .task { await store.markRead(report) }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { _ = await store.loadReport(id: reportID) }
            }
        }
        .navigationTitle(L10n.text("weekly_topics.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.bgPrimary.ignoresSafeArea())
    }
}

private struct WeeklyTopicsSettingsView: View {
    @ObservedObject var store: WeeklyTopicsStore
    @Environment(\.dismiss) private var dismiss

    @State private var enabled = true
    @State private var weekday = 1
    @State private var time = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L10n.text("weekly_topics.settings.enabled"), isOn: $enabled)

                    Picker(L10n.text("weekly_topics.settings.weekday"), selection: $weekday) {
                        ForEach(1...7, id: \.self) { value in
                            Text(weekdayName(value)).tag(value)
                        }
                    }

                    DatePicker(
                        L10n.text("weekly_topics.settings.time"),
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    Text(L10n.text("weekly_topics.settings.source_scope"))
                        .font(.footnote)
                        .foregroundColor(.textSub)
                }
            }
            .navigationTitle(L10n.text("weekly_topics.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.save")) {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                        Task {
                            let saved = await store.saveSettings(
                                enabled: enabled,
                                weekday: weekday,
                                hour: components.hour ?? 9,
                                minute: components.minute ?? 0
                            )
                            if saved {
                                await store.reload()
                                dismiss()
                            }
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
            .onAppear {
                guard let settings = store.dashboard?.settings else { return }
                enabled = settings.enabled
                weekday = settings.weekday
                time = Calendar.current.date(
                    from: DateComponents(hour: settings.hour, minute: settings.minute)
                ) ?? time
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let calendarIndex = weekday == 7 ? 1 : weekday + 1
        return Calendar.current.weekdaySymbols[calendarIndex - 1]
    }
}

#if DEBUG
struct WeeklyTopicsDesignPreview: View {
    var body: some View {
        NavigationStack {
            WeeklyTopicReportContent(
                report: Self.report,
                initiallyExpandedTopicIDs: previewExpandedTopicIDs
            ) { _ in }
                .navigationTitle(L10n.text("weekly_topics.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        Button(action: {}) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .tint(.inspirationAccentText)
    }

    private var previewExpandedTopicIDs: Set<String>? {
        ProcessInfo.processInfo.arguments.contains("-weekly-topics-design-preview-topic-2")
            ? ["topic-2"]
            : nil
    }

    private static let report = WeeklyTopicReport(
        id: "weekly-topics-design-preview",
        periodStart: makeDate(year: 2026, month: 7, day: 27),
        periodEnd: makeDate(year: 2026, month: 8, day: 2),
        sourceNoteCount: 12,
        language: "zh-Hans",
        topics: [
            WeeklyTopicItem(
                id: "topic-1",
                title: "为什么「收藏」不等于真正掌握",
                sources: [
                    WeeklyTopicSource(
                        noteId: "15C73B2E-6ACF-44CB-8269-F1C487B6DA39",
                        noteTitle: "从收藏到掌握：建立自己的知识系统",
                        platformName: "YouTube",
                        excerpt: "把信息转化为自己的观点，需要重新组织和输出。"
                    ),
                    WeeklyTopicSource(
                        noteId: "80938D8B-1181-4C02-867A-0786E9B66337",
                        noteTitle: "把信息变成观点的三个步骤",
                        platformName: nil,
                        excerpt: "收藏只是输入，输出才会暴露理解中的空白。"
                    )
                ]
            ),
            WeeklyTopicItem(
                id: "topic-2",
                title: "把零散灵感变成稳定输出",
                sources: [
                    WeeklyTopicSource(
                        noteId: "86A7B1C6-48C6-4E7D-A1C1-6D78F67E41F2",
                        noteTitle: "创作者如何建立稳定的灵感工作流",
                        platformName: "TikTok",
                        excerpt: "把随手收藏变成固定的整理、连接与输出流程。"
                    )
                ]
            ),
            WeeklyTopicItem(
                id: "topic-3",
                title: "AI 工具正在重塑创作者工作流",
                sources: [
                    WeeklyTopicSource(
                        noteId: "E0706305-034F-4D20-8F44-6A3C9CF8E2C9",
                        noteTitle: "AI 不是替代创作，而是缩短准备时间",
                        platformName: "Instagram Reels",
                        excerpt: "真正被改变的是从灵感到初稿之间的重复劳动。"
                    )
                ]
            ),
            WeeklyTopicItem(
                id: "topic-4",
                title: "持续阅读，构建长期影响力",
                sources: [
                    WeeklyTopicSource(
                        noteId: "C801F577-EF34-457D-990A-7B86DAEC9169",
                        noteTitle: "长期输出来自持续输入与反复思考",
                        platformName: "YouTube",
                        excerpt: "稳定阅读让观点不断生长，而不是追逐短期热点。"
                    )
                ]
            )
        ],
        readAt: nil,
        regenerationCount: 0,
        createdAt: makeDate(year: 2026, month: 8, day: 2)
    )

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
#endif
