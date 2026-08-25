package com.sponteoai.chillscript.share

import android.content.Intent
import android.graphics.Color as AndroidColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.data.remote.extractWebUrl
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import kotlinx.coroutines.delay

/**
 * Android's visual counterpart to the iOS Share Extension.
 *
 * It is deliberately a tiny translucent activity, not MainActivity. The
 * sending app remains visible underneath and is revealed again as soon as the
 * durable import has been accepted.
 */
class ShareImportActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = AndroidColor.TRANSPARENT
        window.navigationBarColor = AndroidColor.TRANSPARENT
        setContent {
            ChillScriptTheme {
                ShareImportOverlay(
                    sharedText = intent.sharedText().orEmpty(),
                    onComplete = ::finish,
                )
            }
        }
    }
}

private sealed interface ShareOverlayState {
    data class Working(val stage: ShareLinkImportStage) : ShareOverlayState
    data class Success(val sourceName: String) : ShareOverlayState
    data object Failure : ShareOverlayState
}

@Composable
private fun ShareImportOverlay(
    sharedText: String,
    onComplete: () -> Unit,
) {
    val context = LocalContext.current
    val initialSourceName = remember(sharedText) {
        extractWebUrl(sharedText)?.let { url ->
            runCatching { sourceForUrl(url).platformName.ifBlank { sourceForUrl(url).host } }.getOrNull()
        }.orEmpty()
    }
    var state: ShareOverlayState by remember {
        mutableStateOf(ShareOverlayState.Working(ShareLinkImportStage.ReadingContent))
    }

    LaunchedEffect(sharedText) {
        runCatching {
            ShareLinkImportCoordinator(context).importSharedText(sharedText) { stage ->
                state = ShareOverlayState.Working(stage)
            }
        }.onSuccess { pending ->
            state = ShareOverlayState.Success(
                pending.source.platformName.ifBlank { pending.source.host.ifBlank { initialSourceName } },
            )
            delay(SUCCESS_VISIBILITY_MILLIS)
            onComplete()
        }.onFailure {
            state = ShareOverlayState.Failure
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.24f)),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 560.dp),
            shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp),
            color = ChillColors.BackgroundSecondary,
            shadowElevation = 18.dp,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(12.dp))
                Box(
                    Modifier
                        .size(width = 58.dp, height = 6.dp)
                        .clip(CircleShape)
                        .background(ChillColors.Separator),
                )
                Spacer(Modifier.height(34.dp))
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.onboarding_wordmark),
                    contentDescription = null,
                    modifier = Modifier.height(34.dp),
                    contentScale = ContentScale.Fit,
                )
                Spacer(Modifier.height(28.dp))
                SourcePill(initialSourceName)
                Spacer(Modifier.height(44.dp))
                AnimatedContent(targetState = state, label = "share-import-state") { current ->
                    when (current) {
                        is ShareOverlayState.Working -> WorkingContent(current.stage)
                        is ShareOverlayState.Success -> SuccessContent()
                        ShareOverlayState.Failure -> FailureContent()
                    }
                }
            }
        }
    }
}

@Composable
private fun SourcePill(sourceName: String) {
    if (sourceName.isBlank()) return
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(ChillColors.BrandBlueSoft)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        horizontalArrangement = Arrangement.spacedBy(7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Outlined.Link,
            contentDescription = null,
            tint = ChillColors.BrandBlueText,
            modifier = Modifier.size(17.dp),
        )
        Text(
            text = stringResource(R.string.share_extension_source_format, sourceName),
            color = ChillColors.BrandBlueText,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun WorkingContent(stage: ShareLinkImportStage) {
    val message = when (stage) {
        ShareLinkImportStage.ReadingContent -> stringResource(R.string.share_extension_reading_content)
        ShareLinkImportStage.Saving -> stringResource(R.string.share_extension_saving)
        ShareLinkImportStage.Completed -> stringResource(R.string.share_extension_saved)
    }
    Column(
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(52.dp),
            color = ChillColors.BrandBlue,
            strokeWidth = 5.dp,
        )
        Spacer(Modifier.height(24.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.titleMedium,
            color = ChillColors.TextMain,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(18.dp))
        repeat(3) { index ->
            Box(
                Modifier
                    .padding(top = 9.dp)
                    .fillMaxWidth(if (index == 2) 0.63f else 0.88f)
                    .height(12.dp)
                    .clip(CircleShape)
                    .background(ChillColors.BrandBlueSoft),
            )
        }
    }
}

@Composable
private fun SuccessContent() {
    Column(
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(Color(0xFFE8F6EC), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = null,
                tint = Color(0xFF248A4B),
                modifier = Modifier.size(42.dp),
            )
        }
        Spacer(Modifier.height(22.dp))
        Text(
            text = stringResource(R.string.share_extension_saved),
            color = ChillColors.TextMain,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun FailureContent() {
    Column(
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.share_extension_failed),
            color = ChillColors.TextMain,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.share_extension_no_link),
            color = ChillColors.TextSub,
            fontSize = 15.sp,
        )
    }
}

private fun Intent.sharedText(): String? =
    takeIf { action == Intent.ACTION_SEND && type?.startsWith("text/") == true }
        ?.getCharSequenceExtra(Intent.EXTRA_TEXT)
        ?.toString()

private const val SUCCESS_VISIBILITY_MILLIS = 850L
