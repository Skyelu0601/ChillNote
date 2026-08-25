package com.sponteoai.chillscript.onboarding

import android.media.MediaPlayer
import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.BackHandler
import androidx.annotation.RawRes
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.AddCircle
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ClosedCaption
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Replay
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.isVisible
import com.sponteoai.chillscript.R
import kotlinx.coroutines.delay
import kotlin.math.abs

private const val ONBOARDING_VIDEO_ASPECT_RATIO = 810f / 1710f
private val ONBOARDING_PHONE_OUTER_CORNER = 20.dp
private val ONBOARDING_PHONE_SCREEN_CORNER = 14.dp

/**
 * Android rendering of the current iOS `OnboardingFlowView`.
 *
 * The SwiftUI screen and BrandTokens are the source of truth. Keep this screen
 * deliberately self-contained so the Android app theme cannot silently change
 * its marketing layout, colors, type scale, or component shapes.
 */
@Composable
fun IOSParityOnboardingScreen(
    onFinish: () -> Unit,
    onLogIn: () -> Unit,
    modifier: Modifier = Modifier,
    initialPage: Int = 0,
) {
    var pageIndex by remember(initialPage) {
        mutableIntStateOf(initialPage.coerceIn(0, 5))
    }
    var saveVideoComplete by remember { mutableStateOf(false) }
    var extractIdeasComplete by remember { mutableStateOf(false) }
    var generateHooksComplete by remember { mutableStateOf(false) }
    var lockedHintRequest by remember { mutableIntStateOf(0) }
    var showLockedHint by remember { mutableStateOf(false) }
    var dragDistance by remember { mutableFloatStateOf(0f) }
    val haptics = LocalHapticFeedback.current
    val density = LocalDensity.current
    val dragThreshold = with(density) { 52.dp.toPx() }
    val pageDescription = stringResource(
        R.string.onboarding_page_accessibility_format,
        pageIndex + 1,
        6,
    )

    fun isLocked(index: Int): Boolean = when (index) {
        1 -> !saveVideoComplete
        2 -> !extractIdeasComplete
        4 -> !generateHooksComplete
        else -> false
    }

    fun firstIncompleteDemo(): Int? = when {
        !saveVideoComplete -> 1
        !extractIdeasComplete -> 2
        !generateHooksComplete -> 4
        else -> null
    }

    fun requestPage(requestedPage: Int) {
        if (requestedPage !in 0..5) return
        val firstIncomplete = firstIncompleteDemo()
        if (firstIncomplete != null && requestedPage > firstIncomplete) {
            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            lockedHintRequest += 1
            showLockedHint = true
            return
        }
        showLockedHint = false
        pageIndex = requestedPage
    }

    LaunchedEffect(lockedHintRequest) {
        if (lockedHintRequest == 0) return@LaunchedEffect
        delay(1_200)
        showLockedHint = false
    }

    BackHandler(enabled = pageIndex > 0) {
        requestPage(pageIndex - 1)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(IOSOnboardingColors.Background)
            .semantics { contentDescription = pageDescription }
            .detectOnboardingSwipe(
                onDragStart = { dragDistance = 0f },
                onDrag = { delta -> dragDistance += delta },
                onDragEnd = {
                    if (abs(dragDistance) >= dragThreshold) {
                        requestPage(if (dragDistance < 0) pageIndex + 1 else pageIndex - 1)
                    }
                    dragDistance = 0f
                },
            ),
    ) {
        IOSBrandBackground()

        AnimatedContent(
            targetState = pageIndex,
            modifier = Modifier.fillMaxSize(),
            transitionSpec = {
                val direction = if (targetState > initialState) 1 else -1
                (slideInHorizontally(
                    animationSpec = spring(dampingRatio = 0.82f, stiffness = 360f),
                    initialOffsetX = { it * direction },
                ) + fadeIn(tween(180))) togetherWith
                    (slideOutHorizontally(
                        animationSpec = spring(dampingRatio = 0.82f, stiffness = 360f),
                        targetOffsetX = { -it * direction },
                    ) + fadeOut(tween(150)))
            },
            label = "iOS onboarding page",
        ) { page ->
            Box(
                Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .padding(horizontal = IOSOnboardingTokens.Space24)
                    // SwiftUI's page content uses BrandTokens.Space.s4 (24 pt)
                    // below the safe area. Keep the same inset on Android so the
                    // wordmark, subtitle, and demo phone share the iOS baseline.
                    .padding(top = IOSOnboardingTokens.Space24)
                    .padding(bottom = if (isLocked(page)) 20.dp else if (page == 0) 156.dp else 104.dp),
            ) {
                when (page) {
                    0 -> IOSHeroPage(isActive = pageIndex == 0)
                    1 -> IOSSaveVideoPage(
                        isActive = pageIndex == 1,
                        onFlowComplete = { saveVideoComplete = true },
                    )
                    2 -> IOSExtractIdeasPage(
                        isActive = pageIndex == 2,
                        onFlowComplete = { extractIdeasComplete = true },
                    )
                    3 -> IOSCaptureShowcasePage()
                    4 -> IOSGenerateHooksPage(
                        isActive = pageIndex == 4,
                        onFlowComplete = { generateHooksComplete = true },
                    )
                    else -> IOSAISkillsPage(isActive = pageIndex == 5)
                }
            }
        }

        AnimatedVisibility(
            visible = !isLocked(pageIndex),
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = fadeIn(tween(180)) + slideInVertically { it / 3 },
            exit = fadeOut(tween(140)) + slideOutVertically { it / 3 },
        ) {
            IOSOnboardingActionBar(
                isHero = pageIndex == 0,
                isLast = pageIndex == 5,
                isGenerateHooks = pageIndex == 4,
                onPrimary = {
                    haptics.performHapticFeedback(
                        if (pageIndex == 5) HapticFeedbackType.LongPress else HapticFeedbackType.TextHandleMove,
                    )
                    if (pageIndex == 5) onFinish() else requestPage(pageIndex + 1)
                },
                onLogin = {
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onLogIn()
                },
            )
        }

        AnimatedVisibility(
            visible = showLockedHint,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = IOSOnboardingTokens.Space24),
            enter = fadeIn(tween(180)) + slideInVertically { it / 2 },
            exit = fadeOut(tween(160)) + slideOutVertically { it / 2 },
        ) {
            Text(
                text = stringResource(R.string.onboarding_demo_almost_done),
                color = Color.White,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .shadow(10.dp, CircleShape)
                    .background(Color.Black.copy(alpha = 0.76f), CircleShape)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
    }
}

private fun Modifier.detectOnboardingSwipe(
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit,
): Modifier = this.then(
    Modifier.pointerInputCompat(onDragStart, onDrag, onDragEnd),
)

private fun Modifier.pointerInputCompat(
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit,
): Modifier = pointerInput(onDragStart, onDrag, onDragEnd) {
    detectHorizontalDragGestures(
        onDragStart = { onDragStart() },
        onHorizontalDrag = { change, dragAmount ->
            change.consume()
            onDrag(dragAmount)
        },
        onDragCancel = onDragEnd,
        onDragEnd = onDragEnd,
    )
}

@Composable
private fun IOSBrandBackground() {
    Box(
        Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        IOSOnboardingColors.Background,
                        Color.White.copy(alpha = 0.96f),
                        IOSOnboardingColors.BrandBlueSoft.copy(alpha = 0.45f),
                    ),
                    start = Offset.Zero,
                    end = Offset.Infinite,
                ),
            ),
    ) {
        Box(
            Modifier
                .align(Alignment.Center)
                .offset(x = 138.dp, y = (-270).dp)
                .size(240.dp)
                .blur(14.dp)
                .background(IOSOnboardingColors.Accent.copy(alpha = 0.08f), CircleShape),
        )
        Box(
            Modifier
                .align(Alignment.Center)
                .offset(x = (-140).dp, y = 320.dp)
                .size(210.dp)
                .blur(18.dp)
                .background(IOSOnboardingColors.Teal.copy(alpha = 0.07f), CircleShape),
        )
    }
}

@Composable
private fun IOSHeroPage(isActive: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(
            painter = painterResource(R.drawable.onboarding_wordmark),
            contentDescription = "ChillScript",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .widthIn(max = 330.dp)
                .fillMaxWidth()
                .height(93.dp),
        )

        Text(
            text = stringResource(R.string.onboarding_page_hero_body),
            color = IOSOnboardingColors.TextMain.copy(alpha = 0.72f),
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(top = 12.dp)
                .widthIn(max = 330.dp),
        )

        Spacer(Modifier.height(27.dp))

        IOSPhoneVideo(
            rawRes = R.raw.onboarding_demo1,
            isActive = isActive,
            loops = true,
            autoplay = true,
            showPlaybackControl = false,
            modifier = Modifier
                .widthIn(max = onboardingVideoMaxWidth(hero = true))
                .fillMaxWidth(),
        )

        Spacer(Modifier.heightIn(min = 28.dp).weight(1f))
    }
}

@Composable
private fun IOSSaveVideoPage(
    isActive: Boolean,
    onFlowComplete: () -> Unit,
) {
    var videoComplete by remember { mutableStateOf(false) }
    var revealPhase by remember { mutableIntStateOf(0) }

    LaunchedEffect(videoComplete) {
        if (!videoComplete || revealPhase > 0) return@LaunchedEffect
        delay(160)
        revealPhase = 1
        repeat(3) {
            delay(280)
            revealPhase += 1
        }
        delay(260)
        onFlowComplete()
    }

    IOSMarketingPageColumn {
        IOSHighlightedTitle(
            full = stringResource(R.string.onboarding_page_save_video_title),
            highlight = stringResource(R.string.onboarding_highlight_save_video),
        )

        IOSPhoneVideo(
            rawRes = R.raw.onboarding_demo1,
            isActive = isActive,
            loops = false,
            autoplay = true,
            showPlaybackControl = true,
            onComplete = { videoComplete = true },
            modifier = Modifier
                .padding(top = 16.dp)
                .widthIn(max = onboardingVideoMaxWidth())
                .fillMaxWidth()
                .align(Alignment.CenterHorizontally),
        )

        AnimatedVisibility(
            visible = revealPhase > 0,
            enter = fadeIn(tween(220)) + scaleIn(initialScale = 0.98f),
            exit = ExitTransition.None,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
            ) {
                Text(
                    text = stringResource(R.string.onboarding_save_video_platforms),
                    color = IOSOnboardingColors.TextMain,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(12.dp))
                IOSPlatformChips(visibleCount = (revealPhase - 1).coerceIn(0, 3))
            }
        }

        Spacer(Modifier.heightIn(min = 18.dp).weight(1f))
    }
}

@Composable
private fun IOSExtractIdeasPage(
    isActive: Boolean,
    onFlowComplete: () -> Unit,
) {
    var videoComplete by remember { mutableStateOf(false) }
    var revealPhase by remember { mutableIntStateOf(0) }
    val regularVideoWidth = onboardingVideoMaxWidth()
    val videoWidth by animateDpAsState(
        targetValue = if (revealPhase > 0) {
            (regularVideoWidth - 20.dp).coerceAtLeast(155.dp)
        } else {
            regularVideoWidth
        },
        animationSpec = tween(260, easing = FastOutSlowInEasing),
        label = "extract demo width",
    )
    val videoTopPadding by animateDpAsState(
        targetValue = if (revealPhase > 0) 8.dp else 24.dp,
        animationSpec = tween(260, easing = FastOutSlowInEasing),
        label = "extract demo top padding",
    )

    LaunchedEffect(videoComplete) {
        if (!videoComplete || revealPhase > 0) return@LaunchedEffect
        delay(160)
        revealPhase = 1
        repeat(4) {
            delay(260)
            revealPhase += 1
        }
        delay(260)
        onFlowComplete()
    }

    IOSMarketingPageColumn {
        IOSHighlightedTitle(
            full = stringResource(R.string.onboarding_page_extract_title),
            highlight = stringResource(R.string.onboarding_highlight_extract_ideas),
        )

        IOSPhoneVideo(
            rawRes = R.raw.onboarding_demo2,
            isActive = isActive,
            loops = false,
            autoplay = true,
            showPlaybackControl = true,
            onComplete = { videoComplete = true },
            modifier = Modifier
                .padding(top = videoTopPadding)
                .widthIn(max = videoWidth)
                .fillMaxWidth()
                .align(Alignment.CenterHorizontally),
        )

        AnimatedVisibility(
            visible = revealPhase > 0,
            enter = fadeIn(tween(220)) + scaleIn(initialScale = 0.98f),
            exit = ExitTransition.None,
        ) {
            IOSExtractedSectionsCard(
                visibleCount = (revealPhase - 1).coerceIn(0, 4),
                modifier = Modifier.padding(top = 16.dp),
            )
        }

        Spacer(Modifier.heightIn(min = 18.dp).weight(1f))
    }
}

@Composable
private fun IOSCaptureShowcasePage() {
    var revealPhase by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        delay(120)
        revealPhase = 1
        delay(320)
        revealPhase = 2
        delay(480)
        revealPhase = 3
    }

    IOSMarketingPageColumn {
        IOSHighlightedTitle(
            full = stringResource(R.string.onboarding_page_capture_title),
            highlight = stringResource(R.string.onboarding_highlight_capture_idea),
        )

        Spacer(Modifier.heightIn(min = 22.dp).weight(1f))

        IOSCaptureBoard(revealPhase = revealPhase)

        Spacer(Modifier.heightIn(min = 18.dp).weight(1f))
    }
}

@Composable
private fun IOSGenerateHooksPage(
    isActive: Boolean,
    onFlowComplete: () -> Unit,
) {
    var videoComplete by remember { mutableStateOf(false) }
    var revealTransition by remember { mutableStateOf(false) }

    LaunchedEffect(videoComplete) {
        if (!videoComplete || revealTransition) return@LaunchedEffect
        delay(260)
        revealTransition = true
        delay(520)
        onFlowComplete()
    }

    IOSMarketingPageColumn {
        IOSHighlightedTitle(
            full = stringResource(R.string.onboarding_page_hooks_title),
            highlight = stringResource(R.string.onboarding_highlight_generate_hooks),
        )

        IOSPhoneVideo(
            rawRes = R.raw.onboarding_demo3,
            isActive = isActive,
            loops = false,
            autoplay = true,
            showPlaybackControl = true,
            onComplete = { videoComplete = true },
            modifier = Modifier
                .padding(top = 24.dp)
                .widthIn(max = onboardingVideoMaxWidth())
                .fillMaxWidth()
                .align(Alignment.CenterHorizontally),
        )

        AnimatedVisibility(
            visible = revealTransition,
            enter = fadeIn(tween(220)) + scaleIn(initialScale = 0.98f),
            exit = ExitTransition.None,
        ) {
            IOSHooksTransitionCard(Modifier.padding(top = 24.dp))
        }

        Spacer(Modifier.heightIn(min = 18.dp).weight(1f))
    }
}

@Composable
private fun IOSAISkillsPage(isActive: Boolean) {
    var revealPhase by remember { mutableIntStateOf(1) }
    LaunchedEffect(isActive) {
        if (!isActive) {
            revealPhase = 1
            return@LaunchedEffect
        }
        revealPhase = 1
        delay(300)
        for (phase in 2..8) {
            revealPhase = phase
            delay(if (phase == 8) 280 else 220)
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val compact = maxHeight <= 700.dp
        IOSMarketingPageColumn {
            IOSHighlightedTitle(
                full = stringResource(R.string.onboarding_page_skills_title),
                highlight = stringResource(R.string.onboarding_highlight_ai_skills),
            )

            IOSSkillsLibraryCard(
                compact = compact,
                revealPhase = revealPhase,
                modifier = Modifier.padding(top = if (compact) 16.dp else 32.dp),
            )

            Spacer(Modifier.heightIn(min = if (compact) 18.dp else 28.dp).weight(1f))
        }
    }
}

@Composable
private fun IOSMarketingPageColumn(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.Start,
        content = content,
    )
}

@Composable
private fun onboardingVideoMaxWidth(hero: Boolean = false): Dp {
    val screenHeightDp = LocalConfiguration.current.screenHeightDp
    val regularWidth = when {
        screenHeightDp < 650 -> 170.dp
        screenHeightDp < 760 -> 195.dp
        screenHeightDp < 860 -> 210.dp
        else -> 220.dp
    }
    return if (hero) {
        when {
            screenHeightDp < 650 -> 150.dp
            screenHeightDp < 760 -> 165.dp
            screenHeightDp < 860 -> 175.dp
            else -> 185.dp
        }
    } else {
        regularWidth
    }
}

@Composable
private fun IOSHighlightedTitle(full: String, highlight: String) {
    val title = remember(full, highlight) { highlightedString(full, highlight) }
    Text(
        text = title,
        color = IOSOnboardingColors.TextMain,
        fontSize = 34.sp,
        lineHeight = 38.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 32.dp),
    )
}

private fun highlightedString(full: String, highlight: String): AnnotatedString = buildAnnotatedString {
    append(full)
    val start = full.indexOf(highlight)
    if (start >= 0 && highlight.isNotEmpty()) {
        addStyle(
            style = SpanStyle(color = IOSOnboardingColors.Accent),
            start = start,
            end = start + highlight.length,
        )
    }
}

@Composable
private fun IOSOnboardingActionBar(
    isHero: Boolean,
    isLast: Boolean,
    isGenerateHooks: Boolean,
    onPrimary: () -> Unit,
    onLogin: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(
                        IOSOnboardingColors.Background.copy(alpha = 0f),
                        IOSOnboardingColors.Background.copy(alpha = 0.92f),
                        IOSOnboardingColors.Background,
                    ),
                ),
            )
            .padding(horizontal = 24.dp)
            .padding(top = 12.dp, bottom = 16.dp)
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        val actionText = when {
            isHero -> stringResource(R.string.onboarding_action_get_started)
            isGenerateHooks -> stringResource(R.string.onboarding_action_explore_creator_skills)
            isLast -> stringResource(R.string.onboarding_action_start_creating)
            else -> stringResource(R.string.common_next)
        }
        IOSPrimaryButton(
            text = actionText,
            showArrow = !isHero && !isLast,
            onClick = onPrimary,
        )

        if (isHero) {
            val prompt = stringResource(R.string.onboarding_login_prompt)
            val action = stringResource(R.string.onboarding_login_action)
            val label = remember(prompt, action) {
                buildAnnotatedString {
                    append(prompt)
                    append(" ")
                    pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                    append(action)
                    pop()
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.Transparent)
                    .semantics {
                        role = Role.Button
                        contentDescription = "$prompt $action"
                    }
                    .noRippleClick(onLogin),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    color = IOSOnboardingColors.TextSub,
                    fontSize = 17.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun IOSPrimaryButton(
    text: String,
    showArrow: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .shadow(
                elevation = 12.dp,
                shape = RoundedCornerShape(14.dp),
                ambientColor = IOSOnboardingColors.Accent.copy(alpha = 0.22f),
                spotColor = IOSOnboardingColors.Accent.copy(alpha = 0.22f),
            )
            .clip(RoundedCornerShape(14.dp))
            .background(IOSOnboardingColors.Accent)
            .semantics {
                role = Role.Button
                contentDescription = text
            }
            .noRippleClick(onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            color = Color.White,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
        )
        if (showArrow) {
            Icon(
                imageVector = Icons.AutoMirrored.Outlined.ArrowForward,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .padding(start = 8.dp)
                    .size(16.dp),
            )
        }
    }
}

@Composable
private fun IOSPhoneVideo(
    @RawRes rawRes: Int,
    isActive: Boolean,
    loops: Boolean,
    autoplay: Boolean,
    showPlaybackControl: Boolean,
    modifier: Modifier = Modifier,
    phoneAspectRatio: Float = ONBOARDING_VIDEO_ASPECT_RATIO,
    onComplete: () -> Unit = {},
) {
    val context = LocalContext.current
    val videoView = remember(context, rawRes) { VideoView(context) }
    var prepared by remember(rawRes) { mutableStateOf(false) }
    var playing by remember(rawRes) { mutableStateOf(false) }
    var completed by remember(rawRes) { mutableStateOf(false) }
    var durationMs by remember(rawRes) { mutableIntStateOf(0) }
    var progress by remember(rawRes) { mutableFloatStateOf(0f) }
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(80, easing = FastOutSlowInEasing),
        label = "demo progress",
    )

    fun playFromBeginning() {
        if (!prepared) return
        completed = false
        progress = 0f
        videoView.seekTo(0)
        videoView.start()
        playing = true
    }

    fun togglePlayback() {
        if (!prepared) return
        when {
            playing -> {
                videoView.pause()
                playing = false
            }
            completed -> playFromBeginning()
            else -> {
                videoView.start()
                playing = true
            }
        }
    }

    DisposableEffect(videoView, rawRes) {
        videoView.setVideoURI(Uri.parse("android.resource://${context.packageName}/$rawRes"))
        videoView.setOnPreparedListener { mediaPlayer ->
            mediaPlayer.isLooping = loops
            mediaPlayer.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING)
            mediaPlayer.setVolume(0f, 0f)
            durationMs = mediaPlayer.duration.coerceAtLeast(0)
            prepared = true
            if (loops && isActive) {
                videoView.start()
                playing = true
            }
        }
        videoView.setOnCompletionListener {
            if (!loops) {
                progress = 1f
                playing = false
                completed = true
                onComplete()
            }
        }
        videoView.setOnErrorListener { _, _, _ ->
            playing = false
            completed = true
            progress = 1f
            onComplete()
            true
        }
        onDispose {
            videoView.stopPlayback()
        }
    }

    LaunchedEffect(isActive, prepared, autoplay) {
        if (!isActive) {
            if (!loops && !completed) {
                videoView.pause()
                videoView.seekTo(0)
                progress = 0f
            } else {
                videoView.pause()
            }
            playing = false
            return@LaunchedEffect
        }
        if (prepared && autoplay && (!completed || loops)) {
            delay(300)
            if (loops) {
                videoView.start()
                playing = true
            } else if (videoView.currentPosition == 0) {
                playFromBeginning()
            }
        }
    }

    LaunchedEffect(playing, durationMs) {
        while (playing) {
            val duration = durationMs.takeIf { it > 0 } ?: videoView.duration
            if (duration > 0) {
                progress = (videoView.currentPosition.toFloat() / duration).coerceIn(0f, 1f)
            }
            delay(50)
        }
    }

    val playLabel = when {
        playing -> stringResource(R.string.onboarding_demo_accessibility_pause)
        completed -> stringResource(R.string.onboarding_demo_accessibility_replay)
        else -> stringResource(R.string.onboarding_demo_accessibility_play)
    }
    val progressLabel = stringResource(
        R.string.onboarding_demo_accessibility_progress,
        (progress * 100).toInt(),
    )

    Box(
        modifier = modifier
            .aspectRatio(phoneAspectRatio)
            .shadow(
                elevation = 20.dp,
                shape = RoundedCornerShape(ONBOARDING_PHONE_OUTER_CORNER),
                ambientColor = Color.Black.copy(alpha = 0.20f),
                spotColor = Color.Black.copy(alpha = 0.20f),
            )
            .background(Color.Black, RoundedCornerShape(ONBOARDING_PHONE_OUTER_CORNER))
            .border(
                BorderStroke(
                    1.2.dp,
                    Brush.linearGradient(
                        listOf(
                            Color.White.copy(alpha = 0.34f),
                            Color.White.copy(alpha = 0.05f),
                            Color.Black.copy(alpha = 0.42f),
                        ),
                    ),
                ),
                RoundedCornerShape(ONBOARDING_PHONE_OUTER_CORNER),
            )
            .padding(horizontal = 6.dp, vertical = 7.dp)
            .semantics(mergeDescendants = true) {
                if (showPlaybackControl) {
                    role = Role.Button
                    contentDescription = playLabel
                    stateDescription = progressLabel
                }
            }
            .then(if (showPlaybackControl) Modifier.noRippleClick { togglePlayback() } else Modifier),
    ) {
        AndroidView(
            factory = { videoView },
            update = { view -> view.isVisible = true },
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(ONBOARDING_PHONE_SCREEN_CORNER))
                .background(Color.Black),
        )

        if (showPlaybackControl) {
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(horizontal = 3.dp, vertical = 3.dp)
                    .height(3.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.24f)),
            ) {
                Box(
                    Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(animatedProgress.coerceIn(0f, 1f))
                        .background(IOSOnboardingColors.Accent, CircleShape),
                )
            }

            AnimatedVisibility(
                visible = !playing,
                modifier = Modifier.align(Alignment.Center),
                enter = fadeIn(tween(180)) + scaleIn(initialScale = 0.9f),
                exit = fadeOut(tween(140)) + scaleOut(targetScale = 0.9f),
            ) {
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .shadow(
                            elevation = 16.dp,
                            shape = CircleShape,
                            ambientColor = IOSOnboardingColors.Accent.copy(alpha = 0.28f),
                            spotColor = IOSOnboardingColors.Accent.copy(alpha = 0.28f),
                        )
                        .background(IOSOnboardingColors.Accent, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (completed) Icons.Outlined.Replay else Icons.Outlined.PlayArrow,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(29.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSPlatformChips(visibleCount: Int) {
    val chips = listOf(
        Triple("TikTok", Color.White, Color.Black.copy(alpha = 0.92f)),
        Triple("YouTube", Color(0xFFFF1717), Color(0xFFFF1717).copy(alpha = 0.12f)),
        Triple("Reels", Color.White, Color(0xFFE84D83)),
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) {
        chips.forEachIndexed { index, (label, foreground, background) ->
            val stroke = when (label) {
                "TikTok" -> Color(0xFF2EF2E6).copy(alpha = 0.34f)
                "YouTube" -> Color(0xFFFF1717).copy(alpha = 0.22f)
                else -> Color.White.copy(alpha = 0.22f)
            }
            AnimatedVisibility(
                visible = index < visibleCount,
                enter = fadeIn(tween(220, delayMillis = index * 25)) + scaleIn(initialScale = 0.96f),
                exit = ExitTransition.None,
            ) {
                Row(
                    modifier = Modifier
                        .background(
                            if (label == "Reels") {
                                Brush.linearGradient(
                                    listOf(
                                        Color(0xFFFAB82E),
                                        Color(0xFFF2387A),
                                        Color(0xFF7845EB),
                                    ),
                                )
                            } else {
                                Brush.linearGradient(listOf(background, background))
                            },
                            CircleShape,
                        )
                        .border(BorderStroke(1.dp, stroke), CircleShape)
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Icon(
                        Icons.Outlined.CheckCircle,
                        contentDescription = null,
                        tint = foreground,
                        modifier = Modifier.size(13.dp),
                    )
                    Text(
                        text = label,
                        color = foreground,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSExtractedSectionsCard(visibleCount: Int, modifier: Modifier = Modifier) {
    val sections = listOf(
        stringResource(R.string.onboarding_extract_description),
        stringResource(R.string.onboarding_extract_author),
        stringResource(R.string.onboarding_extract_link),
        stringResource(R.string.onboarding_extract_transcript),
    )
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(16.dp, RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.72f), RoundedCornerShape(20.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = stringResource(R.string.onboarding_extract_saved_as),
            color = IOSOnboardingColors.TextSub,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
        )
        sections.chunked(2).forEachIndexed { rowIndex, rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                rowItems.forEachIndexed { columnIndex, item ->
                    val index = rowIndex * 2 + columnIndex
                    AnimatedVisibility(
                        visible = index < visibleCount,
                        modifier = Modifier.weight(1f),
                        enter = fadeIn(tween(220, delayMillis = index * 25)) + scaleIn(initialScale = 0.96f),
                        exit = ExitTransition.None,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color.White.copy(alpha = 0.88f), RoundedCornerShape(14.dp))
                                .border(
                                    BorderStroke(1.dp, IOSOnboardingColors.Accent.copy(alpha = 0.12f)),
                                    RoundedCornerShape(14.dp),
                                )
                                .padding(horizontal = 11.dp, vertical = 11.dp),
                            horizontalArrangement = Arrangement.spacedBy(7.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Outlined.CheckCircle,
                                contentDescription = null,
                                tint = IOSOnboardingColors.Accent,
                                modifier = Modifier.size(14.dp),
                            )
                            Text(
                                text = item,
                                color = IOSOnboardingColors.TextMain,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun IOSCaptureBoard(revealPhase: Int) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(16.dp, RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.96f), RoundedCornerShape(20.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        IOSCaptureMethod(
            visible = revealPhase >= 1,
            icon = Icons.Outlined.Edit,
            tint = IOSOnboardingColors.TextMain,
            background = Color.White.copy(alpha = 0.82f),
            border = Color.Black.copy(alpha = 0.05f),
            title = stringResource(R.string.onboarding_capture_text_title),
            body = stringResource(R.string.onboarding_capture_text_body),
        )
        IOSDivider(visible = revealPhase >= 2)
        IOSCaptureMethod(
            visible = revealPhase >= 2,
            icon = Icons.Outlined.GraphicEq,
            animatedWaveform = true,
            tint = IOSOnboardingColors.Accent,
            background = IOSOnboardingColors.Accent.copy(alpha = 0.08f),
            border = IOSOnboardingColors.Accent.copy(alpha = 0.18f),
            title = stringResource(R.string.onboarding_capture_voice_title),
            chips = listOf(
                stringResource(R.string.onboarding_capture_voice_remove_filler),
                stringResource(R.string.onboarding_capture_voice_extract_todos),
                stringResource(R.string.onboarding_capture_voice_fix_grammar),
                stringResource(R.string.onboarding_capture_voice_clarify_thoughts),
            ),
        )
        IOSDivider(visible = revealPhase >= 3)
        IOSCaptureMethod(
            visible = revealPhase >= 3,
            icon = Icons.Outlined.Link,
            tint = Color(0xFF2E9E6B),
            background = Color(0xFF2E9E6B).copy(alpha = 0.08f),
            border = Color(0xFF2E9E6B).copy(alpha = 0.16f),
            title = stringResource(R.string.onboarding_capture_links_title),
            body = stringResource(R.string.onboarding_capture_links_body),
        )
    }
}

@Composable
private fun IOSCaptureMethod(
    visible: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    animatedWaveform: Boolean = false,
    tint: Color,
    background: Color,
    border: Color,
    title: String,
    body: String? = null,
    chips: List<String> = emptyList(),
) {
    val visibilityProgress by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "capture method visibility",
    )
    val scaleProgress by animateFloatAsState(
        targetValue = if (animatedWaveform || visible) 1f else 0.98f,
        animationSpec = tween(200, easing = FastOutSlowInEasing),
        label = "capture method scale",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = visibilityProgress
                scaleX = scaleProgress
                scaleY = scaleProgress
            }
            .then(if (visible) Modifier else Modifier.clearAndSetSemantics {})
            .background(background, RoundedCornerShape(18.dp))
            .border(BorderStroke(1.dp, border), RoundedCornerShape(18.dp))
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .padding(top = 2.dp)
                .size(40.dp)
                .background(tint.copy(alpha = 0.12f), RoundedCornerShape(13.dp)),
            contentAlignment = Alignment.Center,
        ) {
            if (animatedWaveform) {
                IOSVoiceWaveform(tint = tint)
            } else {
                Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            Text(
                text = title,
                color = IOSOnboardingColors.TextMain,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
            )
            if (body != null) {
                Text(
                    text = body,
                    color = IOSOnboardingColors.TextSub,
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            chips.forEach { chip ->
                Row(
                    modifier = Modifier
                        .background(Color.White.copy(alpha = 0.88f), CircleShape)
                        .border(
                            BorderStroke(1.dp, IOSOnboardingColors.Accent.copy(alpha = 0.16f)),
                            CircleShape,
                        )
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Outlined.CheckCircle,
                        contentDescription = null,
                        tint = IOSOnboardingColors.Accent,
                        modifier = Modifier.size(12.dp),
                    )
                    Text(
                        text = chip,
                        color = IOSOnboardingColors.TextMain,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSVoiceWaveform(tint: Color) {
    val transition = rememberInfiniteTransition(label = "voice waveform")
    val morph by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(550, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "voice waveform height",
    )
    val startHeights = intArrayOf(18, 12, 20, 14)
    val endHeights = intArrayOf(14, 20, 12, 18)
    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        startHeights.indices.forEach { index ->
            val height = startHeights[index] + (endHeights[index] - startHeights[index]) * morph
            Box(
                Modifier
                    .width(3.dp)
                    .height(height.dp)
                    .background(tint, CircleShape),
            )
        }
    }
}

@Composable
private fun IOSDivider(visible: Boolean) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Color.Black.copy(alpha = if (visible) 0.10f else 0f)),
    )
}

@Composable
private fun IOSHooksTransitionCard(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 16.dp,
                shape = RoundedCornerShape(22.dp),
                ambientColor = IOSOnboardingColors.Accent.copy(alpha = 0.08f),
                spotColor = IOSOnboardingColors.Accent.copy(alpha = 0.08f),
            )
            .background(IOSOnboardingColors.Accent.copy(alpha = 0.07f), RoundedCornerShape(22.dp))
            .border(
                BorderStroke(1.dp, IOSOnboardingColors.Accent.copy(alpha = 0.16f)),
                RoundedCornerShape(22.dp),
            )
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(30.dp)
                .background(IOSOnboardingColors.Accent.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.Bolt,
                contentDescription = null,
                tint = IOSOnboardingColors.Accent,
                modifier = Modifier.size(17.dp),
            )
        }
        Text(
            text = stringResource(R.string.onboarding_generate_hooks_transition),
            color = IOSOnboardingColors.TextMain,
            fontSize = 17.sp,
            lineHeight = 22.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
    }
}

private data class IOSSkillPreview(
    @StringRes val name: Int,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val tint: Color,
    val installed: Boolean,
)

@Composable
private fun IOSSkillsLibraryCard(
    compact: Boolean,
    revealPhase: Int,
    modifier: Modifier = Modifier,
) {
    val skills = listOf(
        IOSSkillPreview(R.string.recipe_hook_generator_name, Icons.Outlined.Link, IOSOnboardingColors.Accent, true),
        IOSSkillPreview(R.string.recipe_rewrite_name, Icons.Outlined.Edit, Color(0xFF38886F), true),
        IOSSkillPreview(R.string.recipe_caption_pack_name, Icons.Outlined.ClosedCaption, Color(0xFFB77A2D), true),
        IOSSkillPreview(R.string.recipe_repurpose_pack_name, Icons.Outlined.Layers, Color(0xFFC76655), true),
        IOSSkillPreview(R.string.recipe_humanizer_name, Icons.Outlined.FavoriteBorder, Color(0xFFB56C82), false),
        IOSSkillPreview(R.string.recipe_style_match_name, Icons.Outlined.GraphicEq, Color(0xFF8A69A5), false),
    )
    val visibleCount = revealPhase.coerceIn(1, skills.size)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(16.dp, RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.96f), RoundedCornerShape(20.dp))
            .padding(if (compact) 12.dp else 14.dp),
        verticalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(R.string.onboarding_skills_library).uppercase(),
                color = IOSOnboardingColors.TextSub,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp,
            )
            Spacer(Modifier.weight(1f))
            AnimatedVisibility(
                visible = revealPhase > 7,
                enter = fadeIn(tween(220)) + slideInHorizontally { it / 2 },
                exit = ExitTransition.None,
            ) {
                IOSSkillsLibraryIconStack(skills.take(4))
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(16.dp))
                .border(BorderStroke(1.dp, Color.Black.copy(alpha = 0.06f)), RoundedCornerShape(16.dp)),
        ) {
            skills.take(visibleCount).forEachIndexed { index, skill ->
                AnimatedVisibility(
                    visible = index < visibleCount,
                    enter = fadeIn(tween(220)) + slideInVertically { it / 2 },
                    exit = ExitTransition.None,
                ) {
                    IOSSkillRow(skill = skill, compact = compact)
                }
                if (index < visibleCount - 1) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(start = if (compact) 52.dp else 58.dp)
                            .height(1.dp)
                            .background(Color.Black.copy(alpha = 0.08f)),
                    )
                }
            }
        }

        AnimatedVisibility(
            visible = revealPhase > skills.size,
            enter = fadeIn(tween(220)) + slideInVertically { it / 2 },
            exit = ExitTransition.None,
        ) {
            IOSBuildYourOwnRow(compact = compact)
        }
    }
}

@Composable
private fun IOSSkillsLibraryIconStack(skills: List<IOSSkillPreview>) {
    Row(
        horizontalArrangement = Arrangement.spacedBy((-7).dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        skills.forEach { skill ->
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .shadow(4.dp, RoundedCornerShape(8.dp))
                    .background(Color.White, CircleShape)
                    .clip(RoundedCornerShape(8.dp))
                    .background(skill.tint.copy(alpha = 0.11f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = skill.icon,
                    contentDescription = null,
                    tint = skill.tint,
                    modifier = Modifier.size(13.dp),
                )
            }
        }
        Box(
            modifier = Modifier
                .padding(start = 3.dp)
                .width(31.dp)
                .height(28.dp)
                .background(IOSOnboardingColors.Accent.copy(alpha = 0.10f), CircleShape)
                .border(
                    BorderStroke(1.dp, IOSOnboardingColors.Accent.copy(alpha = 0.16f)),
                    CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "10+",
                color = IOSOnboardingColors.Accent,
                fontSize = 10.sp,
                fontWeight = FontWeight.Black,
            )
        }
    }
}

@Composable
private fun IOSSkillRow(skill: IOSSkillPreview, compact: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = if (compact) 43.dp else 48.dp)
            .padding(horizontal = if (compact) 10.dp else 12.dp, vertical = if (compact) 4.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(if (compact) 36.dp else 40.dp)
                .background(skill.tint.copy(alpha = 0.11f), RoundedCornerShape(8.dp))
                .border(BorderStroke(1.dp, skill.tint.copy(alpha = 0.22f)), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = skill.icon,
                contentDescription = null,
                tint = skill.tint,
                modifier = Modifier.size(if (compact) 16.dp else 18.dp),
            )
        }
        Text(
            text = stringResource(skill.name),
            color = IOSOnboardingColors.TextMain,
            fontSize = if (compact) 14.sp else 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = stringResource(
                if (skill.installed) R.string.onboarding_skills_installed else R.string.onboarding_skills_new,
            ),
            color = if (skill.installed) IOSOnboardingColors.Accent else IOSOnboardingColors.Teal,
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            modifier = Modifier
                .background(
                    if (skill.installed) IOSOnboardingColors.BrandBlueSoft else IOSOnboardingColors.TealSoft,
                    CircleShape,
                )
                .padding(horizontal = 7.dp, vertical = 3.dp),
        )
    }
}

@Composable
private fun IOSBuildYourOwnRow(compact: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .background(Color.White.copy(alpha = 0.90f), RoundedCornerShape(15.dp))
            .border(BorderStroke(1.dp, Color.Black.copy(alpha = 0.05f)), RoundedCornerShape(15.dp))
            .padding(horizontal = 12.dp, vertical = if (compact) 5.dp else 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(40.dp)
                .background(IOSOnboardingColors.TealSoft, RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.AutoAwesome,
                contentDescription = null,
                tint = IOSOnboardingColors.Teal,
                modifier = Modifier.size(18.dp),
            )
        }
        Text(
            text = stringResource(R.string.onboarding_skills_build_your_own),
            color = IOSOnboardingColors.TextMain,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = stringResource(R.string.onboarding_skills_pro),
            color = IOSOnboardingColors.Accent,
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .background(IOSOnboardingColors.BrandBlueSoft, CircleShape)
                .padding(horizontal = 7.dp, vertical = 3.dp),
        )
        Icon(
            Icons.Outlined.AddCircle,
            contentDescription = null,
            tint = IOSOnboardingColors.Accent,
            modifier = Modifier.size(20.dp),
        )
    }
}

private object IOSOnboardingColors {
    val Accent = Color(0xFF2F86FF)
    val BrandBlueSoft = Color(0xFFEEF5FF)
    val Teal = Color(0xFF258C86)
    val TealSoft = Color(0xFFEAF4F2)
    val Background = Color(0xFFF6F5F2)
    val TextMain = Color(0xFF17181B)
    val TextSub = Color(0xFF6B6B73)
}

private object IOSOnboardingTokens {
    val Space24 = 24.dp
}

private fun Modifier.noRippleClick(onClick: () -> Unit): Modifier = this.then(
    Modifier.clickable(
        interactionSource = null,
        indication = null,
        onClick = onClick,
    ),
)
