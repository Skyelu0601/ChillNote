import SwiftUI
import SwiftData

struct TranslateLanguage: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let flag: String

    static let defaultLanguages: [TranslateLanguage] = [
        TranslateLanguage(id: "zh-Hans", name: "Simplified Chinese", displayName: "简体中文", flag: "🇨🇳"),
        TranslateLanguage(id: "zh-Hant", name: "Traditional Chinese", displayName: "繁體中文", flag: "🇭🇰"),
        TranslateLanguage(id: "fr", name: "French", displayName: "Français", flag: "🇫🇷"),
        TranslateLanguage(id: "en", name: "English", displayName: "English", flag: "🇺🇸"),
        TranslateLanguage(id: "de", name: "German", displayName: "Deutsch", flag: "🇩🇪"),
        TranslateLanguage(id: "ja", name: "Japanese", displayName: "日本語", flag: "🇯🇵"),
        TranslateLanguage(id: "es", name: "Spanish", displayName: "Español", flag: "🇪🇸"),
        TranslateLanguage(id: "ko", name: "Korean", displayName: "한국어", flag: "🇰🇷")
    ]
}

struct HomeScreenState {
    let navigationPath: NavigationPath
    let isSelectionMode: Bool
    let searchText: String
    let isSearchVisible: Bool
    let isTrashSelected: Bool
    let isAgentMenuOpen: Bool
    let showChillRecipes: Bool
    let showingSettings: Bool
    let autoOpenPendingRecordings: Bool
    let showAIChat: Bool
    let isCustomActionInputPresented: Bool
    let customActionPrompt: String
    let isTranslateInputPresented: Bool
    let translateTargetLanguage: String
    let showDeleteConfirmation: Bool
    let showEmptyTrashConfirmation: Bool
    let showBatchTagSheet: Bool
    let isSidebarPresented: Bool
    let selectedTag: Tag?
    let selectedSection: NoteSection?
    let selectedNotes: Set<UUID>
    let isVoiceMode: Bool

    let cachedVisibleNotes: [Note]
    let isLoadingNotes: Bool
    let isSyncingNotes: Bool
    let hasLoadedNotesAtLeastOnce: Bool
    let availableTags: [Tag]
    let translateLanguages: [TranslateLanguage]
    let recipeManager: RecipeManager
    let speechRecognizer: SpeechRecognizer
    let syncManager: SyncManager
    let headerTitle: String
    let actionProgress: String?
    let isExecutingAction: Bool

    let cachedContextNotes: [Note]

    let showAskSoftLimitAlert: Bool
    let showAskHardLimitAlert: Bool
    let showRecipeSoftLimitAlert: Bool
    let showRecipeHardLimitAlert: Bool
    let askHardLimit: Int
    let recipeHardLimit: Int

    let hasPendingRecordings: Bool
    let pendingRecordingsCount: Int
    let showPendingRecordings: Bool
}

enum HomeScreenAction {
    case setNavigationPath(NavigationPath)
    case setSearchText(String)
    case setVoiceMode(Bool)
    case setShowingSettings(Bool)
    case setAutoOpenPendingRecordings(Bool)
    case setShowPendingRecordings(Bool)
    case setShowAIChat(Bool)
    case setCustomActionInputPresented(Bool)
    case setCustomActionPrompt(String)
    case setTranslateInputPresented(Bool)
    case setShowDeleteConfirmation(Bool)
    case setShowEmptyTrashConfirmation(Bool)
    case setShowBatchTagSheet(Bool)
    case setSidebarPresented(Bool)
    case setAgentMenuOpen(Bool)
    case setShowChillRecipes(Bool)
    case setSelectedTag(Tag?)
    case setSelectedSection(NoteSection?)
    case setTrashSelected(Bool)
    case selectSection(NoteSection)

    case toggleSidebar
    case openSidebar
    case enterSelectionMode
    case toggleSearch
    case exitSelectionMode
    case selectAll
    case deselectAll

    case restoreNote(Note)
    case deleteNotePermanently(Note)
    case togglePin(Note)
    case moveNote(Note, NoteSection)
    case deleteNote(Note)
    case loadMoreIfNeeded(Note)
    case toggleNoteSelection(Note)

    case handleAgentRecipeRequest(AgentRecipe)
    case startAIChat
    case cancelVoice
    case confirmVoice
    case pasteLink(QuickCaptureImportService.LinkImportResult)
    case importImageText(String)
    case createBlankNote

    case deleteSelectedNotes
    case emptyTrash
    case applyTagToSelected(Tag)
    case hideKeyboard

    case executePendingAgentAction(String)
    case translateSelect(String)
    case closeTranslate

    case showSettings
    case aiChatDisappear
    case openChillRecipes
    case closeChillRecipes

    case confirmAskSoftLimit
    case confirmRecipeSoftLimit
    case cancelRecipeSoftLimit

    case noteDetailDisappear(Note)
}
