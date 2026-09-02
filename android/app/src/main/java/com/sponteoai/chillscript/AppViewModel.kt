package com.sponteoai.chillscript

import android.app.Application
import android.net.Uri
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sponteoai.chillscript.auth.AuthRepository
import com.sponteoai.chillscript.auth.AuthSession
import com.sponteoai.chillscript.auth.AuthState
import com.sponteoai.chillscript.auth.AuthFailure
import com.sponteoai.chillscript.auth.AuthOperation
import com.sponteoai.chillscript.auth.classifyAuthFailure
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
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import java.util.Locale
import java.util.UUID
import com.sponteoai.chillscript.onboarding.OnboardingPreferences
import com.sponteoai.chillscript.ai.AIConsentManager
import com.sponteoai.chillscript.ai.AIConsentPrompt
import com.sponteoai.chillscript.ai.AIConsentTrigger
import com.sponteoai.chillscript.voice.RecordingFileManager
import com.sponteoai.chillscript.voice.PendingRecording
import com.sponteoai.chillscript.voice.PendingRecordingSaveOutcome
import com.sponteoai.chillscript.voice.PendingRecordingOrigin
import com.sponteoai.chillscript.voice.SharedVideoImporter
import com.sponteoai.chillscript.voice.SharedVideoImportException
import com.sponteoai.chillscript.voice.SharedVideoImportSource
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
import com.sponteoai.chillscript.sync.BackgroundSyncScheduler
import com.sponteoai.chillscript.push.PushNotificationManager
import com.sponteoai.chillscript.share.PendingShareImportQueue

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

data class PendingShareImportAdoption(
    val userId: String,
    val noteId: String,
)

data class HomeNoteRevealRequest(
    val userId: String,
    val noteId: String,
)

enum class VoiceNoteProcessingStage {
    Transcribing,
    Refining,
}

sealed interface VoiceNoteState {
    data class Processing(val stage: VoiceNoteProcessingStage) : VoiceNoteState
    data class Completed(
        val originalText: String,
        val refinedText: String,
    ) : VoiceNoteState
    data class Failed(val message: String) : VoiceNoteState
}

data class AppUiState(
    val authState: AuthState = AuthState.Checking,
    val busy: Boolean = false,
    val initialNotesSyncing: Boolean = false,
    val hasLoadedNotesAtLeastOnce: Boolean = false,
    val codeSentTo: String? = null,
    val errorMessage: String? = null,
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    val activeSubscriptionProductId: String? = null,
    val voiceProcessing: Boolean = false,
    val sharedVideoPreparing: Boolean = false,
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
    private val sharedVideoImporter = SharedVideoImporter(application, recordingFileManager)
    private val recipeStore = RecipeStore(application)
    private val creatorSkillsApi = CreatorSkillsApi()
    private val capturePreferences = CapturePreferences(application)
    private val appRatingTracker = AppRatingTracker(application)
    private val pushNotifications = PushNotificationManager.get(application)
    private val pendingShareImportQueue = PendingShareImportQueue.get(application)
    private var pendingImportMonitor: Job? = null
    private var sessionRefreshJob: Job? = null
    private var pushRegistrationJob: Job? = null
    private var signOutJob: Job? = null
    private var voiceStartAuthorizationJob: Job? = null
    private var foregroundPollSyncJob: Job? = null
    @Volatile private var editorActive: Boolean = false
    private val voiceProcessingJobs = ConcurrentHashMap<String, Job>()
    private val sharedVideoCaptureJobs = ConcurrentHashMap<String, Job>()
    private val sharedVideoAuthorizationJobs = ConcurrentHashMap<String, Job>()
    private val sessionRefreshMutex = Mutex()
    /** Serializes every editor-originated mutation for a note. */
    private val noteMutationMutex = Mutex()
    private val linkImportStartMutex = Mutex()
    private val pendingShareImportMutex = Mutex()
    private val recentLinkImportUrls = ConcurrentHashMap<String, Long>()
    private val noteMutationRequestCounter = AtomicLong()
    private val latestEditorSaveRequest = ConcurrentHashMap<String, Long>()
    private val mutableUiState = MutableStateFlow(AppUiState())
    val uiState: StateFlow<AppUiState> = mutableUiState
    private val mutablePaywallRequests = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val paywallRequests = mutablePaywallRequests.asSharedFlow()
    private val pendingShareImportAdoptions = Channel<PendingShareImportAdoption>(Channel.BUFFERED)
    val pendingShareImportAdoptionEvents = pendingShareImportAdoptions.receiveAsFlow()
    private val homeNoteRevealRequests = Channel<HomeNoteRevealRequest>(Channel.BUFFERED)
    val homeNoteRevealEvents = homeNoteRevealRequests.receiveAsFlow()
    val aiConsentPrompt: StateFlow<AIConsentPrompt?> = aiConsentManager.prompt
    private val mutablePendingRecordings = MutableStateFlow(recordingFileManager.pendingRecordings())
    val pendingRecordings: StateFlow<List<PendingRecording>> = mutablePendingRecordings
    private val mutableVoiceNoteStates = MutableStateFlow<Map<String, VoiceNoteState>>(emptyMap())
    val voiceNoteStates: StateFlow<Map<String, VoiceNoteState>> = mutableVoiceNoteStates.asStateFlow()
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

    val isEditorActive: Boolean
        get() = editorActive

    suspend fun weeklyTopicsAccessToken(): String? {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return null
        return refreshSessionIfNeeded(session)?.accessToken
    }

    suspend fun ensureWeeklyTopicsConsent(): Boolean =
        aiConsentManager.ensureConsent(AIConsentTrigger.Text)

    val notes: StateFlow<List<NoteEntity>> = mutableUiState.flatMapLatest { state ->
        val userId = (state.authState as? AuthState.SignedIn)?.session?.user?.id
        if (userId == null) {
            flowOf(emptyList())
        } else {
            notesRepository.observeNotes(userId).onEach {
                // `stateIn` starts with an empty list, so the list value alone cannot tell
                // whether Room has returned its first real snapshot. Mark loading complete
                // here, before StateFlow can conflate an actual empty snapshot with its
                // initial empty value.
                if (currentUserId == userId && !mutableUiState.value.hasLoadedNotesAtLeastOnce) {
                    mutableUiState.value = mutableUiState.value.copy(hasLoadedNotesAtLeastOnce = true)
                }
            }
        }
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
        if (session != null) {
            viewModelScope.launch {
                val activeSession = refreshSessionIfNeeded(session) ?: return@launch
                consumePendingShareImports(activeSession)
                syncInitialNotes(activeSession)
                refreshSubscription()
                refreshCredits()
                startSessionRefreshLoop(activeSession)
            }
        }
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

    fun sendCode(email: String) = launchAuthBusy(AuthOperation.SendEmailCode) {
        authRepository.sendEmailCode(email)
        mutableUiState.value = mutableUiState.value.copy(codeSentTo = email.trim().lowercase())
    }

    fun verifyCode(code: String) = launchAuthBusy(AuthOperation.VerifyEmailCode) {
        val email = requireNotNull(mutableUiState.value.codeSentTo)
        val session = authRepository.verifyEmailCode(email, code)
        activateSession(session)
    }

    fun signInWithGoogleIdToken(idToken: String) = launchAuthBusy(AuthOperation.GoogleSignIn) {
        val session = authRepository.signInWithGoogleIdToken(idToken)
        activateSession(session)
    }

    fun beginAppleOAuth(): Uri = authRepository.beginAppleOAuth()

    fun reportAuthError(message: String) {
        mutableUiState.value = mutableUiState.value.copy(errorMessage = message)
    }

    fun handleOAuthCallback(uri: Uri) = launchAuthBusy(AuthOperation.AppleSignIn) {
        val session = authRepository.importOAuthCallback(uri)
        activateSession(session)
    }

    fun backToEmail() {
        mutableUiState.value = mutableUiState.value.copy(codeSentTo = null, errorMessage = null)
    }

    fun signOut() {
        if (signOutJob?.isActive == true) return
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session
        cancelVoiceWork()
        sessionRefreshJob?.cancel()
        sessionRefreshJob = null
        pushRegistrationJob?.cancel()
        pushRegistrationJob = null
        mutableUiState.value = mutableUiState.value.copy(busy = true, errorMessage = null)
        signOutJob = viewModelScope.launch {
            if (session != null) {
                runCatching { pushNotifications.deactivate(session.accessToken) }
                    .onFailure {
                        Log.w(TAG, "Push device deactivation failed during sign out", it)
                        runCatching { pushNotifications.clearLocalRegistration() }
                    }
            } else {
                runCatching { pushNotifications.clearLocalRegistration() }
            }
            authRepository.signOut()
            mutableVoiceNoteStates.value = emptyMap()
            mutableUiState.value = AppUiState(authState = AuthState.SignedOut)
        }
    }

    fun refreshPushRegistration() {
        if (pushRegistrationJob?.isActive == true) return
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        pushRegistrationJob = viewModelScope.launch {
            val activeSession = refreshSessionIfNeeded(session) ?: return@launch
            registerPushForSession(activeSession)
        }
    }

    fun refreshSubscription() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching { accountApi.subscriptionStatus(session.accessToken) }
                .onSuccess { status -> mutableUiState.value = mutableUiState.value.copy(
                    subscriptionTier = status.tier,
                    subscriptionExpiresAt = status.expiresAt,
                    activeSubscriptionProductId = status.activeProductId,
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

    fun syncRevenueCatSubscription() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching { accountApi.syncRevenueCatSubscription(session.accessToken) }
                .onSuccess { status ->
                    if (currentUserId == session.user.id) {
                        mutableUiState.value = mutableUiState.value.copy(
                            subscriptionTier = status.tier,
                            subscriptionExpiresAt = status.expiresAt,
                            activeSubscriptionProductId = status.activeProductId,
                            introPaywallResolved = true,
                            introPaywallRequired = status.tier != "pro" &&
                                !onboardingPreferences.hasShownIntroPaywall(session.user.id),
                        )
                        if (status.tier == "pro") onboardingPreferences.setIntroPaywallShown(session.user.id)
                        refreshCredits()
                    }
                }
                .onFailure { refreshSubscription() }
        }
    }

    fun refreshCredits() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            runCatching { accountApi.creditBalance(session.accessToken) }
                .onSuccess { response ->
                    if (currentUserId == session.user.id) {
                        mutableUiState.value = mutableUiState.value.copy(
                            creditBalance = response.balance,
                            hasFetchedCreditBalance = true,
                        )
                    }
                }
        }
    }

    fun deleteAccount() {
        cancelVoiceWork()
        launchBusy {
            val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return@launchBusy
            // Invalidate responses from sync requests that were already in flight
            // before the destructive server operation began.
            notesRepository.invalidateInFlightSync(session.user.id)
            accountApi.deleteAccount(session.accessToken)
            try {
                sessionRefreshJob?.cancel()
                sessionRefreshJob = null
                pendingImportMonitor?.cancel()
                notesRepository.clearLocalUserData(session.user.id)
                recordingFileManager.clearAll()
                recipeStore.clearUserData()
                onboardingPreferences.clearUserData(session.user.id)
                appRatingTracker.clearUserData()
                mutablePendingRecordings.value = emptyList()
                mutableVoiceNoteStates.value = emptyMap()
                mutableAISkillState.value = AISkillUiState()
                mutableContextChatState.value = ContextChatUiState()
                runCatching { pushNotifications.clearLocalRegistration() }
            } finally {
                // The remote account is already deleted, so never retain its session locally.
                authRepository.signOut()
                mutableUiState.value = AppUiState(authState = AuthState.SignedOut)
            }
        }
    }

    fun verifyGooglePlayPurchase(productId: String, purchaseToken: String) = launchBusy {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return@launchBusy
        val status = accountApi.verifyGooglePlayPurchase(session.accessToken, productId, purchaseToken)
        mutableUiState.value = mutableUiState.value.copy(
            subscriptionTier = status.tier,
            subscriptionExpiresAt = status.expiresAt,
            activeSubscriptionProductId = status.activeProductId ?: productId,
            introPaywallResolved = true,
            introPaywallRequired = false,
        )
        onboardingPreferences.setIntroPaywallShown(session.user.id)
        refreshCredits()
    }

    /**
     * Claims the temporary ACTION_SEND grant immediately. The original video is copied and
     * reduced to an audio-only recovery file before this function returns its result to UI.
     */
    fun captureSharedVideo(uri: Uri, declaredMimeType: String?, sourcePackage: String?) {
        val captureKey = uri.toString()
        if (sharedVideoCaptureJobs.containsKey(captureKey)) return
        val ownerUserId = currentUserId
        val job = viewModelScope.launch(start = CoroutineStart.LAZY) {
            mutableUiState.value = mutableUiState.value.copy(sharedVideoPreparing = true, errorMessage = null)
            try {
                sharedVideoImporter.import(
                    SharedVideoImportSource(uri, declaredMimeType, sourcePackage),
                    ownerUserId = ownerUserId,
                )
                refreshPendingRecordings()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                Log.w(TAG, "Shared video capture failed", error)
                mutableUiState.value = mutableUiState.value.copy(
                    errorMessage = getApplication<Application>().getString(sharedVideoErrorResource(error)),
                )
            } finally {
                sharedVideoCaptureJobs.remove(captureKey)
                mutableUiState.value = mutableUiState.value.copy(
                    sharedVideoPreparing = sharedVideoCaptureJobs.values.any { it.isActive },
                )
            }
        }
        if (sharedVideoCaptureJobs.putIfAbsent(captureKey, job) == null) job.start() else job.cancel()
    }

    /** Starts one durable shared-video item. On failure its extracted audio remains retryable. */
    fun processPendingSharedVideoImports(
        section: String,
        tagIds: List<String> = emptyList(),
        onNoteReady: (NoteEntity) -> Unit = {},
        onInsufficientCredits: () -> Unit = {},
    ) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        val recording = mutablePendingRecordings.value.firstOrNull { pending ->
            pending.origin == PendingRecordingOrigin.SharedVideo &&
                (pending.ownerUserId == null || pending.ownerUserId == session.user.id) &&
                pending.file.isFile &&
                !voiceProcessingJobs.containsKey(pending.file.absolutePath) &&
                !sharedVideoAuthorizationJobs.containsKey(pending.file.absolutePath)
        } ?: return
        val recordingKey = recording.file.absolutePath
        val job = viewModelScope.launch(start = CoroutineStart.LAZY) {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Audio)) return@launch
            ensureVoiceSessionActive(session.user.id)
            if (recording.ownerUserId == null) {
                recordingFileManager.setOwnerUserId(recording.file, session.user.id)
                refreshPendingRecordings()
            }
            val authorized = try {
                val creditState = accountApi.consumeVoiceCredits(session.accessToken)
                ensureVoiceSessionActive(session.user.id)
                mutableUiState.value = mutableUiState.value.copy(
                    creditBalance = creditState.balance,
                    hasFetchedCreditBalance = true,
                    subscriptionTier = creditState.tier ?: mutableUiState.value.subscriptionTier,
                )
                true
            } catch (error: SyncHttpException) {
                ensureVoiceSessionActive(session.user.id)
                if (error.statusCode == 402) {
                    mutableUiState.value = mutableUiState.value.copy(
                        creditBalance = 0,
                        hasFetchedCreditBalance = true,
                    )
                }
                false
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                // Match the microphone path: temporary connectivity failures do not destroy capture.
                Log.w(TAG, "Shared video credit preflight unavailable; allowing transcription", error)
                true
            }
            ensureVoiceSessionActive(session.user.id)
            if (authorized) {
                processVoiceRecording(recording.file, section, tagIds, onNoteReady)
            } else {
                onInsufficientCredits()
            }
        }
        if (sharedVideoAuthorizationJobs.putIfAbsent(recordingKey, job) == null) {
            job.invokeOnCompletion { sharedVideoAuthorizationJobs.remove(recordingKey, job) }
            job.start()
        } else {
            job.cancel()
        }
    }

    private fun sharedVideoErrorResource(error: Throwable): Int = when (error) {
        SharedVideoImportException.TooLarge -> R.string.shared_video_import_error_too_large
        SharedVideoImportException.TooLong -> R.string.shared_video_import_error_too_long
        SharedVideoImportException.NoAudioTrack -> R.string.shared_video_import_error_no_audio
        SharedVideoImportException.UnsupportedType,
        SharedVideoImportException.UnableToExtractAudio -> R.string.shared_video_import_error_unsupported
        SharedVideoImportException.Empty -> R.string.shared_video_import_error_empty
        else -> R.string.shared_video_import_error_failed
    }

    fun processVoiceRecording(
        file: File,
        section: String,
        tagIds: List<String> = emptyList(),
        onNoteReady: (NoteEntity) -> Unit = {},
        onOutcome: (PendingRecordingSaveOutcome) -> Unit = {},
    ) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: run {
            onOutcome(PendingRecordingSaveOutcome.Error)
            return
        }
        val recordingKey = file.absolutePath
        val job = viewModelScope.launch(start = CoroutineStart.LAZY) {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Audio)) {
                ensureVoiceSessionActive(session.user.id)
                refreshPendingRecordings()
                onOutcome(PendingRecordingSaveOutcome.ConsentDeclined)
                return@launch
            }
            ensureVoiceSessionActive(session.user.id)
            var outcome = PendingRecordingSaveOutcome.Error
            var voiceNote: NoteEntity? = null
            try {
                voiceNote = noteMutationMutex.withLock {
                    val linkedNote = recordingFileManager.noteId(file)?.let { linkedId ->
                        notesRepository.note(session.user.id, linkedId)?.let { existing ->
                            if (existing.deletedAt != null) {
                                notesRepository.restore(existing)
                                notesRepository.note(session.user.id, existing.id)
                            } else {
                                existing
                            }
                        }
                    }
                    linkedNote ?: notesRepository.createNote(session.user.id, "", section).let { created ->
                        if (tagIds.isEmpty()) created else notesRepository.setNoteTags(created, tagIds)
                    }
                }
                ensureVoiceSessionActive(session.user.id)
                val note = requireNotNull(voiceNote)
                recordingFileManager.setNoteId(file, note.id)
                setVoiceNoteState(
                    note.id,
                    VoiceNoteState.Processing(VoiceNoteProcessingStage.Transcribing),
                )
                onNoteReady(note)

                ensureVoiceSessionActive(session.user.id)
                val voiceSettings = voiceLanguageSettings.value
                val raw = voiceApi.transcribe(
                    session.accessToken, file, recordingFileManager.mimeType(file), Locale.getDefault().toLanguageTag(),
                    voiceSettings.mode, voiceSettings.languageHint, countUsage = false,
                )
                ensureVoiceSessionActive(session.user.id)
                require(raw.isNotBlank()) { "Voice transcription was empty" }
                setVoiceNoteState(
                    note.id,
                    VoiceNoteState.Processing(VoiceNoteProcessingStage.Refining),
                )
                val refined = try {
                    voiceApi.refine(session.accessToken, raw)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (error: Throwable) {
                    Log.w(TAG, "Voice refinement failed; preserving transcription", error)
                    raw
                }
                ensureVoiceSessionActive(session.user.id)
                val finalText = refined.ifBlank { raw }
                val updatedNote = noteMutationMutex.withLock {
                    notesRepository.updateLatestNote(session.user.id, note.id, finalText, note.section)
                }
                ensureVoiceSessionActive(session.user.id)
                checkNotNull(updatedNote) { "Voice note disappeared while processing" }
                recordingFileManager.complete(file)
                val completedState = VoiceNoteState.Completed(
                    originalText = raw,
                    refinedText = finalText,
                )
                setVoiceNoteState(note.id, completedState)
                appRatingTracker.registerVoiceNote()
                refreshCredits()
                sync()
                outcome = PendingRecordingSaveOutcome.Saved
                viewModelScope.launch {
                    delay(10_000)
                    if (
                        currentUserId == session.user.id &&
                        mutableVoiceNoteStates.value[note.id] == completedState
                    ) {
                        setVoiceNoteState(note.id, null)
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                Log.w(TAG, "Voice transcription failed", error)
                if (currentUserId == session.user.id) {
                    val message = getApplication<Application>().getString(R.string.voice_processing_error)
                    val noteId = voiceNote?.id
                    if (noteId == null) {
                        mutableUiState.value = mutableUiState.value.copy(errorMessage = message)
                    } else {
                        setVoiceNoteState(noteId, VoiceNoteState.Failed(message))
                    }
                }
            } finally {
                if (currentCoroutineContext().isActive && currentUserId == session.user.id) {
                    refreshPendingRecordings()
                    onOutcome(outcome)
                }
            }
        }
        voiceProcessingJobs.put(recordingKey, job)?.cancel()
        job.invokeOnCompletion { voiceProcessingJobs.remove(recordingKey, job) }
        job.start()
    }

    /**
     * Mirrors iOS recording preflight: consent and the voice credit are resolved before
     * the microphone starts. The transcription request must therefore use countUsage=false.
     */
    fun authorizeVoiceRecordingStart(
        onAuthorized: () -> Unit,
        onInsufficientCredits: () -> Unit,
    ) {
        if (voiceStartAuthorizationJob?.isActive == true) return
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        voiceStartAuthorizationJob = viewModelScope.launch {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Audio)) return@launch
            ensureVoiceSessionActive(session.user.id)
            val authorized = try {
                val creditState = accountApi.consumeVoiceCredits(session.accessToken)
                ensureVoiceSessionActive(session.user.id)
                mutableUiState.value = mutableUiState.value.copy(
                    creditBalance = creditState.balance,
                    hasFetchedCreditBalance = true,
                    subscriptionTier = creditState.tier ?: mutableUiState.value.subscriptionTier,
                )
                true
            } catch (error: SyncHttpException) {
                ensureVoiceSessionActive(session.user.id)
                if (error.statusCode == 402) {
                    mutableUiState.value = mutableUiState.value.copy(
                        creditBalance = 0,
                        hasFetchedCreditBalance = true,
                    )
                }
                false
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Throwable) {
                // iOS intentionally fails open for connection errors so recording remains usable.
                Log.w(TAG, "Voice recording preflight unavailable; allowing recording", error)
                true
            }
            ensureVoiceSessionActive(session.user.id)
            if (authorized) onAuthorized() else onInsufficientCredits()
        }
    }

    fun retryPendingRecording(
        recording: PendingRecording,
        section: String = "inbox",
        onOutcome: (PendingRecordingSaveOutcome) -> Unit = {},
    ) {
        if (recording.ownerUserId != null && recording.ownerUserId != currentUserId) {
            onOutcome(PendingRecordingSaveOutcome.Error)
            return
        }
        processVoiceRecording(recording.file, section, onOutcome = onOutcome)
    }

    fun deletePendingRecording(recording: PendingRecording) {
        sharedVideoAuthorizationJobs.remove(recording.file.absolutePath)?.cancel()
        voiceProcessingJobs.remove(recording.file.absolutePath)?.cancel()
        recordingFileManager.cancel(recording.file)
        refreshPendingRecordings()
    }

    fun restoreOriginalVoiceResult(noteId: String) {
        val state = mutableVoiceNoteStates.value[noteId] as? VoiceNoteState.Completed ?: return
        setVoiceNoteState(noteId, null)
        val userId = currentUserId ?: return
        viewModelScope.launch {
            noteMutationMutex.withLock {
                notesRepository.updateNoteContent(userId, noteId, state.originalText)
            }
            sync()
        }
    }

    fun dismissVoiceNoteState(noteId: String) {
        setVoiceNoteState(noteId, null)
    }

    private fun setVoiceNoteState(noteId: String, state: VoiceNoteState?) {
        mutableVoiceNoteStates.value = mutableVoiceNoteStates.value.toMutableMap().apply {
            if (state == null) remove(noteId) else put(noteId, state)
        }
        mutableUiState.value = mutableUiState.value.copy(
            voiceProcessing = mutableVoiceNoteStates.value.values.any { it is VoiceNoteState.Processing },
            errorMessage = null,
        )
    }

    private fun refreshPendingRecordings() {
        mutablePendingRecordings.value = recordingFileManager.pendingRecordings()
    }

    private suspend fun ensureVoiceSessionActive(expectedUserId: String) {
        currentCoroutineContext().ensureActive()
        if (currentUserId != expectedUserId) {
            throw CancellationException("Voice processing session changed")
        }
    }

    private fun cancelVoiceWork() {
        voiceStartAuthorizationJob?.cancel()
        voiceStartAuthorizationJob = null
        sharedVideoAuthorizationJobs.values.toList().forEach { it.cancel() }
        sharedVideoAuthorizationJobs.clear()
        voiceProcessingJobs.values.toList().forEach { it.cancel() }
        voiceProcessingJobs.clear()
        mutableVoiceNoteStates.value = emptyMap()
        mutableUiState.value = mutableUiState.value.copy(voiceProcessing = false)
    }

    fun acceptAIDataConsent() = aiConsentManager.accept()

    fun declineAIDataConsent() = aiConsentManager.decline()

    fun runCreatorSkill(
        recipe: AgentRecipe,
        content: String,
        instruction: String? = null,
        onFlowEndedWithoutResult: () -> Unit = {},
    ) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        if (content.isBlank() || mutableAISkillState.value.processingRecipeId != null) return
        viewModelScope.launch {
            if (!aiConsentManager.ensureConsent(AIConsentTrigger.Text)) {
                onFlowEndedWithoutResult()
                return@launch
            }
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
                Log.w(TAG, "AI skill request failed", error)
                if (error is SyncHttpException && error.statusCode == 402) {
                    mutableAISkillState.value = AISkillUiState()
                    mutablePaywallRequests.tryEmit(Unit)
                    refreshCredits()
                    onFlowEndedWithoutResult()
                } else {
                    mutableAISkillState.value = AISkillUiState(
                        errorMessage = getApplication<Application>().getString(R.string.ai_request_error),
                    )
                }
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
                Log.w(TAG, "AI context chat request failed", error)
                if (error is SyncHttpException && error.statusCode == 402) {
                    mutableContextChatState.value = mutableContextChatState.value.copy(
                        processing = false,
                        errorMessage = null,
                    )
                    mutablePaywallRequests.tryEmit(Unit)
                    refreshCredits()
                } else {
                    mutableContextChatState.value = mutableContextChatState.value.copy(
                        processing = false,
                        errorMessage = getApplication<Application>().getString(R.string.ai_request_error),
                    )
                }
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

    fun createNoteForEditing(
        content: String,
        section: String,
        tagIds: List<String> = emptyList(),
        onComplete: (NoteEntity?) -> Unit,
    ) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session
        if (session == null) {
            onComplete(null)
            return
        }
        viewModelScope.launch {
            runCatching {
                noteMutationMutex.withLock {
                    val created = notesRepository.createNote(session.user.id, content, section)
                    if (tagIds.isEmpty()) created else notesRepository.setNoteTags(created, tagIds)
                }
            }.onSuccess { note ->
                onComplete(note)
                sync()
            }.onFailure { error ->
                Log.w(TAG, "Creating editor note failed", error)
                mutableUiState.value = mutableUiState.value.copy(
                    errorMessage = getApplication<Application>().getString(R.string.common_request_failed),
                )
                onComplete(null)
            }
        }
    }

    fun saveNote(existing: NoteEntity?, content: String, section: String, tagIds: List<String>? = null) {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        val requestId = existing?.id?.let(::markLatestEditorMutation)
        viewModelScope.launch {
            val saved = noteMutationMutex.withLock {
                if (existing != null && latestEditorSaveRequest[existing.id] != requestId) {
                    return@withLock null
                }
                val latest = (if (existing == null) {
                    notesRepository.createNote(session.user.id, content, section)
                } else {
                    notesRepository.updateLatestNote(session.user.id, existing.id, content, section)
                }) ?: return@withLock null
                if (tagIds == null) latest else notesRepository.setNoteTags(latest, tagIds)
            }
            if (existing != null && requestId != null) {
                latestEditorSaveRequest.remove(existing.id, requestId)
            }
            if (saved != null) sync()
        }
    }

    fun replaceNoteContent(noteId: String, content: String) {
        val userId = currentUserId ?: return
        viewModelScope.launch {
            noteMutationMutex.withLock {
                notesRepository.updateNoteContent(userId, noteId, content)
            }
            sync()
        }
    }

    fun deleteNote(note: NoteEntity) {
        markLatestEditorMutation(note.id)
        viewModelScope.launch {
            noteMutationMutex.withLock { notesRepository.moveToTrash(note) }
            sync()
        }
    }

    fun restoreNote(note: NoteEntity) {
        markLatestEditorMutation(note.id)
        viewModelScope.launch {
            noteMutationMutex.withLock { notesRepository.restore(note) }
            sync()
        }
    }

    fun togglePin(note: NoteEntity) {
        viewModelScope.launch { notesRepository.togglePin(note); sync() }
    }

    fun moveNote(note: NoteEntity, section: String) {
        if (note.deletedAt != null || note.section == section) return
        viewModelScope.launch { notesRepository.moveNote(note.userId, note.id, section); sync() }
    }

    fun permanentlyDelete(note: NoteEntity) {
        val userId = (mutableUiState.value.authState as? AuthState.SignedIn)?.session?.user?.id ?: return
        markLatestEditorMutation(note.id)
        viewModelScope.launch {
            noteMutationMutex.withLock { notesRepository.permanentlyDelete(userId, note) }
            sync()
        }
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

    fun addTagToNote(
        noteId: String,
        name: String,
        colorHex: String,
        parentId: String?,
        onAttached: (TagEntity) -> Unit = {},
    ) {
        val userId = currentUserId ?: return
        if (name.isBlank()) return
        viewModelScope.launch {
            runCatching {
                noteMutationMutex.withLock {
                    val tag = notesRepository.findOrCreateTag(userId, name, colorHex, parentId)
                    check(notesRepository.addTagToNote(userId, noteId, tag))
                    tag
                }
            }.onSuccess { tag ->
                onAttached(tag)
                sync()
            }.onFailure { error ->
                Log.w(TAG, "Adding note tag failed", error)
                mutableUiState.value = mutableUiState.value.copy(
                    errorMessage = getApplication<Application>().getString(R.string.common_request_failed),
                )
            }
        }
    }

    fun removeTagFromNote(noteId: String, tagId: String) {
        val userId = currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                noteMutationMutex.withLock {
                    check(notesRepository.removeTagFromNote(userId, noteId, tagId))
                }
            }.onSuccess {
                sync()
            }.onFailure { error ->
                Log.w(TAG, "Removing note tag failed", error)
                mutableUiState.value = mutableUiState.value.copy(
                    errorMessage = getApplication<Application>().getString(R.string.common_request_failed),
                )
            }
        }
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
        tagIds: List<String> = emptyList(),
        onPlainText: (String) -> Unit,
        onInsufficientCredits: () -> Unit,
    ) {
        val url = extractWebUrl(text)
        if (url == null) { onPlainText(text); return }
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch {
            linkImportStartMutex.withLock {
                val now = System.currentTimeMillis()
                val recentKey = "${session.user.id}|$url"
                recentLinkImportUrls.entries.removeIf { now - it.value >= 60_000L }
                val recentlyStarted = recentLinkImportUrls[recentKey]?.let { now - it < 20_000L } == true
                if (recentlyStarted || notesRepository.hasPendingLinkImport(session.user.id, url)) {
                    return@withLock
                }
                recentLinkImportUrls[recentKey] = now

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
                    val noteId = UUID.randomUUID().toString()
                    homeNoteRevealRequests.trySend(HomeNoteRevealRequest(session.user.id, noteId))
                    notesRepository.importLink(
                        session.user.id,
                        session.accessToken,
                        url,
                        section,
                        placeholder,
                        mediaLinkSections.value,
                        tagIds,
                        noteId,
                        contentLocale = configuredAppLanguageTag(),
                    )
                }
                    .onSuccess {
                        BackgroundSyncScheduler.enqueueLinkImportRecovery(getApplication())
                        refreshCredits()
                        sync()
                    }
                    .onFailure { error ->
                        if (error is SyncHttpException && error.statusCode == 402) {
                            onInsufficientCredits()
                            refreshCredits()
                        } else {
                            Log.w(TAG, "Shared link import failed", error)
                            mutableUiState.value = mutableUiState.value.copy(
                                errorMessage = getApplication<Application>().getString(R.string.link_import_failed),
                            )
                        }
                    }
            }
        }
    }

    fun sync() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch { syncSession(session) }
    }

    fun setEditorActive(active: Boolean) {
        editorActive = active
        if (active) {
            // Cancelling a poll after its HTTP commit is safe because protocol v4
            // retries the persisted mutation ID instead of guessing from timestamps.
            foregroundPollSyncJob?.cancel()
            foregroundPollSyncJob = null
        }
    }

    fun syncFromForegroundPoll() {
        if (editorActive || foregroundPollSyncJob?.isActive == true) return
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        foregroundPollSyncJob = viewModelScope.launch {
            if (!editorActive) syncSession(session)
        }
    }

    private suspend fun syncSession(session: AuthSession) {
        try {
            notesRepository.purgeExpiredTrash(session.user.id)
            notesRepository.sync(session.user.id, session.accessToken)
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            Log.w(TAG, "Note sync failed", error)
            // Keep a network-constrained retry durable across process death.
            // If a foreground worker is already pending/running, unique KEEP
            // semantics avoid creating duplicate work.
            BackgroundSyncScheduler.enqueueForegroundSync(getApplication())
            if (currentUserId == session.user.id) {
                mutableUiState.value = mutableUiState.value.copy(
                    errorMessage = getApplication<Application>().getString(R.string.sync_error),
                )
            }
        }
    }

    /**
     * Hands durable share-extension work to Room. This mirrors iOS
     * `consumePendingShareImports`: a server job is adopted when available;
     * otherwise the exact same UUID is enqueued after sign-in/foregrounding.
     */
    fun consumePendingShareImports() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        viewModelScope.launch { consumePendingShareImports(session) }
    }

    private suspend fun consumePendingShareImports(session: AuthSession) = pendingShareImportMutex.withLock {
        pendingShareImportQueue.pending().forEach { pending ->
            if (pending.ownerUserId != null && pending.ownerUserId != session.user.id) return@forEach
            if (notesRepository.note(session.user.id, pending.id) != null) {
                // A background sync can download the server-created note before
                // MainActivity resumes. It is still the newly shared note and must
                // trigger the same one-shot reveal as a foreground adoption.
                homeNoteRevealRequests.trySend(HomeNoteRevealRequest(session.user.id, pending.id))
                pendingShareImportAdoptions.trySend(
                    PendingShareImportAdoption(
                        userId = session.user.id,
                        noteId = pending.id,
                    ),
                )
                pendingShareImportQueue.remove(pending.id)
                return@forEach
            }

            val placeholder = buildString {
                append("# ")
                append(getApplication<Application>().getString(R.string.quick_capture_link_import_placeholder_title))
                append("\n\n")
                append(
                    getApplication<Application>().getString(
                        R.string.quick_capture_link_import_placeholder_format,
                        pending.source.host.ifBlank { pending.url },
                    ),
                )
            }
            runCatching {
                val jobId = pending.importJobId
                if (jobId != null) {
                    notesRepository.adoptPendingLinkImport(
                        userId = session.user.id,
                        noteId = pending.id,
                        placeholder = placeholder,
                        source = pending.source,
                        importJobId = jobId,
                        importStatus = pending.importStatus ?: "queued",
                        createdAt = pending.createdAt,
                    )
                } else {
                    notesRepository.importLink(
                        userId = session.user.id,
                        accessToken = session.accessToken,
                        url = pending.url,
                        section = "inbox",
                        placeholder = placeholder,
                        mediaLinkSections = MediaLinkSectionsDto.TranscriptOnly,
                        noteId = pending.id,
                        source = pending.source,
                        contentLocale = configuredAppLanguageTag(),
                    )
                }
            }.onSuccess {
                homeNoteRevealRequests.trySend(HomeNoteRevealRequest(session.user.id, pending.id))
                pendingShareImportAdoptions.trySend(
                    PendingShareImportAdoption(
                        userId = session.user.id,
                        noteId = pending.id,
                    ),
                )
                pendingShareImportQueue.remove(pending.id)
                BackgroundSyncScheduler.enqueueLinkImportRecovery(getApplication())
            }.onFailure { error ->
                Log.w(TAG, "Pending shared link hand-off failed", error)
                // `importLink` writes a visible failed placeholder before throwing.
                // Once that row exists, the durable hand-off has completed and must
                // not enqueue the same paid import again on every foreground event.
                if (notesRepository.note(session.user.id, pending.id) != null) {
                    homeNoteRevealRequests.trySend(HomeNoteRevealRequest(session.user.id, pending.id))
                    pendingShareImportQueue.remove(pending.id)
                }
            }
        }
    }

    suspend fun syncForPushDestination() {
        val session = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: return
        val activeSession = refreshSessionIfNeeded(session) ?: return
        runCatching {
            notesRepository.purgeExpiredTrash(activeSession.user.id)
            notesRepository.sync(activeSession.user.id, activeSession.accessToken)
        }.onFailure {
            Log.w(TAG, "Push destination sync failed", it)
            mutableUiState.value = mutableUiState.value.copy(
                errorMessage = getApplication<Application>().getString(R.string.sync_error),
            )
        }
    }

    private fun syncInitialNotes(session: com.sponteoai.chillscript.auth.AuthSession) {
        if (currentUserId == session.user.id) {
            mutableUiState.value = mutableUiState.value.copy(initialNotesSyncing = true)
        }
        viewModelScope.launch {
            try {
                runCatching {
                    notesRepository.sync(session.user.id, session.accessToken)
                    notesRepository.purgeExpiredTrash(session.user.id)
                }.onFailure {
                    Log.w(TAG, "Initial note sync failed", it)
                    if (currentUserId == session.user.id) {
                        mutableUiState.value = mutableUiState.value.copy(
                            errorMessage = getApplication<Application>().getString(R.string.sync_error),
                        )
                    }
                }
            } finally {
                if (currentUserId == session.user.id) {
                    mutableUiState.value = mutableUiState.value.copy(initialNotesSyncing = false)
                }
            }
        }
    }

    private fun activateSession(session: AuthSession) {
        if (currentUserId != session.user.id) cancelVoiceWork()
        mutableUiState.value = AppUiState(authState = AuthState.SignedIn(session))
        startSessionRefreshLoop(session)
        consumePendingShareImports()
        syncInitialNotes(session)
        refreshSubscription()
        refreshCredits()
        refreshPushRegistration()
    }

    private suspend fun registerPushForSession(session: AuthSession) {
        runCatching {
            pushNotifications.refreshRegistration(
                userId = session.user.id,
                accessToken = session.accessToken,
            )
        }.onFailure { Log.w(TAG, "Push device registration failed", it) }
    }

    private fun startSessionRefreshLoop(initialSession: AuthSession) {
        sessionRefreshJob?.cancel()
        sessionRefreshJob = viewModelScope.launch {
            var session = initialSession
            while (isActive && currentUserId == session.user.id) {
                val nowSeconds = System.currentTimeMillis() / 1_000L
                val expiresAt = session.expiresAt ?: (nowSeconds + session.expiresIn)
                val refreshAt = expiresAt - SESSION_REFRESH_LEEWAY_SECONDS
                delay(((refreshAt - nowSeconds).coerceAtLeast(1L)) * 1_000L)

                val current = (mutableUiState.value.authState as? AuthState.SignedIn)?.session
                    ?: return@launch
                val refreshed = refreshSessionIfNeeded(current, force = true) ?: return@launch
                if (refreshed.accessToken == current.accessToken) {
                    // A temporary network failure should not destroy a valid refresh token.
                    delay(SESSION_REFRESH_RETRY_MILLIS)
                }
                session = refreshed
            }
        }
    }

    private suspend fun refreshSessionIfNeeded(session: AuthSession, force: Boolean = false): AuthSession? =
        sessionRefreshMutex.withLock {
            val current = (mutableUiState.value.authState as? AuthState.SignedIn)?.session ?: session
            val nowSeconds = System.currentTimeMillis() / 1_000L
            val expiresAt = current.expiresAt ?: (nowSeconds + current.expiresIn)
            if (!force && expiresAt - nowSeconds > SESSION_REFRESH_LEEWAY_SECONDS) return@withLock current

            runCatching { authRepository.refresh(current) }
                .onSuccess { refreshed ->
                    mutableUiState.value = mutableUiState.value.copy(authState = AuthState.SignedIn(refreshed))
                }
                .fold(
                    onSuccess = { it },
                    onFailure = { error ->
                        val isRejectedRefresh = error is com.sponteoai.chillscript.auth.AuthException &&
                            error.statusCode in setOf(400, 401, 403)
                        if (isRejectedRefresh) {
                            cancelVoiceWork()
                            authRepository.signOut()
                            mutableUiState.value = AppUiState(authState = AuthState.SignedOut)
                            null
                        } else {
                            current
                        }
                    },
                )
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
                .onFailure {
                    Log.w(TAG, "App request failed", it)
                    mutableUiState.value = mutableUiState.value.copy(
                        errorMessage = getApplication<Application>().getString(R.string.common_request_failed),
                    )
                }
            mutableUiState.value = mutableUiState.value.copy(busy = false)
        }
    }

    private fun launchAuthBusy(operation: AuthOperation, block: suspend () -> Unit) {
        viewModelScope.launch {
            mutableUiState.value = mutableUiState.value.copy(busy = true, errorMessage = null)
            runCatching { block() }
                .onFailure { error ->
                    Log.w(TAG, "Authentication request failed", error)
                    val messageResource = when (classifyAuthFailure(operation, error)) {
                        AuthFailure.Cancelled -> null
                        AuthFailure.Network -> R.string.auth_login_error_network
                        AuthFailure.TooManyRequests -> R.string.auth_login_error_too_many_requests
                        AuthFailure.InvalidVerificationCode -> R.string.auth_login_error_invalid_verification_code
                        AuthFailure.SendCodeFailed -> R.string.auth_login_error_send_failed
                        AuthFailure.VerificationFailed -> R.string.auth_login_error_verification_failed
                        AuthFailure.GoogleSignInFailed -> R.string.auth_google_failed
                        AuthFailure.AppleSignInFailed -> R.string.auth_apple_failed
                    }
                    mutableUiState.value = mutableUiState.value.copy(
                        errorMessage = messageResource?.let {
                            getApplication<Application>().getString(it)
                        },
                    )
                }
            mutableUiState.value = mutableUiState.value.copy(busy = false)
        }
    }

    private fun configuredAppLanguageTag(): String {
        val configuredLocales = getApplication<Application>().resources.configuration.locales
        return configuredLocales.get(0)?.toLanguageTag()?.takeIf { it.isNotBlank() }
            ?: Locale.getDefault().toLanguageTag().ifBlank { "en" }
    }

    private companion object {
        const val TAG = "AppViewModel"
        const val SESSION_REFRESH_LEEWAY_SECONDS = 5 * 60L
        const val SESSION_REFRESH_RETRY_MILLIS = 30_000L
    }

    private fun markLatestEditorMutation(noteId: String): Long =
        noteMutationRequestCounter.incrementAndGet().also { requestId ->
            latestEditorSaveRequest[noteId] = requestId
        }
}
