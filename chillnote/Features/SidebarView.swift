import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import OSLog

private let sidebarLogger = Logger(subsystem: "com.chillnote.app", category: "sidebar")

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @StateObject private var storeService = StoreService.shared
    @Query(filter: #Predicate<Tag> { $0.deletedAt == nil }, sort: \Tag.name) private var _allTags: [Tag]
    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }) private var activeNotes: [Note]
    
    @Binding var isPresented: Bool
    @Binding var selectedTag: Tag?
    @Binding var selectedSection: NoteSection?
    @Binding var isTrashSelected: Bool
    @State private var showSubscription = false
    var hasPendingRecordings: Bool = false
    var pendingRecordingsCount: Int = 0
    var onSettingsTap: (() -> Void)?
    var onChillRecipesTap: (() -> Void)?
    var onPendingRecordingsTap: (() -> Void)?
    
    private let sidebarCloseMinTranslation: CGFloat = 30
    private let sidebarCloseHorizontalBias: CGFloat = 12
    
    // Filter tags by current user
    private var allTags: [Tag] {
        guard let userId = authService.currentUserId else { return [] }
        return _allTags.filter { $0.userId == userId }
    }

    /// Root-level tags (those without a parent)
    private var rootTags: [Tag] {
        allTags.filter { $0.isRoot }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sectionStats: [SidebarSectionStat] {
        NoteSection.allCases.map { section in
            SidebarSectionStat(
                section: section,
                count: activeNotesCount(for: section)
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background Blur/Dim
            if isPresented {
                Color.black.opacity(0.15) // 更轻薄的遮罩
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Drawer Content
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 24) { // 减小整体间距
                    // Header - Minimalist (Membership + Settings)
                    HStack(spacing: 0) {
                        membershipEntry
                        
                        Spacer()
                        
                        // Settings Button
                        Button(action: {
                            isPresented = false // Close sidebar
                            onSettingsTap?()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.textMain.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(Color.textMain.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.text("sidebar.accessibility.open_settings"))
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)

                    SidebarStatsView(stats: sectionStats)
                        .padding(.horizontal, 16)
                    
                    // Main Navigation
                    VStack(spacing: 6) {
                        SidebarItem(
                            icon: "doc.text",
                            title: L10n.text("note_section.inbox"),
                            isSelected: selectedTag == nil && selectedSection == .inbox && !isTrashSelected
                        ) {
                            selectedTag = nil
                            selectedSection = .inbox
                            isTrashSelected = false
                            isPresented = false
                        }

                        SidebarItem(icon: "trash", title: L10n.text("sidebar.nav.recycle_bin"), isSelected: isTrashSelected) {
                            selectedTag = nil
                            selectedSection = nil
                            isTrashSelected = true
                            isPresented = false
                        }

                        if pendingRecordingsCount > 0 {
                            SidebarItem(
                                icon: "waveform",
                                title: L10n.text("sidebar.nav.pending_records"),
                                isSelected: false,
                                badgeCount: pendingRecordingsCount
                            ) {
                                isPresented = false
                                onPendingRecordingsTap?()
                            }
                        }

                        SidebarItem(icon: "book.closed", title: L10n.text("sidebar.nav.chill_skills"), isSelected: false) {
                            isPresented = false
                            onChillRecipesTap?()
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Tags Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Section Header as Root Drop Target
                        RootDropZone(modelContext: modelContext)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(rootTags) { tag in
                                        TagTreeItemView(
                                            tag: tag,
                                            selectedTag: $selectedTag,
                                            selectedSection: $selectedSection,
                                            isTrashSelected: $isTrashSelected,
                                            isPresented: $isPresented,
                                            modelContext: modelContext,
                                            depth: 0
                                        )
                                }
                                
                                if allTags.isEmpty {
                                    Text(L10n.text("sidebar.tags.empty"))
                                        .font(.system(size: 13, design: .serif))
                                        .foregroundColor(.textSub.opacity(0.6))
                                        .padding(.top, 40)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                // Drag area filler to ensure drop zone covers remaining space
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(height: 100)
                            }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            handleRootDrop(items: items)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()

                    TrashDropZone(modelContext: modelContext)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .frame(width: 320)
                .background(Color.bgSecondary) // 纯净背景
                .offset(x: isPresented ? 0 : -320)
                
                Spacer()
            }
        }
        .ignoresSafeArea(.all, edges: .vertical)
        .simultaneousGesture(sidebarCloseGesture)
        .zIndex(1000)
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .task {
            await storeService.refreshSubscriptionStatus()
        }
    }
    
    // MARK: - Helper Methods
    
    private var sidebarCloseGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                guard shouldCloseSidebar(from: value) else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPresented = false
                }
                triggerSidebarHaptic()
            }
    }
    
    private func shouldCloseSidebar(from value: DragGesture.Value) -> Bool {
        guard isPresented else { return false }
        
        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        let predictedHorizontal = value.predictedEndTranslation.width
        
        let hasEnoughLeftDistance =
            horizontal <= -sidebarCloseMinTranslation ||
            predictedHorizontal <= -sidebarCloseMinTranslation * 1.3
        let isMostlyHorizontal = abs(horizontal) > vertical + sidebarCloseHorizontalBias
        
        return hasEnoughLeftDistance && isMostlyHorizontal
    }

    private func triggerSidebarHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func activeNotesCount(for section: NoteSection) -> Int {
        guard let userId = authService.currentUserId else { return 0 }
        return activeNotes.filter { note in
            note.userId == userId && note.section == section
        }.count
    }
    
    private func handleRootDrop(items: [String]) -> Bool {
        guard let droppedIdString = items.first,
              let droppedId = UUID(uuidString: droppedIdString) else {
            return false
        }
        
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedId })
        let droppedTag: Tag
        do {
            guard let fetched = try modelContext.fetch(fetchDescriptor).first else { return false }
            droppedTag = fetched
        } catch {
            sidebarLogger.error("Failed to fetch dropped root tag: \(error.localizedDescription, privacy: .public)")
            return false
        }
        
        // Only proceed if tag is not already root
        if droppedTag.parent == nil { return false }
        
        let now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
                oldParent.updatedAt = now
            }
            droppedTag.parent = nil
            droppedTag.updatedAt = now
        }
        return saveSidebarChangesAndSync(reason: "moving tag to root")
    }

    private func saveSidebarChangesAndSync(reason: String) -> Bool {
        do {
            try modelContext.save()
        } catch {
            sidebarLogger.error("Failed to save sidebar changes while \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        Task {
            await syncManager.syncNow(context: modelContext)
        }
        return true
    }

    private var membershipEntry: some View {
        Button {
            isPresented = false
            showSubscription = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(storeService.currentTier == .pro ? L10n.text("sidebar.membership.pro") : L10n.text("sidebar.membership.free_plan"))
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(storeService.currentTier == .pro ? .white : .textMain.opacity(0.9))

                    // Credit balance display for free users.
                    if storeService.currentTier == .free {
                        sidebarCreditBalanceLabel
                    }
                }

                if storeService.currentTier != .pro {
                    Text(L10n.text("sidebar.membership.upgrade"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentPrimary))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, storeService.currentTier == .pro ? 14 : 6)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    storeService.currentTier == .pro ? Color.accentPrimary : Color.textMain.opacity(0.04)
                )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sidebarCreditBalanceLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: storeService.creditBalance == 0 ? "lock.fill" : "bolt.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(sidebarCreditBalanceColor)
            Text(storeService.creditBalance == 0
                ? L10n.text("sidebar.credits.locked")
                : L10n.text("sidebar.credits.remaining", Int64(storeService.creditBalance)))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(sidebarCreditBalanceColor)
        }
    }

    private var sidebarCreditBalanceColor: Color {
        let balance = storeService.creditBalance
        if balance == 0 { return .red }
        if balance <= 10 { return .orange }
        return .green
    }
}

// MARK: - Sidebar Stats

private struct SidebarSectionStat: Identifiable {
    let section: NoteSection
    let count: Int

    var id: NoteSection { section }
}

private struct SidebarStatsView: View {
    let stats: [SidebarSectionStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(stats) { stat in
                    SidebarStatTile(stat: stat)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.textMain.opacity(0.035))
        )
        .accessibilityElement(children: .contain)
    }
}

private struct SidebarStatTile: View {
    let stat: SidebarSectionStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: stat.section.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .frame(width: 18, height: 18, alignment: .leading)

            Text("\(stat.count)")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(verbatim: stat.section.title)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundColor(.textSub.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgSecondary.opacity(0.72))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("sidebar.stats.accessibility.item", stat.section.title, stat.count))
    }
}

// MARK: - Tag Tree Item View

struct TagTreeItemView: View {
    @EnvironmentObject private var syncManager: SyncManager
    let tag: Tag
    @Binding var selectedTag: Tag?
    @Binding var selectedSection: NoteSection?
    @Binding var isTrashSelected: Bool
    @Binding var isPresented: Bool
    let modelContext: ModelContext
    let depth: Int
    
    @State private var isExpanded: Bool = true
    @State private var isDropTargeted: Bool = false
    
    private var hasChildren: Bool {
        !tag.sortedChildren.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Indentation
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth * 18))
                }

                // Selection/State Indicator (Minimalist dot instead of #)
                ZStack {
                    if hasChildren {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(tag.color.opacity(0.6))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        ZStack {
                            Circle()
                                .fill(tag.color.opacity(0.28))
                                .frame(width: 10, height: 10)
                            Circle()
                                .fill(tag.color.opacity(0.92))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .frame(width: 12)

                Button {
                    selectedTag = tag
                    selectedSection = nil
                    isTrashSelected = false
                    isPresented = false
                } label: {
                    HStack(spacing: 0) {
                        Text(tag.name)
                            .font(.system(size: 15, weight: selectedTag?.id == tag.id ? .semibold : .medium, design: .serif))
                            .foregroundColor(selectedTag?.id == tag.id ? .textMain : .textMain.opacity(0.7))
                            .lineLimit(1)

                        Spacer()

                        if selectedTag?.id == tag.id {
                            Circle()
                                .fill(Color.accentPrimary)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTag?.id == tag.id ? Color.textMain.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
            // Drag and Drop
            .draggable(tag.id.uuidString) {
                Text(tag.name)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.bgSecondary)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let droppedIdString = items.first,
                      let droppedId = UUID(uuidString: droppedIdString) else {
                    return false
                }
                return handleDrop(droppedTagId: droppedId, onto: tag)
            } isTargeted: { targeted in
                withAnimation(.spring(response: 0.2)) {
                    isDropTargeted = targeted
                }
            }
            .overlay(
                // Drop indicator border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentPrimary.opacity(0.5), lineWidth: isDropTargeted ? 2 : 0)
            )
            
            // Children
            if isExpanded && hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tag.sortedChildren) { child in
                        TagTreeItemView(
                            tag: child,
                            selectedTag: $selectedTag,
                            selectedSection: $selectedSection,
                            isTrashSelected: $isTrashSelected,
                            isPresented: $isPresented,
                            modelContext: modelContext,
                            depth: depth + 1
                        )
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private func moveToRoot() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let parent = tag.parent {
                let now = Date()
                parent.children.removeAll { $0.id == tag.id }
                parent.updatedAt = now
                tag.parent = nil
                tag.updatedAt = now
            }
        }
        _ = saveTagRowChangesAndSync(reason: "moving tag row to root")
    }
    
    private func deleteTag() {
        withAnimation {
            // Remove the tag from any associated notes to avoid syncing stale relations
            for note in tag.notes {
                note.tags.removeAll { $0.id == tag.id }
                note.updatedAt = Date()
            }
            tag.deletedAt = Date()
            tag.updatedAt = tag.deletedAt ?? Date()
        }
        _ = saveTagRowChangesAndSync(reason: "deleting tag row")
    }

    private func handleDrop(droppedTagId: UUID, onto targetTag: Tag) -> Bool {
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedTagId })
        let droppedTag: Tag
        do {
            guard let fetched = try modelContext.fetch(fetchDescriptor).first else { return false }
            droppedTag = fetched
        } catch {
            sidebarLogger.error("Failed to fetch dropped child tag: \(error.localizedDescription, privacy: .public)")
            return false
        }
        
        guard droppedTag.id != targetTag.id else { return false }
        guard !droppedTag.isAncestor(of: targetTag) else { return false }
        
        let now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
                oldParent.updatedAt = now
            }
            droppedTag.parent = targetTag
            if !targetTag.children.contains(where: { $0.id == droppedTag.id }) {
                targetTag.children.append(droppedTag)
            }
            droppedTag.updatedAt = now
            targetTag.updatedAt = now
        }
        return saveTagRowChangesAndSync(reason: "moving tag under another tag")
    }

    private func saveTagRowChangesAndSync(reason: String) -> Bool {
        do {
            try modelContext.save()
        } catch {
            sidebarLogger.error("Failed to save tag row changes while \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        Task {
            await syncManager.syncNow(context: modelContext)
        }
        return true
    }
}

// MARK: - Root Drop Zone (Improved)

struct RootDropZone: View {
    @EnvironmentObject private var syncManager: SyncManager
    let modelContext: ModelContext
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        HStack {
            Text(L10n.text("sidebar.tags.title"))
                .font(.system(size: 11, weight: .black, design: .serif))
                .foregroundColor(.textSub.opacity(0.4))
                .tracking(1.2)
            
            Spacer()
            
            if isDropTargeted {
                Text(L10n.text("sidebar.tags.release_to_unnest"))
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(.accentPrimary)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentPrimary.opacity(0.1) : Color.clear)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let droppedIdString = items.first,
                  let droppedId = UUID(uuidString: droppedIdString) else {
                return false
            }
            return handleDropToRoot(droppedTagId: droppedId)
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.2)) {
                isDropTargeted = targeted
            }
        }
    }
    
    private func handleDropToRoot(droppedTagId: UUID) -> Bool {
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedTagId })
        let droppedTag: Tag
        do {
            guard let fetched = try modelContext.fetch(fetchDescriptor).first else { return false }
            droppedTag = fetched
        } catch {
            sidebarLogger.error("Failed to fetch tag dropped to root zone: \(error.localizedDescription, privacy: .public)")
            return false
        }
        
        if droppedTag.parent == nil { return false }
        
        let now = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
                oldParent.updatedAt = now
            }
            droppedTag.parent = nil
            droppedTag.updatedAt = now
        }
        return saveRootDropChangesAndSync(reason: "dropping tag to root")
    }

    private func saveRootDropChangesAndSync(reason: String) -> Bool {
        do {
            try modelContext.save()
        } catch {
            sidebarLogger.error("Failed to save root drop changes while \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        Task {
            await syncManager.syncNow(context: modelContext)
        }
        return true
    }
}

// MARK: - Trash Drop Zone

struct TrashDropZone: View {
    @EnvironmentObject private var syncManager: SyncManager
    let modelContext: ModelContext
    @State private var isTargeted: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isTargeted ? "trash.fill" : "trash")
                .font(.system(size: 16))
            
            Text(isTargeted ? L10n.text("sidebar.trash.release_to_delete") : L10n.text("sidebar.trash.drag_to_delete"))
                .font(.system(size: 14, weight: isTargeted ? .bold : .medium, design: .serif))
        }
        .foregroundColor(isTargeted ? .red : .textMain.opacity(0.4))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.red.opacity(0.08) : Color.clear)
                .strokeBorder(isTargeted ? Color.red.opacity(0.3) : Color.textMain.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .dropDestination(for: String.self) { items, location in
            guard let droppedIdString = items.first,
                  let droppedId = UUID(uuidString: droppedIdString) else {
                return false
            }
            return handleDeleteDrop(droppedTagId: droppedId)
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.2)) {
                isTargeted = targeted
            }
        }
    }
    
    private func handleDeleteDrop(droppedTagId: UUID) -> Bool {
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedTagId })
        let droppedTag: Tag
        do {
            guard let fetched = try modelContext.fetch(fetchDescriptor).first else { return false }
            droppedTag = fetched
        } catch {
            sidebarLogger.error("Failed to fetch tag dropped to trash: \(error.localizedDescription, privacy: .public)")
            return false
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove from parent if needed (SwiftData usually handles relationship cleanup, but manual is safer for tree UI)
            if let parent = droppedTag.parent {
                parent.children.removeAll { $0.id == droppedTag.id }
            }
            for note in droppedTag.notes {
                note.tags.removeAll { $0.id == droppedTag.id }
                note.updatedAt = Date()
            }
            droppedTag.deletedAt = Date()
            droppedTag.updatedAt = droppedTag.deletedAt ?? Date()
        }
        guard saveTrashDropChangesAndSync(reason: "dropping tag to trash") else { return false }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        return true
    }

    private func saveTrashDropChangesAndSync(reason: String) -> Bool {
        do {
            try modelContext.save()
        } catch {
            sidebarLogger.error("Failed to save trash drop changes while \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        Task {
            await syncManager.syncNow(context: modelContext)
        }
        return true
    }
}

// MARK: - Sidebar Item (Cleaned Up)

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var badgeCount: Int = 0
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentPrimary : .textMain.opacity(0.6))
                    .frame(width: 20)
                
                Text(verbatim: title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium, design: .serif))
                    .foregroundColor(isSelected ? .textMain : .textMain.opacity(0.8)) // increased opacity slightly for serif readability
                
                Spacer()
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
