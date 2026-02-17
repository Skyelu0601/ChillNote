import SwiftUI
import SwiftData

struct TranslateLanguage: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let flag: String
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
    let showMergeSuccessAlert: Bool
    let showEmptyTrashConfirmation: Bool
    let showBatchTagSheet: Bool
    let isSidebarPresented: Bool
    let selectedTag: Tag?
    let selectedNotes: Set<UUID>
    let notesToDeleteAfterMerge: [Note]
    let inputText: String
    let isVoiceMode: Bool

    let cachedVisibleNotes: [Note]
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
    case setInputText(String)
    case setVoiceMode(Bool)
    case setShowingSettings(Bool)
    case setAutoOpenPendingRecordings(Bool)
    case setShowPendingRecordings(Bool)
    case setShowAIChat(Bool)
    case setCustomActionInputPresented(Bool)
    case setCustomActionPrompt(String)
    case setTranslateInputPresented(Bool)
    case setShowDeleteConfirmation(Bool)
    case setShowMergeSuccessAlert(Bool)
    case setShowEmptyTrashConfirmation(Bool)
    case setShowBatchTagSheet(Bool)
    case setSidebarPresented(Bool)
    case setAgentMenuOpen(Bool)
    case setShowChillRecipes(Bool)
    case setSelectedTag(Tag?)
    case setTrashSelected(Bool)

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
    case deleteNote(Note)
    case loadMoreIfNeeded(Note)
    case toggleNoteSelection(Note)

    case handleAgentRecipeRequest(AgentRecipe)
    case startAIChat
    case submitText
    case cancelVoice
    case confirmVoice
    case createBlankNote

    case deleteSelectedNotes
    case deleteNotesAfterMerge
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
