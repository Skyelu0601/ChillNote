package com.sponteoai.chillscript

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sponteoai.chillscript.auth.AuthRepository
import com.sponteoai.chillscript.auth.AuthState
import com.sponteoai.chillscript.data.NotesRepository
import com.sponteoai.chillscript.data.local.ChillScriptDatabase
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.remote.SyncApi
import com.sponteoai.chillscript.data.remote.SyncHttpException
import com.sponteoai.chillscript.data.remote.AccountApi
import com.sponteoai.chillscript.data.remote.VoiceApi
import com.sponteoai.chillscript.data.remote.extractWebUrl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import android.util.Base64
import java.io.File
import java.util.Locale
import java.time.Instant
import java.time.Duration
import com.sponteoai.chillscript.onboarding.OnboardingPreferences
import com.sponteoai.chillscript.ai.AIConsentManager
import com.sponteoai.chillscript.ai.AIConsentPrompt
import com.sponteoai.chillscript.ai.AIConsentTrigger
import com.sponteoai.chillscript.voice.RecordingFileManager
import com.sponteoai.chillscript.voice.PendingRecording
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.RecipeStore
import com.sponteoai.chillscript.ai.requestPrompts
import com.sponteoai.chillscript.data.remote.CreatorSkillsApi
import com.sponteoai.chillscript.ai.ChatMessage
import com.sponteoai.chillscript.ai.ChatRole
import com.sponteoai.chillscript.ai.ContextChatPrompt
import com.sponteoai.chillscript.preferences.CapturePreferences
import com.sponteoai.chillscript.preferences.VoiceLanguageSettings
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import com.sponteoai.chillscript.rating.AppRatingTracker

data class AISkillPreviewState(
    val recipe: AgentRecipe,
    val result: String,
    val instruction: String? = null,
)

data class AISkillUiState(
    val processingRecipeId: String? = null,
    val preview: AISkillPreviewState? = null,
    val errorMessage: String? = null,
)

data class ContextChatUiState(
    val isOpen: Boolean = false,
    val contextNotes: List<NoteEntity> = emptyList(),
    val messages: List<ChatMessage> = emptyList(),
    val processing: Boolean = false,
    val errorMessage: String? = null,
    val savedMessageId: String? = null,
)

data class VoiceRefinementState(
    val note: NoteEntity,
    val originalText: String,
)

data class AppUiState(
    val authState: AuthState = AuthState.Checking,
    val busy: Boolean = false,
    val codeSentTo: String? = null,
    val errorMessage: String? = null,
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    val voiceProcessing: Boolean = false,
    val introPaywallResolved: Boolean = false,
    val introPaywallRequired: Boolean = false,
    val creditBalance: Int? = null,
    val hasFetchedCreditBalance: Boolean = false,
)

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class AppViewModel(application: Application) : AndroidViewModel(application) {
    private val authRepository = AuthRepository(application)
    private val notesRepository = NotesRepository(ChillScriptDatabase.get(application).dao(), SyncApi())
    private val accountApi = AccountApi()
    private val voiceApi = VoiceApi()
    private val onboardingPreferences = OnboardingPreferences(application)
    private val aiConsentManager = AIConsentManager(application)
    private val recordingFileManager = RecordingFileManager(application)
    private val recipeStore = RecipeStore(application)
    private val creatorSkillsApi = CreatorSkillsApi()
    private val capturePreferences = CapturePreferences(application)
    private val appRatingTracker = AppRatingTracker(application)
    private var pendingImportMonitor: Job? = null
    private val noteContentMutationMutex = Mutex()
    private val mutableUiState = MutableStateFlow(AppUiState())
    val uiState: StateFlow<AppUiState> = mutableUiState
    val aiConsentPrompt: StateFlow<AIConsentPrompt?> = aiConsentManager.prompt
    private val mutablePendingRecordings = MutableStateFlow(recordingFileManager.pendingRecordings())
    val pendingRecordings: StateFlow<List<PendingRecording>> = mutablePendingRecordings
    private val mutableVoiceRefinementState = MutableStateFlow<VoiceRefinementState?>(null)
    val voiceRefinementState: StateFlow<VoiceRefinementState?> = mutableVoiceRefinementState
    val installedRecipes: StateFlow<List<AgentRecipe>> = recipeStore.installed
    val availableRecipes: List<AgentRecipe> get() = recipeStore.available
    private val mutableAISkillState = MutableStateFlow(AISkillUiState())
    val aiSkillState: StateFlow<AISkillUiState> = mutableAISkillState
    private val mutableContextChatState = MutableStateFlow(ContextChatUiState())
    val contextChatState: StateFlow<ContextChatUiState> = mutableContextChatState
    val voiceLanguageSettings: StateFlow<VoiceLanguageSettings> = capturePreferences.voice
    val mediaLinkSections: StateFlow<MediaLinkSectionsDto> = capturePreferences.mediaSections
    val reviewRequests = appRatingTracker.requests
    val currentUserId: String?
        get() = (mutableUiState.value.authState as? AuthState.SignedIn)?.session?.user?.id

    val notes: StateFlow<List<NoteEntity>> = mutableUiState.flatMapLatest { state ->
        val userId = (state.authState as? AuthState.SignedIn)?.session?.user?.id
        if (userId == null) flowOf(emptyList()) else notesRepository.observeNotes(userId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val tags: StateFlow<List<TagEntity>> = mutableUiState.flatMapLatest { state ->
        val userId = (state.authState as? AuthState.SignedIn)?.session?.user?.id
        if (userId == null) flowOf(emptyList()) else notesRepository.observeTags(userId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val noteTags: StateFlow<List<NoteTagCrossRef>> = notesRepository.observeNoteTags()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    private val searchQuery = MutableStateFlow("")
    val searchResults: StateFlow<List<NoteEntity>> = combine(mutableUiState, searchQuery) { state, query -> state to query }
        .flatMapLatest { (state, query) ->
            val userId = (state.authState as? AuthState.SignedIn)?.session?.user?.id
            if (userId == null || query.isBlank()) flowOf(emptyList()) else notesRepository.searchNotes(userId, query)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        val session = authRepository.restoreSession()
        mutableUiState.value = if (session == null) AppUiState(authState = AuthState.SignedOut) else AppUiState(
            authState = AuthState.SignedIn(session),
            introPaywallResolved = onboardingPreferences.hasShownIntroPaywall(session.user.id),
        )
        if (session != null) { syncAndSeedWelcomeIfNeeded(session); refreshSubscription(); refreshCredits() }
        viewModelScope.launch {
            notes.collect { currentNotes ->
                if (currentNotes.any { it.importStatus == "queued" || it.importStatus == "processing" }) {
                    startPendingImportMonitorIfNeeded()
                }
                currentNotes.filter {
                    it.deletedAt == null && it.sourceUrl != null && it.importJobId != null && it.importStatus == "completed" && it.content.isNotBlank()
                }.forEach { appRatingTracker.registerCompletedLinkImport(it.id) }
            }
        }
    }

    fun sendCode(email: String) = launchBusy {
        authRepository.sendEmailCode(email)
        mutableUiState.value = mutableUiState.value.copy(codeSentTo = email.trim().lowercase())
    }

    fun verifyCode(code: String) = launchBusy {
        val email = requireNotNull(mutableUiState.value.codeSentTo)
        val session = authRepository.verifyEmailCode(email, code)
        mutableUiState.value = AppUiState(authState = AuthState.SignedIn(session))
        syncAndSeedWelcomeIfNeeded(session)
        refreshSubscription()
        refreshCredits()
    }

    fun signInWithGoogleIdToken(idToken: String) = launchBusy {
        val session = authRepository.signInWithGoogleIdToken(idToken)
        mutableUiState.value = AppUiState(authState = AuthState.SignedIn(session))
        syncAndSeedWelcomeIfNeeded(session)
        refreshSubscription()
        refreshCredits()
    }

    fun reportAuthError(message: String) {
        mutableUiState.value = mutableUiState.value.copy(errorMessage = message)
    }

    fun handleOAuthCallback(uri: Uri) = launchBusy {
        val session = authRepository.importOAuthCallback(uri)
        mutableUiState.value = AppUiState(authState = AuthState.SignedIn(session))
        syncAndSeedWelcomeIfNeeded(session)
        refreshSubscription()
        refreshCredits()
    }

    fun backToEmail() {
        mutableUiState.value = mutableUiState.value.copy(codeSentTo = null, errorMessage = null)
    }

    fun signOut() {
        authRepository.signOut()
        mutableVoiceRefinementState.value = null
        mutableUiState.value = AppUiState(authState = AuthState.SignedOut)
    }

    fun refreshSubscription() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching { accountApi.subscriptionStatus(session.accessToken) }
                .onSuccess { status -> mutableUiState.value = mutableUiState.value.copy(
                    subscriptionTier = status.tier,
                    subscriptionExpiresAt = status.expiresAt,
                    introPaywallResolved = true,
                    introPaywallRequired = status.tier != "pro" && !onboardingPreferences.hasShownIntroPaywall(session.user.id),
                ).also {
                    if (status.tier == "pro") onboardingPreferences.setIntroPaywallShown(session.user.id)
                } }
                .onFailure {
                    mutableUiState.value = mutableUiState.value.copy(
                        introPaywallResolved = true,
                        introPaywallRequired = !onboardingPreferences.hasShownIntroPaywall(session.user.id),
                    )
                }
        }
    }

    fun refreshCredits() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching { accountApi.creditBalance(session.accessToken) }
                .onSuccess { response -> mutableUiState.value = mutableUiState.value.copy(
                    creditBalance = response.balance,
                    hasFetchedCreditBalance = true,
                ) }
        }
    }

    fun deleteAccount() = launchBusy {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return@launchBusy
        accountApi.deleteAccount(session.accessToken)
        try {
            pendingImportMonitor?.cancel()
            notesRepository.clearLocalUserData(session.user.id)
            recordingFileManager.clearAll()
            recipeStore.clearUserData()
            onboardingPreferences.clearUserData(session.user.id)
            appRatingTracker.clearUserData()
            mutablePendingRecordings.value = emptyList()
            mutableVoiceRefinementState.value = null
            mutableAISkillState.value = AISkillUiState()
            mutableContextChatState.value = ContextChatUiState()
        } finally {
            // The remote account is already deleted, so never retain its session locally.
            authRepository.signOut()
            mutableUiState.value = AppUiState(authState = AuthState.SignedOut)
        }
    }

    fun verifyGooglePlayPurchase(productId: String, purchaseToken: String) = launchBusy {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return@launchBusy
        val status = accountApi.verifyGooglePlayPurchase(session.accessToken, productId, purchaseToken)
        mutableUiState.value = mutableUiState.value.copy(
            subscriptionTier = status.tier,
            subscriptionExpiresAt = status.expiresAt,
            introPaywallResolved = true,
            introPaywallRequired = false,
        )
        onboardingPreferences.setIntroPaywallShown(session.user.id)
        refreshCredits()
    }

    fun processVoiceRecording(file: File, section: String) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Audio)) {
                refreshPendingRecordings()
                return@launch
            }
            mutableUiState.value = mutableUiState.value.copy(voiceProcessing = true, errorMessage = null)
            mutableVoiceRefinementState.value = null
            try {
                val base64 = Base64.encodeToString(file.readBytes(), Base64.NO_WRAP)
                val voiceSettings = voiceLanguageSettings.value
                val raw = voiceApi.transcribe(
                    session.accessToken, base64, "audio/mp4", Locale.getDefault().toLanguageTag(),
                    voiceSettings.mode, voiceSettings.languageHint,
                )
                require(raw.isNotBlank()) { "Voice transcription was empty" }
                val refined = runCatching { voiceApi.refine(session.accessToken, raw) }.getOrDefault(raw)
                val finalText = refined.ifBlank { raw }
                val createdNote = notesRepository.createNote(session.user.id, finalText, section)
                if (finalText != raw) mutableVoiceRefinementState.value = VoiceRefinementState(createdNote, raw)
                recordingFileManager.complete(file)
                appRatingTracker.registerVoiceNote()
                refreshCredits()
                sync()
            } catch (error: Throwable) {
                mutableUiState.value = mutableUiState.value.copy(errorMessage = error.message)
            } finally {
                refreshPendingRecordings()
                mutableUiState.value = mutableUiState.value.copy(voiceProcessing = false)
            }
        }
    }

    fun retryPendingRecording(recording: PendingRecording, section: String = "inbox") {
        processVoiceRecording(recording.file, section)
    }

    fun deletePendingRecording(recording: PendingRecording) {
        recordingFileManager.cancel(recording.file)
        refreshPendingRecordings()
    }

    fun restoreOriginalVoiceResult() {
        val state = mutableVoiceRefinementState.value ?: return
        mutableVoiceRefinementState.value = null
        viewModelScope.launch {
            notesRepository.updateNote(state.note, state.originalText)
            sync()
        }
    }

    fun dismissVoiceRefinement() {
        mutableVoiceRefinementState.value = null
    }

    private fun refreshPendingRecordings() {
        mutablePendingRecordings.value = recordingFileManager.pendingRecordings()
    }

    fun acceptAIDataConsent() = aiConsentManager.accept()

    fun declineAIDataConsent() = aiConsentManager.decline()

    fun runCreatorSkill(recipe: AgentRecipe, content: String, instruction: String? = null) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        if (content.isBlank() || mutableAISkillState.value.processingRecipeId != null) return
        viewModelScope.launch {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Text)) return@launch
            mutableAISkillState.value = AISkillUiState(processingRecipeId = recipe.id)
            runCatching {
                val (prompt, systemPrompt) = recipe.requestPrompts(content, instruction)
                creatorSkillsApi.generate(session.accessToken, prompt, systemPrompt)
            }.onSuccess { result ->
                mutableAISkillState.value = AISkillUiState(
                    preview = AISkillPreviewState(recipe, result, instruction),
                )
                refreshCredits()
            }.onFailure { error ->
                mutableAISkillState.value = AISkillUiState(errorMessage = error.message)
            }
        }
    }

    fun dismissCreatorSkillResult() {
        mutableAISkillState.value = AISkillUiState()
    }

    fun toggleRecipe(recipe: AgentRecipe) = recipeStore.toggle(recipe)

    fun createCustomRecipe(name: String, prompt: String) {
        if (name.isBlank() || prompt.isBlank()) return
        recipeStore.addCustom(name, prompt)
    }

    fun deleteCustomRecipe(recipe: AgentRecipe) = recipeStore.deleteCustom(recipe)

    fun openContextChat(noteIds: Set<String>) {
        val selected = notes.value.filter { it.id in noteIds && it.deletedAt == null }
        if (selected.isEmpty()) return
        mutableContextChatState.value = ContextChatUiState(isOpen = true, contextNotes = selected)
    }

    fun closeContextChat() {
        mutableContextChatState.value = ContextChatUiState()
    }

    fun clearContextChat() {
        mutableContextChatState.value = mutableContextChatState.value.copy(
            messages = emptyList(), errorMessage = null, savedMessageId = null,
        )
    }

    fun sendContextChatMessage(content: String) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        val trimmed = content.trim()
        val state = mutableContextChatState.value
        if (!state.isOpen || state.processing || trimmed.isEmpty()) return
        viewModelScope.launch {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Text)) return@launch
            val before = mutableContextChatState.value
            val userMessage = ChatMessage(role = ChatRole.USER, content = trimmed)
            mutableContextChatState.value = before.copy(
                messages = before.messages + userMessage,
                processing = true,
                errorMessage = null,
            )
            runCatching {
                val (prompt, systemPrompt) = ContextChatPrompt.build(
                    notes = before.contextNotes,
                    history = before.messages,
                    userMessage = trimmed,
                    installedRecipes = installedRecipes.value,
                )
                creatorSkillsApi.generate(session.accessToken, prompt, systemPrompt, usageType = "chat")
            }.onSuccess { response ->
                val current = mutableContextChatState.value
                mutableContextChatState.value = current.copy(
                    messages = current.messages + ChatMessage(role = ChatRole.ASSISTANT, content = ContextChatPrompt.sanitize(response)),
                    processing = false,
                )
                refreshCredits()
            }.onFailure { error ->
                mutableContextChatState.value = mutableContextChatState.value.copy(
                    processing = false,
                    errorMessage = error.message,
                )
            }
        }
    }

    fun saveChatMessageAsNote(message: ChatMessage) {
        if (message.role != ChatRole.ASSISTANT || message.content.isBlank()) return
        val userId = currentUserId ?: return
        viewModelScope.launch {
            notesRepository.createNote(userId, ContextChatPrompt.sanitize(message.content))
            sync()
            mutableContextChatState.value = mutableContextChatState.value.copy(savedMessageId = message.id)
            delay(2_000)
            if (mutableContextChatState.value.savedMessageId == message.id) {
                mutableContextChatState.value = mutableContextChatState.value.copy(savedMessageId = null)
            }
        }
    }

    fun dismissContextChatError() {
        mutableContextChatState.value = mutableContextChatState.value.copy(errorMessage = null)
    }

    fun updateVoiceLanguage(mode: String, languageHint: String) = capturePreferences.updateVoice(mode, languageHint)

    fun updateMediaLinkSections(sections: MediaLinkSectionsDto) = capturePreferences.updateMediaSections(sections)

    fun dismissIntroPaywall() {
        val userId = currentUserId ?: return
        onboardingPreferences.setIntroPaywallShown(userId)
        mutableUiState.value = mutableUiState.value.copy(introPaywallResolved = true, introPaywallRequired = false)
    }

    fun createNote(content: String, section: String) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            notesRepository.createNote(session.user.id, content, section)
            sync()
        }
    }

    fun saveNote(existing: NoteEntity?, content: String, section: String, tagIds: List<String> = emptyList()) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            val saved = if (existing == null) notesRepository.createNote(session.user.id, content, section)
            else notesRepository.updateNote(existing, content, section)
            notesRepository.setNoteTags(saved, tagIds)
            sync()
        }
    }

    fun replaceNoteContent(noteId: String, content: String) {
        val userId = currentUserId ?: return
        viewModelScope.launch {
            noteContentMutationMutex.withLock {
                notesRepository.updateNoteContent(userId, noteId, content)
            }
            sync()
        }
    }

    fun deleteNote(note: NoteEntity) {
        viewModelScope.launch { notesRepository.moveToTrash(note); sync() }
    }

    fun restoreNote(note: NoteEntity) {
        viewModelScope.launch { notesRepository.restore(note); sync() }
    }

    fun togglePin(note: NoteEntity) {
        viewModelScope.launch { notesRepository.togglePin(note); sync() }
    }

    fun moveNote(note: NoteEntity, section: String) {
        if (note.deletedAt != null || note.section == section) return
        viewModelScope.launch { notesRepository.updateNote(note, note.content, section); sync() }
    }

    fun permanentlyDelete(note: NoteEntity) {
        val userId = (mutableUiState.value.authState as? AuthState.SignedIn)?.session?.user?.id ?: return
        viewModelScope.launch { notesRepository.permanentlyDelete(userId, note); sync() }
    }

    fun emptyTrash() {
        val userId = (mutableUiState.value.authState as? AuthState.SignedIn)?.session?.user?.id ?: return
        viewModelScope.launch { notesRepository.emptyTrash(userId); sync() }
    }

    fun createTag(name: String, colorHex: String, parentId: String? = null) {
        val userId = (mutableUiState.value.authState as? AuthState.SignedIn)?.session?.user?.id ?: return
        if (name.isBlank()) return
        viewModelScope.launch { notesRepository.createTag(userId, name, colorHex, parentId); sync() }
    }

    fun updateTag(tag: TagEntity, name: String, colorHex: String, parentId: String?) {
        if (name.isBlank()) return
        viewModelScope.launch { notesRepository.updateTag(tag, name, colorHex, parentId); sync() }
    }

    fun deleteTag(tag: TagEntity) {
        viewModelScope.launch { notesRepository.deleteTag(tag); sync() }
    }

    fun addTagToNotes(noteIds: Set<String>, tag: TagEntity) {
        val selected = notes.value.filter { it.id in noteIds && it.deletedAt == null }
        if (selected.isEmpty()) return
        viewModelScope.launch { notesRepository.addTagToNotes(selected, tag); sync() }
    }

    fun deleteNotes(noteIds: Set<String>) {
        val userId = currentUserId ?: return
        val selected = notes.value.filter { it.id in noteIds && it.deletedAt == null }
        if (selected.isEmpty()) return
        viewModelScope.launch { notesRepository.deleteNotes(userId, selected); sync() }
    }


    fun importSharedText(
        text: String,
        section: String,
        onPlainText: (String) -> Unit,
        onInsufficientCredits: () -> Unit,
    ) {
        val url = extractWebUrl(text)
        if (url == null) { onPlainText(text); return }
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            val sourceHost = runCatching { java.net.URI(url).host.orEmpty() }.getOrDefault(url)
            val placeholder = getApplication<Application>().getString(
                R.string.quick_capture_link_import_placeholder_format,
                sourceHost,
            )
            runCatching {
                val creditState = accountApi.consumeImportCredits(session.accessToken)
                mutableUiState.value = mutableUiState.value.copy(
                    creditBalance = creditState.balance,
                    hasFetchedCreditBalance = true,
                    subscriptionTier = creditState.tier ?: mutableUiState.value.subscriptionTier,
                )
                notesRepository.importLink(
                    session.user.id, session.accessToken, url, section, placeholder, mediaLinkSections.value,
                )
            }
                .onSuccess {
                    refreshCredits()
                    sync()
                }
                .onFailure { error ->
                    if (error is SyncHttpException && error.statusCode == 402) {
                        onInsufficientCredits()
                        refreshCredits()
                    } else {
                        mutableUiState.value = mutableUiState.value.copy(errorMessage = error.message)
                    }
                }
        }
    }

    fun sync() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching {
                notesRepository.purgeExpiredTrash(session.user.id)
                notesRepository.sync(session.user.id, session.accessToken)
            }
                .onFailure { mutableUiState.value = mutableUiState.value.copy(errorMessage = it.message) }
        }
    }

    private fun syncAndSeedWelcomeIfNeeded(session: com.sponteoai.chillscript.auth.AuthSession) {
        viewModelScope.launch {
            runCatching {
                notesRepository.sync(session.user.id, session.accessToken)
                notesRepository.purgeExpiredTrash(session.user.id)
                seedWelcomeIfEligible(session.user)
                notesRepository.sync(session.user.id, session.accessToken)
            }.onFailure { mutableUiState.value = mutableUiState.value.copy(errorMessage = it.message) }
        }
    }

    private suspend fun seedWelcomeIfEligible(user: com.sponteoai.chillscript.auth.AuthUser) {
        if (onboardingPreferences.hasHandledWelcomeNote(user.id)) return
        val createdAt = user.createdAt?.let { runCatching { Instant.parse(it) }.getOrNull() }
        val isFreshAccount = createdAt?.let {
            val age = Duration.between(it, Instant.now())
            !age.isNegative && age <= Duration.ofMinutes(10)
        } == true
        if (isFreshAccount) {
            notesRepository.createWelcomeContent(
                user.id,
                getApplication<Application>().getString(R.string.onboarding_welcome_note_content),
                getApplication<Application>().getString(R.string.onboarding_welcome_note_tag),
            )
        }
        onboardingPreferences.setWelcomeNoteHandled(user.id)
    }

    fun clearError() { mutableUiState.value = mutableUiState.value.copy(errorMessage = null) }

    fun updateSearchQuery(query: String) {
        searchQuery.value = query.trim()
    }

    private fun startPendingImportMonitorIfNeeded() {
        if (pendingImportMonitor?.isActive == true) return
        pendingImportMonitor = viewModelScope.launch {
            try {
                repeat(40) {
                    if (notes.value.none { it.importStatus == "queued" || it.importStatus == "processing" }) return@launch
                    delay(3_000)
                    val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return@launch
                    runCatching { notesRepository.sync(session.user.id, session.accessToken) }
                }
            } finally {
                pendingImportMonitor = null
            }
        }
    }

    private fun launchBusy(block: suspend () -> Unit) {
        viewModelScope.launch {
            mutableUiState.value = mutableUiState.value.copy(busy = true, errorMessage = null)
            runCatching { block() }
                .onFailure { mutableUiState.value = mutableUiState.value.copy(errorMessage = it.message) }
            mutableUiState.value = mutableUiState.value.copy(busy = false)
        }
    }
}
