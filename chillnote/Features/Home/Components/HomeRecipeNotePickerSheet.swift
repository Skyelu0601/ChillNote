import SwiftUI

struct HomeRecipeNotePickerSheet: View {
    let recipe: AgentRecipe
    let notes: [Note]
    @Binding var selectedNoteIDs: Set<UUID>
    let onRun: () -> Void
    let onCancel: () -> Void

    private var canRun: Bool {
        !selectedNoteIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if notes.isEmpty {
                    VStack(spacing: 12) {
                        CreatorSkillIcon(recipe: recipe, size: 22, container: 48)

                        Text(L10n.text("home.recipe_picker.empty.title"))
                            .font(.headline)
                            .foregroundColor(.textMain)

                        Text(L10n.text("home.recipe_picker.empty.message"))
                            .font(.body)
                            .foregroundColor(.textSub)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(notes) { note in
                                Button {
                                    toggle(note)
                                } label: {
                                    HomeRecipeNotePickerRow(
                                        note: note,
                                        isSelected: selectedNoteIDs.contains(note.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(L10n.text("home.recipe_picker.choose_notes"))
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Button(action: onRun) {
                    Text(L10n.text("home.recipe_picker.generate", recipe.localizedName))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canRun ? Color.accentSecondary : Color.textSub.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(!canRun)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.bgSecondary)
            }
            .navigationTitle(L10n.text("home.recipe_picker.title", recipe.localizedName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel"), action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func toggle(_ note: Note) {
        selectedNoteIDs = [note.id]
    }
}

private struct HomeRecipeNotePickerRow: View {
    let note: Note
    let isSelected: Bool

    private var previewText: String {
        let trimmed = note.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L10n.text("home.recipe_picker.untitled_note")
        }
        return trimmed
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(isSelected ? .accentPrimary : .textSub.opacity(0.42))

            VStack(alignment: .leading, spacing: 5) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.textSub)

                Text(previewText)
                    .font(.body)
                    .foregroundColor(.textMain)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
