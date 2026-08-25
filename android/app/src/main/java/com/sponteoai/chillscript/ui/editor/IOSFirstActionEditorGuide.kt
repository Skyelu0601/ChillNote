package com.sponteoai.chillscript.ui.editor

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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

/** Mirrors iOS `FirstActionTranscriptReviewPromptView`. */
@Composable
internal fun IOSFirstActionTranscriptReviewPrompt(
    onContinue: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .shadow(10.dp, RoundedCornerShape(20.dp), ambientColor = Color.Black.copy(alpha = 0.08f))
            .background(Color.White, RoundedCornerShape(20.dp))
            .border(1.dp, ChillColors.BorderSubtle, RoundedCornerShape(20.dp))
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stringResource(R.string.onboarding_first_action_step_progress, 3, 7),
                    color = ChillColors.BrandBlue,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    stringResource(R.string.onboarding_first_action_transcript_review_title),
                    color = ChillColors.TextMain,
                    fontSize = 18.sp,
                    lineHeight = 23.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = onDismiss, modifier = Modifier.size(44.dp)) {
                Icon(
                    Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.common_skip),
                    tint = ChillColors.TextSub,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        Row(
            Modifier
                .fillMaxWidth()
                .height(48.dp)
                .background(ChillColors.BrandBlue, RoundedCornerShape(12.dp))
                .clickable(onClick = onContinue),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.onboarding_first_action_transcript_review_action),
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.width(7.dp))
            Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null, tint = Color.White, modifier = Modifier.size(15.dp))
        }
    }
}

/** Cut-out spotlight and guide bubble matching iOS steps 4–7. */
@Composable
internal fun IOSFirstActionEditorSpotlight(
    targetBounds: Rect,
    message: String,
    step: Int,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val accessibilityMessage = stringResource(R.string.onboarding_first_action_step_progress, step, 7) + ". " + message
    val pulseScale = remember(targetBounds, step) { Animatable(1f) }
    LaunchedEffect(targetBounds, step) {
        repeat(2) {
            pulseScale.animateTo(1.025f, tween(750))
            pulseScale.animateTo(1f, tween(750))
        }
    }
    BoxWithConstraints(modifier.fillMaxSize().semantics { contentDescription = accessibilityMessage }) {
        val expansionPx = with(density) { 5.dp.toPx() }
        val leftPx = (targetBounds.left - expansionPx).coerceAtLeast(0f)
        val topPx = (targetBounds.top - expansionPx).coerceAtLeast(0f)
        val rightPx = (targetBounds.right + expansionPx).coerceAtMost(constraints.maxWidth.toFloat())
        val bottomPx = (targetBounds.bottom + expansionPx).coerceAtMost(constraints.maxHeight.toFloat())
        val left = with(density) { leftPx.toDp() }
        val top = with(density) { topPx.toDp() }
        val right = with(density) { rightPx.toDp() }
        val bottom = with(density) { bottomPx.toDp() }
        val targetWidth = (right - left).coerceAtLeast(1.dp)
        val targetHeight = (bottom - top).coerceAtLeast(1.dp)
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
                cornerRadius = CornerRadius((bottomPx - topPx) / 2f),
                blendMode = BlendMode.Clear,
            )
        }
        Box(
            Modifier
                .offset(x = left, y = top)
                .width(targetWidth)
                .height(targetHeight)
                .graphicsLayer { scaleX = pulseScale.value; scaleY = pulseScale.value }
                .border(3.dp, ChillColors.BrandBlue, CircleShape),
        )

        val preferredWidth = if (step == 4) 310.dp else 340.dp
        val bubbleWidth = preferredWidth.coerceAtMost((screenWidth - 32.dp).coerceAtLeast(1.dp))
        val bubbleHeight = 94.dp
        val targetCenter = left + targetWidth / 2
        val bubbleLeft = (targetCenter - bubbleWidth / 2).coerceIn(16.dp, (screenWidth - bubbleWidth - 16.dp).coerceAtLeast(16.dp))
        val belowTop = bottom + 18.dp
        val aboveTop = top - 18.dp - bubbleHeight
        val bubbleTop = if (belowTop + bubbleHeight <= screenHeight - 32.dp) belowTop else aboveTop.coerceAtLeast(70.dp)

        Column(
            Modifier
                .offset(x = bubbleLeft, y = bubbleTop)
                .width(bubbleWidth)
                .heightIn(min = 64.dp)
                .shadow(10.dp, RoundedCornerShape(14.dp), ambientColor = Color.Black.copy(alpha = 0.10f))
                .background(Color.White, RoundedCornerShape(14.dp))
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                stringResource(R.string.onboarding_first_action_step_progress, step, 7),
                color = ChillColors.BrandBlue,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(message, color = ChillColors.TextMain, fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold)
        }

        Text(
            stringResource(R.string.common_skip),
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = 16.dp, bottom = 24.dp)
                .background(Color.Black.copy(alpha = 0.50f), CircleShape)
                .clickable(onClick = onDismiss)
                .padding(horizontal = 14.dp, vertical = 9.dp),
        )
    }
}
