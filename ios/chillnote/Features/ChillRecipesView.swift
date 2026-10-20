import SwiftUI

struct ChillRecipesView: View {
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var storeService = StoreService.shared
    @State private var showingCreateRecipe = false
    @State private var showingSubscription = false
    @State private var showingCaptionPackSettings = false
    @State private var showingRepurposePackSettings = false
    @State private var showingTranslateSettings = false
    @State private var showingBrandVoiceSettings = false
    @State private var showingMinimumFavoriteAlert = false
    @State private var pendingReplacement: AgentRecipe?
    @State private var pendingDeleteRecipe: AgentRecipe?

    @State private var newRecipeName = ""
    @State private var newRecipePrompt = ""
    @State private var newRecipeIcon = "sparkles"

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(L10n.text("recipes.favorites.help"))
                        .font(.footnote).foregroundStyle(Color.textSub)
                    if !installedRecipes.isEmpty {
                        SkillSection(
                            title: L10n.text("recipes.section.installed"),
                            recipes: installedRecipes,
                            isInstalled: true,
                            configureAction: configureAction,
                            configureLabel: configureLabel,
                            onToggle: toggleRecipe,
                            onDelete: { pendingDeleteRecipe = $0 }
                        )
                    }

                    if !availableRecipes.isEmpty {
                        SkillSection(
                            title: L10n.text("recipes.section.available"),
                            recipes: availableRecipes,
                            isInstalled: false,
                            configureAction: configureAction,
                            configureLabel: configureLabel,
                            onToggle: toggleRecipe,
                            onDelete: { pendingDeleteRecipe = $0 }
                        )
                    }

                    CreateCustomSkillRow(action: showCreateRecipe)
                        .accessibilityIdentifier("skills-create-custom")
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(L10n.text("recipes.action.manage"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.text("recipes.favorites.replace"), isPresented: Binding(
            get: { pendingReplacement != nil },
            set: { if !$0 { pendingReplacement = nil } }
        ), titleVisibility: .visible) {
            ForEach(recipeManager.favoriteRecipes) { favorite in
                Button(favorite.localizedName) {
                    if let recipe = pendingReplacement { recipeManager.replaceFavorite(favorite, with: recipe) }
                    pendingReplacement = nil
                }
            }
            Button(L10n.text("common.cancel"), role: .cancel) { pendingReplacement = nil }
        }
        .sheet(isPresented: $showingCreateRecipe) {
            CreateRecipeSheet(
                name: $newRecipeName,
                prompt: $newRecipePrompt,
                icon: $newRecipeIcon,
                onSave: saveCustomRecipe,
                onCancel: {
                    resetCreateRecipe()
                    showingCreateRecipe = false
                }
            )
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingCaptionPackSettings) {
            CaptionPackSettingsSheet()
        }
        .sheet(isPresented: $showingRepurposePackSettings) {
            RepurposePackSettingsSheet()
        }
        .sheet(isPresented: $showingTranslateSettings) {
            TranslateSettingsSheet()
        }
        .sheet(isPresented: $showingBrandVoiceSettings) {
            BrandVoiceSettingsSheet()
        }
        .alert(L10n.text("recipes.favorites.minimum"), isPresented: $showingMinimumFavoriteAlert) {
            Button(L10n.text("common.ok"), role: .cancel) {}
        }
        .alert(L10n.text("recipes.alert.delete_skill.title"), isPresented: Binding(
            get: { pendingDeleteRecipe != nil },
            set: { isPresented in if !isPresented { pendingDeleteRecipe = nil } }
        )) {
            Button(L10n.text("common.cancel"), role: .cancel) { pendingDeleteRecipe = nil }
            Button(L10n.text("common.delete"), role: .destructive) {
                if let recipe = pendingDeleteRecipe {
                    withAnimation { recipeManager.deleteCustomRecipe(recipe) }
                }
                pendingDeleteRecipe = nil
            }
        } message: {
            Text(L10n.text("recipes.alert.delete_skill.message"))
        }
    }

    private func showCreateRecipe() {
        Task {
            await storeService.ensureSubscriptionStatusReadyForFeatureGate()
            if storeService.currentTier == .free {
                showingSubscription = true
            } else {
                showingCreateRecipe = true
            }
        }
    }

    private func toggleRecipe(_ recipe: AgentRecipe) {
        if recipeManager.isAdded(recipe) && recipeManager.favoriteRecipes.count <= 1 {
            showingMinimumFavoriteAlert = true
        } else if !recipeManager.isAdded(recipe) && recipeManager.favoriteRecipes.count >= 4 {
            pendingReplacement = recipe
        } else {
            withAnimation { recipeManager.toggleRecipe(recipe) }
        }
    }

    private func configureAction(for recipe: AgentRecipe) -> (() -> Void)? {
        switch recipe.id {
        case "translate": return { showingTranslateSettings = true }
        case "caption_pack": return { showingCaptionPackSettings = true }
        case "repurpose_pack": return { showingRepurposePackSettings = true }
        case "style_match": return { showingBrandVoiceSettings = true }
        default: return nil
        }
    }

    private func configureLabel(for recipe: AgentRecipe) -> String {
        switch recipe.id {
        case "translate": return L10n.text("translate.settings.title")
        case "caption_pack": return L10n.text("caption_pack.settings.title")
        case "repurpose_pack": return L10n.text("repurpose_pack.settings.title")
        case "style_match": return L10n.text("brand_voice.settings.title")
        default: return L10n.text("caption_pack.settings.title")
        }
    }

    private var installedRecipes: [AgentRecipe] {
        recipeManager.favoriteRecipes
    }

    private var availableRecipes: [AgentRecipe] {
        recipeManager.savedRecipes.filter { !recipeManager.isAdded($0) }
    }

    private func saveCustomRecipe() {
        let trimmedName = newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = newRecipePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }
        _ = recipeManager.addCustomRecipe(
            name: trimmedName,
            systemIcon: newRecipeIcon,
            prompt: trimmedPrompt
        )
        resetCreateRecipe()
        showingCreateRecipe = false
    }

    private func resetCreateRecipe() {
        newRecipeName = ""
        newRecipePrompt = ""
        newRecipeIcon = "sparkles"
    }
}

struct CreatorSkillsManagementSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ChillRecipesView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("common.close")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Subviews

private struct SkillSection: View {
    let title: String
    let recipes: [AgentRecipe]
    let isInstalled: Bool
    let configureAction: (AgentRecipe) -> (() -> Void)?
    let configureLabel: (AgentRecipe) -> String
    let onToggle: (AgentRecipe) -> Void
    let onDelete: (AgentRecipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSub)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    SkillManagementRow(
                        recipe: recipe,
                        isInstalled: isInstalled,
                        onConfigure: configureAction(recipe),
                        configureLabel: configureLabel(recipe),
                        onToggle: { onToggle(recipe) },
                        onDelete: recipe.isCustom ? { onDelete(recipe) } : nil
                    )

                    if index < recipes.count - 1 {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.shadowColor.opacity(0.45), radius: 10, x: 0, y: 4)
        }
    }
}

private struct SkillManagementRow: View {
    let recipe: AgentRecipe
    let isInstalled: Bool
    let onConfigure: (() -> Void)?
    let configureLabel: String
    let onToggle: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            skillLabel

            if let onConfigure {
                Button(action: onConfigure) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.textSub)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(configureLabel)
                .accessibilityIdentifier("skills-configure-\(recipe.id)")
            }

            Group {
                Button(action: onToggle) {
                    Image(systemName: isInstalled ? "star.fill" : "star")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(isInstalled ? Color.brandBlue : Color.textSub)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(isInstalled ? "recipes.action.remove" : "recipes.action.add"))
                .accessibilityIdentifier("skills-\(isInstalled ? "remove" : "add")-\(recipe.id)")
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text("home.notes.action.delete_permanently"))
                    .accessibilityIdentifier("skills-delete-\(recipe.id)")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var skillLabel: some View {
        HStack(spacing: 12) {
            CreatorSkillIcon(recipe: recipe, size: 18, container: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textMain)
                    .fixedSize(horizontal: false, vertical: true)
                Text(recipe.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.textSub)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct CreateCustomSkillRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(CreatorSkillPalette.customCreationTint.opacity(0.11))
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(CreatorSkillPalette.customCreationTint)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L10n.text("recipes.custom.create.title"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textMain)
                            .lineLimit(1)

                        Text(L10n.text("recipes.custom.create.badge"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(CreatorSkillPalette.customCreationTint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CreatorSkillPalette.customCreationTint.opacity(0.11))
                            .clipShape(Capsule())
                    }

                    Text(L10n.text("recipes.custom.create.subtitle"))
                        .font(.system(size: 13))
                        .foregroundColor(.textSub)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(CreatorSkillPalette.customCreationTint)
            }
            .frame(minHeight: 64)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.shadowColor.opacity(0.45), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// Shared, open layout for skill defaults. Copy and preference storage stay in each screen.
private struct SkillConfigurationPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let symbol: String
    var confirmationTitle: String? = nil
    var confirmationEnabled = true
    var onConfirm: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: symbol)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color.brandTealText)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.textMain)
                            .accessibilityAddTraits(.isHeader)
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("common.cancel"), action: onCancel)
                            .tint(Color.textSub)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle ?? L10n.text("common.done")) {
                        if let onConfirm { onConfirm() } else { dismiss() }
                    }
                    .font(.body.weight(.semibold))
                    .tint(Color.accentPrimaryText)
                    .disabled(!confirmationEnabled)
                }
            }
        }
    }
}

private struct SkillConfigurationSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.textMain)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content }
        }
    }
}

private struct SkillSelectionToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 16) {
                configuration.label
                    .foregroundStyle(Color.textMain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(configuration.isOn ? Color.accentPrimary : Color.textSub)
                    .accessibilityHidden(true)
            }
            .font(.body)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

private struct SkillPlatformLabel: View {
    let title: String
    var asset: String? = nil
    var symbol: String = "text.alignleft"

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let asset {
                    Image(asset).resizable().scaledToFit()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                }
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
            Text(title)
        }
    }
}

private struct SkillSettingsDivider: View {
    var body: some View {
        Rectangle().fill(Color.separator).frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct TranslateSettingsSheet: View {
    @AppStorage(TranslatePreferences.targetLanguageKey) private var languageID = "en"

    var body: some View {
        SkillConfigurationPage(title: L10n.text("translate.settings.title"), symbol: "globe") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    SkillSettingsDivider()
                    ForEach(TranslateLanguage.defaultLanguages) { language in
                        Button {
                            languageID = language.id
                        } label: {
                            HStack(spacing: 16) {
                                Text(verbatim: language.displayName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if TranslatePreferences.language(for: languageID).id == language.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentPrimary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .font(.body)
                            .foregroundStyle(Color.textMain)
                            .frame(minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(TranslatePreferences.language(for: languageID).id == language.id ? [.isSelected] : [])
                        SkillSettingsDivider()
                    }
                }
                .accessibilityIdentifier("translate-default-language")
                Text(L10n.text("translate.settings.help"))
                    .font(.footnote)
                    .foregroundStyle(Color.textSub)
            }
        }
    }
}

private struct CaptionPackSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CaptionPackPreferences.tiktokKey) private var includeTikTok = true
    @AppStorage(CaptionPackPreferences.instagramReelsKey) private var includeInstagramReels = true
    @AppStorage(CaptionPackPreferences.youtubeShortsKey) private var includeYouTubeShorts = true
    @AppStorage(CaptionPackPreferences.youtubeLongVideoKey) private var includeYouTubeLongVideo = true
    @AppStorage(CaptionPackPreferences.goalKey) private var goalRawValue = CaptionPackGoal.startDiscussion.rawValue
    @AppStorage(CaptionPackPreferences.toneKey) private var toneRawValue = CaptionPackTone.casualUseful.rawValue
    @AppStorage(CaptionPackPreferences.outputStyleKey) private var outputStyleRawValue = CaptionPackOutputStyle.balanced.rawValue

    private var selectedPlatformCount: Int {
        [includeTikTok, includeInstagramReels, includeYouTubeShorts, includeYouTubeLongVideo].filter { $0 }.count
    }

    var body: some View {
        SkillConfigurationPage(title: L10n.text("caption_pack.settings.title"), symbol: "square.and.pencil") {
            SkillConfigurationSection(title: L10n.text("caption_pack.settings.platforms")) {
                platformRow("caption_pack.platform.tiktok", asset: "TikTokBrandLogo", binding: $includeTikTok)
                platformRow("caption_pack.platform.instagram_reels", asset: "InstagramBrandLogo", binding: $includeInstagramReels)
                platformRow("caption_pack.platform.youtube_shorts", asset: "YouTubeBrandLogo", binding: $includeYouTubeShorts)
                platformRow("caption_pack.platform.youtube_long_video", asset: "YouTubeBrandLogo", binding: $includeYouTubeLongVideo)
            }
            VStack(spacing: 0) {
                SkillSettingsDivider()
                HStack {
                    Text(L10n.text("caption_pack.settings.goal")).font(.headline)
                    Spacer(minLength: 12)
                    Picker(L10n.text("caption_pack.settings.goal"), selection: $goalRawValue) {
                        ForEach(CaptionPackGoal.allCases) { goal in
                            Text(goal.localizedTitle).tag(goal.rawValue)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).tint(Color.textSub)
                }
                .frame(minHeight: 64)
                SkillSettingsDivider()
                HStack {
                    Text(L10n.text("caption_pack.settings.tone")).font(.headline)
                    Spacer(minLength: 12)
                    Picker(L10n.text("caption_pack.settings.tone"), selection: Binding(
                        get: { CaptionPackTone.fromCaptionRawValue(toneRawValue).rawValue },
                        set: { toneRawValue = $0 }
                    )) {
                        ForEach(CaptionPackTone.captionOptions) { tone in
                            Text(tone.localizedTitle).tag(tone.rawValue)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).tint(Color.textSub)
                }
                .frame(minHeight: 64)
                SkillSettingsDivider()
            }
            .foregroundStyle(Color.textMain)
            SkillConfigurationSection(title: L10n.text("caption_pack.settings.output_style")) {
                Picker(L10n.text("caption_pack.settings.output_style"), selection: $outputStyleRawValue) {
                    ForEach(CaptionPackOutputStyle.allCases) { style in
                        Text(style.localizedTitle).tag(style.rawValue)
                    }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
        }
    }

    private func platformRow(_ key: String, asset: String, binding: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            Toggle(isOn: bindingForPlatform(binding)) {
                SkillPlatformLabel(title: L10n.text(key), asset: asset)
            }
            .toggleStyle(SkillSelectionToggleStyle())
            SkillSettingsDivider()
        }
    }

    private func bindingForPlatform(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                if !newValue && selectedPlatformCount <= 1 {
                    return
                }
                binding.wrappedValue = newValue
            }
        )
    }
}

private struct BrandVoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferences = BrandVoicePreferences.current
    @State private var editor: WritingExampleDraft?

    var body: some View {
        SkillConfigurationPage(title: L10n.text("brand_voice.settings.title"), symbol: "pencil.and.scribble") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    SkillSettingsDivider()
                    ForEach(preferences.samples.indices, id: \.self) { index in
                        Button {
                            editor = WritingExampleDraft(index: index, text: preferences.samples[index])
                        } label: {
                            HStack(spacing: 16) {
                                Text(L10n.text("brand_voice.settings.example_title", index + 1))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.textSub)
                                    .accessibilityHidden(true)
                            }
                            .font(.body)
                            .foregroundStyle(Color.textMain)
                            .frame(minHeight: 68)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SkillSettingsDivider()
                    }
                    Button {
                        editor = WritingExampleDraft(index: nil, text: "")
                    } label: {
                        Label(L10n.text("brand_voice.settings.add_example"), systemImage: "plus")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentPrimaryText)
                    SkillSettingsDivider()
                }
                Text(L10n.text("brand_voice.settings.examples_help"))
                    .font(.footnote)
                    .foregroundStyle(Color.textSub)
            }
        }
        .sheet(item: $editor) { draft in
            WritingExampleEditor(draft: draft) { text in
                if let index = draft.index {
                    preferences.samples[index] = text
                } else {
                    preferences.samples.append(text)
                }
                preferences.save()
            } onDelete: {
                if let index = draft.index {
                    preferences.samples.remove(at: index)
                    preferences.save()
                }
            }
        }
    }
}

private struct WritingExampleDraft: Identifiable {
    let id = UUID()
    let index: Int?
    var text: String
}

private struct WritingExampleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let draft: WritingExampleDraft
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @State private var text: String

    init(draft: WritingExampleDraft, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: draft.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .accessibilityIdentifier("brand-voice-example-text")
                        .frame(minHeight: 260)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(L10n.text("brand_voice.settings.paste_placeholder"))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8).padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                if draft.index != nil {
                    Button(L10n.text("common.delete"), role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle(draft.index.map { L10n.text("brand_voice.settings.example_title", $0 + 1) }
                ?? L10n.text("brand_voice.settings.add_example"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.save")) {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct RepurposePackSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferences = RepurposePackPreferences.current

    var body: some View {
        SkillConfigurationPage(title: L10n.text("repurpose_pack.settings.title"), symbol: "square.stack.3d.up") {
            SkillConfigurationSection(title: L10n.text("repurpose_pack.settings.formats")) {
                ForEach(RepurposeFormat.primaryFormats) { format in
                    formatRow(format)
                }
            }
            SkillConfigurationSection(title: L10n.text("repurpose_pack.settings.more_platforms")) {
                ForEach(RepurposeFormat.additionalFormats) { format in
                    formatRow(format)
                }
            }
        }
    }

    @ViewBuilder
    private func formatRow(_ format: RepurposeFormat) -> some View {
        Toggle(isOn: formatBinding(format)) {
            SkillPlatformLabel(title: format.localizedTitle, asset: asset(for: format), symbol: symbol(for: format))
        }
        .toggleStyle(SkillSelectionToggleStyle())
        .accessibilityIdentifier("repurpose-format-\(format.id)")

        if format == .youtubeVideo && preferences.selectedFormats.contains(.youtubeVideo) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("repurpose_pack.settings.long_video_duration"))
                    .font(.subheadline).foregroundStyle(Color.textSub)
                Picker(L10n.text("repurpose_pack.settings.long_video_duration"), selection: savedBinding(\.longVideoMinutes)) {
                    ForEach(RepurposePackPreferences.longVideoOptions, id: \.self) { minutes in
                        Text(L10n.text("repurpose_pack.duration.minutes", minutes)).tag(minutes)
                    }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            .padding(.leading, 44)
            .padding(.bottom, 18)
        }
        if format == .threads && preferences.selectedFormats.contains(.threads) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("repurpose_pack.settings.thread_length"))
                    .font(.subheadline).foregroundStyle(Color.textSub)
                Picker(L10n.text("repurpose_pack.settings.thread_length"), selection: savedBinding(\.threadLength)) {
                    ForEach(RepurposeThreadLength.allCases) { length in
                        Text(length.localizedTitle).tag(length)
                    }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            .padding(.leading, 44)
            .padding(.bottom, 18)
        }
        SkillSettingsDivider()
    }

    private func asset(for format: RepurposeFormat) -> String? {
        switch format {
        case .tiktok: return "TikTokBrandLogo"
        case .instagramReels: return "InstagramBrandLogo"
        case .youtubeShorts, .youtubeVideo: return "YouTubeBrandLogo"
        default: return nil
        }
    }

    private func symbol(for format: RepurposeFormat) -> String {
        switch format {
        case .newsletter: return "envelope"
        case .xPost: return "text.bubble"
        case .threads: return "at"
        case .linkedin: return "briefcase"
        default: return "play.rectangle"
        }
    }

    private func savedBinding<Value>(_ keyPath: WritableKeyPath<RepurposePackPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: keyPath] }, set: {
            preferences[keyPath: keyPath] = $0
            preferences.save()
        })
    }

    private func formatBinding(_ format: RepurposeFormat) -> Binding<Bool> {
        Binding(get: { preferences.selectedFormats.contains(format) }, set: { enabled in
            var selected = preferences.selectedFormats
            if enabled {
                if !selected.contains(format) { selected.append(format) }
            } else {
                guard selected.count > 1 else { return }
                selected.removeAll { $0 == format }
            }
            preferences.formats = RepurposeFormat.allCases.filter { selected.contains($0) }
            preferences.save()
        })
    }
}

private struct CreateRecipeSheet: View {
    @Binding var name: String
    @Binding var prompt: String
    @Binding var icon: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var isIconPickerPresented = false

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SkillConfigurationPage(
            title: L10n.text("recipes.create_sheet.title"),
            symbol: "square.and.pencil",
            confirmationTitle: L10n.text("common.save"),
            confirmationEnabled: !isSaveDisabled,
            onConfirm: onSave,
            onCancel: onCancel
        ) {
            SkillConfigurationSection(title: L10n.text("recipes.create_sheet.details")) {
                TextField(L10n.text("recipes.create_sheet.name_placeholder"), text: $name)
                    .font(.body)
                    .foregroundStyle(Color.textMain)
                    .padding(16)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    }
                    .accessibilityIdentifier("custom-skill-name")

                Button(action: { isIconPickerPresented = true }) {
                    HStack(spacing: 16) {
                        Text(L10n.text("recipes.create_sheet.icon"))
                        Spacer()
                        Image(systemName: icon.isEmpty ? "sparkles" : icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.brandTealText)
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.textSub)
                            .accessibilityHidden(true)
                    }
                    .font(.body)
                    .foregroundStyle(Color.textMain)
                    .frame(minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom-skill-icon")
                SkillSettingsDivider()
            }

            SkillConfigurationSection(title: L10n.text("recipes.create_sheet.prompt")) {
                TextEditor(text: $prompt)
                    .font(.body)
                    .foregroundStyle(Color.textMain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 240)
                    .padding(12)
                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.borderSubtle, lineWidth: 1)
                    }
                    .accessibilityLabel(L10n.text("recipes.create_sheet.prompt"))
                    .accessibilityIdentifier("custom-skill-prompt")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $isIconPickerPresented) {
            IconPickerView(selectedIcon: $icon)
        }
    }
}

#Preview {
    NavigationStack {
        ChillRecipesView()
    }
}
