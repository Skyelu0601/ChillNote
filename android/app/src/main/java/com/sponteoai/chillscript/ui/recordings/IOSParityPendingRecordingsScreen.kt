package com.sponteoai.chillscript.ui.recordings

import android.media.MediaPlayer
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.voice.PendingRecording
import com.sponteoai.chillscript.voice.PendingRecordingSaveOutcome
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val IOSSystemGreen = Color(0xFF34C759)
private val IOSSystemRed = Color(0xFFFF3B30)
private val IOSSystemGray = Color(0xFF8E8E93)

internal enum class PendingRecordingRowSaveState {
    Idle,
    Saving,
    Saved,
}

internal fun rowStateAfter(
    outcome: PendingRecordingSaveOutcome,
): PendingRecordingRowSaveState = when (outcome) {
    PendingRecordingSaveOutcome.Saved -> PendingRecordingRowSaveState.Saved
    PendingRecordingSaveOutcome.ConsentDeclined,
    PendingRecordingSaveOutcome.Error -> PendingRecordingRowSaveState.Idle
}

private data class PendingRecordingToast(
    val id: Long,
    val text: String,
    val isSuccess: Boolean,
)

/**
 * One-to-one Android port of iOS `PendingRecordingsView`.
 *
 * The screen deliberately owns row state instead of using the app-wide voice-processing flag:
 * iOS allows each pending recording to show its own saving/saved lifecycle independently.
 */
@Composable
fun IOSParityPendingRecordingsScreen(
    recordings: List<PendingRecording>,
    onBack: () -> Unit,
    onSave: (PendingRecording, (PendingRecordingSaveOutcome) -> Unit) -> Unit,
    onDelete: (PendingRecording) -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val displayedRecordings = remember {
        mutableStateListOf<PendingRecording>().apply { addAll(recordings) }
    }
    val rowStates = remember { mutableStateMapOf<String, PendingRecordingRowSaveState>() }
    val rowVisibility = remember { mutableStateMapOf<String, Boolean>() }

    var mediaPlayer by remember { mutableStateOf<MediaPlayer?>(null) }
    var playingPath by remember { mutableStateOf<String?>(null) }
    var alertMessage by remember { mutableStateOf<String?>(null) }
    var toast by remember { mutableStateOf<PendingRecordingToast?>(null) }
    var toastJob by remember { mutableStateOf<Job?>(null) }

    val playbackPrepareError = stringResource(R.string.pending_recordings_error_unable_to_prepare_playback)
    val playbackStartError = stringResource(R.string.pending_recordings_error_unable_to_start_playback)
    val transcriptionError = stringResource(R.string.pending_recordings_error_transcription_failed)
    val noteSavedToast = stringResource(R.string.pending_recordings_toast_note_saved)
    val saveFailedToast = stringResource(R.string.pending_recordings_toast_save_failed)

    fun stopPlayback() {
        val activePlayer = mediaPlayer
        mediaPlayer = null
        playingPath = null
        activePlayer?.let { player ->
            runCatching { player.stop() }
            runCatching { player.release() }
        }
    }

    fun stopPlaybackIfNeeded(path: String) {
        if (playingPath == path) stopPlayback()
    }

    fun showToast(message: String, isSuccess: Boolean = true) {
        toastJob?.cancel()
        toast = PendingRecordingToast(
            id = System.nanoTime(),
            text = message,
            isSuccess = isSuccess,
        )
        toastJob = scope.launch {
            delay(2_500)
            toast = null
        }
    }

    fun removeRowAfterConfirmation(path: String) {
        scope.launch {
            delay(900)
            rowVisibility[path] = false
            delay(400)
            displayedRecordings.removeAll { it.file.absolutePath == path }
            rowStates.remove(path)
            rowVisibility.remove(path)
        }
    }

    fun togglePlayback(recording: PendingRecording) {
        val path = recording.file.absolutePath
        if (playingPath == path) {
            stopPlayback()
            return
        }

        stopPlayback()
        val nextPlayer = MediaPlayer()
        try {
            nextPlayer.setDataSource(path)
            nextPlayer.prepare()
        } catch (_: Throwable) {
            runCatching { nextPlayer.release() }
            alertMessage = playbackPrepareError
            return
        }

        nextPlayer.setOnCompletionListener { completedPlayer ->
            if (mediaPlayer === completedPlayer) {
                mediaPlayer = null
                playingPath = null
            }
            runCatching { completedPlayer.release() }
        }
        nextPlayer.setOnErrorListener { failedPlayer, _, _ ->
            if (mediaPlayer === failedPlayer) {
                mediaPlayer = null
                playingPath = null
            }
            runCatching { failedPlayer.release() }
            alertMessage = playbackStartError
            true
        }

        mediaPlayer = nextPlayer
        playingPath = path
        try {
            nextPlayer.start()
        } catch (_: Throwable) {
            mediaPlayer = null
            playingPath = null
            runCatching { nextPlayer.release() }
            alertMessage = playbackStartError
        }
    }

    LaunchedEffect(recordings.map { it.file.absolutePath }) {
        val incomingByPath = recordings.associateBy { it.file.absolutePath }

        recordings.forEach { incoming ->
            val path = incoming.file.absolutePath
            val existingIndex = displayedRecordings.indexOfFirst { it.file.absolutePath == path }
            if (existingIndex == -1) {
                displayedRecordings.add(incoming)
            } else {
                displayedRecordings[existingIndex] = incoming
            }
            rowVisibility.putIfAbsent(path, true)
        }

        displayedRecordings.removeAll { displayed ->
            val path = displayed.file.absolutePath
            path !in incomingByPath &&
                rowStates[path] == null &&
                rowVisibility[path] != false
        }
        displayedRecordings.sortByDescending { it.createdAt }
    }

    DisposableEffect(Unit) {
        onDispose {
            toastJob?.cancel()
            stopPlayback()
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding(),
        ) {
            PendingRecordingsNavigationBar(onBack = onBack)

            Box(modifier = Modifier.fillMaxSize()) {
                if (displayedRecordings.isEmpty()) {
                    PendingRecordingsEmptyState()
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 20.dp),
                        contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
                    ) {
                        items(
                            items = displayedRecordings,
                            key = { it.file.absolutePath },
                        ) { recording ->
                            val path = recording.file.absolutePath
                            val state = rowStates[path] ?: PendingRecordingRowSaveState.Idle
                            androidx.compose.animation.AnimatedVisibility(
                                visible = rowVisibility[path] != false,
                                enter = fadeIn(tween(220)) + slideInVertically(
                                    animationSpec = spring(
                                        dampingRatio = Spring.DampingRatioMediumBouncy,
                                        stiffness = Spring.StiffnessMediumLow,
                                    ),
                                ) { -it / 3 },
                                exit = fadeOut(tween(260)) + scaleOut(
                                    targetScale = 0.95f,
                                    animationSpec = tween(300),
                                ),
                            ) {
                                PendingRecordingRow(
                                    recording = recording,
                                    state = state,
                                    isPlaying = playingPath == path,
                                    onTogglePlayback = { togglePlayback(recording) },
                                    onDelete = {
                                        if (state == PendingRecordingRowSaveState.Idle) {
                                            stopPlaybackIfNeeded(path)
                                            rowVisibility[path] = false
                                            onDelete(recording)
                                            scope.launch {
                                                delay(400)
                                                displayedRecordings.removeAll { it.file.absolutePath == path }
                                                rowStates.remove(path)
                                                rowVisibility.remove(path)
                                            }
                                        }
                                    },
                                    onSave = {
                                        if (state == PendingRecordingRowSaveState.Idle) {
                                            stopPlaybackIfNeeded(path)
                                            rowStates[path] = PendingRecordingRowSaveState.Saving
                                            onSave(recording) { outcome ->
                                                scope.launch {
                                                    rowStates[path] = rowStateAfter(outcome)
                                                    when (outcome) {
                                                        PendingRecordingSaveOutcome.Saved -> {
                                                            showToast(noteSavedToast)
                                                            removeRowAfterConfirmation(path)
                                                        }

                                                        PendingRecordingSaveOutcome.ConsentDeclined -> Unit

                                                        PendingRecordingSaveOutcome.Error -> {
                                                            alertMessage = transcriptionError
                                                            showToast(saveFailedToast, isSuccess = false)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    },
                                )
                            }
                        }
                    }
                }

                androidx.compose.animation.AnimatedVisibility(
                    visible = toast != null,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 8.dp),
                    enter = slideInVertically(
                        animationSpec = spring(
                            dampingRatio = Spring.DampingRatioMediumBouncy,
                            stiffness = Spring.StiffnessMediumLow,
                        ),
                    ) { -it } + fadeIn(),
                    exit = slideOutVertically(tween(220)) { -it } + fadeOut(tween(220)),
                ) {
                    toast?.let { message -> PendingRecordingToastView(message) }
                }
            }
        }
    }

    alertMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { alertMessage = null },
            title = {
                Text(
                    text = stringResource(R.string.transcription_failure_title),
                    color = ChillColors.TextMain,
                )
            },
            text = {
                Text(
                    text = message,
                    color = ChillColors.TextSub,
                )
            },
            confirmButton = {
                TextButton(onClick = { alertMessage = null }) {
                    Text(stringResource(R.string.common_ok))
                }
            },
            containerColor = ChillColors.BackgroundSecondary,
        )
    }
}

@Composable
private fun PendingRecordingsNavigationBar(onBack: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp),
    ) {
        Text(
            text = stringResource(R.string.common_close),
            color = ChillColors.BrandBlue,
            fontSize = 17.sp,
            lineHeight = 22.sp,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .iosPlainClickable(
                    onClick = onBack,
                    role = Role.Button,
                    contentDescription = stringResource(R.string.common_close),
                )
                .padding(horizontal = 16.dp, vertical = 11.dp),
        )

        Text(
            text = stringResource(R.string.pending_recordings_title),
            color = ChillColors.TextMain,
            fontSize = 17.sp,
            lineHeight = 22.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.align(Alignment.Center),
        )
    }
}

@Composable
private fun PendingRecordingsEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(top = 40.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Outlined.GraphicEq,
            contentDescription = null,
            tint = ChillColors.TextSub.copy(alpha = 0.6f),
            modifier = Modifier.size(44.dp),
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.pending_recordings_empty),
            color = ChillColors.TextSub,
            fontSize = 16.sp,
            lineHeight = 21.sp,
        )
    }
}

@Composable
private fun PendingRecordingRow(
    recording: PendingRecording,
    state: PendingRecordingRowSaveState,
    isPlaying: Boolean,
    onTogglePlayback: () -> Unit,
    onDelete: () -> Unit,
    onSave: () -> Unit,
) {
    val isIdle = state == PendingRecordingRowSaveState.Idle
    val isSaved = state == PendingRecordingRowSaveState.Saved
    val cardColor = if (isSaved) IOSSystemGreen.copy(alpha = 0.06f) else ChillColors.BackgroundSecondary
    val borderColor = if (isSaved) IOSSystemGreen.copy(alpha = 0.30f) else IOSSystemGray.copy(alpha = 0.10f)
    val borderWidth by animateDpAsState(
        targetValue = if (isSaved) 1.5.dp else 1.dp,
        animationSpec = tween(250),
        label = "pending recording border",
    )
    val shape = RoundedCornerShape(16.dp)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .background(cardColor, shape)
            .border(borderWidth, borderColor, shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val playbackLabel = stringResource(
                if (isPlaying) R.string.pending_recordings_pause else R.string.pending_recordings_play,
            )
            Icon(
                imageVector = if (isPlaying) Icons.Filled.PauseCircle else Icons.Filled.PlayCircle,
                contentDescription = null,
                tint = if (isPlaying) ChillColors.BrandBlue else ChillColors.TextSub,
                modifier = Modifier
                    .size(36.dp)
                    .alpha(if (isIdle) 1f else 0.45f)
                    .iosPlainClickable(
                        enabled = isIdle,
                        onClick = onTogglePlayback,
                        role = Role.Button,
                        contentDescription = playbackLabel,
                    )
                    .padding(4.dp),
            )

            Text(
                text = recording.durationText,
                color = ChillColors.TextMain,
                fontSize = 16.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.SemiBold,
            )

            Spacer(modifier = Modifier.weight(1f))
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.common_delete),
                color = IOSSystemRed.copy(alpha = 0.85f),
                fontSize = 15.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .alpha(if (isIdle) 1f else 0.45f)
                    .clip(RoundedCornerShape(10.dp))
                    .background(IOSSystemRed.copy(alpha = 0.08f))
                    .iosPlainClickable(
                        enabled = isIdle,
                        onClick = onDelete,
                        role = Role.Button,
                        contentDescription = stringResource(R.string.common_delete),
                    )
                    .padding(horizontal = 18.dp, vertical = 10.dp),
            )

            PendingRecordingSaveButton(
                state = state,
                onSave = onSave,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PendingRecordingSaveButton(
    state: PendingRecordingRowSaveState,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AnimatedContent(
        targetState = state,
        modifier = modifier,
        transitionSpec = {
            (if (targetState == PendingRecordingRowSaveState.Saved) {
                (scaleIn(tween(220), initialScale = 0.9f) + fadeIn(tween(220))) togetherWith
                    fadeOut(tween(120))
            } else {
                fadeIn(tween(160)) togetherWith fadeOut(tween(120))
            }).using(SizeTransform(clip = false))
        },
        label = "pending recording save state",
    ) { currentState ->
        when (currentState) {
            PendingRecordingRowSaveState.Idle -> PendingRecordingActionSurface(
                background = ChillColors.BrandBlue,
                onClick = onSave,
                contentDescription = stringResource(R.string.pending_recordings_save_as_note),
            ) {
                Text(
                    text = stringResource(R.string.pending_recordings_save_as_note),
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            PendingRecordingRowSaveState.Saving -> PendingRecordingActionSurface(
                background = IOSSystemGray.copy(alpha = 0.45f),
                onClick = {},
                enabled = false,
                contentDescription = stringResource(R.string.pending_recordings_saving),
            ) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = stringResource(R.string.pending_recordings_saving),
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            PendingRecordingRowSaveState.Saved -> PendingRecordingActionSurface(
                background = IOSSystemGreen.copy(alpha = 0.85f),
                onClick = {},
                enabled = false,
                contentDescription = stringResource(R.string.pending_recordings_saved),
            ) {
                Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = stringResource(R.string.pending_recordings_saved),
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun PendingRecordingActionSurface(
    background: Color,
    onClick: () -> Unit,
    contentDescription: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(background)
            .iosPlainClickable(
                enabled = enabled,
                onClick = onClick,
                role = Role.Button,
                contentDescription = contentDescription,
            )
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
private fun PendingRecordingToastView(toast: PendingRecordingToast) {
    Row(
        modifier = Modifier
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(20.dp),
                ambientColor = Color.Black.copy(alpha = 0.12f),
                spotColor = Color.Black.copy(alpha = 0.12f),
            )
            .background(ChillColors.BackgroundSecondary, RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = if (toast.isSuccess) Icons.Filled.CheckCircle else Icons.Filled.Cancel,
            contentDescription = null,
            tint = if (toast.isSuccess) IOSSystemGreen else IOSSystemRed,
            modifier = Modifier.size(15.dp),
        )
        Text(
            text = toast.text,
            color = ChillColors.TextMain,
            fontSize = 15.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun Modifier.iosPlainClickable(
    enabled: Boolean = true,
    onClick: () -> Unit,
    role: Role,
    contentDescription: String,
): Modifier {
    val interactionSource = remember { MutableInteractionSource() }
    return semantics {
        this.contentDescription = contentDescription
        this.role = role
    }.clickable(
        enabled = enabled,
        interactionSource = interactionSource,
        indication = null,
        role = role,
        onClick = onClick,
    )
}
