package com.sponteoai.chillscript

import android.content.Intent
import android.content.ClipboardManager
import android.content.ClipDescription
import android.os.Bundle
import android.net.Uri
import android.provider.Settings
import android.Manifest
import android.media.MediaPlayer
import android.content.pm.PackageManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Label
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.automirrored.outlined.Undo
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Logout
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.PauseCircle
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Button
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Tab
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.TextRange
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import com.sponteoai.chillscript.auth.AuthState
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import com.sponteoai.chillscript.billing.BillingProduct
import com.sponteoai.chillscript.billing.BillingUiState
import com.sponteoai.chillscript.billing.PlayBillingManager
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import com.sponteoai.chillscript.voice.VoiceRecorder
import com.sponteoai.chillscript.voice.PendingRecording
import com.sponteoai.chillscript.domain.ChecklistDraft
import com.sponteoai.chillscript.domain.ChecklistDraftItem
import com.sponteoai.chillscript.domain.ChecklistMarkdown
import com.sponteoai.chillscript.domain.MarkdownEditing
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TagHierarchy
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.sourceMetadata
import com.sponteoai.chillscript.ui.markdown.MarkdownText
import com.sponteoai.chillscript.ui.source.NoteSourceCard
import com.sponteoai.chillscript.onboarding.OnboardingPreferences
import com.sponteoai.chillscript.onboarding.OnboardingScreen
import com.sponteoai.chillscript.onboarding.OnboardingSubscriptionScreen
import com.sponteoai.chillscript.ai.AIConsentDialog
import com.sponteoai.chillscript.ai.AISkillApplyMode
import com.sponteoai.chillscript.ai.AISkillTextApplication
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.TextSelection
import com.sponteoai.chillscript.ui.skills.AISkillPreviewDialog
import com.sponteoai.chillscript.ui.skills.AISkillProcessingDialog
import com.sponteoai.chillscript.ui.skills.CreatorSkillNotePickerDialog
import com.sponteoai.chillscript.ui.skills.CreatorSkillPickerDialog
import com.sponteoai.chillscript.ui.skills.CreatorSkillsLibrary
import com.sponteoai.chillscript.ui.skills.CreatorSkillsRail
import com.sponteoai.chillscript.ui.skills.TranslateTargetDialog
import com.sponteoai.chillscript.ui.chat.ContextChatScreen
import com.sponteoai.chillscript.teleprompter.TeleprompterCameraScreen
import com.sponteoai.chillscript.export.NoteExportFormat
import com.sponteoai.chillscript.export.NotesExporter
import com.sponteoai.chillscript.export.NotesExportProgress
import com.sponteoai.chillscript.export.NotesExportStage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.withContext
import java.util.Locale
import com.sponteoai.chillscript.preferences.VoiceLanguageSettings
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import com.sponteoai.chillscript.data.remote.extractWebUrl
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()
    private val sharedText = mutableStateOf<String?>(null)
    private val recordRequest = mutableLongStateOf(0L)
    private lateinit var credentialManager: CredentialManager
    private lateinit var billingManager: PlayBillingManager
    private lateinit var onboardingPreferences: OnboardingPreferences
    private lateinit var reviewManager: ReviewManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        credentialManager = CredentialManager.create(this)
        billingManager = PlayBillingManager(this, viewModel::verifyGooglePlayPurchase)
        onboardingPreferences = OnboardingPreferences(this)
        reviewManager = ReviewManagerFactory.create(this)
        billingManager.connect()
        sharedText.value = intent.sharedPlainText()
        if (intent.isRecordRequest()) recordRequest.longValue = System.nanoTime()
        intent.oauthCallback()?.let(viewModel::handleOAuthCallback)
        setContent {
            val uiState by viewModel.uiState.collectAsState()
            val notes by viewModel.notes.collectAsState()
            val tags by viewModel.tags.collectAsState()
            val noteTags by viewModel.noteTags.collectAsState()
            val searchResults by viewModel.searchResults.collectAsState()
            val pendingRecordings by viewModel.pendingRecordings.collectAsState()
            val billingState by billingManager.state.collectAsState()
            val aiConsentPrompt by viewModel.aiConsentPrompt.collectAsState()
            var showRatingPrompt by remember { mutableStateOf(false) }
            LaunchedEffect(Unit) {
                viewModel.reviewRequests.collect { showRatingPrompt = true }
            }
            var hasViewedIntro by remember { mutableStateOf(onboardingPreferences.hasViewedIntroOnDevice()) }
            ChillScriptTheme {
                when (uiState.authState) {
                    AuthState.Checking -> LoadingScreen()
                    AuthState.SignedOut -> if (hasViewedIntro) {
                        LoginScreen(uiState, viewModel, ::startGoogleSignIn, ::startAppleSignIn)
                    } else {
                        OnboardingScreen {
                            onboardingPreferences.setIntroViewedOnDevice()
                            hasViewedIntro = true
                        }
                    }
                    is AuthState.SignedIn -> if (!uiState.introPaywallResolved) LoadingScreen() else if (uiState.introPaywallRequired) {
                        OnboardingSubscriptionScreen(
                            billingState = billingState,
                            onPurchase = { product -> viewModel.currentUserId?.let { billingManager.launchPurchase(this, product, it) } },
                            onRestore = billingManager::restorePurchases,
                            onDismiss = viewModel::dismissIntroPaywall,
                            onOpenUrl = { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(it))) },
                        )
                    } else HomeScreen(
                        notes, searchResults, tags, noteTags, pendingRecordings, sharedText.value, uiState, viewModel,
                        onSharedTextConsumed = { sharedText.value = null },
                        recordRequest = recordRequest.longValue,
                        onRecordRequestConsumed = { recordRequest.longValue = 0L },
                        billingState = billingState,
                        onPurchase = { product -> viewModel.currentUserId?.let { billingManager.launchPurchase(this, product, it) } },
                        onRestorePurchases = billingManager::restorePurchases,
                        onOpenUrl = { target ->
                            val action = if (target.startsWith("package:")) Settings.ACTION_APPLICATION_DETAILS_SETTINGS else Intent.ACTION_VIEW
                            startActivity(Intent(action, Uri.parse(target)))
                        },
                    )
                }
                aiConsentPrompt?.let { prompt ->
                    AIConsentDialog(
                        prompt = prompt,
                        onAccept = viewModel::acceptAIDataConsent,
                        onDecline = viewModel::declineAIDataConsent,
                        onOpenPrivacyPolicy = { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.chillnoteai.com/privacy"))) },
                    )
                }
                if (showRatingPrompt) AlertDialog(
                    onDismissRequest = { showRatingPrompt = false },
                    title = { Text(stringResource(R.string.home_rating_prompt_title)) },
                    text = { Text(stringResource(R.string.home_rating_prompt_message)) },
                    confirmButton = {
                        TextButton(onClick = {
                            showRatingPrompt = false
                            launchInAppReview()
                        }) { Text(stringResource(R.string.home_rating_prompt_action_like)) }
                    },
                    dismissButton = {
                        TextButton(onClick = {
                            showRatingPrompt = false
                            openFeedbackEmail()
                        }) { Text(stringResource(R.string.home_rating_prompt_action_dislike)) }
                    },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedText.value = intent.sharedPlainText()
        if (intent.isRecordRequest()) recordRequest.longValue = System.nanoTime()
        intent.oauthCallback()?.let(viewModel::handleOAuthCallback)
    }

    override fun onResume() {
        super.onResume()
        if (intent.action != Intent.ACTION_SEND) importNewClipboardCreatorLink()
    }

    override fun onDestroy() {
        billingManager.close()
        super.onDestroy()
    }

    private fun startGoogleSignIn() {
        lifecycleScope.launch {
            try {
                val option = GetGoogleIdOption.Builder()
                    .setFilterByAuthorizedAccounts(false)
                    .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
                    .build()
                val result = credentialManager.getCredential(
                    context = this@MainActivity,
                    request = GetCredentialRequest.Builder().addCredentialOption(option).build(),
                )
                val credential = result.credential
                if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
                    viewModel.signInWithGoogleIdToken(googleCredential.idToken)
                } else {
                    viewModel.reportAuthError(getString(R.string.auth_google_invalid_credential))
                }
            } catch (_: NoCredentialException) {
                viewModel.reportAuthError(getString(R.string.auth_google_no_account))
            } catch (error: GetCredentialException) {
                viewModel.reportAuthError(error.message ?: getString(R.string.auth_google_failed))
            } catch (error: Throwable) {
                viewModel.reportAuthError(error.message ?: getString(R.string.auth_google_failed))
            }
        }
    }

    private fun startAppleSignIn() {
        val redirect = Uri.encode("chillscript://auth-callback")
        val url = Uri.parse("${BuildConfig.SUPABASE_URL}/auth/v1/authorize?provider=apple&redirect_to=$redirect")
        runCatching { startActivity(Intent(Intent.ACTION_VIEW, url)) }
            .onFailure { viewModel.reportAuthError(getString(R.string.auth_apple_failed)) }
    }

    private fun launchInAppReview() {
        reviewManager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) reviewManager.launchReviewFlow(this, request.result)
        }
    }

    private fun openFeedbackEmail() {
        val uri = Uri.parse("mailto:support@chillnoteai.com?subject=ChillScript%20Feedback")
        runCatching { startActivity(Intent(Intent.ACTION_SENDTO, uri)) }
    }

    private fun importNewClipboardCreatorLink() {
        if (viewModel.currentUserId == null) return
        val clipboard = getSystemService(ClipboardManager::class.java)
        val description = clipboard.primaryClipDescription ?: return
        if (!description.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN) &&
            !description.hasMimeType(ClipDescription.MIMETYPE_TEXT_HTML)
        ) return
        val text = clipboard.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()?.trim().orEmpty()
        val url = extractWebUrl(text) ?: return
        val isCreatorLink = runCatching { sourceForUrl(url).platformID != "web" }.getOrDefault(false)
        if (!isCreatorLink) return
        val fingerprint = "${description.timestamp}:${text.hashCode()}"
        val preferences = getSharedPreferences("clipboard_import", MODE_PRIVATE)
        if (preferences.getString("last_clip", null) == fingerprint) return
        preferences.edit().putString("last_clip", fingerprint).apply()
        sharedText.value = url
    }
}

private fun Intent.sharedPlainText(): String? =
    takeIf { action == Intent.ACTION_SEND && type?.startsWith("text/") == true }
        ?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()

private fun Intent.oauthCallback(): Uri? = data?.takeIf { it.scheme == "chillscript" && it.host == "auth-callback" }

private fun Intent.isRecordRequest(): Boolean =
    action == Intent.ACTION_VIEW && data?.host == "record" && data?.scheme in setOf("chillscript", "chillnote")

private data class AppliedAISkillTransformation(
    val recipe: AgentRecipe,
    val instruction: String?,
    val inputContent: String,
    val sourceContent: String,
    val sourceSelection: TextSelection,
    val mode: AISkillApplyMode,
    val targetNoteId: String?,
)

@Composable private fun LoadingScreen() = Column(
    Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), Arrangement.Center, Alignment.CenterHorizontally,
) { CircularProgressIndicator() }

@Composable
private fun LoginScreen(
    state: AppUiState,
    viewModel: AppViewModel,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("ChillScript", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.auth_login_subtitle), modifier = Modifier.padding(top = 8.dp, bottom = 32.dp))
        Button(
            onClick = onGoogleSignIn,
            enabled = !state.busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            Icon(Icons.Outlined.AccountCircle, null)
            Text(stringResource(R.string.auth_login_google_button), modifier = Modifier.padding(start = 10.dp))
        }
        Button(
            onClick = onAppleSignIn,
            enabled = !state.busy,
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp).height(52.dp),
        ) { Text(stringResource(R.string.auth_login_apple_button)) }
        Text(stringResource(R.string.auth_login_or), modifier = Modifier.padding(vertical = 16.dp))
        if (state.codeSentTo == null) {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it; viewModel.clearError() },
                label = { Text(stringResource(R.string.auth_login_email_placeholder)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { viewModel.sendCode(email) },
                enabled = email.isNotBlank() && !state.busy,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp).height(52.dp),
            ) { if (state.busy) CircularProgressIndicator() else Text(stringResource(R.string.auth_login_send_code)) }
        } else {
            Text(stringResource(R.string.auth_login_code_sent_to_format, state.codeSentTo))
            OutlinedTextField(
                value = code,
                onValueChange = { code = it.filter(Char::isDigit); viewModel.clearError() },
                label = { Text(stringResource(R.string.auth_login_verification_code_placeholder)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            )
            Button(
                onClick = { viewModel.verifyCode(code) },
                enabled = code.isNotBlank() && !state.busy,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp).height(52.dp),
            ) { if (state.busy) CircularProgressIndicator() else Text(stringResource(R.string.auth_login_verify_button)) }
            Text(
                stringResource(R.string.auth_login_use_different_email),
                modifier = Modifier.padding(top = 16.dp).clickable { viewModel.backToEmail() },
                color = MaterialTheme.colorScheme.primary,
            )
        }
        state.errorMessage?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 14.dp)) }
        Text(stringResource(R.string.auth_login_legal_plain), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 28.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreen(
    notes: List<NoteEntity>, searchResults: List<NoteEntity>, tags: List<TagEntity>, noteTags: List<NoteTagCrossRef>,
    pendingRecordings: List<PendingRecording>,
    sharedText: String?, uiState: AppUiState, viewModel: AppViewModel, onOpenUrl: (String) -> Unit,
    onSharedTextConsumed: () -> Unit,
    recordRequest: Long, onRecordRequestConsumed: () -> Unit,
    billingState: BillingUiState, onPurchase: (BillingProduct) -> Unit, onRestorePurchases: () -> Unit,
) {
    val sections = listOf("inbox", "drafts", "published", "trash")
    var selectedSection by remember { mutableStateOf("inbox") }
    var editorText by remember { mutableStateOf(TextFieldValue("")) }
    var checklistDraft by remember { mutableStateOf<ChecklistDraft?>(null) }
    var editorPreview by remember { mutableStateOf(false) }
    var undoStack by remember { mutableStateOf<List<TextFieldValue>>(emptyList()) }
    var redoStack by remember { mutableStateOf<List<TextFieldValue>>(emptyList()) }
    var editorOpen by remember { mutableStateOf(false) }
    var editingNote by remember { mutableStateOf<NoteEntity?>(null) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedTagId by remember { mutableStateOf<String?>(null) }
    var showCreateTag by remember { mutableStateOf(false) }
    var showManageTags by remember { mutableStateOf(false) }
    var editingTag by remember { mutableStateOf<TagEntity?>(null) }
    var isSelectionMode by remember { mutableStateOf(false) }
    var selectedNoteIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var showBatchTagDialog by remember { mutableStateOf(false) }
    var showBatchDeleteConfirmation by remember { mutableStateOf(false) }
    var selectedEditorTagIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var showSettings by remember { mutableStateOf(false) }
    var showPendingRecordings by remember { mutableStateOf(false) }
    var showCreatorSkillsLibrary by remember { mutableStateOf(false) }
    var showEditorSkillPicker by remember { mutableStateOf(false) }
    var pendingHomeRecipe by remember { mutableStateOf<AgentRecipe?>(null) }
    var pendingTranslateRecipe by remember { mutableStateOf<AgentRecipe?>(null) }
    var pendingRecipeInput by remember { mutableStateOf("") }
    var aiSourceText by remember { mutableStateOf<TextFieldValue?>(null) }
    var aiHomeNote by remember { mutableStateOf<NoteEntity?>(null) }
    var teleprompterOpen by remember { mutableStateOf(false) }
    var teleprompterScript by remember { mutableStateOf("") }
    var showNoteExport by remember { mutableStateOf(false) }
    var showSubscription by remember { mutableStateOf(false) }
    var appliedAITransformation by remember { mutableStateOf<AppliedAISkillTransformation?>(null) }
    var retryingAITransformation by remember { mutableStateOf<AppliedAISkillTransformation?>(null) }
    val installedRecipes by viewModel.installedRecipes.collectAsState()
    val aiSkillState by viewModel.aiSkillState.collectAsState()
    val contextChatState by viewModel.contextChatState.collectAsState()
    val voiceRefinementState by viewModel.voiceRefinementState.collectAsState()
    val voiceLanguageSettings by viewModel.voiceLanguageSettings.collectAsState()
    val mediaLinkSections by viewModel.mediaLinkSections.collectAsState()
    val context = LocalContext.current
    val voiceStartError = stringResource(R.string.voice_error_start)
    val voicePermissionError = stringResource(R.string.voice_error_permission)
    val voiceEmptyError = stringResource(R.string.voice_error_empty)
    val voiceRefinedMessage = stringResource(R.string.voice_refined)
    val voiceShowOriginal = stringResource(R.string.voice_show_original)
    val voiceRecorder = remember { VoiceRecorder(context) }
    var isRecording by remember { mutableStateOf(false) }
    val microphonePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) runCatching { voiceRecorder.start(); isRecording = true }
            .onFailure { viewModel.reportAuthError(it.message ?: voiceStartError) }
        else viewModel.reportAuthError(voicePermissionError)
    }
    val startVoiceRecording = {
        if (!isRecording && ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            runCatching { voiceRecorder.start(); isRecording = true }
                .onFailure { viewModel.reportAuthError(it.message ?: voiceStartError) }
        } else if (!isRecording) microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
    }
    DisposableEffect(voiceRecorder) { onDispose { voiceRecorder.cancel() } }
    val snackbarHost = remember { SnackbarHostState() }
    LaunchedEffect(uiState.errorMessage) { if (!uiState.errorMessage.isNullOrBlank()) snackbarHost.showSnackbar(uiState.errorMessage) }
    LaunchedEffect(voiceRefinementState) {
        if (voiceRefinementState != null) {
            val result = snackbarHost.showSnackbar(
                message = voiceRefinedMessage,
                actionLabel = voiceShowOriginal,
                duration = SnackbarDuration.Long,
            )
            if (result == SnackbarResult.ActionPerformed) viewModel.restoreOriginalVoiceResult()
            else viewModel.dismissVoiceRefinement()
        }
    }
    LaunchedEffect(aiSkillState.preview, retryingAITransformation) {
        val preview = aiSkillState.preview ?: return@LaunchedEffect
        val transformation = retryingAITransformation ?: return@LaunchedEffect
        val applied = AISkillTextApplication.apply(
            transformation.sourceContent,
            preview.result,
            transformation.sourceSelection,
            transformation.mode,
        )
        if (transformation.targetNoteId == null) {
            editorText = TextFieldValue(applied, TextRange(applied.length))
            checklistDraft = ChecklistMarkdown.parse(applied)
        } else {
            viewModel.replaceNoteContent(transformation.targetNoteId, applied)
        }
        appliedAITransformation = transformation
        retryingAITransformation = null
        viewModel.dismissCreatorSkillResult()
    }
    LaunchedEffect(aiSkillState.errorMessage) {
        if (aiSkillState.errorMessage != null) retryingAITransformation = null
    }
    LaunchedEffect(sharedText) {
        if (!sharedText.isNullOrBlank()) {
            viewModel.importSharedText(
                text = sharedText,
                section = selectedSection,
                onPlainText = { plainText ->
                    editorText = TextFieldValue(plainText)
                    checklistDraft = ChecklistMarkdown.parse(plainText)
                undoStack = emptyList(); redoStack = emptyList(); editorPreview = false
                appliedAITransformation = null; retryingAITransformation = null
                editorOpen = true
                },
                onInsufficientCredits = { showSubscription = true },
            )
            onSharedTextConsumed()
        }
    }
    LaunchedEffect(recordRequest) {
        if (recordRequest != 0L) {
            startVoiceRecording()
            onRecordRequestConsumed()
        }
    }
    val visibleNotes = (if (searchQuery.isBlank()) notes else searchResults).filter { note ->
        val matchesLocation = if (selectedSection == "trash") note.deletedAt != null
            else note.section == selectedSection && note.deletedAt == null
        val noteTagIds = noteTags.filter { it.noteId == note.id }.mapTo(mutableSetOf()) { it.tagId }
        val matchesTag = selectedTagId == null || selectedTagId in noteTagIds
        matchesLocation && matchesTag
    }
    LaunchedEffect(selectedSection, selectedTagId, searchQuery, visibleNotes.map { it.id }) {
        if (selectedSection == "trash") isSelectionMode = false
        selectedNoteIds = selectedNoteIds.intersect(visibleNotes.mapTo(mutableSetOf()) { it.id })
    }
    if (showSettings) {
        SettingsScreen(
            uiState = uiState,
            notes = notes,
            voiceSettings = voiceLanguageSettings,
            mediaSections = mediaLinkSections,
            onBack = { showSettings = false },
            onSignOut = viewModel::signOut,
            onDeleteAccount = viewModel::deleteAccount,
            onOpenUrl = onOpenUrl,
            billingState = billingState,
            onPurchase = onPurchase,
            onRestorePurchases = onRestorePurchases,
            onUpdateVoice = viewModel::updateVoiceLanguage,
            onUpdateMediaSections = viewModel::updateMediaLinkSections,
        )
        return
    }
    if (teleprompterOpen) {
        TeleprompterCameraScreen(initialScript = teleprompterScript, onClose = { teleprompterOpen = false })
        return
    }
    if (showCreatorSkillsLibrary) {
        CreatorSkillsLibrary(
            available = viewModel.availableRecipes,
            installed = installedRecipes,
            onBack = { showCreatorSkillsLibrary = false },
            onToggle = viewModel::toggleRecipe,
            onCreateCustom = viewModel::createCustomRecipe,
            onDeleteCustom = viewModel::deleteCustomRecipe,
        )
        return
    }
    if (contextChatState.isOpen) {
        ContextChatScreen(
            state = contextChatState,
            onClose = {
                viewModel.closeContextChat()
                isSelectionMode = false
                selectedNoteIds = emptySet()
            },
            onClear = viewModel::clearContextChat,
            onSend = viewModel::sendContextChatMessage,
            onSave = viewModel::saveChatMessageAsNote,
            onDismissError = viewModel::dismissContextChatError,
        )
        return
    }
    if (showPendingRecordings) {
        PendingRecordingsScreen(
            recordings = pendingRecordings,
            isProcessing = uiState.voiceProcessing,
            onBack = { showPendingRecordings = false },
            onRetry = viewModel::retryPendingRecording,
            onDelete = viewModel::deletePendingRecording,
        )
        return
    }
    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHost) },
        bottomBar = {
            appliedAITransformation?.let { transformation ->
                AISkillAppliedActionBar(
                    retrying = retryingAITransformation != null,
                    onRetry = {
                        retryingAITransformation = transformation
                        viewModel.runCreatorSkill(
                            transformation.recipe,
                            transformation.inputContent,
                            transformation.instruction,
                        )
                    },
                    onUndo = {
                        if (transformation.targetNoteId == null) {
                            editorText = TextFieldValue(
                                transformation.sourceContent,
                                TextRange(transformation.sourceSelection.start.coerceAtMost(transformation.sourceContent.length)),
                            )
                            checklistDraft = ChecklistMarkdown.parse(transformation.sourceContent)
                        } else {
                            viewModel.replaceNoteContent(transformation.targetNoteId, transformation.sourceContent)
                        }
                        retryingAITransformation = null
                        appliedAITransformation = null
                    },
                    onSave = {
                        retryingAITransformation = null
                        appliedAITransformation = null
                    },
                )
            }
        },
        topBar = {
            Column {
                CenterAlignedTopAppBar(
                    title = { Text(if (isSelectionMode) pluralStringResource(R.plurals.home_selection_count, selectedNoteIds.size, selectedNoteIds.size) else stringResource(R.string.app_name)) },
                    navigationIcon = {
                        if (isSelectionMode) TextButton(onClick = {
                            isSelectionMode = false
                            selectedNoteIds = emptySet()
                        }) { Text(stringResource(R.string.common_cancel)) }
                    },
                    actions = {
                        if (isSelectionMode) {
                            TextButton(onClick = { viewModel.openContextChat(selectedNoteIds) }, enabled = selectedNoteIds.isNotEmpty()) {
                                Text(stringResource(R.string.ai_chat_start))
                            }
                            TextButton(onClick = {
                                selectedNoteIds = if (selectedNoteIds.size == visibleNotes.size) emptySet()
                                else visibleNotes.mapTo(mutableSetOf()) { it.id }
                            }) { Text(stringResource(if (selectedNoteIds.size == visibleNotes.size) R.string.home_deselect_all else R.string.home_select_all)) }
                            IconButton(onClick = { showBatchTagDialog = true }, enabled = selectedNoteIds.isNotEmpty()) {
                                Icon(Icons.AutoMirrored.Outlined.Label, stringResource(R.string.home_batch_tag_title))
                            }
                            IconButton(onClick = { showBatchDeleteConfirmation = true }, enabled = selectedNoteIds.isNotEmpty()) {
                                Icon(Icons.Outlined.Delete, stringResource(R.string.home_batch_delete_action), tint = MaterialTheme.colorScheme.error)
                            }
                        } else {
                            if (selectedSection != "trash") TextButton(onClick = {
                                isSelectionMode = true
                                selectedNoteIds = emptySet()
                            }) { Text(stringResource(R.string.home_select_notes)) }
                            if (pendingRecordings.isNotEmpty()) IconButton(onClick = { showPendingRecordings = true }) {
                                Icon(Icons.Outlined.GraphicEq, stringResource(R.string.pending_recordings_title), tint = MaterialTheme.colorScheme.primary)
                            }
                            IconButton(onClick = { showSettings = true }) { Icon(Icons.Outlined.Settings, stringResource(R.string.settings_title)) }
                        }
                    },
                )
                PrimaryTabRow(selectedTabIndex = sections.indexOf(selectedSection)) {
                    sections.forEach { section ->
                        Tab(
                            selected = section == selectedSection,
                            onClick = { selectedSection = section },
                            text = { Text(stringResource(section.titleResource())) },
                        )
                    }
                }
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it; viewModel.updateSearchQuery(it) },
                    leadingIcon = { Icon(Icons.Outlined.Search, null) },
                    placeholder = { Text(stringResource(R.string.home_search_placeholder)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                )
                if (selectedSection == "trash") {
                    TextButton(onClick = viewModel::emptyTrash, modifier = Modifier.align(Alignment.End)) {
                        Text(stringResource(R.string.trash_empty_action))
                    }
                }
                if (selectedSection != "trash") LazyRow(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item { FilterChip(selectedTagId == null, { selectedTagId = null }, { Text(stringResource(R.string.tags_all)) }) }
                    items(tags, key = { it.id }) { tag ->
                        FilterChip(selectedTagId == tag.id, { selectedTagId = tag.id }, { Text(tag.name) })
                    }
                    item { FilterChip(false, { showCreateTag = true }, { Text(stringResource(R.string.tags_add)) }) }
                    if (tags.isNotEmpty()) item {
                        FilterChip(false, { showManageTags = true }, { Text(stringResource(R.string.tags_manage)) })
                    }
                }
                if (selectedSection != "trash" && selectedTagId == null && !isSelectionMode) {
                    CreatorSkillsRail(
                        recipes = installedRecipes,
                        onRecipe = { pendingHomeRecipe = it },
                        onAddMore = { showCreatorSkillsLibrary = true },
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                }
            }
        },
        floatingActionButton = {
            if (!isSelectionMode) Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SmallFloatingActionButton(onClick = {
                    if (isRecording) {
                        val file = voiceRecorder.stop()
                        isRecording = false
                        if (file != null) viewModel.processVoiceRecording(file, selectedSection)
                        else viewModel.reportAuthError(voiceEmptyError)
                    } else startVoiceRecording()
                }) {
                    Icon(
                        if (isRecording) Icons.Outlined.Stop else Icons.Outlined.Mic,
                        stringResource(if (isRecording) R.string.voice_stop else R.string.voice_start),
                    )
                }
                FloatingActionButton(onClick = {
                    editingNote = null; editorText = TextFieldValue(""); checklistDraft = null
                    undoStack = emptyList(); redoStack = emptyList(); editorPreview = false; editorOpen = true
                    appliedAITransformation = null; retryingAITransformation = null
                }) {
                    Icon(Icons.Outlined.Add, stringResource(R.string.home_create_note))
                }
            }
        },
    ) { padding ->
        if (uiState.voiceProcessing) {
            Row(
                Modifier.fillMaxWidth().padding(padding).padding(horizontal = 20.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) { CircularProgressIndicator(); Text(stringResource(R.string.voice_processing)) }
        }
        if (editorOpen) {
            Column(Modifier.fillMaxSize().padding(padding).padding(20.dp)) {
                editingNote?.sourceMetadata()?.let { source ->
                    NoteSourceCard(source = source, onOpen = { onOpenUrl(source.url) })
                    Spacer(Modifier.height(14.dp))
                }
                editingNote?.let { note ->
                    when (note.importStatus) {
                        "queued", "processing" -> Text(
                            stringResource(R.string.link_import_processing),
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(bottom = 12.dp),
                        )
                        "failed" -> Text(
                            stringResource(R.string.link_import_failed),
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.padding(bottom = 12.dp),
                        )
                    }
                }
                val draft = checklistDraft
                if (draft == null) {
                    LazyRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        item { TextButton(onClick = { showEditorSkillPicker = true }) {
                            Text(stringResource(R.string.creator_skills_title))
                        } }
                        item { TextButton(onClick = {
                            teleprompterScript = checklistDraft?.let { ChecklistMarkdown.serialize(it.notes, it.items) } ?: editorText.text
                            teleprompterOpen = true
                        }) { Text(stringResource(R.string.teleprompter_action_open)) } }
                        item { TextButton(onClick = {
                            val result = MarkdownEditing.toggleBold(editorText.text, editorText.selection.start, editorText.selection.end)
                            undoStack = (undoStack + editorText).takeLast(100); redoStack = emptyList()
                            editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
                        }) { Text(stringResource(R.string.markdown_toolbar_bold)) } }
                        item { TextButton(onClick = {
                            val result = MarkdownEditing.toggleHeading(editorText.text, editorText.selection.start, editorText.selection.end, 1)
                            undoStack = (undoStack + editorText).takeLast(100); redoStack = emptyList()
                            editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
                        }) { Text(stringResource(R.string.markdown_toolbar_h1)) } }
                        item { TextButton(onClick = {
                            val result = MarkdownEditing.toggleHeading(editorText.text, editorText.selection.start, editorText.selection.end, 2)
                            undoStack = (undoStack + editorText).takeLast(100); redoStack = emptyList()
                            editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
                        }) { Text(stringResource(R.string.markdown_toolbar_h2)) } }
                        item { TextButton(onClick = {
                            val result = MarkdownEditing.toggleChecklist(editorText.text, editorText.selection.start, editorText.selection.end)
                            undoStack = (undoStack + editorText).takeLast(100); redoStack = emptyList()
                            editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
                        }) { Text(stringResource(R.string.markdown_toolbar_checklist)) } }
                        item { TextButton(onClick = {
                            undoStack.lastOrNull()?.let { previous ->
                                redoStack = (redoStack + editorText).takeLast(100)
                                editorText = previous; undoStack = undoStack.dropLast(1)
                            }
                        }, enabled = undoStack.isNotEmpty()) { Text(stringResource(R.string.markdown_toolbar_undo)) } }
                        item { TextButton(onClick = {
                            redoStack.lastOrNull()?.let { next ->
                                undoStack = (undoStack + editorText).takeLast(100)
                                editorText = next; redoStack = redoStack.dropLast(1)
                            }
                        }, enabled = redoStack.isNotEmpty()) { Text(stringResource(R.string.markdown_toolbar_redo)) } }
                        item { FilterChip(
                            selected = editorPreview,
                            onClick = { editorPreview = !editorPreview },
                            label = { Text(stringResource(R.string.markdown_toolbar_preview)) },
                        ) }
                    }
                    if (editorPreview) {
                        MarkdownText(
                            markdown = editorText.text,
                            modifier = Modifier.fillMaxWidth().weight(1f).padding(vertical = 16.dp),
                        )
                    } else OutlinedTextField(
                        value = editorText,
                        onValueChange = { value ->
                            if (value.text != editorText.text) {
                                undoStack = (undoStack + editorText).takeLast(100)
                                redoStack = emptyList()
                            }
                            editorText = value
                        },
                        label = { Text(stringResource(R.string.note_editor_placeholder)) },
                        modifier = Modifier.fillMaxWidth().weight(1f),
                    )
                    TextButton(onClick = {
                        checklistDraft = ChecklistDraft(editorText.text.trim(), listOf(ChecklistDraftItem("")))
                    }) { Text(stringResource(R.string.checklist_convert_action)) }
                } else {
                    Column(Modifier.weight(1f)) {
                        OutlinedTextField(
                            value = draft.notes,
                            onValueChange = { checklistDraft = draft.copy(notes = it) },
                            label = { Text(stringResource(R.string.checklist_notes_placeholder)) },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        LazyColumn(Modifier.weight(1f).padding(top = 8.dp)) {
                            items(draft.items.size) { index ->
                                val item = draft.items[index]
                                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(
                                        checked = item.isDone,
                                        onCheckedChange = { checked ->
                                            checklistDraft = draft.copy(items = draft.items.toMutableList().also { it[index] = item.copy(isDone = checked) })
                                        },
                                    )
                                    OutlinedTextField(
                                        value = item.text,
                                        onValueChange = { text ->
                                            checklistDraft = draft.copy(items = draft.items.toMutableList().also { it[index] = item.copy(text = text) })
                                        },
                                        placeholder = { Text(stringResource(R.string.checklist_item_placeholder)) },
                                        modifier = Modifier.weight(1f),
                                    )
                                    TextButton(onClick = {
                                        checklistDraft = draft.copy(items = draft.items.filterIndexed { itemIndex, _ -> itemIndex != index })
                                    }) { Text(stringResource(R.string.common_delete)) }
                                }
                            }
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            TextButton(onClick = { checklistDraft = draft.copy(items = draft.items + ChecklistDraftItem("")) }) {
                                Text(stringResource(R.string.checklist_add_item))
                            }
                            TextButton(onClick = {
                                editorText = TextFieldValue(ChecklistMarkdown.serializePlainText(draft.notes, draft.items))
                                checklistDraft = null
                            }) { Text(stringResource(R.string.checklist_convert_to_text)) }
                        }
                    }
                }
                if (tags.isNotEmpty()) {
                    Text(stringResource(R.string.note_tags_title), style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 10.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(tags, key = { it.id }) { tag ->
                            FilterChip(
                                selected = tag.id in selectedEditorTagIds,
                                onClick = { selectedEditorTagIds = if (tag.id in selectedEditorTagIds) selectedEditorTagIds - tag.id else selectedEditorTagIds + tag.id },
                                label = { Text(tag.name) },
                            )
                        }
                    }
                }
                Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    editingNote?.let { note ->
                        IconButton(onClick = {
                            viewModel.deleteNote(note); editorOpen = false
                            appliedAITransformation = null; retryingAITransformation = null
                        }) {
                            Icon(Icons.Outlined.Delete, stringResource(R.string.note_delete))
                        }
                        TextButton(onClick = { showNoteExport = true }) { Text(stringResource(R.string.note_export)) }
                    }
                    Button(onClick = {
                        editorOpen = false; editingNote = null; checklistDraft = null
                        appliedAITransformation = null; retryingAITransformation = null
                    }, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.common_cancel)) }
                    Button(
                        onClick = {
                            val note = editingNote
                            val content = checklistDraft?.let { ChecklistMarkdown.serialize(it.notes, it.items) } ?: editorText.text
                            viewModel.saveNote(note, content, selectedSection, selectedEditorTagIds.toList())
                            editorOpen = false; editingNote = null; checklistDraft = null
                            appliedAITransformation = null; retryingAITransformation = null
                        },
                        enabled = checklistDraft?.let { it.notes.isNotBlank() || it.items.any { item -> item.text.isNotBlank() } } ?: editorText.text.isNotBlank(),
                        modifier = Modifier.weight(1f),
                    ) { Text(stringResource(R.string.common_save)) }
                }
            }
        } else {
            if (visibleNotes.isEmpty()) Column(
                Modifier.fillMaxSize().padding(padding), Arrangement.Center, Alignment.CenterHorizontally,
            ) { Text(stringResource(R.string.home_empty_title)) }
            else LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)) {
                items(visibleNotes, key = { it.id }) { note ->
                    NoteRow(
                        note = note,
                        isTrash = selectedSection == "trash",
                        isSelectionMode = isSelectionMode,
                        isSelected = note.id in selectedNoteIds,
                        onClick = { if (isSelectionMode) {
                            selectedNoteIds = if (note.id in selectedNoteIds) selectedNoteIds - note.id else selectedNoteIds + note.id
                        } else if (selectedSection != "trash") {
                            editingNote = note; editorText = TextFieldValue(note.content); checklistDraft = ChecklistMarkdown.parse(note.content)
                            undoStack = emptyList(); redoStack = emptyList(); editorPreview = false
                            selectedEditorTagIds = noteTags.filter { it.noteId == note.id }.map { it.tagId }.toSet()
                            appliedAITransformation = null; retryingAITransformation = null
                            editorOpen = true
                        } },
                        onPin = { viewModel.togglePin(note) },
                        onMove = { section -> viewModel.moveNote(note, section) },
                        onDelete = { viewModel.deleteNote(note) },
                        onOpenSource = onOpenUrl,
                        onRestore = { viewModel.restoreNote(note) },
                        onPermanentDelete = { viewModel.permanentlyDelete(note) },
                    )
                }
                item { Spacer(Modifier.height(96.dp)) }
            }
        }
    }
    if (showCreateTag) TagEditorDialog(
        tag = null,
        tags = tags,
        onDismiss = { showCreateTag = false },
        onSave = { name, colorHex, parentId ->
            viewModel.createTag(name, colorHex, parentId)
            showCreateTag = false
        },
    )
    if (showManageTags) TagManagerDialog(
        tags = tags,
        onDismiss = { showManageTags = false },
        onEdit = { tag -> editingTag = tag; showManageTags = false },
    )
    editingTag?.let { tag ->
        TagEditorDialog(
            tag = tag,
            tags = tags,
            onDismiss = { editingTag = null },
            onSave = { name, colorHex, parentId ->
                viewModel.updateTag(tag, name, colorHex, parentId)
                editingTag = null
            },
            onDelete = {
                if (selectedTagId == tag.id) selectedTagId = null
                viewModel.deleteTag(tag)
                editingTag = null
            },
        )
    }
    if (showBatchTagDialog) BatchTagDialog(
        tags = tags,
        selectedNoteIds = selectedNoteIds,
        noteTags = noteTags,
        onDismiss = { showBatchTagDialog = false },
        onApply = { tag ->
            viewModel.addTagToNotes(selectedNoteIds, tag)
            showBatchTagDialog = false
            isSelectionMode = false
            selectedNoteIds = emptySet()
        },
    )
    if (showBatchDeleteConfirmation) AlertDialog(
        onDismissRequest = { showBatchDeleteConfirmation = false },
        title = { Text(stringResource(R.string.home_batch_delete_title)) },
        text = { Text(pluralStringResource(R.plurals.home_batch_delete_message, selectedNoteIds.size, selectedNoteIds.size)) },
        confirmButton = { TextButton(onClick = {
            viewModel.deleteNotes(selectedNoteIds)
            showBatchDeleteConfirmation = false
            isSelectionMode = false
            selectedNoteIds = emptySet()
        }) { Text(stringResource(R.string.home_batch_delete_action), color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = { showBatchDeleteConfirmation = false }) { Text(stringResource(R.string.common_cancel)) } },
    )
    if (showNoteExport) {
        val sourceNote = editingNote
        AlertDialog(
            onDismissRequest = { showNoteExport = false },
            title = { Text(stringResource(R.string.note_export)) },
            text = {
                Column {
                    NoteExportFormat.entries.forEach { format ->
                        TextButton(onClick = {
                            sourceNote?.let { original ->
                                val currentContent = checklistDraft?.let { ChecklistMarkdown.serialize(it.notes, it.items) } ?: editorText.text
                                val file = NotesExporter.exportNote(context, original.copy(content = currentContent), format)
                                NotesExporter.share(context, file, format.mimeType)
                            }
                            showNoteExport = false
                        }, modifier = Modifier.fillMaxWidth()) {
                            Text(stringResource(when (format) {
                                NoteExportFormat.MARKDOWN -> R.string.note_export_markdown
                                NoteExportFormat.TEXT -> R.string.note_export_text
                                NoteExportFormat.JSON -> R.string.note_export_json
                            }))
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { showNoteExport = false }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }
    if (showEditorSkillPicker) CreatorSkillPickerDialog(
        recipes = installedRecipes,
        onDismiss = { showEditorSkillPicker = false },
        onSelect = { recipe ->
            showEditorSkillPicker = false
            val source = editorText
            val selection = TextSelection(source.selection.start, source.selection.end).normalized(source.text)
            aiSourceText = source
            aiHomeNote = null
            pendingRecipeInput = if (selection.isCollapsed) source.text else source.text.substring(selection.start, selection.end)
            if (recipe.id == "translate") pendingTranslateRecipe = recipe
            else viewModel.runCreatorSkill(recipe, pendingRecipeInput)
        },
    )
    pendingHomeRecipe?.let { recipe ->
        CreatorSkillNotePickerDialog(
            recipe = recipe,
            notes = visibleNotes.filter { it.deletedAt == null },
            onDismiss = { pendingHomeRecipe = null },
            onSelect = { note ->
                pendingHomeRecipe = null
                aiSourceText = null
                aiHomeNote = note
                pendingRecipeInput = note.content
                if (recipe.id == "translate") pendingTranslateRecipe = recipe
                else viewModel.runCreatorSkill(recipe, note.content)
            },
        )
    }
    pendingTranslateRecipe?.let { recipe ->
        TranslateTargetDialog(
            onDismiss = { pendingTranslateRecipe = null },
            onRun = { language ->
                pendingTranslateRecipe = null
                viewModel.runCreatorSkill(recipe, pendingRecipeInput, language)
            },
        )
    }
    aiSkillState.processingRecipeId?.let { recipeId ->
        viewModel.availableRecipes.firstOrNull { it.id == recipeId }?.let { AISkillProcessingDialog(it) }
    }
    aiSkillState.preview?.takeIf { retryingAITransformation == null }?.let { preview ->
        val source = aiSourceText
        val homeNote = aiHomeNote
        val sourceContent = source?.text ?: homeNote?.content.orEmpty()
        val sourceSelection = source?.let { TextSelection(it.selection.start, it.selection.end).normalized(it.text) }
            ?: TextSelection(sourceContent.length, sourceContent.length)
        AISkillPreviewDialog(
            recipe = preview.recipe,
            result = preview.result,
            selection = sourceSelection,
            modes = if (homeNote == null) AISkillTextApplication.availableModes(sourceSelection)
                else listOf(AISkillApplyMode.REPLACE_ALL, AISkillApplyMode.APPEND_TO_END),
            onDismiss = {
                viewModel.dismissCreatorSkillResult(); aiSourceText = null; aiHomeNote = null
            },
            onApply = { mode ->
                val applied = AISkillTextApplication.apply(sourceContent, preview.result, sourceSelection, mode)
                val inputContent = if (sourceSelection.isCollapsed) sourceContent
                    else sourceContent.substring(sourceSelection.start, sourceSelection.end)
                appliedAITransformation = AppliedAISkillTransformation(
                    recipe = preview.recipe,
                    instruction = preview.instruction,
                    inputContent = inputContent,
                    sourceContent = sourceContent,
                    sourceSelection = sourceSelection,
                    mode = mode,
                    targetNoteId = homeNote?.id,
                )
                if (source != null) {
                    undoStack = (undoStack + editorText).takeLast(100)
                    redoStack = emptyList()
                    editorText = TextFieldValue(applied, TextRange(applied.length))
                    checklistDraft = ChecklistMarkdown.parse(applied)
                } else if (homeNote != null) {
                    viewModel.replaceNoteContent(homeNote.id, applied)
                }
                viewModel.dismissCreatorSkillResult(); aiSourceText = null; aiHomeNote = null
            },
            onSaveDraft = {
                viewModel.createNote(preview.result, "drafts")
                viewModel.dismissCreatorSkillResult(); aiSourceText = null; aiHomeNote = null
            },
        )
    }
    aiSkillState.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::dismissCreatorSkillResult,
            title = { Text(stringResource(R.string.ai_skill_error_title)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = viewModel::dismissCreatorSkillResult) { Text(stringResource(R.string.common_close)) } },
        )
    }
    if (showSubscription) SubscriptionDialog(
        uiState = uiState,
        billingState = billingState,
        onDismiss = { showSubscription = false },
        onPurchase = onPurchase,
        onRestore = onRestorePurchases,
        onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
    )
}

@Composable
private fun AISkillAppliedActionBar(
    retrying: Boolean,
    onRetry: () -> Unit,
    onUndo: () -> Unit,
    onSave: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 48.dp, vertical = 10.dp),
        shape = RoundedCornerShape(16.dp),
        tonalElevation = 6.dp,
        shadowElevation = 10.dp,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onRetry, enabled = !retrying) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    if (retrying) CircularProgressIndicator(Modifier.size(20.dp))
                    else Icon(Icons.Outlined.Refresh, stringResource(R.string.common_retry))
                    Text(stringResource(R.string.common_retry), style = MaterialTheme.typography.labelSmall)
                }
            }
            TextButton(onClick = onUndo, enabled = !retrying) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.AutoMirrored.Outlined.Undo, stringResource(R.string.common_undo))
                    Text(stringResource(R.string.common_undo), style = MaterialTheme.typography.labelSmall)
                }
            }
            TextButton(onClick = onSave, enabled = !retrying) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Outlined.Check, stringResource(R.string.common_save))
                    Text(stringResource(R.string.common_save), style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PendingRecordingsScreen(
    recordings: List<PendingRecording>,
    isProcessing: Boolean,
    onBack: () -> Unit,
    onRetry: (PendingRecording) -> Unit,
    onDelete: (PendingRecording) -> Unit,
) {
    val context = LocalContext.current
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    var playingPath by remember { mutableStateOf<String?>(null) }
    fun stopPlayback() {
        player?.stop()
        player?.release()
        player = null
        playingPath = null
    }
    DisposableEffect(Unit) { onDispose { stopPlayback() } }
    Scaffold(topBar = {
        CenterAlignedTopAppBar(
            title = { Text(stringResource(R.string.pending_recordings_title)) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back)) } },
        )
    }) { padding ->
        if (recordings.isEmpty()) Column(
            Modifier.fillMaxSize().padding(padding),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) { Text(stringResource(R.string.pending_recordings_empty), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        else LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp)) {
            items(recordings, key = { it.file.absolutePath }) { recording ->
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 12.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(16.dp))
                        .padding(16.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = {
                            if (playingPath == recording.file.absolutePath) stopPlayback()
                            else {
                                stopPlayback()
                                player = MediaPlayer.create(context, Uri.fromFile(recording.file))?.also { mediaPlayer ->
                                    playingPath = recording.file.absolutePath
                                    mediaPlayer.setOnCompletionListener { stopPlayback() }
                                    mediaPlayer.start()
                                }
                            }
                        }, enabled = !isProcessing) {
                            Icon(
                                if (playingPath == recording.file.absolutePath) Icons.Outlined.PauseCircle else Icons.Outlined.PlayCircle,
                                stringResource(if (playingPath == recording.file.absolutePath) R.string.pending_recordings_pause else R.string.pending_recordings_play),
                            )
                        }
                        Text(recording.durationText, fontWeight = FontWeight.SemiBold)
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TextButton(onClick = { stopPlayback(); onDelete(recording) }, enabled = !isProcessing) {
                            Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error)
                        }
                        Button(onClick = { stopPlayback(); onRetry(recording) }, enabled = !isProcessing, modifier = Modifier.weight(1f)) {
                            if (isProcessing) CircularProgressIndicator() else Text(stringResource(R.string.pending_recordings_save_as_note))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsScreen(
    uiState: AppUiState,
    notes: List<NoteEntity>,
    voiceSettings: VoiceLanguageSettings,
    mediaSections: MediaLinkSectionsDto,
    onBack: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    onOpenUrl: (String) -> Unit,
    billingState: BillingUiState,
    onPurchase: (BillingProduct) -> Unit,
    onRestorePurchases: () -> Unit,
    onUpdateVoice: (String, String) -> Unit,
    onUpdateMediaSections: (MediaLinkSectionsDto) -> Unit,
) {
    var confirmDelete by remember { mutableStateOf(false) }
    var deleteInProgress by remember { mutableStateOf(false) }
    var deleteStarted by remember { mutableStateOf(false) }
    var showDeleteError by remember { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var showSubscription by remember { mutableStateOf(false) }
    var exportError by remember { mutableStateOf<String?>(null) }
    var exporting by remember { mutableStateOf(false) }
    var exportProgress by remember { mutableStateOf<NotesExportProgress?>(null) }
    var exportJob by remember { mutableStateOf<Job?>(null) }
    var showVoiceSettings by remember { mutableStateOf(false) }
    var showMediaSections by remember { mutableStateOf(false) }
    var showAbout by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val noNotesMessage = stringResource(R.string.settings_export_no_notes)
    val exportFailedMessage = stringResource(R.string.settings_export_failed)
    val accountEmail = (uiState.authState as? AuthState.SignedIn)?.session?.user?.email
        ?.takeIf { it.isNotBlank() } ?: stringResource(R.string.settings_unknown_email)
    LaunchedEffect(deleteInProgress, uiState.busy, uiState.errorMessage) {
        if (!deleteInProgress) return@LaunchedEffect
        if (uiState.busy) {
            deleteStarted = true
        } else if (deleteStarted && uiState.authState is AuthState.SignedIn) {
            deleteInProgress = false
            deleteStarted = false
            showDeleteError = true
        }
    }
    Scaffold(topBar = {
        CenterAlignedTopAppBar(
            title = { Text(stringResource(R.string.settings_title)) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back)) } },
        )
    }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 20.dp)) {
            item {
                Text(stringResource(R.string.settings_account_section), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 20.dp, bottom = 10.dp))
                Text(
                    accountEmail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                SettingsRow(stringResource(R.string.settings_subscription_plan),
                    if (uiState.subscriptionTier == "pro") stringResource(R.string.subscription_pro) else stringResource(R.string.subscription_free)) {
                    showSubscription = true
                }
                SettingsRow(stringResource(R.string.settings_privacy_policy)) { onOpenUrl("https://www.chillnoteai.com/privacy") }
                SettingsRow(stringResource(R.string.settings_terms)) { onOpenUrl("https://www.chillnoteai.com/terms") }
                SettingsRow(stringResource(R.string.settings_permissions)) { onOpenUrl("package:com.sponteoai.chillscript") }
                Spacer(Modifier.height(20.dp))
                Text(stringResource(R.string.settings_data_section), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 8.dp))
                SettingsRow(
                    stringResource(R.string.settings_export_all_notes),
                    if (exporting) stringResource(R.string.settings_exporting) else null,
                ) {
                    val active = notes.filter { it.deletedAt == null }
                    if (active.isEmpty()) exportError = noNotesMessage else scope.launch {
                        exportJob?.cancel()
                        exporting = true
                        exportProgress = NotesExportProgress(NotesExportStage.PREPARING, 0, active.size)
                        exportJob = kotlinx.coroutines.currentCoroutineContext()[Job]
                        try {
                            val file = withContext(Dispatchers.IO) {
                                NotesExporter.exportAll(context, active) { progress ->
                                    withContext(Dispatchers.Main.immediate) { exportProgress = progress }
                                }
                            }
                            NotesExporter.share(context, file, "application/zip")
                        } catch (_: CancellationException) {
                            // Closing the progress dialog is the cancellation confirmation.
                        } catch (_: Throwable) {
                            exportError = exportFailedMessage
                        } finally {
                            exporting = false
                            exportProgress = null
                            exportJob = null
                        }
                    }
                }
                Text(stringResource(R.string.settings_export_all_summary), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                SettingsRow(
                    stringResource(R.string.settings_voice_language),
                    if (voiceSettings.mode == "auto") stringResource(R.string.settings_voice_auto)
                    else voiceSettings.languageHint.ifBlank { stringResource(R.string.settings_voice_not_set) },
                ) { showVoiceSettings = true }
                SettingsRow(stringResource(R.string.settings_media_sections)) { showMediaSections = true }
                Spacer(Modifier.height(20.dp))
                Text(stringResource(R.string.settings_support_section), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 8.dp))
                SettingsRow(stringResource(R.string.settings_send_feedback)) { onOpenUrl("mailto:support@chillnoteai.com") }
                SettingsRow(stringResource(R.string.settings_about)) { showAbout = true }
                Spacer(Modifier.height(24.dp))
                Button(onClick = { confirmSignOut = true }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.auth_logout)) }
                TextButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.settings_delete_account), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text(stringResource(R.string.settings_delete_account_confirm_title)) },
        text = { Text(stringResource(R.string.settings_delete_account_confirm_message)) },
        confirmButton = { TextButton(onClick = {
            confirmDelete = false
            deleteInProgress = true
            deleteStarted = false
            onDeleteAccount()
        }) {
            Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error)
        } },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.common_cancel)) } },
    )
    if (confirmSignOut) AlertDialog(
        onDismissRequest = { confirmSignOut = false },
        title = { Text(stringResource(R.string.auth_logout)) },
        text = { Text(stringResource(R.string.settings_sign_out_confirm_message)) },
        confirmButton = { TextButton(onClick = { confirmSignOut = false; onSignOut() }) {
            Text(stringResource(R.string.auth_logout), color = MaterialTheme.colorScheme.error)
        } },
        dismissButton = { TextButton(onClick = { confirmSignOut = false }) { Text(stringResource(R.string.common_cancel)) } },
    )
    if (deleteInProgress) AlertDialog(
        onDismissRequest = {},
        title = { Text(stringResource(R.string.settings_delete_account_deleting_title)) },
        text = {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(24.dp))
                Text(stringResource(R.string.settings_delete_account_deleting_message))
            }
        },
        confirmButton = {},
    )
    if (showDeleteError) AlertDialog(
        onDismissRequest = { showDeleteError = false },
        title = { Text(stringResource(R.string.settings_delete_account_failed_title)) },
        text = { Text(stringResource(R.string.settings_delete_account_failed_message)) },
        confirmButton = {
            TextButton(onClick = { showDeleteError = false }) { Text(stringResource(R.string.common_close)) }
        },
    )
    if (exporting) {
        val progress = exportProgress
        val stageMessage = when (progress?.stage) {
            NotesExportStage.WRITING -> stringResource(R.string.settings_export_progress_writing)
            NotesExportStage.PACKAGING -> stringResource(R.string.settings_export_progress_packaging)
            else -> stringResource(R.string.settings_export_progress_preparing)
        }
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.settings_export_all_notes)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stageMessage)
                    LinearProgressIndicator(
                        progress = { progress?.fraction ?: 0f },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    progress?.takeIf { it.total > 0 }?.let {
                        Text(
                            pluralStringResource(R.plurals.settings_export_progress_count, it.total, it.processed, it.total),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { exportJob?.cancel() }) {
                    Text(stringResource(R.string.common_cancel), color = MaterialTheme.colorScheme.error)
                }
            },
        )
    }
    if (showSubscription) SubscriptionDialog(
        uiState = uiState,
        billingState = billingState,
        onDismiss = { showSubscription = false },
        onPurchase = onPurchase,
        onRestore = onRestorePurchases,
        onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
    )
    exportError?.let { message ->
        AlertDialog(
            onDismissRequest = { exportError = null },
            title = { Text(stringResource(R.string.settings_export_all_notes)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { exportError = null }) { Text(stringResource(R.string.common_close)) } },
        )
    }
    if (showVoiceSettings) VoiceLanguageDialog(
        settings = voiceSettings,
        onDismiss = { showVoiceSettings = false },
        onSave = { mode, hint -> onUpdateVoice(mode, hint); showVoiceSettings = false },
    )
    if (showMediaSections) MediaLinkSectionsDialog(
        current = mediaSections,
        onDismiss = { showMediaSections = false },
        onSave = { onUpdateMediaSections(it); showMediaSections = false },
    )
    if (showAbout) AlertDialog(
        onDismissRequest = { showAbout = false },
        title = { Text(stringResource(R.string.settings_about)) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.settings_about_message))
            Text(stringResource(R.string.settings_version_format, BuildConfig.VERSION_NAME))
        } },
        confirmButton = { TextButton(onClick = { showAbout = false }) { Text(stringResource(R.string.common_close)) } },
    )
}

@Composable
private fun VoiceLanguageDialog(
    settings: VoiceLanguageSettings,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit,
) {
    var mode by remember(settings) { mutableStateOf(settings.mode) }
    var hint by remember(settings) { mutableStateOf(settings.languageHint) }
    var search by remember { mutableStateOf("") }
    val languageCodes = remember { listOf(
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "ar", "bn", "bg", "hr", "cs", "da",
        "nl", "et", "fi", "el", "he", "hi", "hu", "id", "it", "lv", "lt", "no", "pl", "pt", "ro", "ru",
        "sr", "sk", "sl", "sw", "sv", "th", "tr", "uk", "vi",
    ) }
    val locale = LocalConfiguration.current.locales[0]
    val filtered = languageCodes.filter { code ->
        val name = Locale.forLanguageTag(code).getDisplayName(locale)
        search.isBlank() || code.contains(search, true) || name.contains(search, true)
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.settings_voice_title)) },
        text = { Column {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(mode == "auto", { mode = "auto" }, { Text(stringResource(R.string.settings_voice_auto)) })
                FilterChip(mode == "prefer", { mode = "prefer" }, { Text(stringResource(R.string.settings_voice_prefer)) })
            }
            Text(
                stringResource(if (mode == "auto") R.string.settings_voice_auto_help else R.string.settings_voice_preferred_help),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(vertical = 8.dp),
            )
            if (mode == "prefer") {
                OutlinedTextField(search, { search = it }, label = { Text(stringResource(R.string.settings_voice_search)) }, modifier = Modifier.fillMaxWidth())
                LazyColumn(Modifier.height(280.dp)) {
                    items(filtered, key = { it }) { code ->
                        val name = Locale.forLanguageTag(code).getDisplayName(locale).ifBlank { code }
                        Row(
                            Modifier.fillMaxWidth().clickable { hint = code }.padding(vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(name, modifier = Modifier.weight(1f))
                            Text(code, color = if (hint == code) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        } },
        confirmButton = { TextButton(onClick = { onSave(mode, hint) }, enabled = mode == "auto" || hint.isNotBlank()) { Text(stringResource(R.string.common_save)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun MediaLinkSectionsDialog(
    current: MediaLinkSectionsDto,
    onDismiss: () -> Unit,
    onSave: (MediaLinkSectionsDto) -> Unit,
) {
    var value by remember(current) { mutableStateOf(current) }
    val selectedCount = listOf(value.showDescription, value.showAuthor, value.showHook, value.showTranscript).count { it }
    fun update(field: String, enabled: Boolean) {
        if (!enabled && selectedCount <= 1) return
        value = when (field) {
            "description" -> value.copy(showDescription = enabled)
            "author" -> value.copy(showAuthor = enabled)
            "hook" -> value.copy(showHook = enabled)
            else -> value.copy(showTranscript = enabled)
        }
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.settings_media_sections_title)) },
        text = { Column {
            Text(stringResource(R.string.settings_media_sections_help), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(bottom = 10.dp))
            listOf(
                Triple("description", R.string.settings_media_description, value.showDescription),
                Triple("author", R.string.settings_media_author, value.showAuthor),
                Triple("hook", R.string.settings_media_hook, value.showHook),
                Triple("transcript", R.string.settings_media_transcript, value.showTranscript),
            ).forEach { (field, label, checked) ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(label), modifier = Modifier.weight(1f))
                    Switch(checked = checked, onCheckedChange = { update(field, it) })
                }
            }
        } },
        confirmButton = { TextButton(onClick = { onSave(value) }) { Text(stringResource(R.string.common_done)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun SubscriptionDialog(
    uiState: AppUiState,
    billingState: BillingUiState,
    onDismiss: () -> Unit,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onManage: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (uiState.subscriptionTier == "pro") stringResource(R.string.subscription_current_pro) else stringResource(R.string.subscription_upgrade_title)) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (uiState.subscriptionTier == "pro") {
                Text(stringResource(R.string.subscription_active_message))
                uiState.subscriptionExpiresAt?.let { Text(stringResource(R.string.subscription_expires_format, it)) }
            } else if (billingState.loading) {
                CircularProgressIndicator()
            } else if (billingState.products.isEmpty()) {
                Text(billingState.error ?: stringResource(R.string.subscription_products_unavailable))
            } else billingState.products.forEach { product ->
                Button(onClick = { onPurchase(product) }, modifier = Modifier.fillMaxWidth()) {
                    Text("${product.title} · ${product.formattedPrice}")
                }
            }
            billingState.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            TextButton(onClick = onRestore, enabled = !billingState.restoring) {
                if (billingState.restoring) CircularProgressIndicator()
                else Text(stringResource(R.string.subscription_restore_purchases))
            }
        } },
        confirmButton = {
            if (uiState.subscriptionTier == "pro") TextButton(onClick = onManage) { Text(stringResource(R.string.subscription_manage)) }
            else TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) }
        },
        dismissButton = { if (uiState.subscriptionTier == "pro") TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_close)) } },
    )
}

@Composable
private fun SettingsRow(label: String, value: String? = null, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        value?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
        Icon(Icons.AutoMirrored.Outlined.OpenInNew, null, modifier = Modifier.padding(start = 8.dp))
    }
}

@Composable
private fun TagManagerDialog(tags: List<TagEntity>, onDismiss: () -> Unit, onEdit: (TagEntity) -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.tags_manage_title)) },
        text = {
            LazyColumn {
                items(tags, key = { it.id }) { tag ->
                    Row(
                        Modifier.fillMaxWidth().clickable { onEdit(tag) }.padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TagColorDot(tag.colorHex, selected = false)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text(tag.name)
                            tag.parentId?.let { parentId ->
                                tags.firstOrNull { it.id == parentId }?.let { parent ->
                                    Text(
                                        stringResource(R.string.tags_parent_value_format, parent.name),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_close)) } },
    )
}

@Composable
private fun BatchTagDialog(
    tags: List<TagEntity>,
    selectedNoteIds: Set<String>,
    noteTags: List<NoteTagCrossRef>,
    onDismiss: () -> Unit,
    onApply: (TagEntity) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.home_batch_tag_title)) },
        text = {
            if (tags.isEmpty()) Text(stringResource(R.string.home_batch_tag_empty))
            else LazyColumn {
                items(tags, key = { it.id }) { tag ->
                    val appliedCount = selectedNoteIds.count { noteId ->
                        noteTags.any { it.noteId == noteId && it.tagId == tag.id }
                    }
                    val isAppliedToAll = selectedNoteIds.isNotEmpty() && appliedCount == selectedNoteIds.size
                    Row(
                        Modifier.fillMaxWidth()
                            .clickable(enabled = !isAppliedToAll) { onApply(tag) }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TagColorDot(tag.colorHex, selected = isAppliedToAll)
                        Text(tag.name, modifier = Modifier.weight(1f).padding(start = 12.dp))
                        if (isAppliedToAll) Text(stringResource(R.string.home_batch_tag_added), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else if (appliedCount > 0) Text(stringResource(R.string.home_batch_tag_partial), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun TagEditorDialog(
    tag: TagEntity?,
    tags: List<TagEntity>,
    onDismiss: () -> Unit,
    onSave: (String, String, String?) -> Unit,
    onDelete: (() -> Unit)? = null,
) {
    var name by remember(tag?.id) { mutableStateOf(tag?.name.orEmpty()) }
    var colorHex by remember(tag?.id) { mutableStateOf(tag?.colorHex ?: TagColors.automatic(tags)) }
    var parentId by remember(tag?.id) { mutableStateOf(tag?.parentId) }
    var confirmDelete by remember(tag?.id) { mutableStateOf(false) }
    val possibleParents = if (tag == null) tags else TagHierarchy.validParents(tag.id, tags)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(if (tag == null) R.string.tags_create_title else R.string.tags_edit_title)) },
        text = { Column {
            OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.tags_name_placeholder)) })
            Text(stringResource(R.string.tags_color_title), modifier = Modifier.padding(top = 16.dp, bottom = 8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                items(TagColors.Palette) { candidate ->
                    TagColorDot(candidate, selected = candidate == colorHex, modifier = Modifier.clickable { colorHex = candidate })
                }
            }
            if (possibleParents.isNotEmpty()) {
                Text(stringResource(R.string.tags_parent_title), modifier = Modifier.padding(top = 12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(parentId == null, { checked -> if (checked) parentId = null })
                    Text(stringResource(R.string.tags_no_parent))
                }
                possibleParents.forEach { parent -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(parentId == parent.id, { checked -> parentId = if (checked) parent.id else null }); Text(parent.name)
                } }
            }
        } },
        confirmButton = { TextButton(onClick = { onSave(name, colorHex, parentId) }, enabled = name.isNotBlank()) { Text(stringResource(R.string.common_save)) } },
        dismissButton = { Row {
            if (onDelete != null) TextButton(onClick = { confirmDelete = true }) { Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) }
        } },
    )
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text(stringResource(R.string.tags_delete_confirm_title, tag?.name.orEmpty())) },
        text = { Text(stringResource(R.string.tags_delete_confirm_message)) },
        confirmButton = { TextButton(onClick = { confirmDelete = false; onDelete?.invoke() }) { Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun TagColorDot(hex: String, selected: Boolean, modifier: Modifier = Modifier) {
    val color = Color(android.graphics.Color.parseColor(TagColors.normalize(hex)))
    Box(
        modifier.size(32.dp)
            .background(color, CircleShape)
            .border(if (selected) 3.dp else 1.dp, if (selected) MaterialTheme.colorScheme.onSurface else Color.Transparent, CircleShape),
    )
}

@Composable private fun NoteRow(
    note: NoteEntity,
    isTrash: Boolean,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit,
    onPin: () -> Unit,
    onMove: (String) -> Unit,
    onDelete: () -> Unit,
    onOpenSource: (String) -> Unit,
    onRestore: () -> Unit,
    onPermanentDelete: () -> Unit,
) = Column(
    Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 14.dp),
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        if (isSelectionMode) Checkbox(checked = isSelected, onCheckedChange = { onClick() })
        if (note.importStatus == "queued" || note.importStatus == "processing") {
            Text(stringResource(R.string.link_import_processing), modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.primary)
        } else {
            MarkdownText(note.content, maxLines = 4, modifier = Modifier.weight(1f))
        }
        if (!isSelectionMode) IconButton(onClick = if (isTrash) onRestore else onPin) {
            Icon(
                if (isTrash) Icons.Outlined.Restore else Icons.Outlined.PushPin,
                stringResource(if (isTrash) R.string.note_restore else R.string.note_pin),
                tint = if (note.pinnedAt != null) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (!isTrash && !isSelectionMode) NoteActionsMenu(note.section, onMove, onDelete)
        if (isTrash && !isSelectionMode) IconButton(onClick = onPermanentDelete) {
            Icon(Icons.Outlined.Delete, stringResource(R.string.trash_delete_permanently))
        }
    }
    note.sourceMetadata()?.let { source ->
        NoteSourceCard(source = source, compact = true, onOpen = { onOpenSource(source.url) })
    }
    if (note.importStatus == "failed") {
        Text(stringResource(R.string.link_import_failed), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
    }
    Text(note.updatedAt, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    if (isTrash) note.deletedAt?.let { deletedAt ->
        val days = TrashPolicy.daysRemaining(deletedAt)
        Text(
            if (days == 0L) stringResource(R.string.trash_expires_today)
            else pluralStringResource(
                R.plurals.trash_days_left,
                days.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt(),
                days,
            ),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun NoteActionsMenu(currentSection: String, onMove: (String) -> Unit, onDelete: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Outlined.MoreVert, stringResource(R.string.note_actions))
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            listOf("inbox", "drafts", "published").filter { it != currentSection }.forEach { section ->
                DropdownMenuItem(
                    text = { Text(stringResource(section.moveActionResource())) },
                    onClick = { expanded = false; onMove(section) },
                )
            }
            DropdownMenuItem(
                text = { Text(stringResource(R.string.note_delete), color = MaterialTheme.colorScheme.error) },
                onClick = { expanded = false; onDelete() },
            )
        }
    }
}

private fun String.titleResource(): Int = when (this) {
    "drafts" -> R.string.home_section_drafts
    "published" -> R.string.home_section_published
    "trash" -> R.string.home_section_trash
    else -> R.string.home_section_inbox
}

private fun String.moveActionResource(): Int = when (this) {
    "drafts" -> R.string.note_move_to_drafts
    "published" -> R.string.note_move_to_published
    else -> R.string.note_move_to_inbox
}
