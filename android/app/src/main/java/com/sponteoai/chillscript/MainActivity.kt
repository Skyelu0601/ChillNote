package com.sponteoai.chillscript

import android.content.Intent
import android.content.ClipboardManager
import android.content.ClipDescription
import android.os.Bundle
import android.os.Build
import android.net.Uri
import android.provider.Settings
import android.Manifest
import android.content.pm.PackageManager
import android.text.format.DateUtils
import android.text.format.Formatter
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.BackHandler
import androidx.activity.viewModels
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.selectable
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
import androidx.compose.foundation.lazy.itemsIndexed
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
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
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
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalResources
import com.sponteoai.chillscript.auth.AuthState
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import com.sponteoai.chillscript.ui.theme.BrandBackground
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.billing.BillingProduct
import com.sponteoai.chillscript.billing.BillingUiState
import com.sponteoai.chillscript.billing.PlayBillingManager
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import com.sponteoai.chillscript.voice.VoiceRecorder
import com.sponteoai.chillscript.voice.PendingRecording
import com.sponteoai.chillscript.voice.PendingRecordingOrigin
import com.sponteoai.chillscript.domain.ChecklistDraft
import com.sponteoai.chillscript.domain.ChecklistDraftItem
import com.sponteoai.chillscript.domain.ChecklistMarkdown
import com.sponteoai.chillscript.domain.MarkdownEditing
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TagHierarchy
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.shouldPersistEditorContentOnClose
import com.sponteoai.chillscript.domain.sourceMetadata
import com.sponteoai.chillscript.ui.markdown.MarkdownText
import com.sponteoai.chillscript.ui.source.NoteSourceCard
import com.sponteoai.chillscript.ui.home.IOSParityHomeScreen
import com.sponteoai.chillscript.ui.home.HomeFirstActionGuideStore
import com.sponteoai.chillscript.ui.home.HomeFirstActionStage
import com.sponteoai.chillscript.ui.editor.IOSParityEditorScreen
import com.sponteoai.chillscript.ui.settings.IOSParitySettingsContent
import com.sponteoai.chillscript.ui.settings.IOSParityAboutScreen
import com.sponteoai.chillscript.ui.settings.IOSParityExportAllNotesSheet
import com.sponteoai.chillscript.ui.settings.IOSParityVoiceLanguageSheet
import com.sponteoai.chillscript.ui.recordings.IOSParityPendingRecordingsScreen
import com.sponteoai.chillscript.onboarding.OnboardingPreferences
import com.sponteoai.chillscript.onboarding.IOSParityOnboardingScreen
import com.sponteoai.chillscript.ui.auth.IOSParityLoginScreen
import com.sponteoai.chillscript.ui.subscription.IOSParitySubscriptionScreen
import com.sponteoai.chillscript.ui.subscription.SubscriptionDebugPreviewPricing
import com.sponteoai.chillscript.ui.subscription.SubscriptionScreenContext
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Locale
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import com.sponteoai.chillscript.preferences.VoiceLanguageSettings
import com.sponteoai.chillscript.data.remote.extractWebUrl
import com.sponteoai.chillscript.data.remote.extractCreatorMediaUrl
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.sponteoai.chillscript.weekly.WeeklyTopicsController
import com.sponteoai.chillscript.weekly.WeeklyTopicsPreviewScreen
import com.sponteoai.chillscript.weekly.WeeklyTopicsRoute
import com.sponteoai.chillscript.weekly.WeeklyTopicsSettingsOverlay
import com.sponteoai.chillscript.weekly.WeeklyTopicsTokenProvider
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import com.sponteoai.chillscript.sync.BackgroundSyncScheduler
import com.sponteoai.chillscript.push.PushContract
import com.sponteoai.chillscript.push.PushDestination
import com.sponteoai.chillscript.push.PushNotificationManager
import com.sponteoai.chillscript.push.ImportNotificationPromptPreferences
import com.sponteoai.chillscript.push.ImportedContentCandidate
import com.sponteoai.chillscript.push.parsePushDestination
import com.sponteoai.chillscript.push.shouldOfferImportNotificationPrompt

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels()
    private val sharedText = mutableStateOf<String?>(null)
    private val recordRequest = mutableLongStateOf(0L)
    private val weeklyTopicsRequest = mutableLongStateOf(0L)
    private val notificationNoteRequest = mutableStateOf<String?>(null)
    private lateinit var credentialManager: CredentialManager
    private lateinit var billingManager: PlayBillingManager
    private lateinit var onboardingPreferences: OnboardingPreferences
    private lateinit var reviewManager: ReviewManager
    private var foregroundSyncJob: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BackgroundSyncScheduler.ensurePeriodic(this)
        credentialManager = CredentialManager.create(this)
        billingManager = PlayBillingManager(this, viewModel::verifyGooglePlayPurchase)
        onboardingPreferences = OnboardingPreferences(this)
        reviewManager = ReviewManagerFactory.create(this)
        billingManager.connect()
        sharedText.value = intent.sharedPlainText()
        captureSharedVideo(intent)
        if (intent.isRecordRequest()) recordRequest.longValue = System.nanoTime()
        intent.oauthCallback()?.let { callback ->
            intent.data = null
            viewModel.handleOAuthCallback(callback)
        }
        handlePushIntent(intent)
        val showSubscriptionPreview = BuildConfig.DEBUG &&
            intent.getBooleanExtra("chillscript.debug.subscription_preview", false)
        setContent {
            val uiState by viewModel.uiState.collectAsState()
            val notes by viewModel.notes.collectAsState()
            val tags by viewModel.tags.collectAsState()
            val noteTags by viewModel.noteTags.collectAsState()
            val searchResults by viewModel.searchResults.collectAsState()
            val pendingRecordings by viewModel.pendingRecordings.collectAsState()
            val billingState by billingManager.state.collectAsState()
            val aiConsentPrompt by viewModel.aiConsentPrompt.collectAsState()
            LaunchedEffect(Unit) {
                viewModel.reviewRequests.collect { launchInAppReview() }
            }
            var hasViewedIntro by remember { mutableStateOf(onboardingPreferences.hasViewedIntroOnDevice()) }
            ChillScriptTheme {
                if (showSubscriptionPreview) {
                    IOSParitySubscriptionScreen(
                        context = SubscriptionScreenContext.OnboardingTrial,
                        isPro = false,
                        subscriptionExpiresAt = null,
                        billingState = billingState,
                        onPurchase = {},
                        onRestore = billingManager::restorePurchases,
                        onRetryProducts = billingManager::connect,
                        onDismiss = ::finish,
                        onOpenUrl = ::openExternalTarget,
                        debugPreviewPricing = SubscriptionDebugPreviewPricing(
                            annualPrice = "¥398",
                            annualWeeklyPrice = "¥7.65",
                            weeklyPrice = "¥48",
                            annualTrialDayCount = 7,
                        ),
                    )
                } else when (uiState.authState) {
                    AuthState.Checking -> LoadingScreen()
                    AuthState.SignedOut -> if (hasViewedIntro) {
                        IOSParityLoginScreen(
                            state = uiState,
                            onGoogleSignIn = ::startGoogleSignIn,
                            onAppleSignIn = ::startAppleSignIn,
                            onSendCode = viewModel::sendCode,
                            onVerifyCode = viewModel::verifyCode,
                            onBackToEmail = viewModel::backToEmail,
                            onClearError = viewModel::clearError,
                            onOpenUrl = ::openExternalTarget,
                        )
                    } else {
                        IOSParityOnboardingScreen(
                            onFinish = {
                                onboardingPreferences.setIntroViewedOnDevice()
                                hasViewedIntro = true
                            },
                            onLogIn = {
                                onboardingPreferences.setIntroViewedOnDevice()
                                hasViewedIntro = true
                            },
                        )
                    }
                    is AuthState.SignedIn -> if (!uiState.introPaywallResolved) LoadingScreen() else if (uiState.introPaywallRequired) {
                        IOSParitySubscriptionScreen(
                            context = SubscriptionScreenContext.OnboardingTrial,
                            isPro = false,
                            subscriptionExpiresAt = null,
                            billingState = billingState,
                            isPurchasing = uiState.busy,
                            onPurchase = { product -> viewModel.currentUserId?.let { billingManager.launchPurchase(this, product, it) } },
                            onRestore = billingManager::restorePurchases,
                            onRetryProducts = billingManager::connect,
                            onDismiss = viewModel::dismissIntroPaywall,
                            onOpenUrl = ::openExternalTarget,
                        )
                    } else HomeScreen(
                        notes, searchResults, tags, noteTags, pendingRecordings, sharedText.value, uiState, viewModel,
                        onSharedTextConsumed = { sharedText.value = null },
                        recordRequest = recordRequest.longValue,
                        onRecordRequestConsumed = { recordRequest.longValue = 0L },
                        weeklyTopicsRequest = weeklyTopicsRequest.longValue,
                        onWeeklyTopicsRequestConsumed = { weeklyTopicsRequest.longValue = 0L },
                        notificationNoteId = notificationNoteRequest.value,
                        onNotificationNoteConsumed = { notificationNoteRequest.value = null },
                        billingState = billingState,
                        onPurchase = { product -> viewModel.currentUserId?.let { billingManager.launchPurchase(this, product, it) } },
                        onRestorePurchases = billingManager::restorePurchases,
                        onRetryBilling = billingManager::connect,
                        onOpenUrl = ::openExternalTarget,
                        onRequestReview = ::launchInAppReview,
                    )
                }
                aiConsentPrompt?.let { prompt ->
                    AIConsentDialog(
                        prompt = prompt,
                        onAccept = viewModel::acceptAIDataConsent,
                        onDecline = viewModel::declineAIDataConsent,
                        onOpenPrivacyPolicy = { openExternalTarget("https://www.chillnoteai.com/privacy") },
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedText.value = intent.sharedPlainText()
        captureSharedVideo(intent)
        if (intent.isRecordRequest()) recordRequest.longValue = System.nanoTime()
        intent.oauthCallback()?.let { callback ->
            intent.data = null
            viewModel.handleOAuthCallback(callback)
        }
        handlePushIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        foregroundSyncJob?.cancel()
        foregroundSyncJob = lifecycleScope.launch {
            while (true) {
                // onResume already schedules an immediate network-constrained sync.
                // Poll only while this Activity remains visible so iOS edits arrive
                // promptly without keeping a foreground timer alive in background.
                delay(FOREGROUND_SYNC_INTERVAL_MS)
                viewModel.syncFromForegroundPoll()
            }
        }
    }

    override fun onStop() {
        foregroundSyncJob?.cancel()
        foregroundSyncJob = null
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        BackgroundSyncScheduler.enqueueForegroundSync(this)
        viewModel.consumePendingShareImports()
        viewModel.refreshPushRegistration()
        if (intent.action != Intent.ACTION_SEND) importNewClipboardCreatorLink()
    }

    override fun onDestroy() {
        billingManager.close()
        super.onDestroy()
    }

    private fun handlePushIntent(intent: Intent) {
        val destination = parsePushDestination(
            route = intent.getStringExtra(PushContract.DATA_ROUTE),
            noteId = intent.getStringExtra(PushContract.DATA_NOTE_ID),
        )
        when (destination) {
            PushDestination.WeeklyTopics -> {
                notificationNoteRequest.value = null
                weeklyTopicsRequest.longValue = System.nanoTime()
            }
            is PushDestination.Note -> {
                weeklyTopicsRequest.longValue = 0L
                notificationNoteRequest.value = destination.noteId
            }
            PushDestination.Home -> return
        }
        intent.removeExtra(PushContract.DATA_ROUTE)
        intent.removeExtra(PushContract.DATA_NOTE_ID)
        intent.removeExtra(PushContract.DATA_KIND)
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
            } catch (_: GetCredentialCancellationException) {
                // Closing the Google account chooser is a normal user action, not a login error.
            } catch (_: NoCredentialException) {
                viewModel.reportAuthError(getString(R.string.auth_google_no_account))
            } catch (error: GetCredentialException) {
                Log.w(TAG, "Google credential request failed", error)
                viewModel.reportAuthError(getString(R.string.auth_google_failed))
            } catch (error: Throwable) {
                Log.w(TAG, "Google sign-in failed", error)
                viewModel.reportAuthError(getString(R.string.auth_google_failed))
            }
        }
    }

    private fun startAppleSignIn() {
        val url = runCatching(viewModel::beginAppleOAuth).getOrElse {
            Log.w(TAG, "Could not prepare Apple sign-in", it)
            viewModel.reportAuthError(getString(R.string.auth_apple_failed))
            return
        }
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
        openExternalTarget(uri.toString())
    }

    private fun openExternalTarget(target: String) {
        val action = if (target.startsWith("package:")) {
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS
        } else {
            Intent.ACTION_VIEW
        }
        runCatching { startActivity(Intent(action, Uri.parse(target))) }
            .onFailure {
                Log.w(TAG, "No activity can open external target", it)
                Toast.makeText(this, R.string.android_external_link_error, Toast.LENGTH_LONG).show()
            }
    }

    private fun openAppLanguageSettings() {
        val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Settings.ACTION_APP_LOCALE_SETTINGS
        } else {
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS
        }
        runCatching { startActivity(Intent(action, Uri.parse("package:$packageName"))) }
            .onFailure { Toast.makeText(this, R.string.android_external_link_error, Toast.LENGTH_LONG).show() }
    }

    private fun importNewClipboardCreatorLink() {
        if (viewModel.currentUserId == null) return
        val clipboard = getSystemService(ClipboardManager::class.java)
        val description = clipboard.primaryClipDescription ?: return
        if (!description.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN) &&
            !description.hasMimeType(ClipDescription.MIMETYPE_TEXT_HTML)
        ) return
        val text = clipboard.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()?.trim().orEmpty()
        val url = extractCreatorMediaUrl(text) ?: return
        val fingerprint = "${description.timestamp}:${text.hashCode()}"
        val preferences = getSharedPreferences("clipboard_import", MODE_PRIVATE)
        if (preferences.getString("last_clip", null) == fingerprint) return
        preferences.edit().putString("last_clip", fingerprint).apply()
        sharedText.value = url
    }

    private fun captureSharedVideo(intent: Intent) {
        val uri = intent.sharedVideoUri() ?: return
        val sourcePackage = intent.sharedSourcePackageHint() ?: referrer?.host
        viewModel.captureSharedVideo(uri, intent.type, sourcePackage)
        // The content has already been claimed by the ViewModel. Removing the payload prevents
        // a configuration change from importing the same video twice; the URI grant remains
        // valid for the launched task while the private copy is made.
        intent.removeExtra(Intent.EXTRA_STREAM)
        intent.clipData = null
    }

    private companion object {
        const val TAG = "MainActivity"
        const val FOREGROUND_SYNC_INTERVAL_MS = 60_000L
    }
}

private fun Intent.sharedPlainText(): String? =
    takeIf { action == Intent.ACTION_SEND && type?.startsWith("text/") == true }
        ?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()

private fun Intent.sharedVideoUri(): Uri? {
    if (action != Intent.ACTION_SEND || type?.startsWith("video/") != true) return null
    val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        @Suppress("DEPRECATION")
        (getParcelableExtra<android.os.Parcelable>(Intent.EXTRA_STREAM) as? Uri)
    }
    return stream ?: clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
}

private fun Intent.sharedSourcePackageHint(): String? {
    val raw = getStringExtra(Intent.EXTRA_REFERRER_NAME)?.trim().orEmpty()
    return raw.takeIf(String::isNotEmpty)?.let { value ->
        runCatching { Uri.parse(value).host }.getOrNull() ?: value.take(240)
    }
}

private fun Intent.oauthCallback(): Uri? = data?.takeIf { uri ->
    (uri.scheme.equals("chillscript", ignoreCase = true) &&
        uri.host.equals("auth-callback", ignoreCase = true)) ||
        (uri.scheme.equals("https", ignoreCase = true) &&
            uri.host.equals("www.chillnoteai.com", ignoreCase = true) &&
            uri.path == "/auth/android/callback")
}

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

@Composable
private fun LoadingScreen() = BrandBackground {
    CircularProgressIndicator(
        color = ChillColors.BrandBlue,
        strokeWidth = 4.dp,
        modifier = Modifier.align(Alignment.Center).size(48.dp),
    )
}

@Composable
private fun LoginScreen(
    state: AppUiState,
    viewModel: AppViewModel,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(stringResource(R.string.app_name), style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
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
        Text(
            stringResource(R.string.auth_login_legal_plain),
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(top = 28.dp),
        )
        Row(horizontalArrangement = Arrangement.Center) {
            TextButton(onClick = { onOpenUrl("https://www.chillnoteai.com/terms") }) {
                Text(stringResource(R.string.settings_terms))
            }
            TextButton(onClick = { onOpenUrl("https://www.chillnoteai.com/privacy") }) {
                Text(stringResource(R.string.settings_privacy_policy))
            }
        }
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
    weeklyTopicsRequest: Long, onWeeklyTopicsRequestConsumed: () -> Unit,
    notificationNoteId: String?, onNotificationNoteConsumed: () -> Unit,
    billingState: BillingUiState, onPurchase: (BillingProduct) -> Unit, onRestorePurchases: () -> Unit,
    onRetryBilling: () -> Unit,
    onRequestReview: () -> Unit,
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
    LaunchedEffect(editorOpen) {
        viewModel.setEditorActive(editorOpen)
    }
    DisposableEffect(viewModel) {
        onDispose { viewModel.setEditorActive(false) }
    }
    var searchQuery by remember { mutableStateOf("") }
    var searchVisible by remember { mutableStateOf(false) }
    var selectedTagId by remember { mutableStateOf<String?>(null) }
    var showCreateTag by remember { mutableStateOf(false) }
    var taggingNoteId by remember { mutableStateOf<String?>(null) }
    var showManageTags by remember { mutableStateOf(false) }
    var editingTag by remember { mutableStateOf<TagEntity?>(null) }
    var isSelectionMode by remember { mutableStateOf(false) }
    var selectedNoteIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var showBatchTagDialog by remember { mutableStateOf(false) }
    var showBatchDeleteConfirmation by remember { mutableStateOf(false) }
    var showAskSoftLimitAlert by remember { mutableStateOf(false) }
    var showAskHardLimitAlert by remember { mutableStateOf(false) }
    var showEmptyTrashConfirmation by remember { mutableStateOf(false) }
    var pendingPermanentDeleteNote by remember { mutableStateOf<NoteEntity?>(null) }
    var selectedEditorTagIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var editorPersistedContent by remember { mutableStateOf("") }
    var editorTagSelectionTouched by remember { mutableStateOf(false) }
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
    var noteExportFailed by remember { mutableStateOf(false) }
    var showSubscription by remember { mutableStateOf(false) }
    var showWeeklyTopics by remember { mutableStateOf(false) }
    var showWeeklyTopicsPreview by remember { mutableStateOf(false) }
    var showWeeklyTopicsSettings by remember { mutableStateOf(false) }
    var creatingEditorNote by remember { mutableStateOf(false) }
    var appliedAITransformation by remember { mutableStateOf<AppliedAISkillTransformation?>(null) }
    var retryingAITransformation by remember { mutableStateOf<AppliedAISkillTransformation?>(null) }
    var returnToNoteRequest by remember { mutableLongStateOf(0L) }
    val installedRecipes by viewModel.installedRecipes.collectAsState()
    val aiSkillState by viewModel.aiSkillState.collectAsState()
    val contextChatState by viewModel.contextChatState.collectAsState()
    val voiceNoteStates by viewModel.voiceNoteStates.collectAsState()
    val activeVoiceNoteState = editingNote?.id?.let(voiceNoteStates::get)
    val voiceLanguageSettings by viewModel.voiceLanguageSettings.collectAsState()
    val coroutineScope = rememberCoroutineScope()
    LaunchedEffect(viewModel) {
        viewModel.paywallRequests.collect { showSubscription = true }
    }
    val weeklyTopicsController = remember(viewModel.currentUserId) {
        WeeklyTopicsController(
            tokenProvider = WeeklyTopicsTokenProvider { viewModel.weeklyTopicsAccessToken() },
        )
    }
    val weeklyTopicsState by weeklyTopicsController.state.collectAsState()
    val context = LocalContext.current
    val signedInUser = (uiState.authState as? AuthState.SignedIn)?.session?.user
    var homeNoteRevealTargetId by remember(signedInUser?.id) { mutableStateOf<String?>(null) }
    LaunchedEffect(viewModel, signedInUser?.id) {
        val userId = signedInUser?.id ?: return@LaunchedEffect
        viewModel.homeNoteRevealEvents.collect { request ->
            if (request.userId == userId) homeNoteRevealTargetId = request.noteId
        }
    }
    val firstActionGuideStore = remember(context) { HomeFirstActionGuideStore(context) }
    var firstActionGuideState by remember(signedInUser?.id) {
        mutableStateOf(firstActionGuideStore.configure(signedInUser?.id, signedInUser?.createdAt))
    }
    var captureFirstActionImport by remember(signedInUser?.id) { mutableStateOf(false) }
    var firstActionImportBaseline by remember(signedInUser?.id) { mutableStateOf<Set<String>>(emptySet()) }
    LaunchedEffect(viewModel, signedInUser?.id) {
        val userId = signedInUser?.id ?: return@LaunchedEffect
        viewModel.pendingShareImportAdoptionEvents.collect { adoption ->
            if (adoption.userId == userId &&
                (firstActionGuideState.stage == HomeFirstActionStage.SharePrompt ||
                    firstActionGuideState.stage == HomeFirstActionStage.AwaitingShare)
            ) {
                firstActionGuideState = firstActionGuideStore.registerImport(
                    userId,
                    firstActionGuideState,
                    adoption.noteId,
                )
            }
        }
    }
    val completeFirstActionAISkillFlow: () -> Unit = {
        val userId = signedInUser?.id
        val noteId = editingNote?.id
        if (userId != null && noteId != null) {
            firstActionGuideState = firstActionGuideStore.markAISkillsFlowDismissed(
                userId,
                firstActionGuideState,
                noteId,
            )
        }
    }
    val importNotificationPromptPreferences = remember(context) {
        ImportNotificationPromptPreferences(context)
    }
    var showImportNotificationPermissionPrompt by remember { mutableStateOf(false) }
    val voiceStartError = stringResource(R.string.voice_error_start)
    val voicePermissionError = stringResource(R.string.voice_error_permission)
    val voiceEmptyError = stringResource(R.string.voice_error_empty)
    val voiceRecorder = remember { VoiceRecorder(context) }
    var isRecording by remember { mutableStateOf(false) }
    val microphonePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) runCatching { voiceRecorder.start(); isRecording = true }
            .onFailure { viewModel.reportAuthError(voiceStartError) }
        else viewModel.reportAuthError(voicePermissionError)
    }
    val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.refreshPushRegistration()
    }
    val requestPushRegistration = {
        viewModel.currentUserId?.let(importNotificationPromptPreferences::markSeen)
        showImportNotificationPermissionPrompt = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            viewModel.refreshPushRegistration()
        }
    }
    val beginVoiceCapture: () -> Unit = {
        if (!isRecording && ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            runCatching { voiceRecorder.start(); isRecording = true }
                .onFailure { viewModel.reportAuthError(voiceStartError) }
        } else if (!isRecording) microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
    }
    val startVoiceRecording = {
        if (!isRecording) {
            viewModel.authorizeVoiceRecordingStart(
                onAuthorized = beginVoiceCapture,
                onInsufficientCredits = { showSubscription = true },
            )
        }
    }
    val activeCaptureSection = selectedSection.takeIf { it in setOf("inbox", "drafts", "published") } ?: "inbox"
    val activeCaptureTagIds = selectedTagId?.let { setOf(it) }.orEmpty()
    val currentEditorContent: () -> String = {
        checklistDraft?.let { ChecklistMarkdown.serialize(it.notes, it.items) } ?: editorText.text
    }
    val clearEditorState: () -> Unit = {
        editorOpen = false
        editingNote = null
        editorText = TextFieldValue("")
        checklistDraft = null
        selectedEditorTagIds = emptySet()
        editorPersistedContent = ""
        editorTagSelectionTouched = false
        undoStack = emptyList()
        redoStack = emptyList()
        editorPreview = false
        showNoteExport = false
        appliedAITransformation = null
        retryingAITransformation = null
    }
    val openNoteInEditor: (NoteEntity) -> Unit = { note ->
        val loadedTagIds = noteTags.filter { it.noteId == note.id }.mapTo(mutableSetOf()) { it.tagId }
        selectedSection = if (note.deletedAt != null) "trash" else note.section
        editingNote = note
        editorText = TextFieldValue(note.content)
        checklistDraft = ChecklistMarkdown.parse(note.content)
        selectedEditorTagIds = loadedTagIds
        editorPersistedContent = currentEditorContent()
        editorTagSelectionTouched = false
        undoStack = emptyList()
        redoStack = emptyList()
        editorPreview = false
        appliedAITransformation = null
        retryingAITransformation = null
        editorOpen = true
    }
    val saveAndCloseEditor: () -> Unit = {
        val note = editingNote
        val content = currentEditorContent()
        val isVoiceProcessing = activeVoiceNoteState is VoiceNoteState.Processing
        when {
            note?.deletedAt != null -> Unit
            note != null && content.isBlank() && activeVoiceNoteState != null -> Unit
            note != null && content.isBlank() && !isVoiceProcessing -> viewModel.permanentlyDelete(note)
            note != null || content.isNotBlank() -> {
                if (shouldPersistEditorContentOnClose(
                        hasExistingNote = note != null,
                        currentContent = content,
                        persistedContent = editorPersistedContent,
                        isVoiceProcessing = isVoiceProcessing,
                    )
                ) {
                    viewModel.saveNote(note, content, note?.section ?: activeCaptureSection)
                }
            }
        }
        clearEditorState()
    }
    val createAndOpenEditorNote: (String) -> Unit = { initialContent ->
        if (!creatingEditorNote) {
            val targetSection = activeCaptureSection
            val targetTagIds = activeCaptureTagIds
            if (editorOpen) saveAndCloseEditor()
            creatingEditorNote = true
            viewModel.createNoteForEditing(
                content = initialContent,
                section = targetSection,
                tagIds = targetTagIds.toList(),
            ) { created ->
                creatingEditorNote = false
                if (created != null) {
                    openNoteInEditor(created)
                    // noteTags is a database Flow and may publish one frame after
                    // the note callback, so retain the persisted capture context.
                    selectedEditorTagIds = targetTagIds
                    editorTagSelectionTouched = true
                }
            }
        }
    }
    DisposableEffect(voiceRecorder) { onDispose { voiceRecorder.cancel() } }
    val snackbarHost = remember { SnackbarHostState() }
    LaunchedEffect(uiState.errorMessage) { if (!uiState.errorMessage.isNullOrBlank()) snackbarHost.showSnackbar(uiState.errorMessage) }
    LaunchedEffect(editingNote?.id, activeVoiceNoteState) {
        val completed = activeVoiceNoteState as? VoiceNoteState.Completed ?: return@LaunchedEffect
        if (editorOpen && editorText.text != completed.refinedText) {
            editorText = TextFieldValue(
                completed.refinedText,
                TextRange(completed.refinedText.length),
            )
            checklistDraft = ChecklistMarkdown.parse(completed.refinedText)
            editorPersistedContent = completed.refinedText
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
            if (extractWebUrl(sharedText) != null &&
                (firstActionGuideState.stage == HomeFirstActionStage.SharePrompt ||
                    firstActionGuideState.stage == HomeFirstActionStage.AwaitingShare)
            ) {
                firstActionImportBaseline = notes.mapTo(mutableSetOf()) { it.id }
                captureFirstActionImport = true
            }
            viewModel.importSharedText(
                text = sharedText,
                section = activeCaptureSection,
                tagIds = activeCaptureTagIds.toList(),
                onPlainText = createAndOpenEditorNote,
                onInsufficientCredits = { showSubscription = true },
            )
            onSharedTextConsumed()
        }
    }
    LaunchedEffect(
        pendingRecordings.map { listOf(it.file.absolutePath, it.origin.persistedValue, it.ownerUserId.orEmpty()) },
        activeCaptureSection,
        activeCaptureTagIds,
    ) {
        if (pendingRecordings.any { it.origin == PendingRecordingOrigin.SharedVideo }) {
            viewModel.processPendingSharedVideoImports(
                section = activeCaptureSection,
                tagIds = activeCaptureTagIds.toList(),
                onNoteReady = openNoteInEditor,
                onInsufficientCredits = { showSubscription = true },
            )
        }
    }
    LaunchedEffect(
        captureFirstActionImport,
        firstActionGuideState,
        notes.map { listOf(it.id, it.importStatus.orEmpty(), it.sourceUrl.orEmpty()) },
    ) {
        val userId = signedInUser?.id ?: return@LaunchedEffect
        if (firstActionGuideState.stage == HomeFirstActionStage.AwaitingShare &&
            firstActionGuideState.targetNoteId == null
        ) {
            // Version 3 adopted Share Extension imports without notifying the guide.
            // Recover that one-time state from the newest link import created after
            // the prompt acknowledgement, or after account creation for v3 state.
            val recoveryStart = sequenceOf(
                firstActionGuideState.shareAcknowledgedAt,
                signedInUser.createdAt,
            ).mapNotNull { raw -> raw?.let { runCatching { Instant.parse(it) }.getOrNull() } }
                .firstOrNull()
            val recoveredImport = notes.asSequence()
                .filter { it.sourceUrl != null }
                .filter { note ->
                    val createdAt = runCatching { Instant.parse(note.createdAt) }.getOrNull()
                    createdAt != null && recoveryStart != null && !createdAt.isBefore(recoveryStart)
                }
                .maxByOrNull { it.createdAt }
            if (recoveredImport != null) {
                firstActionGuideState = firstActionGuideStore.registerImport(
                    userId,
                    firstActionGuideState,
                    recoveredImport.id,
                )
            }
        }
        if (captureFirstActionImport &&
            (firstActionGuideState.stage == HomeFirstActionStage.SharePrompt ||
                firstActionGuideState.stage == HomeFirstActionStage.AwaitingShare)
        ) {
            val importedNote = notes.asSequence()
                .filter { it.id !in firstActionImportBaseline && it.sourceUrl != null }
                .maxByOrNull { it.createdAt }
            if (importedNote != null) {
                firstActionGuideState = firstActionGuideStore.registerImport(
                    userId,
                    firstActionGuideState,
                    importedNote.id,
                )
                captureFirstActionImport = false
            }
        }
        if (firstActionGuideState.stage == HomeFirstActionStage.WaitingForImport) {
            val target = notes.firstOrNull { it.id == firstActionGuideState.targetNoteId }
            if (target != null) {
                val updated = firstActionGuideStore.updateImport(userId, firstActionGuideState, target.importStatus)
                if (updated.stage == HomeFirstActionStage.OpenImportedNote &&
                    firstActionGuideState.stage != HomeFirstActionStage.OpenImportedNote
                ) {
                    selectedSection = target.section
                    selectedTagId = null
                    searchVisible = false
                    searchQuery = ""
                    viewModel.updateSearchQuery("")
                }
                firstActionGuideState = updated
            }
        }
        if (firstActionGuideState.stage == HomeFirstActionStage.OpenImportedNote) {
            notes.firstOrNull { it.id == firstActionGuideState.targetNoteId }?.let { target ->
                selectedSection = target.section
                selectedTagId = null
                searchVisible = false
                searchQuery = ""
                viewModel.updateSearchQuery("")
            }
        }
    }
    LaunchedEffect(recordRequest) {
        if (recordRequest != 0L) {
            startVoiceRecording()
            onRecordRequestConsumed()
        }
    }
    LaunchedEffect(weeklyTopicsRequest) {
        if (weeklyTopicsRequest != 0L) {
            showSettings = false
            showWeeklyTopicsSettings = false
            if (uiState.subscriptionTier == "pro") showWeeklyTopics = true
            else showWeeklyTopicsPreview = true
            onWeeklyTopicsRequestConsumed()
        }
    }
    LaunchedEffect(
        viewModel.currentUserId,
        notes.map { listOf(it.id, it.sourceUrl.orEmpty(), it.createdAt) },
    ) {
        val userId = viewModel.currentUserId ?: return@LaunchedEffect
        showImportNotificationPermissionPrompt = shouldOfferImportNotificationPrompt(
            alreadySeen = importNotificationPromptPreferences.hasSeen(userId),
            firebaseConfigured = PushNotificationManager.isFirebaseConfigured(),
            notificationPermissionGranted = PushNotificationManager.hasNotificationPermission(context),
            candidates = notes.map { ImportedContentCandidate(it.sourceUrl, it.createdAt) },
        )
    }
    val visibleNotes = (if (searchQuery.isBlank()) notes else searchResults).filter { note ->
        val matchesLocation = when {
            selectedSection == "trash" -> note.deletedAt != null
            selectedTagId != null -> note.deletedAt == null
            else -> note.section == selectedSection && note.deletedAt == null
        }
        val noteTagIds = noteTags.filter { it.noteId == note.id }.mapTo(mutableSetOf()) { it.tagId }
        val matchesTag = selectedTagId == null || selectedTagId in noteTagIds
        matchesLocation && matchesTag
    }
    LaunchedEffect(selectedSection, selectedTagId, searchQuery, visibleNotes.map { it.id }) {
        if (selectedSection == "trash") isSelectionMode = false
        selectedNoteIds = selectedNoteIds.intersect(visibleNotes.mapTo(mutableSetOf()) { it.id })
    }
    var notePushSyncRequestedFor by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(notificationNoteId, notes.map { it.id }) {
        val noteId = notificationNoteId ?: return@LaunchedEffect
        val note = notes.firstOrNull { it.id == noteId }
        if (note != null) {
            notePushSyncRequestedFor = null
            showSettings = false
            showWeeklyTopicsSettings = false
            showWeeklyTopics = false
            showWeeklyTopicsPreview = false
            openNoteInEditor(note)
            onNotificationNoteConsumed()
        } else if (notePushSyncRequestedFor != noteId) {
            notePushSyncRequestedFor = noteId
            viewModel.syncForPushDestination()
        }
    }
    if (showImportNotificationPermissionPrompt) {
        val markPromptSeen = {
            viewModel.currentUserId?.let(importNotificationPromptPreferences::markSeen)
            showImportNotificationPermissionPrompt = false
        }
        AlertDialog(
            onDismissRequest = markPromptSeen,
            title = { Text(stringResource(R.string.notification_permission_import_title)) },
            text = { Text(stringResource(R.string.notification_permission_import_message)) },
            confirmButton = {
                TextButton(onClick = requestPushRegistration) {
                    Text(stringResource(R.string.notification_permission_import_enable))
                }
            },
            dismissButton = {
                TextButton(onClick = markPromptSeen) {
                    Text(stringResource(R.string.notification_permission_import_not_now))
                }
            },
        )
    }
    if (showSettings) {
        BackHandler { showSettings = false }
        SettingsScreen(
            uiState = uiState,
            notes = notes,
            voiceSettings = voiceLanguageSettings,
            onBack = { showSettings = false },
            onSignOut = viewModel::signOut,
            onDeleteAccount = viewModel::deleteAccount,
            onOpenUrl = onOpenUrl,
            billingState = billingState,
            onPurchase = onPurchase,
            onRestorePurchases = onRestorePurchases,
            onRetryBilling = onRetryBilling,
            onUpdateVoice = viewModel::updateVoiceLanguage,
            onRequestReview = onRequestReview,
        )
        return
    }
    if (showWeeklyTopicsPreview) {
        WeeklyTopicsPreviewScreen(
            onBack = { showWeeklyTopicsPreview = false },
            onTry = {
                showWeeklyTopicsPreview = false
                showSubscription = true
            },
        )
        return
    }
    if (showWeeklyTopics) {
        WeeklyTopicsRoute(
            controller = weeklyTopicsController,
            onBack = {
                showWeeklyTopicsSettings = false
                showWeeklyTopics = false
            },
            onConfigureWeeklyTopics = { showWeeklyTopicsSettings = true },
            onOpenSource = { source ->
                val localNote = notes.firstOrNull { it.id == source.noteId }
                if (localNote != null) {
                    showWeeklyTopics = false
                    openNoteInEditor(localNote)
                } else {
                    // Match iOS: a report can reference a note that has not yet
                    // reached this device. Sync once, then resolve the source again.
                    coroutineScope.launch {
                        viewModel.syncForPushDestination()
                        viewModel.notes.value.firstOrNull { it.id == source.noteId }?.let { syncedNote ->
                            showWeeklyTopics = false
                            openNoteInEditor(syncedNote)
                        }
                    }
                }
            },
        )
        if (showWeeklyTopicsSettings) {
            val settingsContent: @Composable (Boolean) -> Unit = { applyTopInset ->
                WeeklyTopicsSettingsOverlay(
                    settings = weeklyTopicsState.dashboard?.settings,
                    isSaving = weeklyTopicsState.isSavingSettings,
                    onDismiss = { showWeeklyTopicsSettings = false },
                    onSave = { enabled, weekday, hour, minute ->
                        coroutineScope.launch {
                            if (enabled && !viewModel.ensureWeeklyTopicsConsent()) return@launch
                            if (weeklyTopicsController.saveSettings(enabled, weekday, hour, minute)) {
                                weeklyTopicsController.loadDashboard(forceRefresh = true)
                                showWeeklyTopicsSettings = false
                                if (enabled) requestPushRegistration()
                            }
                        }
                    },
                    applyTopInset = applyTopInset,
                )
            }
            if (weeklyTopicsState.dashboard?.settings?.enabled == true) {
                IOSLargeModalSheet(onDismiss = { showWeeklyTopicsSettings = false }) {
                    settingsContent(false)
                }
            } else {
                settingsContent(true)
            }
        }
        return
    }
    if (teleprompterOpen) {
        BackHandler { teleprompterOpen = false }
        TeleprompterCameraScreen(initialScript = teleprompterScript, onClose = { teleprompterOpen = false })
        return
    }
    if (showCreatorSkillsLibrary) {
        BackHandler { showCreatorSkillsLibrary = false }
        CreatorSkillsLibrary(
            available = viewModel.availableRecipes,
            installed = installedRecipes,
            isPro = uiState.subscriptionTier.equals("pro", ignoreCase = true),
            onBack = { showCreatorSkillsLibrary = false },
            onToggle = viewModel::toggleRecipe,
            onCreateCustom = viewModel::createCustomRecipe,
            onDeleteCustom = viewModel::deleteCustomRecipe,
            onRequestCustomUpgrade = { showSubscription = true },
        )
        if (showSubscription) SubscriptionDialog(
            uiState = uiState,
            billingState = billingState,
            onDismiss = { showSubscription = false },
            onPurchase = onPurchase,
            onRestore = onRestorePurchases,
            onRetryProducts = onRetryBilling,
            onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
            onOpenUrl = onOpenUrl,
        )
        return
    }
    if (contextChatState.isOpen) {
        BackHandler {
            viewModel.closeContextChat()
            isSelectionMode = false
            selectedNoteIds = emptySet()
        }
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
        if (showSubscription) SubscriptionDialog(
            uiState = uiState,
            billingState = billingState,
            onDismiss = { showSubscription = false },
            onPurchase = onPurchase,
            onRestore = onRestorePurchases,
            onRetryProducts = onRetryBilling,
            onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
            onOpenUrl = onOpenUrl,
        )
        return
    }
    if (showPendingRecordings) {
        BackHandler { showPendingRecordings = false }
        IOSParityPendingRecordingsScreen(
            recordings = pendingRecordings,
            onBack = { showPendingRecordings = false },
            onSave = { recording, onOutcome ->
                viewModel.retryPendingRecording(recording, onOutcome = onOutcome)
            },
            onDelete = viewModel::deletePendingRecording,
        )
        return
    }
    BackHandler(enabled = isSelectionMode && !editorOpen) {
        isSelectionMode = false
        selectedNoteIds = emptySet()
    }
    val databaseEditorTagIds = editingNote?.let { note ->
        noteTags.filter { it.noteId == note.id }.mapTo(mutableSetOf()) { it.tagId }
    }.orEmpty()
    LaunchedEffect(editorOpen, editingNote?.id, databaseEditorTagIds) {
        if (editorOpen && editingNote != null && !editorTagSelectionTouched) {
            selectedEditorTagIds = databaseEditorTagIds
        }
    }
    LaunchedEffect(
        editorOpen,
        editingNote?.id,
        editorText.text,
        checklistDraft,
        selectedEditorTagIds,
        editorTagSelectionTouched,
    ) {
        val note = editingNote ?: return@LaunchedEffect
        if (!editorOpen || note.deletedAt != null) return@LaunchedEffect
        val hasContentChange = currentEditorContent() != editorPersistedContent
        if (!hasContentChange) return@LaunchedEffect
        delay(500)
        val content = currentEditorContent()
        editorPersistedContent = content
        viewModel.saveNote(note, content, note.section)
    }
    val closeEditor = saveAndCloseEditor
    BackHandler(enabled = editorOpen, onBack = closeEditor)
    if (editorOpen) {
        IOSParityEditorScreen(
            note = editingNote,
            text = editorText,
            selectedTags = tags.filter { it.id in selectedEditorTagIds },
            recipes = installedRecipes,
            canUseAISkills = !uiState.busy && activeVoiceNoteState !is VoiceNoteState.Processing,
            canEdit = activeVoiceNoteState !is VoiceNoteState.Processing,
            canUndo = undoStack.isNotEmpty(),
            canRedo = redoStack.isNotEmpty(),
            onTextChange = { value ->
                if (value.text != editorText.text) {
                    undoStack = (undoStack + editorText).takeLast(100)
                    redoStack = emptyList()
                }
                checklistDraft = null
                editorText = value
            },
            onBack = closeEditor,
            onRestore = {
                editingNote?.let(viewModel::restoreNote)
                // A deleted-note snapshot must never be passed through saveNote:
                // doing so can reapply deletedAt after the restore coroutine.
                clearEditorState()
            },
            onAddTopic = {
                taggingNoteId = editingNote?.id
                showCreateTag = taggingNoteId != null
            },
            onExport = {
                editingNote?.let { original ->
                    val currentContent = checklistDraft?.let {
                        ChecklistMarkdown.serialize(it.notes, it.items)
                    } ?: editorText.text
                    runCatching {
                        val file = NotesExporter.exportNote(
                            context,
                            original.copy(content = currentContent),
                            NoteExportFormat.MARKDOWN,
                        )
                        NotesExporter.share(context, file, NoteExportFormat.MARKDOWN.mimeType)
                    }.onFailure { noteExportFailed = true }
                }
            },
            onDelete = {
                editingNote?.let { note ->
                    if (currentEditorContent().isBlank()) viewModel.permanentlyDelete(note)
                    else viewModel.deleteNote(note)
                }
                clearEditorState()
            },
            onOpenSource = onOpenUrl,
            onRemoveTag = { tag ->
                editorTagSelectionTouched = true
                selectedEditorTagIds = selectedEditorTagIds - tag.id
                editingNote?.let { note -> viewModel.removeTagFromNote(note.id, tag.id) }
            },
            onSelectRecipe = { recipe ->
                val source = editorText
                val selection = TextSelection(source.selection.start, source.selection.end).normalized(source.text)
                aiSourceText = source
                aiHomeNote = null
                pendingRecipeInput = if (selection.isCollapsed) source.text else source.text.substring(selection.start, selection.end)
                if (recipe.id == "translate") pendingTranslateRecipe = recipe
                else viewModel.runCreatorSkill(
                    recipe,
                    pendingRecipeInput,
                    onFlowEndedWithoutResult = completeFirstActionAISkillFlow,
                )
            },
            onManageSkills = { showCreatorSkillsLibrary = true },
            onStartRecording = {
                teleprompterScript = editorText.text
                teleprompterOpen = true
            },
            onBold = {
                val result = MarkdownEditing.toggleBold(editorText.text, editorText.selection.start, editorText.selection.end)
                undoStack = (undoStack + editorText).takeLast(100)
                redoStack = emptyList()
                editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
            },
            onChecklist = {
                val result = MarkdownEditing.toggleChecklist(editorText.text, editorText.selection.start, editorText.selection.end)
                undoStack = (undoStack + editorText).takeLast(100)
                redoStack = emptyList()
                editorText = TextFieldValue(result.text, TextRange(result.selectionStart, result.selectionEnd))
            },
            onUndo = {
                undoStack.lastOrNull()?.let { previous ->
                    redoStack = (redoStack + editorText).takeLast(100)
                    editorText = previous
                    undoStack = undoStack.dropLast(1)
                }
            },
            onRedo = {
                redoStack.lastOrNull()?.let { next ->
                    undoStack = (undoStack + editorText).takeLast(100)
                    editorText = next
                    redoStack = redoStack.dropLast(1)
                }
            },
            voiceNoteState = activeVoiceNoteState,
            onShowOriginalVoiceResult = {
                val noteId = editingNote?.id
                val completed = activeVoiceNoteState as? VoiceNoteState.Completed
                if (noteId != null && completed != null) {
                    undoStack = (undoStack + editorText).takeLast(100)
                    redoStack = emptyList()
                    editorText = TextFieldValue(
                        completed.originalText,
                        TextRange(completed.originalText.length),
                    )
                    checklistDraft = ChecklistMarkdown.parse(completed.originalText)
                    editorPersistedContent = completed.originalText
                    viewModel.restoreOriginalVoiceResult(noteId)
                }
            },
            onDismissVoiceFailure = {
                editingNote?.id?.let(viewModel::dismissVoiceNoteState)
            },
            snackbarHostState = snackbarHost,
            showAIActions = appliedAITransformation?.let { it.targetNoteId == null } == true,
            isAIRetrying = retryingAITransformation != null,
            onAIRetry = {
                appliedAITransformation?.let { transformation ->
                    retryingAITransformation = transformation
                    viewModel.runCreatorSkill(
                        transformation.recipe,
                        transformation.inputContent,
                        transformation.instruction,
                        onFlowEndedWithoutResult = { retryingAITransformation = null },
                    )
                }
            },
            onAIUndo = {
                appliedAITransformation?.let { transformation ->
                    if (transformation.targetNoteId == null) {
                        editorText = TextFieldValue(
                            transformation.sourceContent,
                            TextRange(
                                transformation.sourceSelection.start
                                    .coerceAtMost(transformation.sourceContent.length),
                            ),
                        )
                        checklistDraft = ChecklistMarkdown.parse(transformation.sourceContent)
                    } else {
                        viewModel.replaceNoteContent(
                            transformation.targetNoteId,
                            transformation.sourceContent,
                        )
                    }
                    retryingAITransformation = null
                    appliedAITransformation = null
                }
            },
            onAISave = {
                val content = currentEditorContent()
                editingNote?.takeIf { it.deletedAt == null }?.let { note ->
                    editorPersistedContent = content
                    viewModel.saveNote(note, content, note.section)
                }
                retryingAITransformation = null
                appliedAITransformation = null
            },
            returnToNoteRequest = returnToNoteRequest,
            firstActionGuideState = firstActionGuideState,
            onReviewTranscript = {
                val userId = signedInUser?.id
                val noteId = editingNote?.id
                if (userId != null && noteId != null) {
                    firstActionGuideState = firstActionGuideStore.markTranscriptReviewed(
                        userId,
                        firstActionGuideState,
                        noteId,
                    )
                }
            },
            onOpenCreateTab = {
                val userId = signedInUser?.id
                val noteId = editingNote?.id
                if (userId != null && noteId != null) {
                    firstActionGuideState = firstActionGuideStore.markCreateTabTapped(
                        userId,
                        firstActionGuideState,
                        noteId,
                    )
                }
            },
            onOpenAISkill = {
                val userId = signedInUser?.id
                val noteId = editingNote?.id
                if (userId != null && noteId != null) {
                    firstActionGuideState = firstActionGuideStore.markAISkillsTapped(
                        userId,
                        firstActionGuideState,
                        noteId,
                    )
                }
            },
            onOpenRecordTab = {
                val userId = signedInUser?.id
                val noteId = editingNote?.id
                if (userId != null && noteId != null) {
                    firstActionGuideState = firstActionGuideStore.markRecordTabTapped(
                        userId,
                        firstActionGuideState,
                        noteId,
                    )
                }
            },
            onOpenTeleprompter = {
                val userId = signedInUser?.id
                val noteId = editingNote?.id
                if (userId != null && noteId != null) {
                    firstActionGuideState = firstActionGuideStore.markTeleprompterTapped(
                        userId,
                        firstActionGuideState,
                        noteId,
                    )
                }
            },
            onDismissFirstActionGuide = {
                signedInUser?.id?.let { userId ->
                    firstActionGuideState = firstActionGuideStore.dismiss(userId)
                }
            },
        )
    if (false) Scaffold(
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
                    TextButton(
                        onClick = { showEmptyTrashConfirmation = true },
                        enabled = visibleNotes.isNotEmpty(),
                        modifier = Modifier.align(Alignment.End),
                    ) {
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
                    FilledTonalButton(
                        onClick = { showWeeklyTopics = true },
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    ) {
                        Icon(Icons.Outlined.AutoAwesome, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text(stringResource(R.string.weekly_topics_title))
                    }
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
        if (uiState.voiceProcessing || uiState.sharedVideoPreparing) {
            Row(
                Modifier.fillMaxWidth().padding(padding).padding(horizontal = 20.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CircularProgressIndicator()
                Text(
                    stringResource(
                        if (uiState.sharedVideoPreparing) R.string.shared_video_import_preparing
                        else R.string.voice_processing,
                    ),
                )
            }
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
            if (visibleNotes.isEmpty()) HomeEmptyState(
                section = selectedSection,
                hasActiveFilter = searchQuery.isNotBlank() || selectedTagId != null,
                modifier = Modifier.fillMaxSize().padding(padding),
            )
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
                        onPermanentDelete = { pendingPermanentDeleteNote = note },
                    )
                }
                item { Spacer(Modifier.height(96.dp)) }
            }
        }
    }
    } else {
        val headerTitle = when {
            selectedSection == "trash" -> stringResource(R.string.home_section_trash)
            selectedTagId != null -> tags.firstOrNull { it.id == selectedTagId }?.name ?: stringResource(R.string.app_name)
            else -> stringResource(R.string.app_name)
        }
        IOSParityHomeScreen(
            notes = visibleNotes,
            allNotes = notes,
            tags = tags,
            noteTags = noteTags,
            selectedSection = selectedSection,
            selectedTagId = selectedTagId,
            headerTitle = headerTitle,
            showSectionPicker = selectedTagId == null,
            searchVisible = searchVisible,
            searchQuery = searchQuery,
            isSelectionMode = isSelectionMode,
            selectedNoteIds = selectedNoteIds,
            isRecording = isRecording,
            isVoiceProcessing = uiState.voiceProcessing,
            initialNotesSyncing = uiState.initialNotesSyncing,
            hasLoadedNotesAtLeastOnce = uiState.hasLoadedNotesAtLeastOnce,
            pendingRecordingsCount = pendingRecordings.size,
            subscriptionTier = uiState.subscriptionTier,
            creditBalance = uiState.creditBalance,
            snackbarHostState = snackbarHost,
            onSelectSection = { section ->
                selectedSection = section
                selectedTagId = null
                isSelectionMode = false
                selectedNoteIds = emptySet()
            },
            onToggleSearch = {
                searchVisible = !searchVisible
                if (!searchVisible) {
                    searchQuery = ""
                    viewModel.updateSearchQuery("")
                }
            },
            onSearchQueryChange = { query ->
                searchQuery = query
                viewModel.updateSearchQuery(query)
            },
            onOpenNote = openNoteInEditor,
            onToggleNoteSelection = { note ->
                selectedNoteIds = if (note.id in selectedNoteIds) selectedNoteIds - note.id else selectedNoteIds + note.id
            },
            onEnterSelectionMode = {
                isSelectionMode = true
                selectedNoteIds = emptySet()
            },
            onExitSelectionMode = {
                isSelectionMode = false
                selectedNoteIds = emptySet()
            },
            onSelectAll = {
                selectedNoteIds = if (selectedNoteIds.size == visibleNotes.size) emptySet()
                else visibleNotes.mapTo(mutableSetOf()) { it.id }
            },
            onDeleteSelection = { showBatchDeleteConfirmation = true },
            onStartAIChat = {
                when {
                    selectedNoteIds.size > 20 -> showAskHardLimitAlert = true
                    selectedNoteIds.size > 10 -> showAskSoftLimitAlert = true
                    else -> viewModel.openContextChat(selectedNoteIds)
                }
            },
            onPin = viewModel::togglePin,
            onManageTags = { note ->
                taggingNoteId = note.id
                showCreateTag = true
            },
            onMove = { note, section -> viewModel.moveNote(note, section) },
            onDelete = viewModel::deleteNote,
            onRestore = viewModel::restoreNote,
            onPermanentDelete = { note -> pendingPermanentDeleteNote = note },
            onOpenSource = onOpenUrl,
            onEmptyTrash = { showEmptyTrashConfirmation = true },
            onCreateBlankNote = { createAndOpenEditorNote("") },
            onStartVoiceRecording = startVoiceRecording,
            onCancelVoiceRecording = {
                voiceRecorder.cancel()
                isRecording = false
            },
            onConfirmVoiceRecording = {
                val file = voiceRecorder.stop()
                isRecording = false
                if (file != null) viewModel.processVoiceRecording(
                    file,
                    activeCaptureSection,
                    activeCaptureTagIds.toList(),
                    onNoteReady = { note ->
                        openNoteInEditor(note)
                        selectedEditorTagIds = activeCaptureTagIds
                        editorTagSelectionTouched = true
                    },
                )
                else viewModel.reportAuthError(voiceEmptyError)
            },
            onPasteLink = { onResult ->
                val clipboard = context.getSystemService(ClipboardManager::class.java)
                val text = clipboard.primaryClip?.takeIf { it.itemCount > 0 }
                    ?.getItemAt(0)?.coerceToText(context)?.toString()?.trim().orEmpty()
                val link = extractCreatorMediaUrl(text)
                if (link != null) {
                    onResult(true)
                    viewModel.importSharedText(
                        text = link,
                        section = activeCaptureSection,
                        tagIds = activeCaptureTagIds.toList(),
                        onPlainText = createAndOpenEditorNote,
                        onInsufficientCredits = { showSubscription = true },
                    )
                } else onResult(false)
            },
            onOpenSubscription = { showSubscription = true },
            onOpenWeeklyTopics = {
                if (uiState.subscriptionTier == "pro") showWeeklyTopics = true
                else showWeeklyTopicsPreview = true
            },
            onOpenPendingRecordings = { showPendingRecordings = true },
            onOpenSettings = { showSettings = true },
            onSelectTag = { tag ->
                selectedTagId = tag.id
                selectedSection = "inbox"
                isSelectionMode = false
                selectedNoteIds = emptySet()
            },
            onMoveTag = { tag, parentId ->
                viewModel.updateTag(tag, tag.name, tag.colorHex, parentId)
            },
            onDeleteTag = { tag ->
                if (selectedTagId == tag.id) {
                    selectedTagId = null
                    selectedSection = "inbox"
                }
                viewModel.deleteTag(tag)
            },
            firstActionGuideState = firstActionGuideState,
            onAcknowledgeFirstActionShare = {
                signedInUser?.id?.let { userId ->
                    firstActionGuideState = firstActionGuideStore.acknowledgeShare(userId, firstActionGuideState)
                }
            },
            onDismissFirstActionGuide = {
                signedInUser?.id?.let { userId ->
                    firstActionGuideState = firstActionGuideStore.dismiss(userId)
                }
                captureFirstActionImport = false
            },
            onOpenFirstActionTarget = {
                signedInUser?.id?.let { userId ->
                    firstActionGuideState.targetNoteId?.let { noteId ->
                        firstActionGuideState = firstActionGuideStore.markImportedNoteOpened(
                            userId,
                            firstActionGuideState,
                            noteId,
                        )
                    }
                }
            },
            noteRevealTargetId = homeNoteRevealTargetId,
            onNoteRevealed = { noteId ->
                if (homeNoteRevealTargetId == noteId) homeNoteRevealTargetId = null
            },
        )
    }
    if (showCreateTag) AddTopicDialog(
        tags = tags,
        onDismiss = {
            showCreateTag = false
            taggingNoteId = null
        },
        onSave = { name, colorHex ->
            val targetNoteId = taggingNoteId
            if (targetNoteId == null) {
                viewModel.createTag(name, colorHex, null)
            } else {
                viewModel.addTagToNote(targetNoteId, name, colorHex, null) { attachedTag ->
                    if (editingNote?.id == targetNoteId) {
                        editorTagSelectionTouched = true
                        selectedEditorTagIds = selectedEditorTagIds + attachedTag.id
                    }
                }
            }
            showCreateTag = false
            taggingNoteId = null
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
    if (showAskSoftLimitAlert) AlertDialog(
        onDismissRequest = { showAskSoftLimitAlert = false },
        title = { Text(stringResource(R.string.home_ask_large_selection_title)) },
        text = {
            Text(stringResource(R.string.home_ask_soft_limit_message, selectedNoteIds.size))
        },
        confirmButton = {
            TextButton(onClick = {
                showAskSoftLimitAlert = false
                viewModel.openContextChat(selectedNoteIds)
            }) { Text(stringResource(R.string.common_continue)) }
        },
        dismissButton = {
            TextButton(onClick = { showAskSoftLimitAlert = false }) {
                Text(stringResource(R.string.common_cancel))
            }
        },
    )
    if (showAskHardLimitAlert) AlertDialog(
        onDismissRequest = { showAskHardLimitAlert = false },
        title = { Text(stringResource(R.string.home_ask_too_many_notes_title)) },
        text = { Text(stringResource(R.string.home_ask_hard_limit_message, 20)) },
        confirmButton = {
            TextButton(onClick = { showAskHardLimitAlert = false }) {
                Text(stringResource(R.string.common_ok))
            }
        },
    )
    if (showEmptyTrashConfirmation) AlertDialog(
        onDismissRequest = { showEmptyTrashConfirmation = false },
        title = { Text(stringResource(R.string.trash_empty_confirm_title)) },
        text = { Text(stringResource(R.string.trash_empty_confirm_message)) },
        confirmButton = { TextButton(onClick = {
            showEmptyTrashConfirmation = false
            viewModel.emptyTrash()
        }) { Text(stringResource(R.string.trash_empty_action), color = MaterialTheme.colorScheme.error) } },
        dismissButton = { TextButton(onClick = { showEmptyTrashConfirmation = false }) { Text(stringResource(R.string.common_cancel)) } },
    )
    pendingPermanentDeleteNote?.let { note ->
        AlertDialog(
            onDismissRequest = { pendingPermanentDeleteNote = null },
            title = { Text(stringResource(R.string.trash_delete_permanently_confirm_title)) },
            text = { Text(stringResource(R.string.trash_delete_permanently_confirm_message)) },
            confirmButton = { TextButton(onClick = {
                pendingPermanentDeleteNote = null
                viewModel.permanentlyDelete(note)
            }) { Text(stringResource(R.string.trash_delete_permanently), color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { pendingPermanentDeleteNote = null }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }
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
            onDismiss = {
                pendingTranslateRecipe = null
                completeFirstActionAISkillFlow()
            },
            onRun = { language ->
                pendingTranslateRecipe = null
                viewModel.runCreatorSkill(
                    recipe,
                    pendingRecipeInput,
                    language,
                    onFlowEndedWithoutResult = completeFirstActionAISkillFlow,
                )
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
                else listOf(AISkillApplyMode.APPEND_TO_END, AISkillApplyMode.REPLACE_ALL),
            onDismiss = {
                viewModel.dismissCreatorSkillResult(); aiSourceText = null; aiHomeNote = null
                completeFirstActionAISkillFlow()
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
                    returnToNoteRequest += 1L
                } else if (homeNote != null) {
                    viewModel.replaceNoteContent(homeNote.id, applied)
                }
                viewModel.dismissCreatorSkillResult(); aiSourceText = null; aiHomeNote = null
                completeFirstActionAISkillFlow()
            },
        )
    }
    aiSkillState.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = {
                viewModel.dismissCreatorSkillResult()
                completeFirstActionAISkillFlow()
            },
            title = { Text(stringResource(R.string.ai_skill_error_title)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = {
                viewModel.dismissCreatorSkillResult()
                completeFirstActionAISkillFlow()
            }) { Text(stringResource(R.string.common_close)) } },
        )
    }
    if (noteExportFailed) AlertDialog(
        onDismissRequest = { noteExportFailed = false },
        title = { Text(stringResource(R.string.note_export_failed_title)) },
        text = { Text(stringResource(R.string.note_export_failed_message)) },
        confirmButton = {
            TextButton(onClick = { noteExportFailed = false }) {
                Text(stringResource(R.string.common_ok))
            }
        },
    )
    if (showSubscription) SubscriptionDialog(
        uiState = uiState,
        billingState = billingState,
        onDismiss = { showSubscription = false },
        onPurchase = onPurchase,
        onRestore = onRestorePurchases,
        onRetryProducts = onRetryBilling,
        onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
        onOpenUrl = onOpenUrl,
    )
}

@Composable
private fun HomeEmptyState(section: String, hasActiveFilter: Boolean, modifier: Modifier = Modifier) {
    val title = if (hasActiveFilter) R.string.home_no_results_title else when (section) {
        "drafts" -> R.string.home_empty_drafts_title
        "published" -> R.string.home_empty_published_title
        "trash" -> R.string.home_empty_trash_title
        else -> R.string.home_empty_inbox_title
    }
    val message = if (hasActiveFilter) R.string.home_no_results_message else when (section) {
        "drafts" -> R.string.home_empty_drafts_message
        "published" -> R.string.home_empty_published_message
        "trash" -> R.string.home_empty_trash_message
        else -> R.string.home_empty_inbox_message
    }
    Column(
        modifier.padding(horizontal = 32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(title),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Text(
            stringResource(message),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
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
private fun SettingsScreen(
    uiState: AppUiState,
    notes: List<NoteEntity>,
    voiceSettings: VoiceLanguageSettings,
    onBack: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    onOpenUrl: (String) -> Unit,
    billingState: BillingUiState,
    onPurchase: (BillingProduct) -> Unit,
    onRestorePurchases: () -> Unit,
    onRetryBilling: () -> Unit,
    onUpdateVoice: (String, String) -> Unit,
    onRequestReview: () -> Unit,
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
    var exportStatusMessage by remember { mutableStateOf<String?>(null) }
    var exportJob by remember { mutableStateOf<Job?>(null) }
    var showExportSheet by remember { mutableStateOf(false) }
    var showVoiceSettings by remember { mutableStateOf(false) }
    var showAbout by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val resources = LocalResources.current
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
    val displayLocale = LocalConfiguration.current.locales[0]
    val voiceLanguageSummary = if (voiceSettings.mode == "auto") {
        stringResource(R.string.settings_voice_auto)
    } else {
        voiceSettings.languageHint
            .takeIf { it.isNotBlank() }
            ?.let { Locale.forLanguageTag(it).getDisplayName(displayLocale) }
            ?.takeIf { it.isNotBlank() }
            ?: stringResource(R.string.settings_voice_not_set)
    }
    val startExport: () -> Unit = {
        val active = notes.filter { it.deletedAt == null }
        if (active.isEmpty()) {
            exportError = noNotesMessage
        } else {
            scope.launch {
                exportJob?.cancel()
                exporting = true
                exportStatusMessage = null
                exportProgress = NotesExportProgress(NotesExportStage.PREPARING, 0, active.size)
                exportJob = kotlinx.coroutines.currentCoroutineContext()[Job]
                try {
                    val file = withContext(Dispatchers.IO) {
                        NotesExporter.exportAll(context, active) { progress ->
                            withContext(Dispatchers.Main.immediate) { exportProgress = progress }
                        }
                    }
                    exportProgress = NotesExportProgress(NotesExportStage.FINISHING, active.size, active.size)
                    exportStatusMessage = resources.getString(
                        R.string.export_success_summary,
                        active.size,
                        Formatter.formatFileSize(context, file.length()),
                    )
                    NotesExporter.share(context, file, "application/zip")
                } catch (_: CancellationException) {
                    exportStatusMessage = resources.getString(R.string.export_progress_cancelled)
                } catch (_: Throwable) {
                    exportError = exportFailedMessage
                } finally {
                    exporting = false
                    exportJob = null
                }
            }
        }
    }

    IOSParitySettingsContent(
        accountEmail = accountEmail,
        isPro = uiState.subscriptionTier == "pro",
        voiceLanguageSummary = voiceLanguageSummary,
        busy = uiState.busy || deleteInProgress,
        exporting = exporting,
        onBack = onBack,
        onSubscription = { showSubscription = true },
        onExport = { showExportSheet = true },
        onVoiceLanguage = { showVoiceSettings = true },
        onPermissions = { onOpenUrl("package:com.sponteoai.chillscript") },
        onFeedback = { onOpenUrl("mailto:support@chillnoteai.com?subject=ChillScript%20Feedback") },
        onRate = onRequestReview,
        onPrivacy = { onOpenUrl("https://www.chillnoteai.com/privacy") },
        onAgreement = { onOpenUrl("https://www.chillnoteai.com/terms") },
        onAbout = { showAbout = true },
        onDeleteAccount = { confirmDelete = true },
        onSignOut = { confirmSignOut = true },
    )
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
    if (showExportSheet) IOSLargeModalSheet(
        onDismiss = { if (!exporting) showExportSheet = false },
        dismissEnabled = !exporting,
    ) {
        IOSParityExportAllNotesSheet(
            noteCount = notes.count { it.deletedAt == null },
            exporting = exporting,
            progress = exportProgress,
            statusMessage = exportStatusMessage,
            onStart = startExport,
            onCancel = { exportJob?.cancel() },
            onClose = { if (!exporting) showExportSheet = false },
            applyTopInset = false,
        )
    }
    if (showSubscription) SubscriptionDialog(
        uiState = uiState,
        billingState = billingState,
        onDismiss = { showSubscription = false },
        onPurchase = onPurchase,
        onRestore = onRestorePurchases,
        onRetryProducts = onRetryBilling,
        onManage = { onOpenUrl("https://play.google.com/store/account/subscriptions?package=com.sponteoai.chillscript") },
        onOpenUrl = onOpenUrl,
    )
    exportError?.let { message ->
        AlertDialog(
            onDismissRequest = { exportError = null },
            title = { Text(stringResource(R.string.settings_export_failed_title)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = {
                    exportError = null
                    startExport()
                }) { Text(stringResource(R.string.common_retry)) }
            },
            dismissButton = {
                TextButton(onClick = { exportError = null }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }
    if (showVoiceSettings) IOSLargeModalSheet(onDismiss = { showVoiceSettings = false }) {
        IOSParityVoiceLanguageSheet(
            settings = voiceSettings,
            onUpdate = onUpdateVoice,
            onClose = { showVoiceSettings = false },
            applyTopInset = false,
        )
    }
    if (showAbout) IOSLargeModalSheet(onDismiss = { showAbout = false }) {
        IOSParityAboutScreen(
            onClose = { showAbout = false },
            applyTopInset = false,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun IOSLargeModalSheet(
    onDismiss: () -> Unit,
    dismissEnabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { dismissEnabled },
    )
    val sheetHeight = (LocalConfiguration.current.screenHeightDp - 18).coerceAtLeast(480).dp
    ModalBottomSheet(
        onDismissRequest = { if (dismissEnabled) onDismiss() },
        sheetState = sheetState,
        containerColor = com.sponteoai.chillscript.ui.theme.ChillColors.BackgroundPrimary,
        dragHandle = { BottomSheetDefaults.DragHandle() },
    ) {
        Box(Modifier.fillMaxWidth().height(sheetHeight)) { content() }
    }
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
private fun SubscriptionDialog(
    uiState: AppUiState,
    billingState: BillingUiState,
    onDismiss: () -> Unit,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onRetryProducts: () -> Unit,
    onManage: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    IOSLargeModalSheet(onDismiss = onDismiss) {
        IOSParitySubscriptionScreen(
            context = SubscriptionScreenContext.Standard,
            isPro = uiState.subscriptionTier == "pro",
            subscriptionExpiresAt = uiState.subscriptionExpiresAt,
            activeProductId = uiState.activeSubscriptionProductId,
            billingState = billingState,
            isPurchasing = uiState.busy,
            onPurchase = onPurchase,
            onRestore = onRestore,
            onRetryProducts = onRetryProducts,
            onDismiss = onDismiss,
            onManage = onManage,
            onOpenUrl = onOpenUrl,
            applyTopInset = false,
        )
    }
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
@OptIn(ExperimentalMaterial3Api::class)
private fun AddTopicDialog(
    tags: List<TagEntity>,
    onDismiss: () -> Unit,
    onSave: (String, String) -> Unit,
) {
    var name by remember { mutableStateOf("") }
    var colorHex by remember { mutableStateOf(TagColors.automatic(tags)) }
    val previewFallbackColor = MaterialTheme.colorScheme.primary
    val previewColor = remember(colorHex, previewFallbackColor) {
        runCatching { Color(android.graphics.Color.parseColor(TagColors.normalize(colorHex))) }
            .getOrDefault(previewFallbackColor)
    }
    val previewName = if (name.trim().isEmpty()) {
        stringResource(R.string.note_detail_add_tag_new_tag_label)
    } else name.trim()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) }
                Text(
                    stringResource(R.string.note_detail_add_tag_title),
                    modifier = Modifier.weight(1f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    fontWeight = FontWeight.SemiBold,
                )
                TextButton(onClick = { onSave(name.trim(), colorHex) }, enabled = name.isNotBlank()) {
                    Text(stringResource(R.string.common_add))
                }
            }
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text(stringResource(R.string.note_detail_add_tag_name_placeholder)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.48f),
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.48f),
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                ),
            )
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.note_detail_add_tag_color_label),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                TagColors.Palette.chunked(5).forEach { rowColors ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                        rowColors.forEach { candidate ->
                            val selected = candidate == colorHex
                            val label = stringResource(R.string.tags_color_option_format, candidate)
                            Box(
                                Modifier
                                    .size(44.dp)
                                    .selectable(
                                        selected = selected,
                                        onClick = { colorHex = candidate },
                                        role = Role.RadioButton,
                                    )
                                    .semantics { contentDescription = label },
                                contentAlignment = Alignment.Center,
                            ) {
                                TagColorDot(candidate, selected = selected)
                            }
                        }
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.note_detail_add_tag_preview_label),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = previewName,
                    color = previewColor,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier
                        .background(previewColor.copy(alpha = 0.12f), CircleShape)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            Spacer(Modifier.height(24.dp))
        }
    }
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
                itemsIndexed(TagColors.Palette) { _, candidate ->
                    val selected = candidate == colorHex
                    val label = stringResource(R.string.tags_color_option_format, candidate)
                    Box(
                        Modifier.size(48.dp)
                            .selectable(
                                selected = selected,
                                onClick = { colorHex = candidate },
                                role = Role.RadioButton,
                            )
                            .semantics { contentDescription = label },
                        contentAlignment = Alignment.Center,
                    ) {
                        TagColorDot(candidate, selected = selected)
                    }
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
        modifier
            .size(38.dp)
            .border(2.dp, if (selected) MaterialTheme.colorScheme.onSurface else Color.Transparent, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(30.dp).background(color, CircleShape), contentAlignment = Alignment.Center) {
            Box(Modifier.size(22.dp).border(1.5.dp, Color.White.copy(alpha = 0.9f), CircleShape))
        }
    }
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
                stringResource(
                    when {
                        isTrash -> R.string.note_restore
                        note.pinnedAt == null -> R.string.note_pin_action
                        else -> R.string.note_unpin_action
                    },
                ),
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
    Text(localizedRelativeTime(note.updatedAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
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

@Composable
private fun localizedRelativeTime(rawValue: String): String {
    val locale = LocalConfiguration.current.locales[0]
    return remember(rawValue, locale) {
        runCatching {
            DateUtils.getRelativeTimeSpanString(
                Instant.parse(rawValue).toEpochMilli(),
                System.currentTimeMillis(),
                DateUtils.MINUTE_IN_MILLIS,
                DateUtils.FORMAT_ABBREV_RELATIVE,
            ).toString()
        }.getOrElse { localizedDate(rawValue, locale) }
    }
}

private fun localizedDate(rawValue: String, locale: Locale): String {
    val formatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)
    runCatching {
        return formatter.withZone(ZoneId.systemDefault()).format(Instant.parse(rawValue))
    }
    return runCatching {
        formatter.format(LocalDate.parse(rawValue.take(10)))
    }.getOrDefault(rawValue)
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
