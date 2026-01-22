import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @Binding var isPresented: Bool
    @Binding var selectedTag: Tag?
    
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
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                            .tracking(0.5)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 28)
                    
                    // Main Navigation
                    VStack(spacing: 6) {
                        SidebarItem(icon: "house", title: "All Notes", isSelected: selectedTag == nil) {
                            selectedTag = nil
                            isPresented = false
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
                                        isPresented: $isPresented,
                                        modelContext: modelContext,
                                        depth: 0
                                    )
                                }
                                
                                if allTags.isEmpty {
                                    Text("Start organizing with tags")
                                        .font(.system(size: 13))
                                        .foregroundColor(.textSub.opacity(0.6))
                                        .padding(.top, 40)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
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
}

// MARK: - Tag Tree Item View

struct TagTreeItemView: View {
    let tag: Tag
    @Binding var selectedTag: Tag?
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
                        .font(.system(size: 15, weight: selectedTag?.id == tag.id ? .semibold : .medium))
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
                    .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.textSub.opacity(0.4))
                .tracking(1.2)
            
            Spacer()
            
            if isDropTargeted {
                Text("Release to unnest")
                    .font(.system(size: 10, weight: .bold))
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
            try? modelContext.save()
        }
        return true
    }
}

// MARK: - Sidebar Item (Cleaned Up)

struct SidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentPrimary : .textMain.opacity(0.6))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .textMain : .textMain.opacity(0.7))
                
                Spacer()
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
