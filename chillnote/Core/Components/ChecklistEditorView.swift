import SwiftUI
import SwiftData

struct ChecklistEditorView: View {
    @Bindable var note: Note
    var isDisabled: Bool
    var isPersistenceSuspended: Bool = false

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    
    // Focus state for managing cursor position
    @FocusState private var focusedItemID: UUID?

    @State private var editMode: EditMode = .inactive
    @State private var persistTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Optional "Notes" section above the checklist
            // Kept simple and clean as requested
            if !note.checklistNotes.isEmpty || editMode == .active {
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $note.checklistNotes)
                        .font(.bodyLarge)
                        .scrollContentBackground(.hidden) // Transparent background
                        .frame(minHeight: 40)
                        .fixedSize(horizontal: false, vertical: true) // Auto-grow height
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .overlay(alignment: .leading) {
                            if note.checklistNotes.isEmpty {
                                Text("Introductory notes...")
                                    .foregroundColor(.textSub.opacity(0.5))
                                    .padding(.horizontal, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                        .disabled(isDisabled)
                        .onChange(of: note.checklistNotes) { _, _ in
                            schedulePersist()
                        }
                }
                .padding(.bottom, 4)
            }

            // The main checklist
            List {
                ForEach(sortedItems) { item in
                    ChecklistRow(
                        item: item,
                        isDisabled: isDisabled,
                        focusedItemID: $focusedItemID,
                        onToggle: {
                            toggleDone(item)
                        },
                        onTextChanged: {
                            schedulePersist()
                        },
                        onSubmit: {
                            addItem(after: item)
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) // Removes default list background
            .environment(\.editMode, $editMode)
            .disabled(isDisabled)
            // Tap background to add item if list is empty or at end?
            // For now, rely on existing items or initial empty item.
        }
        .onDisappear {
            persistTask?.cancel()
            persistNow()
        }
    }

    private var sortedItems: [ChecklistItem] {
        note.checklistItems.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private func toggleDone(_ item: ChecklistItem) {
        withAnimation(.snappy) {
            item.isDone.toggle()
            item.updatedAt = Date()
        }
        persistNow()
    }
    
    private func addItem(after item: ChecklistItem) {
        let sorted = sortedItems
        guard let index = sorted.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Insert new item after the current one
        let newItem = ChecklistItem(text: "", isDone: false, sortOrder: 0, note: note)
        modelContext.insert(newItem)
        note.checklistItems.append(newItem)
        
        // Re-normalize order
        var newSorted = sorted
        newSorted.insert(newItem, at: index + 1)
        
        for (i, it) in newSorted.enumerated() {
            it.sortOrder = i
        }
        
        persistNow()
        
        // Focus the new item
        // Introduce a small delay to ensure the row exists in the List
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedItemID = newItem.id
        }
    }

    // Keep the "Add Task" for empty state or manual add if needed, 
    // but user requested removing the dedicated button area.
    // We can rely on NoteDetailView creating the initial item.
    // If the list is completely empty, we might want to show a placeholder or auto-add one.
    private func ensureOneItem() {
        if note.checklistItems.isEmpty {
             addItem()
        }
    }

    private func addItem() {
        let nextOrder = (note.checklistItems.map(\.sortOrder).max() ?? -1) + 1
        let item = ChecklistItem(text: "", isDone: false, sortOrder: nextOrder, note: note)
        modelContext.insert(item)
        note.checklistItems.append(item)
        persistNow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedItemID = item.id
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = sortedItems
        for index in offsets {
            let item = items[index]
            modelContext.delete(item)
            note.checklistItems.removeAll(where: { $0.id == item.id })
        }
        normalizeSortOrder()
        persistNow()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
            item.updatedAt = Date()
        }
        persistNow()
    }

    private func normalizeSortOrder() {
        for (index, item) in sortedItems.enumerated() {
            if item.sortOrder != index {
                item.sortOrder = index
                item.updatedAt = Date()
            }
        }
    }

    private func schedulePersist() {
        guard note.isChecklist, !isDisabled, !isPersistenceSuspended else { return }
        persistTask?.cancel()
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                persistNow()
            }
        }
    }

    private func persistNow() {
        guard note.isChecklist, !isDisabled, !isPersistenceSuspended else { return }
        note.rebuildContentFromChecklist()
        note.updatedAt = Date()
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }
}

private struct ChecklistRow: View {
    @Bindable var item: ChecklistItem
    var isDisabled: Bool
    var focusedItemID: FocusState<UUID?>.Binding
    
    let onToggle: () -> Void
    let onTextChanged: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(item.isDone ? .accentPrimary : .textSub.opacity(0.4))
                    .contentShape(Rectangle())
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .padding(.leading, -8) // Adjust for the horizontal padding to keep alignment

            TextField("To-do", text: $item.text, axis: .vertical)
                .font(.bodyLarge)
                .foregroundColor(item.isDone ? .textSub : .textMain) // Dim text if done
                .strikethrough(item.isDone, color: .textSub.opacity(0.6))
                .lineLimit(1...10)
                .fixedSize(horizontal: false, vertical: true)
                .disabled(isDisabled)
                .focused(focusedItemID, equals: item.id)
                .submitLabel(.return)
                .onSubmit(onSubmit)
                .padding(.vertical, 10) // Align text with checkbox vertical padding
                .onChange(of: item.text) { _, _ in
                    item.updatedAt = Date()
                    onTextChanged()
                }
        }
        .contentShape(Rectangle()) // Hit testing
    }
}
