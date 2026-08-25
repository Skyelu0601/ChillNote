package com.sponteoai.chillscript.ui.home

import android.content.Context
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.theme.ChillRadius
import java.time.Duration
import java.time.Instant

enum class HomeFirstActionStage {
    Inactive,
    SharePrompt,
    AwaitingShare,
    WaitingForImport,
    OpenImportedNote,
    ReviewTranscript,
    TapCreateTab,
    TapAISkills,
    WaitingForAISkillsDismissal,
    TapRecordTab,
    TapTeleprompter,
    Completed,
    Dismissed,
}

data class HomeFirstActionGuideState(
    val stage: HomeFirstActionStage = HomeFirstActionStage.Inactive,
    val targetNoteId: String? = null,
    val shareAcknowledgedAt: String? = null,
)

/** Per-account persistence matching the iOS first-action guide's Home stages. */
class HomeFirstActionGuideStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "home_first_action_guide",
        Context.MODE_PRIVATE,
    )

    fun configure(userId: String?, accountCreatedAt: String?): HomeFirstActionGuideState {
        if (userId.isNullOrBlank()) return HomeFirstActionGuideState()
        val stored = preferences.getString(stageKey(userId), null)
        val stage = stored?.let { value ->
            HomeFirstActionStage.entries.firstOrNull { it.name == value }
        } ?: if (isFreshAccount(accountCreatedAt)) HomeFirstActionStage.SharePrompt else HomeFirstActionStage.Inactive
        return persist(
            userId,
            HomeFirstActionGuideState(
                stage = stage,
                targetNoteId = preferences.getString(noteKey(userId), null),
                shareAcknowledgedAt = preferences.getString(shareAcknowledgedAtKey(userId), null),
            ),
        )
    }

    fun acknowledgeShare(userId: String, state: HomeFirstActionGuideState) =
        if (state.stage == HomeFirstActionStage.SharePrompt) {
            persist(
                userId,
                state.copy(
                    stage = HomeFirstActionStage.AwaitingShare,
                    shareAcknowledgedAt = state.shareAcknowledgedAt ?: Instant.now().toString(),
                ),
            )
        } else state

    fun registerImport(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        if (state.stage == HomeFirstActionStage.SharePrompt || state.stage == HomeFirstActionStage.AwaitingShare) {
            persist(userId, HomeFirstActionGuideState(HomeFirstActionStage.WaitingForImport, noteId))
        } else state

    fun updateImport(userId: String, state: HomeFirstActionGuideState, importStatus: String?): HomeFirstActionGuideState {
        if (state.stage != HomeFirstActionStage.WaitingForImport || state.targetNoteId == null) return state
        return when (importStatus) {
            "completed" -> persist(userId, state.copy(stage = HomeFirstActionStage.OpenImportedNote))
            "failed" -> persist(userId, HomeFirstActionGuideState(HomeFirstActionStage.SharePrompt))
            else -> state
        }
    }

    fun markImportedNoteOpened(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        if (state.stage == HomeFirstActionStage.OpenImportedNote && state.targetNoteId == noteId) {
            persist(userId, state.copy(stage = HomeFirstActionStage.ReviewTranscript))
        } else state

    fun markTranscriptReviewed(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.ReviewTranscript, HomeFirstActionStage.TapCreateTab)

    fun markCreateTabTapped(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.TapCreateTab, HomeFirstActionStage.TapAISkills)

    fun markAISkillsTapped(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.TapAISkills, HomeFirstActionStage.WaitingForAISkillsDismissal)

    fun markAISkillsFlowDismissed(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.WaitingForAISkillsDismissal, HomeFirstActionStage.TapRecordTab)

    fun markRecordTabTapped(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.TapRecordTab, HomeFirstActionStage.TapTeleprompter)

    fun markTeleprompterTapped(userId: String, state: HomeFirstActionGuideState, noteId: String) =
        transitionForTarget(userId, state, noteId, HomeFirstActionStage.TapTeleprompter, HomeFirstActionStage.Completed)

    fun dismiss(userId: String) = persist(userId, HomeFirstActionGuideState(HomeFirstActionStage.Dismissed))

    private fun persist(userId: String, state: HomeFirstActionGuideState): HomeFirstActionGuideState {
        preferences.edit()
            .putString(stageKey(userId), state.stage.name)
            .apply {
                if (state.targetNoteId == null) remove(noteKey(userId)) else putString(noteKey(userId), state.targetNoteId)
                if (state.shareAcknowledgedAt == null) {
                    remove(shareAcknowledgedAtKey(userId))
                } else {
                    putString(shareAcknowledgedAtKey(userId), state.shareAcknowledgedAt)
                }
            }
            .apply()
        return state
    }

    private fun transitionForTarget(
        userId: String,
        state: HomeFirstActionGuideState,
        noteId: String,
        expected: HomeFirstActionStage,
        next: HomeFirstActionStage,
    ): HomeFirstActionGuideState =
        if (state.stage == expected && state.targetNoteId == noteId) {
            persist(userId, state.copy(stage = next))
        } else state

    private fun isFreshAccount(rawCreatedAt: String?): Boolean {
        val createdAt = rawCreatedAt?.let { runCatching { Instant.parse(it) }.getOrNull() } ?: return false
        val age = Duration.between(createdAt, Instant.now())
        return !age.isNegative && age <= Duration.ofHours(24)
    }

    private fun stageKey(userId: String) = "onboarding.firstAction.stage.$userId"
    private fun noteKey(userId: String) = "onboarding.firstAction.note.$userId"
    private fun shareAcknowledgedAtKey(userId: String) = "onboarding.firstAction.shareAcknowledgedAt.$userId"
}

@Composable
internal fun IOSFirstActionSharePrompt(
    onAcknowledge: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val accessibilityMessage = stringResource(R.string.onboarding_first_action_share_message)
    Column(
        modifier
            .padding(horizontal = 16.dp)
            .shadow(10.dp, RoundedCornerShape(ChillRadius.Card), ambientColor = Color.Black.copy(alpha = 0.04f))
            .background(ChillColors.CardBackground, RoundedCornerShape(ChillRadius.Card))
            .border(1.dp, ChillColors.BorderSubtle, RoundedCornerShape(ChillRadius.Card))
            .semantics { contentDescription = accessibilityMessage }
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(R.string.onboarding_first_action_step_progress, 1, 7),
                    color = ChillColors.BrandBlue,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    stringResource(R.string.onboarding_first_action_share_title),
                    color = ChillColors.TextMain,
                    fontSize = 20.sp,
                    lineHeight = 25.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = onDismiss, modifier = Modifier.size(44.dp)) {
                Icon(
                    Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.common_skip),
                    tint = ChillColors.TextSub,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            GuideInstruction(
                icon = Icons.Outlined.Share,
                iconTint = ChillColors.BrandBlue,
                iconBackground = ChillColors.BrandBlueSoft,
                text = stringResource(R.string.onboarding_first_action_share_instruction_share),
            )
            Box(
                Modifier
                    .padding(start = 22.dp)
                    .width(1.dp)
                    .height(10.dp)
                    .background(ChillColors.Separator),
            )
            GuideInstruction(
                icon = Icons.Outlined.Archive,
                iconTint = ChillColors.TextMain,
                iconBackground = ChillColors.BackgroundPrimary,
                text = stringResource(R.string.onboarding_first_action_share_instruction_choose),
            )
        }
        Row(
            Modifier
                .fillMaxWidth()
                .height(48.dp)
                .background(ChillColors.BrandBlue, RoundedCornerShape(12.dp))
                .clickable(onClick = onAcknowledge),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.onboarding_first_action_share_action),
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.width(7.dp))
            Icon(
                Icons.AutoMirrored.Outlined.ArrowForward,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(15.dp),
            )
        }
    }
}

@Composable
private fun GuideInstruction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    iconBackground: Color,
    text: String,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(Modifier.size(44.dp).background(iconBackground, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(18.dp))
        }
        Text(
            text,
            color = ChillColors.TextMain,
            fontSize = 15.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
internal fun IOSFirstActionImportedNoteSpotlight(
    targetBounds: Rect,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val pulseScale = remember { Animatable(1f) }
    LaunchedEffect(targetBounds) {
        repeat(2) {
            pulseScale.animateTo(1.025f, tween(750))
            pulseScale.animateTo(1f, tween(750))
        }
    }
    BoxWithConstraints(modifier.fillMaxSize()) {
        val insetPx = with(density) { 8.dp.toPx() }
        val leftPx = (targetBounds.left - insetPx).coerceAtLeast(0f)
        val topPx = (targetBounds.top - insetPx).coerceAtLeast(0f)
        val rightPx = (targetBounds.right + insetPx).coerceAtMost(constraints.maxWidth.toFloat())
        val bottomPx = (targetBounds.bottom + insetPx).coerceAtMost(constraints.maxHeight.toFloat())
        val left = with(density) { leftPx.toDp() }
        val top = with(density) { topPx.toDp() }
        val right = with(density) { rightPx.toDp() }
        val bottom = with(density) { bottomPx.toDp() }
        val screenWidth = with(density) { constraints.maxWidth.toDp() }
        val screenHeight = with(density) { constraints.maxHeight.toDp() }
        val mask = Color.Black.copy(alpha = 0.42f)

        Canvas(
            Modifier
                .fillMaxSize()
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen },
        ) {
            drawRect(mask)
            drawRoundRect(
                color = Color.Transparent,
                topLeft = Offset(leftPx, topPx),
                size = Size(rightPx - leftPx, bottomPx - topPx),
                cornerRadius = CornerRadius(20.dp.toPx()),
                blendMode = BlendMode.Clear,
            )
        }
        Box(
            Modifier.offset(x = left, y = top)
                .width((right - left).coerceAtLeast(0.dp))
                .height((bottom - top).coerceAtLeast(0.dp))
                .graphicsLayer { scaleX = pulseScale.value; scaleY = pulseScale.value }
                .border(3.dp, ChillColors.BrandBlue, RoundedCornerShape(20.dp)),
        )

        val bubbleWidth = 340.dp.coerceAtMost((screenWidth - 32.dp).coerceAtLeast(1.dp))
        val bubbleHeight = 94.dp
        val targetCenter = left + (right - left) / 2
        val bubbleLeft = (targetCenter - bubbleWidth / 2)
            .coerceIn(16.dp, (screenWidth - bubbleWidth - 16.dp).coerceAtLeast(16.dp))
        val belowTop = bottom + 18.dp
        val aboveTop = top - 18.dp - bubbleHeight
        val bubbleTop = if (belowTop + bubbleHeight <= screenHeight - 32.dp) belowTop else aboveTop.coerceAtLeast(70.dp)

        Column(
            Modifier
                .offset(x = bubbleLeft, y = bubbleTop)
                .width(bubbleWidth)
                .shadow(10.dp, RoundedCornerShape(14.dp), ambientColor = Color.Black.copy(alpha = 0.10f))
                .background(ChillColors.CardBackground, RoundedCornerShape(14.dp))
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                stringResource(R.string.onboarding_first_action_step_progress, 2, 7),
                color = ChillColors.BrandBlue,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                stringResource(R.string.onboarding_first_action_open_note),
                color = ChillColors.TextMain,
                fontSize = 15.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }

        Text(
            stringResource(R.string.common_skip),
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 22.dp, bottom = 28.dp)
                .background(Color.Black.copy(alpha = 0.34f), CircleShape)
                .clickable(onClick = onDismiss)
                .padding(horizontal = 16.dp, vertical = 9.dp),
        )
    }
}
