package com.sponteoai.chillscript.ui.auth

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBackIos
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.AppUiState
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.BrandBackground
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.theme.ChillRadius
import com.sponteoai.chillscript.ui.theme.ChillSizes
import kotlinx.coroutines.delay

private const val VerificationCodeLength = 6
private const val ResendDelaySeconds = 60
private const val ContentMaxWidth = 360

private val EmailPattern = Regex(
    pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
    option = RegexOption.IGNORE_CASE,
)

private val MarkdownLinkPattern = Regex("\\[([^]]+)]\\s*\\((https://[^)]+)\\)")

private enum class LoginFocusTarget {
    Email,
    VerificationCode,
}

/**
 * One-to-one Compose port of iOS `LoginView`.
 *
 * The host owns authentication; this screen owns only the same local form,
 * validation, countdown and focus state that the SwiftUI view owns.
 */
@Composable
fun IOSParityLoginScreen(
    state: AppUiState,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
    onSendCode: (String) -> Unit,
    onVerifyCode: (String) -> Unit,
    onBackToEmail: () -> Unit,
    onClearError: () -> Unit,
    onOpenUrl: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var showEmailLogin by rememberSaveable { mutableStateOf(state.codeSentTo != null) }
    var email by rememberSaveable { mutableStateOf(state.codeSentTo.orEmpty()) }
    var verificationCode by rememberSaveable { mutableStateOf("") }
    var showEmailValidationError by rememberSaveable { mutableStateOf(false) }
    var resendSecondsRemaining by rememberSaveable { mutableIntStateOf(0) }
    var resendCountdownGeneration by rememberSaveable { mutableIntStateOf(0) }
    var pendingFocus by remember { mutableStateOf<LoginFocusTarget?>(null) }
    var pendingResendResult by remember { mutableStateOf(false) }
    var observedResendBusy by remember { mutableStateOf(false) }
    var lastAutoVerifiedCode by rememberSaveable { mutableStateOf<String?>(null) }

    val emailFocusRequester = remember { FocusRequester() }
    val verificationFocusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    val normalizedEmail = email.trim()
    val isEmailValid = EmailPattern.matches(normalizedEmail)
    val isVerificationCodeComplete = verificationCode.length == VerificationCodeLength

    fun startResendCountdown() {
        resendSecondsRemaining = ResendDelaySeconds
        resendCountdownGeneration += 1
    }

    fun leaveEmailLogin() {
        focusManager.clearFocus(force = true)
        onClearError()
        if (state.codeSentTo != null) onBackToEmail()
        showEmailLogin = false
        verificationCode = ""
        showEmailValidationError = false
        resendSecondsRemaining = 0
        resendCountdownGeneration += 1
        lastAutoVerifiedCode = null
        pendingFocus = null
    }

    fun changeEmail() {
        onClearError()
        if (state.codeSentTo != null) onBackToEmail()
        verificationCode = ""
        resendSecondsRemaining = 0
        resendCountdownGeneration += 1
        lastAutoVerifiedCode = null
        pendingFocus = LoginFocusTarget.Email
    }

    fun submitEmail() {
        showEmailValidationError = !isEmailValid
        if (!isEmailValid || state.busy) return
        focusManager.clearFocus(force = true)
        onSendCode(normalizedEmail)
    }

    fun submitVerificationCode() {
        if (!isVerificationCodeComplete || state.busy) return
        lastAutoVerifiedCode = verificationCode
        focusManager.clearFocus(force = true)
        onVerifyCode(verificationCode)
    }

    BackHandler(enabled = showEmailLogin, onBack = ::leaveEmailLogin)

    LaunchedEffect(pendingFocus, showEmailLogin, state.codeSentTo) {
        val target = pendingFocus ?: return@LaunchedEffect
        delay(220)
        when (target) {
            LoginFocusTarget.Email -> if (showEmailLogin && state.codeSentTo == null) {
                emailFocusRequester.requestFocus()
            }
            LoginFocusTarget.VerificationCode -> if (showEmailLogin && state.codeSentTo != null) {
                verificationFocusRequester.requestFocus()
            }
        }
        pendingFocus = null
    }

    LaunchedEffect(state.codeSentTo) {
        val sentTo = state.codeSentTo ?: return@LaunchedEffect
        showEmailLogin = true
        if (email.isBlank()) email = sentTo
        verificationCode = ""
        lastAutoVerifiedCode = null
        startResendCountdown()
        pendingFocus = LoginFocusTarget.VerificationCode
    }

    LaunchedEffect(state.errorMessage) {
        if (state.codeSentTo != null && !state.errorMessage.isNullOrBlank()) {
            verificationCode = ""
            lastAutoVerifiedCode = null
            pendingFocus = LoginFocusTarget.VerificationCode
        }
    }

    LaunchedEffect(resendCountdownGeneration) {
        while (resendSecondsRemaining > 0) {
            delay(1_000)
            resendSecondsRemaining -= 1
        }
    }

    LaunchedEffect(state.busy, state.errorMessage, pendingResendResult) {
        if (!pendingResendResult) return@LaunchedEffect
        if (state.busy) observedResendBusy = true
        if (observedResendBusy && !state.busy) {
            if (state.errorMessage.isNullOrBlank()) {
                startResendCountdown()
                pendingFocus = LoginFocusTarget.VerificationCode
            }
            pendingResendResult = false
            observedResendBusy = false
        }
    }

    BrandBackground(modifier = modifier) {
        AnimatedContent(
            targetState = showEmailLogin,
            // SwiftUI lays LoginView inside the safe area while its background
            // continues behind the system chrome. Mirror that split here so
            // the provider stack and legal notice share the iOS baselines.
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
            transitionSpec = {
                fadeIn(tween(200)) togetherWith fadeOut(tween(200))
            },
            label = "login-mode",
        ) { emailMode ->
            if (emailMode) {
                FocusedEmailLoginLayout(
                    state = state,
                    email = email,
                    normalizedEmail = normalizedEmail,
                    isEmailValid = isEmailValid,
                    showEmailValidationError = showEmailValidationError,
                    verificationCode = verificationCode,
                    resendSecondsRemaining = resendSecondsRemaining,
                    emailFocusRequester = emailFocusRequester,
                    verificationFocusRequester = verificationFocusRequester,
                    onBack = ::leaveEmailLogin,
                    onEmailFocusLost = {
                        if (normalizedEmail.isNotEmpty()) showEmailValidationError = !isEmailValid
                    },
                    onEmailChange = { value ->
                        email = value
                        showEmailValidationError = false
                        onClearError()
                    },
                    onSubmitEmail = ::submitEmail,
                    onChangeEmail = ::changeEmail,
                    onVerificationCodeChange = { rawCode ->
                        val oldCount = verificationCode.count(Char::isDigit)
                        val normalizedCode = rawCode.filter(Char::isDigit).take(VerificationCodeLength)
                        verificationCode = normalizedCode
                        onClearError()
                        if (
                            normalizedCode.length == VerificationCodeLength &&
                            oldCount < VerificationCodeLength &&
                            normalizedCode != lastAutoVerifiedCode &&
                            !state.busy
                        ) {
                            lastAutoVerifiedCode = normalizedCode
                            focusManager.clearFocus(force = true)
                            onVerifyCode(normalizedCode)
                        }
                    },
                    onSubmitVerificationCode = ::submitVerificationCode,
                    onResendCode = {
                        if (resendSecondsRemaining == 0 && !state.busy) {
                            onClearError()
                            verificationCode = ""
                            lastAutoVerifiedCode = null
                            pendingResendResult = true
                            observedResendBusy = false
                            onSendCode(normalizedEmail)
                        }
                    },
                )
            } else {
                SocialLoginLayout(
                    onGoogleSignIn = onGoogleSignIn,
                    onEmailSignIn = {
                        showEmailLogin = true
                        pendingFocus = LoginFocusTarget.Email
                    },
                    onAppleSignIn = onAppleSignIn,
                    onOpenUrl = onOpenUrl,
                )
            }
        }
    }
}

@Composable
private fun SocialLoginLayout(
    onGoogleSignIn: () -> Unit,
    onEmailSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))

        LoginBrandHeader(
            modifier = Modifier.padding(horizontal = 24.dp),
            iconSize = 96.dp,
            showsWordmark = true,
        )

        Spacer(modifier = Modifier.weight(1f))

        Column(
            modifier = Modifier
                .widthIn(max = ContentMaxWidth.dp)
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            NeutralLoginButton(
                text = stringResource(R.string.auth_login_google_button),
                drawableId = R.drawable.ic_google_g,
                iconSize = 18.dp,
                enabled = true,
                onClick = onGoogleSignIn,
            )
            NeutralLoginButton(
                text = stringResource(R.string.auth_login_email_button),
                imageVector = Icons.Outlined.Mail,
                iconSize = 17.dp,
                enabled = true,
                onClick = onEmailSignIn,
            )
            NeutralLoginButton(
                text = stringResource(R.string.auth_login_apple_button),
                drawableId = R.drawable.apple_signin_logo,
                iconSize = 17.dp,
                drawableRenderSize = 45.dp,
                enabled = true,
                onClick = onAppleSignIn,
            )
        }

        LegalNotice(onOpenUrl = onOpenUrl)
    }
}

@Composable
private fun FocusedEmailLoginLayout(
    state: AppUiState,
    email: String,
    normalizedEmail: String,
    isEmailValid: Boolean,
    showEmailValidationError: Boolean,
    verificationCode: String,
    resendSecondsRemaining: Int,
    emailFocusRequester: FocusRequester,
    verificationFocusRequester: FocusRequester,
    onBack: () -> Unit,
    onEmailFocusLost: () -> Unit,
    onEmailChange: (String) -> Unit,
    onSubmitEmail: () -> Unit,
    onChangeEmail: () -> Unit,
    onVerificationCodeChange: (String) -> Unit,
    onSubmitVerificationCode: () -> Unit,
    onResendCode: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        BackToOptionsButton(onClick = onBack)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            LoginBrandHeader(
                modifier = Modifier.padding(top = 48.dp),
                iconSize = 60.dp,
                showsWordmark = false,
            )

            AnimatedContent(
                targetState = state.codeSentTo != null,
                modifier = Modifier
                    .padding(top = 30.dp, bottom = 24.dp)
                    .widthIn(max = ContentMaxWidth.dp)
                    .fillMaxWidth(),
                transitionSpec = {
                    (slideInHorizontally(tween(200)) { width -> width } + fadeIn(tween(200))) togetherWith
                        (slideOutHorizontally(tween(200)) { width -> width } + fadeOut(tween(200)))
                },
                contentKey = { it },
                label = "email-login-step",
            ) { codeWasSent ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    if (codeWasSent) {
                        VerificationCodeSection(
                            email = normalizedEmail.ifBlank { state.codeSentTo.orEmpty() },
                            code = verificationCode,
                            errorMessage = state.errorMessage,
                            busy = state.busy,
                            resendSecondsRemaining = resendSecondsRemaining,
                            focusRequester = verificationFocusRequester,
                            onChangeEmail = onChangeEmail,
                            onCodeChange = onVerificationCodeChange,
                            onSubmit = onSubmitVerificationCode,
                            onResendCode = onResendCode,
                        )
                    } else {
                        EmailEntrySection(
                            email = email,
                            isEmailValid = isEmailValid,
                            showValidationError = showEmailValidationError,
                            errorMessage = state.errorMessage,
                            focusRequester = emailFocusRequester,
                            onFocusLost = onEmailFocusLost,
                            onEmailChange = onEmailChange,
                            onSubmit = onSubmitEmail,
                        )
                    }

                    PrimaryLoginButton(
                        text = stringResource(
                            if (codeWasSent) R.string.auth_login_verify_button else R.string.auth_login_send_code,
                        ),
                        loading = state.busy,
                        enabled = !state.busy && if (codeWasSent) {
                            verificationCode.length == VerificationCodeLength
                        } else {
                            isEmailValid
                        },
                        onClick = if (codeWasSent) onSubmitVerificationCode else onSubmitEmail,
                    )
                }
            }
        }
    }
}

@Composable
private fun BackToOptionsButton(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(top = 4.dp)
            .heightIn(min = 44.dp)
            .clickable(role = Role.Button, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBackIos,
            contentDescription = null,
            tint = ChillColors.TextMain,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = stringResource(R.string.auth_login_back_to_options),
            modifier = Modifier.padding(start = 6.dp),
            color = ChillColors.TextMain,
            style = TextStyle(
                fontSize = 13.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.SemiBold,
            ),
        )
    }
}

@Composable
private fun EmailEntrySection(
    email: String,
    isEmailValid: Boolean,
    showValidationError: Boolean,
    errorMessage: String?,
    focusRequester: FocusRequester,
    onFocusLost: () -> Unit,
    onEmailChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    val validationError = showValidationError && !isEmailValid
    val visibleError = if (validationError) {
        stringResource(R.string.auth_login_email_invalid)
    } else {
        errorMessage?.takeIf(String::isNotBlank)
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = stringResource(R.string.auth_login_email_title),
                color = ChillColors.TextMain,
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                text = stringResource(R.string.auth_login_email_help),
                color = ChillColors.TextSub,
                style = FootnoteStyle,
            )
        }

        ParityEmailField(
            value = email,
            isError = visibleError != null,
            focusRequester = focusRequester,
            onFocusLost = onFocusLost,
            onValueChange = onEmailChange,
            onSubmit = onSubmit,
        )

        visibleError?.let { LoginErrorMessage(it) }
    }
}

@Composable
private fun ParityEmailField(
    value: String,
    isError: Boolean,
    focusRequester: FocusRequester,
    onFocusLost: () -> Unit,
    onValueChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    var hadFocus by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(ChillRadius.Button)

    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .focusRequester(focusRequester)
            .onFocusChanged { focusState ->
                if (hadFocus && !focusState.isFocused) onFocusLost()
                hadFocus = focusState.isFocused
            }
            .background(ChillColors.BackgroundSecondary, shape)
            .border(
                width = 1.dp,
                color = if (isError) Color.Red.copy(alpha = 0.45f) else ChillColors.TextSub.copy(alpha = 0.10f),
                shape = shape,
            )
            .padding(horizontal = 16.dp),
        enabled = true,
        singleLine = true,
        textStyle = MaterialTheme.typography.bodyLarge.copy(color = ChillColors.TextMain),
        cursorBrush = SolidColor(ChillColors.BrandBlue),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Go,
        ),
        keyboardActions = KeyboardActions(onGo = { onSubmit() }),
        decorationBox = { innerTextField ->
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (value.isEmpty()) {
                    Text(
                        text = stringResource(R.string.auth_login_email_placeholder),
                        color = ChillColors.TextTertiary.copy(alpha = 0.52f),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
                innerTextField()
            }
        },
    )
}

@Composable
private fun VerificationCodeSection(
    email: String,
    code: String,
    errorMessage: String?,
    busy: Boolean,
    resendSecondsRemaining: Int,
    focusRequester: FocusRequester,
    onChangeEmail: () -> Unit,
    onCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onResendCode: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                text = stringResource(R.string.auth_login_code_title),
                color = ChillColors.TextMain,
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.auth_login_code_sent_to_format, email),
                color = ChillColors.TextSub,
                style = FootnoteStyle,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.auth_login_change_email),
                color = ChillColors.BrandBlueText,
                style = FootnoteStyle.copy(fontWeight = FontWeight.SemiBold),
                modifier = Modifier.clickable(role = Role.Button, onClick = onChangeEmail),
            )
        }

        VerificationCodeInput(
            code = code,
            hasError = !errorMessage.isNullOrBlank(),
            focusRequester = focusRequester,
            onCodeChange = onCodeChange,
            onSubmit = onSubmit,
        )

        errorMessage?.takeIf(String::isNotBlank)?.let { LoginErrorMessage(it) }

        val resendEnabled = resendSecondsRemaining == 0 && !busy
        val resendText = if (resendSecondsRemaining > 0) {
            stringResource(R.string.auth_login_resend_countdown_format, resendSecondsRemaining)
        } else {
            stringResource(R.string.auth_login_resend_code)
        }
        Text(
            text = resendText,
            color = if (resendEnabled) ChillColors.BrandBlueText else ChillColors.TextSub,
            style = FootnoteStyle.copy(fontWeight = FontWeight.SemiBold),
            modifier = Modifier.clickable(
                enabled = resendEnabled,
                role = Role.Button,
                onClick = onResendCode,
            ),
        )
    }
}

@Composable
private fun VerificationCodeInput(
    code: String,
    hasError: Boolean,
    focusRequester: FocusRequester,
    onCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    var isFocused by remember { mutableStateOf(false) }
    val codeCharacters = code.toList()
    val accessibilityLabel = stringResource(R.string.auth_login_verification_code_placeholder)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .clearAndSetSemantics { },
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            repeat(VerificationCodeLength) { index ->
                val isActive = isFocused && index == minOf(code.length, VerificationCodeLength - 1)
                val borderColor = when {
                    hasError -> Color.Red.copy(alpha = 0.55f)
                    isActive -> ChillColors.BrandBlue
                    else -> ChillColors.TextSub.copy(alpha = 0.14f)
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .background(ChillColors.BackgroundSecondary, RoundedCornerShape(12.dp))
                        .border(
                            width = if (isActive) 1.5.dp else 1.dp,
                            color = borderColor,
                            shape = RoundedCornerShape(12.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = codeCharacters.getOrNull(index)?.toString().orEmpty(),
                        color = ChillColors.TextMain,
                        style = TextStyle(
                            fontSize = 24.sp,
                            lineHeight = 29.sp,
                            fontWeight = FontWeight.SemiBold,
                        ),
                    )
                }
            }
        }

        BasicTextField(
            value = code,
            onValueChange = onCodeChange,
            modifier = Modifier
                .matchParentSize()
                .focusRequester(focusRequester)
                .onFocusChanged { isFocused = it.isFocused }
                .semantics { contentDescription = accessibilityLabel },
            singleLine = true,
            textStyle = TextStyle(color = Color.Transparent),
            cursorBrush = SolidColor(Color.Transparent),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.NumberPassword,
                imeAction = ImeAction.Done,
            ),
            keyboardActions = KeyboardActions(onDone = { onSubmit() }),
        )
    }
}

@Composable
private fun LoginErrorMessage(message: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 2.dp)
            .clearAndSetSemantics { contentDescription = message },
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Error,
            contentDescription = null,
            tint = Color.Red,
            modifier = Modifier.size(17.dp),
        )
        Text(
            text = message,
            modifier = Modifier.weight(1f),
            color = Color.Red,
            style = FootnoteStyle,
        )
    }
}

@Composable
private fun PrimaryLoginButton(
    text: String,
    loading: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    ParityButtonSurface(
        enabled = enabled,
        background = ChillColors.BrandBlue,
        shadowColor = ChillColors.BrandBlue.copy(alpha = 0.22f),
        shadowElevation = 12.dp,
        pressedScale = 0.97f,
        onClick = onClick,
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = Color.White,
                strokeWidth = 2.5.dp,
            )
        } else {
            Text(
                text = text,
                color = Color.White,
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

@Composable
private fun NeutralLoginButton(
    text: String,
    enabled: Boolean,
    iconSize: androidx.compose.ui.unit.Dp,
    onClick: () -> Unit,
    drawableId: Int? = null,
    drawableRenderSize: androidx.compose.ui.unit.Dp = iconSize,
    imageVector: ImageVector? = null,
) {
    ParityButtonSurface(
        enabled = enabled,
        background = Color.White,
        shadowColor = Color.Black.copy(alpha = 0.06f),
        shadowElevation = 10.dp,
        pressedScale = 0.985f,
        onClick = onClick,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            when {
                drawableId != null -> Box(
                    modifier = Modifier.size(iconSize),
                    contentAlignment = Alignment.Center,
                ) {
                    androidx.compose.foundation.Image(
                        painter = painterResource(drawableId),
                        contentDescription = null,
                        modifier = Modifier.requiredSize(drawableRenderSize),
                    )
                }
                imageVector != null -> Icon(
                    imageVector = imageVector,
                    contentDescription = null,
                    modifier = Modifier.size(iconSize),
                    tint = Color.Black,
                )
            }
            Text(
                text = text,
                color = Color.Black,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
            )
        }
    }
}

@Composable
private fun ParityButtonSurface(
    enabled: Boolean,
    background: Color,
    shadowColor: Color,
    shadowElevation: androidx.compose.ui.unit.Dp,
    pressedScale: Float,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) pressedScale else 1f,
        animationSpec = tween(durationMillis = 90),
        label = "login-button-scale",
    )
    val shape = RoundedCornerShape(ChillRadius.Button)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(ChillSizes.PrimaryButtonHeight)
            .graphicsLayer(scaleX = scale, scaleY = scale)
            .shadow(
                elevation = shadowElevation,
                shape = shape,
                clip = false,
                ambientColor = shadowColor,
                spotColor = shadowColor,
            )
            .clip(shape)
            .background(background)
            .clickable(
                enabled = enabled,
                role = Role.Button,
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

@Composable
private fun LoginBrandHeader(
    modifier: Modifier = Modifier,
    iconSize: androidx.compose.ui.unit.Dp,
    showsWordmark: Boolean,
) {
    val brandTitle = stringResource(R.string.app_name)
    Column(
        modifier = modifier.semantics(mergeDescendants = true) {
            contentDescription = brandTitle
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        LightningBallIcon(size = iconSize)
        if (showsWordmark) {
            androidx.compose.foundation.Image(
                painter = painterResource(R.drawable.onboarding_wordmark),
                contentDescription = null,
                modifier = Modifier
                    .widthIn(max = 190.dp)
                    .fillMaxWidth()
                    .height(56.dp),
            )
        }
    }
}

@Composable
private fun LightningBallIcon(size: androidx.compose.ui.unit.Dp) {
    Box(
        modifier = Modifier
            .size(size)
            .shadow(
                elevation = 5.dp,
                shape = CircleShape,
                clip = false,
                ambientColor = ChillColors.Shadow,
                spotColor = ChillColors.Shadow,
            )
            .background(ChillColors.BackgroundSecondary, CircleShape)
            .border(1.dp, ChillColors.BorderSubtle, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .padding(2.dp)
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            ChillColors.BrandBlue.copy(alpha = 0.10f),
                            Color.White.copy(alpha = 0.02f),
                        ),
                    ),
                    shape = CircleShape,
                ),
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .border(0.5.dp, ChillColors.BrandBlue.copy(alpha = 0.12f), CircleShape),
        )
        Icon(
            imageVector = Icons.Filled.Bolt,
            contentDescription = null,
            tint = ChillColors.BrandBlue.copy(alpha = 0.12f),
            modifier = Modifier
                .size(size * 0.44f)
                .offset(y = 1.dp)
                .blur(2.dp)
                .graphicsLayer(rotationZ = 4f),
        )
        Icon(
            imageVector = Icons.Filled.Bolt,
            contentDescription = null,
            tint = ChillColors.BrandBlue,
            modifier = Modifier
                .size(size * 0.44f)
                .graphicsLayer(rotationZ = 4f),
        )
    }
}

@Composable
private fun LegalNotice(onOpenUrl: (String) -> Unit) {
    val markdown = stringResource(R.string.auth_login_legal_markdown)
    val textColor = ChillColors.TextSub.copy(alpha = 0.80f)
    val linkColor = ChillColors.TextSub.copy(alpha = 0.95f)
    val annotatedText = remember(markdown, textColor, linkColor, onOpenUrl) {
        buildAnnotatedString {
            var cursor = 0
            MarkdownLinkPattern.findAll(markdown).forEach { match ->
                append(markdown.substring(cursor, match.range.first))
                val label = match.groupValues[1]
                val url = match.groupValues[2]
                withLink(
                    LinkAnnotation.Url(
                        url = url,
                        styles = TextLinkStyles(
                            style = SpanStyle(
                                color = linkColor,
                                textDecoration = TextDecoration.None,
                            ),
                        ),
                        linkInteractionListener = { onOpenUrl(url) },
                    ),
                ) {
                    append(label)
                }
                cursor = match.range.last + 1
            }
            append(markdown.substring(cursor))
        }
    }

    Text(
        text = annotatedText,
        modifier = Modifier
            .widthIn(max = ContentMaxWidth.dp)
            .fillMaxWidth()
            .padding(horizontal = 32.dp)
            .padding(bottom = 24.dp),
        color = textColor,
        style = TextStyle(
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Normal,
            textAlign = TextAlign.Center,
        ),
    )
}

private val FootnoteStyle = TextStyle(
    fontSize = 13.sp,
    lineHeight = 18.sp,
    fontWeight = FontWeight.Normal,
)
