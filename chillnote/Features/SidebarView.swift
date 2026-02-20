import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @Query(filter: #Predicate<Tag> { $0.deletedAt == nil }, sort: \Tag.name) private var _allTags: [Tag]
    
    @Binding var isPresented: Bool
    @Binding var selectedTag: Tag?
    @Binding var isTrashSelected: Bool
    var hasPendingRecordings: Bool = false
    var pendingRecordingsCount: Int = 0
    var onSettingsTap: (() -> Void)?
    var onPendingRecordingsTap: (() -> Void)?
    
    // Filter tags by current user
    private var allTags: [Tag] {
        guard let userId = authService.currentUserId else { return [] }
        return _allTags.filter { $0.userId == userId }
    }
    
    /// Root-level tags (those without a parent)
    private var rootTags: [Tag] {
        allTags.filter { $0.isRoot }.sorted { $0.sortOrder < $1.sortOrder }
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
                VStack(alignment: .leading, spacing: 32) { // 增加间距
                    // Header - Minimalist
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 8, height: 8)
                        Text("ChillNote")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                            .tracking(0.5)
                        
                        Spacer()
                        
                        // Settings Button (Moved from Home)
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
                        .accessibilityLabel("Open Settings")
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 28)
                    
                    // Main Navigation
                    VStack(spacing: 6) {
                        SidebarItem(icon: "house", title: "All Notes", isSelected: selectedTag == nil && !isTrashSelected) {
                            selectedTag = nil
                            isTrashSelected = false
                            isPresented = false
                        }
                        SidebarItem(icon: "trash", title: "Recycle Bin", isSelected: isTrashSelected) {
                            selectedTag = nil
                            isTrashSelected = true
                            isPresented = false
                        }

                        if pendingRecordingsCount > 0 {
                            SidebarItem(
                                icon: "waveform",
                                title: "Pending Records",
                                isSelected: false,
                                badgeCount: pendingRecordingsCount
                            ) {
                                isPresented = false
                                onPendingRecordingsTap?()
                            }
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
                                            isTrashSelected: $isTrashSelected,
                                            isPresented: $isPresented,
                                            modelContext: modelContext,
                                            depth: 0
                                        )
                                }
                                
                                if allTags.isEmpty {
                                    Text("Start organizing with tags")
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
                .frame(width: 290)
                .background(Color.bgSecondary) // 纯净背景
                .offset(x: isPresented ? 0 : -290)
                
                Spacer()
            }
        }
        .ignoresSafeArea(.all, edges: .vertical)
        .zIndex(1000)
    }
    
    // MARK: - Helper Methods
    
    private func handleRootDrop(items: [String]) -> Bool {
        guard let droppedIdString = items.first,
              let droppedId = UUID(uuidString: droppedIdString) else {
            return false
        }
        
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedId })
        guard let droppedTag = try? modelContext.fetch(fetchDescriptor).first else { return false }
        
        // Only proceed if tag is not already root
        if droppedTag.parent == nil { return false }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
            }
            droppedTag.parent = nil
            droppedTag.updatedAt = Date()
            try? modelContext.save()
        }
        return true
    }
}

// MARK: - Tag Tree Item View

struct TagTreeItemView: View {
    let tag: Tag
    @Binding var selectedTag: Tag?
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
            Button {
                selectedTag = tag
                isTrashSelected = false
                isPresented = false
            } label: {
                HStack(spacing: 12) {
                    // Indentation
                    if depth > 0 {
                        Spacer().frame(width: CGFloat(depth * 18))
                    }
                    
                    // Selection/State Indicator (Minimalist dot instead of #)
                    ZStack {
                        if hasChildren {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(tag.color.opacity(0.6))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isExpanded.toggle()
                                    }
                                }
                        } else {
                            Circle()
                                .fill(tag.color.opacity(0.4))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(width: 12)
                    
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
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTag?.id == tag.id ? Color.textMain.opacity(0.04) : Color.clear)
                )
            }
            .buttonStyle(.plain)
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
                parent.children.removeAll { $0.id == tag.id }
                tag.parent = nil
                tag.updatedAt = Date()
                try? modelContext.save()
            }
        }
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
            try? modelContext.save()
        }
    }

    private func handleDrop(droppedTagId: UUID, onto targetTag: Tag) -> Bool {
        let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == droppedTagId })
        guard let droppedTag = try? modelContext.fetch(fetchDescriptor).first else { return false }
        
        guard droppedTag.id != targetTag.id else { return false }
        guard !droppedTag.isAncestor(of: targetTag) else { return false }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
            }
            droppedTag.parent = targetTag
            if !targetTag.children.contains(where: { $0.id == droppedTag.id }) {
                targetTag.children.append(droppedTag)
            }
            let now = Date()
            droppedTag.updatedAt = now
            targetTag.updatedAt = now
            try? modelContext.save()
        }
        return true
    }
}

// MARK: - Root Drop Zone (Improved)

struct RootDropZone: View {
    let modelContext: ModelContext
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        HStack {
            Text("TAGS")
                .font(.system(size: 11, weight: .black, design: .serif))
                .foregroundColor(.textSub.opacity(0.4))
                .tracking(1.2)
            
            Spacer()
            
            if isDropTargeted {
                Text("Release to unnest")
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
        guard let droppedTag = try? modelContext.fetch(fetchDescriptor).first else { return false }
        
        if droppedTag.parent == nil { return false }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let oldParent = droppedTag.parent {
                oldParent.children.removeAll { $0.id == droppedTag.id }
            }
            droppedTag.parent = nil
            droppedTag.updatedAt = Date()
            try? modelContext.save()
        }
        return true
    }
}

// MARK: - Trash Drop Zone

struct TrashDropZone: View {
    let modelContext: ModelContext
    @State private var isTargeted: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isTargeted ? "trash.fill" : "trash")
                .font(.system(size: 16))
            
            Text(isTargeted ? "Release to delete" : "Drag here to delete")
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
        guard let droppedTag = try? modelContext.fetch(fetchDescriptor).first else { return false }
        
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
            try? modelContext.save()
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        return true
    }
}

// MARK: - Sidebar Item (Cleaned Up)

struct SidebarItem: View {
    let icon: String
    let title: LocalizedStringKey
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
                
                Text(title)
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
