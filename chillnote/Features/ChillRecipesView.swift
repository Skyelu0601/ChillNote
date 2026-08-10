import SwiftUI

struct ChillRecipesView: View {
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var storeService = StoreService.shared
    @State private var showingCreateRecipe = false
    @State private var showingSubscription = false
    @State private var showingCaptionPackSettings = false
    @State private var showingRepurposePackSettings = false
    @State private var showingBrandVoiceSettings = false
    @State private var showingTimedScriptSettings = false
    @State private var pendingDeleteRecipe: AgentRecipe?

    @State private var newRecipeName = ""
    @State private var newRecipePrompt = ""
    @State private var newRecipeIcon = "sparkles"

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SkillSection(
                        title: L10n.text("recipes.section.installed"),
                        recipes: installedRecipes,
                        isInstalled: true,
                        configureAction: configureAction,
                        configureLabel: configureLabel,
                        onToggle: toggleRecipe,
                        onDelete: { pendingDeleteRecipe = $0 }
                    )

                    SkillSection(
                        title: L10n.text("recipes.section.available"),
                        recipes: availableRecipes,
                        isInstalled: false,
                        configureAction: configureAction,
                        configureLabel: configureLabel,
                        onToggle: toggleRecipe,
                        onDelete: { pendingDeleteRecipe = $0 }
                    )

                    CreateCustomSkillRow(action: showCreateRecipe)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(L10n.text("recipes.title"))
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingBrandVoiceSettings) {
            BrandVoiceSettingsSheet()
        }
        .sheet(isPresented: $showingTimedScriptSettings) {
            TimedScriptSettingsSheet()
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recipeManager.toggleRecipe(recipe)
        }
    }

    private func configureAction(for recipe: AgentRecipe) -> (() -> Void)? {
        switch recipe.id {
        case "caption_pack": return { showingCaptionPackSettings = true }
        case "repurpose_pack": return { showingRepurposePackSettings = true }
        case "style_match": return { showingBrandVoiceSettings = true }
        case "timed_script": return { showingTimedScriptSettings = true }
        default: return nil
        }
    }

    private func configureLabel(for recipe: AgentRecipe) -> String {
        switch recipe.id {
        case "caption_pack": return L10n.text("caption_pack.settings.title")
        case "repurpose_pack": return L10n.text("repurpose_pack.settings.title")
        case "style_match": return L10n.text("brand_voice.settings.title")
        case "timed_script": return L10n.text("timed_script.settings.title")
        default: return L10n.text("caption_pack.settings.title")
        }
    }

    private var libraryRecipes: [AgentRecipe] {
        AgentRecipe.allRecipes.filter {
            !RecipeManager.retiredRecipeIds.contains($0.id)
        }
    }

    private var installedRecipes: [AgentRecipe] {
        recipeManager.savedRecipes.filter {
            !RecipeManager.retiredRecipeIds.contains($0.id)
        }
    }

    private var availableRecipes: [AgentRecipe] {
        libraryRecipes.filter { !recipeManager.isAdded($0) }
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
        HStack(spacing: 12) {
            CreatorSkillIcon(recipe: recipe, size: 18, container: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textMain)
                    .lineLimit(1)

                Text(recipe.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.textSub)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                if let onConfigure {
                    Button(action: onConfigure) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.textSub.opacity(0.75))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(configureLabel)
                }

                if let onDelete {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label(L10n.text("home.notes.action.delete_permanently"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSub)
                            .frame(width: 28, height: 28)
                            .background(Color.bgPrimary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onToggle) {
                        Image(systemName: isInstalled ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(
                                isInstalled
                                    ? .accentSecondary
                                    : .textSub.opacity(0.55)
                            )
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text(isInstalled ? "recipes.action.remove" : "recipes.action.add"))
                }
            }
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
        NavigationStack {
            Form {
                Section(L10n.text("caption_pack.settings.platforms")) {
                    Toggle(L10n.text("caption_pack.platform.tiktok"), isOn: bindingForPlatform($includeTikTok))
                    Toggle(L10n.text("caption_pack.platform.instagram_reels"), isOn: bindingForPlatform($includeInstagramReels))
                    Toggle(L10n.text("caption_pack.platform.youtube_shorts"), isOn: bindingForPlatform($includeYouTubeShorts))
                    Toggle(L10n.text("caption_pack.platform.youtube_long_video"), isOn: bindingForPlatform($includeYouTubeLongVideo))
                }

                Section(L10n.text("caption_pack.settings.goal")) {
                    Picker(L10n.text("caption_pack.settings.goal"), selection: $goalRawValue) {
                        ForEach(CaptionPackGoal.allCases) { goal in
                            Text(goal.localizedTitle).tag(goal.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section(L10n.text("caption_pack.settings.tone")) {
                    Picker(L10n.text("caption_pack.settings.tone"), selection: $toneRawValue) {
                        ForEach(CaptionPackTone.allCases) { tone in
                            Text(tone.localizedTitle).tag(tone.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section(L10n.text("caption_pack.settings.output_style")) {
                    Picker(L10n.text("caption_pack.settings.output_style"), selection: $outputStyleRawValue) {
                        ForEach(CaptionPackOutputStyle.allCases) { style in
                            Text(style.localizedTitle).tag(style.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.text("caption_pack.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done")) {
                        dismiss()
                    }
                }
            }
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

private struct TimedScriptSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TimedScriptPreferences.durationKey) private var durationRawValue = TimedScriptDuration.seconds45.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("timed_script.settings.duration")) {
                    Picker(L10n.text("timed_script.settings.duration"), selection: $durationRawValue) {
                        ForEach(TimedScriptDuration.allCases) { duration in
                            Text(duration.localizedTitle).tag(duration.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.text("timed_script.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct BrandVoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BrandVoicePreferences.sampleKey) private var sample = ""
    @AppStorage(BrandVoicePreferences.toneKey) private var tone = ""
    @AppStorage(BrandVoicePreferences.audienceKey) private var audience = ""
    @AppStorage(BrandVoicePreferences.ctaKey) private var cta = ""
    @AppStorage(BrandVoicePreferences.avoidKey) private var avoid = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.text("brand_voice.settings.tone_placeholder"), text: $tone, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(L10n.text("brand_voice.settings.tone_label"))
                } footer: {
                    Text(L10n.text("brand_voice.settings.tone_help"))
                }

                Section {
                    TextField(L10n.text("brand_voice.settings.audience_placeholder"), text: $audience, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(L10n.text("brand_voice.settings.audience_label"))
                } footer: {
                    Text(L10n.text("brand_voice.settings.audience_help"))
                }

                Section {
                    TextField(L10n.text("brand_voice.settings.cta_placeholder"), text: $cta, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(L10n.text("brand_voice.settings.cta_label"))
                } footer: {
                    Text(L10n.text("brand_voice.settings.cta_help"))
                }

                Section {
                    TextEditor(text: $avoid)
                        .frame(minHeight: 90)
                        .font(.body)
                } header: {
                    Text(L10n.text("brand_voice.settings.avoid_label"))
                } footer: {
                    Text(L10n.text("brand_voice.settings.avoid_help"))
                }

                Section {
                    TextEditor(text: $sample)
                        .frame(minHeight: 140)
                        .font(.body)
                } header: {
                    Text(L10n.text("brand_voice.settings.sample_label"))
                } footer: {
                    Text(L10n.text("brand_voice.settings.sample_help"))
                }
            }
            .navigationTitle(L10n.text("brand_voice.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RepurposePackSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RepurposePackPreferences.xPostKey) private var includeXPost = true
    @AppStorage(RepurposePackPreferences.linkedinKey) private var includeLinkedIn = true
    @AppStorage(RepurposePackPreferences.threadsKey) private var includeThreads = false
    @AppStorage(RepurposePackPreferences.facebookPageKey) private var includeFacebookPage = false
    @AppStorage(RepurposePackPreferences.newsletterKey) private var includeNewsletter = false
    @AppStorage(RepurposePackPreferences.instagramCarouselKey) private var includeInstagramCarousel = true
    @AppStorage(RepurposePackPreferences.pinterestPinKey) private var includePinterestPin = false
    @AppStorage(RepurposePackPreferences.youtubeCommunityKey) private var includeYouTubeCommunity = false
    @AppStorage(RepurposePackPreferences.threadLengthKey) private var threadLengthRawValue = RepurposeThreadLength.medium.rawValue
    @AppStorage(RepurposePackPreferences.toneKey) private var toneRawValue = CaptionPackTone.creatorVoice.rawValue
    @AppStorage(RepurposePackPreferences.ctaKey) private var includeCTA = true

    private var selectedFormatCount: Int {
        [
            includeXPost,
            includeLinkedIn,
            includeThreads,
            includeFacebookPage,
            includeNewsletter,
            includeInstagramCarousel,
            includePinterestPin,
            includeYouTubeCommunity
        ].filter { $0 }.count
    }

    private var showThreadLength: Bool {
        includeThreads
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("repurpose_pack.settings.formats")) {
                    Toggle(L10n.text("repurpose_pack.format.x_post"), isOn: bindingForFormat($includeXPost))
                    Toggle(L10n.text("repurpose_pack.format.linkedin"), isOn: bindingForFormat($includeLinkedIn))
                    Toggle(L10n.text("repurpose_pack.format.threads"), isOn: bindingForFormat($includeThreads))
                    Toggle(L10n.text("repurpose_pack.format.facebook_page"), isOn: bindingForFormat($includeFacebookPage))
                    Toggle(L10n.text("repurpose_pack.format.newsletter"), isOn: bindingForFormat($includeNewsletter))
                    Toggle(L10n.text("repurpose_pack.format.instagram_carousel"), isOn: bindingForFormat($includeInstagramCarousel))
                    Toggle(L10n.text("repurpose_pack.format.pinterest_pin"), isOn: bindingForFormat($includePinterestPin))
                    Toggle(L10n.text("repurpose_pack.format.youtube_community"), isOn: bindingForFormat($includeYouTubeCommunity))
                }

                if showThreadLength {
                    Section(L10n.text("repurpose_pack.settings.thread_length")) {
                        Picker(L10n.text("repurpose_pack.settings.thread_length"), selection: $threadLengthRawValue) {
                            ForEach(RepurposeThreadLength.allCases) { length in
                                Text(length.localizedTitle).tag(length.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                }

                Section(L10n.text("repurpose_pack.settings.tone")) {
                    Picker(L10n.text("repurpose_pack.settings.tone"), selection: $toneRawValue) {
                        ForEach(CaptionPackTone.allCases) { tone in
                            Text(tone.localizedTitle).tag(tone.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section {
                    Toggle(L10n.text("repurpose_pack.settings.cta"), isOn: $includeCTA)
                }
            }
            .navigationTitle(L10n.text("repurpose_pack.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func bindingForFormat(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                if !newValue && selectedFormatCount <= 1 {
                    return
                }
                binding.wrappedValue = newValue
            }
        )
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
        NavigationStack {
            Form {
                Section(L10n.text("recipes.create_sheet.details")) {
                    TextField(L10n.text("recipes.create_sheet.name_placeholder"), text: $name)
                    
                    Button(action: { isIconPickerPresented = true }) {
                        HStack {
                            Text(L10n.text("recipes.create_sheet.icon"))
                                .foregroundColor(.textMain)
                            Spacer()
                            Image(systemName: icon.isEmpty ? "sparkles" : icon)
                                .foregroundColor(.textMain)
                        }
                    }
                }

                Section(L10n.text("recipes.create_sheet.prompt")) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(L10n.text("recipes.create_sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.save"), action: onSave)
                        .disabled(isSaveDisabled)
                }
            }
            .sheet(isPresented: $isIconPickerPresented) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChillRecipesView()
    }
}
