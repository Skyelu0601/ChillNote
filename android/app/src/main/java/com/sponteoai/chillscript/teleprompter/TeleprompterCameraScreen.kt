package com.sponteoai.chillscript.teleprompter

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.video.Quality
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Cameraswitch
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.sponteoai.chillscript.R
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun TeleprompterCameraScreen(initialScript: String, onClose: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val controller = remember { TeleprompterCameraController(context, lifecycleOwner) }
    val scope = rememberCoroutineScope()
    var script by remember { mutableStateOf(initialScript.trim()) }
    var speed by remember { mutableFloatStateOf(24f) }
    var fontSize by remember { mutableFloatStateOf(24f) }
    var textColor by remember { mutableStateOf(Color.White) }
    var showSettings by remember { mutableStateOf(false) }
    var showScriptEditor by remember { mutableStateOf(false) }
    var countdownSeconds by remember { mutableIntStateOf(3) }
    var countdownValue by remember { mutableStateOf<Int?>(null) }
    var countdownJob by remember { mutableStateOf<Job?>(null) }
    var permissionDenied by remember { mutableStateOf(false) }
    var saveMessage by remember { mutableStateOf<String?>(null) }
    var pendingSaveFile by remember { mutableStateOf<java.io.File?>(null) }
    val scrollState = rememberScrollState()
    val savedText = stringResource(R.string.teleprompter_preview_saved)
    val saveFailedText = stringResource(R.string.teleprompter_preview_save_failed)
    val permissions = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        permissionDenied = permissions.any { result[it] != true }
        if (!permissionDenied) controller.onPermissionsGranted()
    }
    val storagePermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val file = pendingSaveFile
        pendingSaveFile = null
        saveMessage = if (granted && file != null && TeleprompterVideoFiles.saveToGallery(context, file)) savedText else saveFailedText
    }

    LaunchedEffect(Unit) {
        if (permissions.any { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }) {
            permissionLauncher.launch(permissions)
        }
    }
    LaunchedEffect(controller.isRecording, speed) {
        while (controller.isRecording) {
            delay(100)
            scrollState.scrollBy(speed * 0.12f)
        }
    }
    DisposableEffect(controller) { onDispose { countdownJob?.cancel(); controller.cleanup() } }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(
            factory = { PreviewView(it).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }.also(controller::attach) },
            modifier = Modifier.fillMaxSize(),
        )
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.fillMaxWidth().padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircleButton(onClick = onClose) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back), tint = Color.White) }
                Spacer(Modifier.weight(1f))
                if (controller.isRecording) Text(formatDuration(controller.recordedMillis), color = Color.White, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                CircleButton(onClick = controller::switchCamera, enabled = !controller.isRecording) {
                    Icon(Icons.Outlined.Cameraswitch, stringResource(R.string.teleprompter_camera_switch), tint = Color.White)
                }
                CircleButton(onClick = { showSettings = !showSettings }, enabled = !controller.isRecording) {
                    Icon(Icons.Outlined.CameraAlt, stringResource(R.string.teleprompter_action_prompt_settings), tint = Color.White)
                }
            }
            if (showSettings) CameraAndPromptSettings(
                speed = speed, onSpeed = { speed = it },
                fontSize = fontSize, onFontSize = { fontSize = it },
                textColor = textColor, onTextColor = { textColor = it },
                countdownSeconds = countdownSeconds, onCountdown = { countdownSeconds = it },
                quality = controller.quality, onQuality = controller::updateQuality,
            )
            Spacer(Modifier.weight(0.15f))
            Surface(
                color = Color.Black.copy(alpha = 0.62f),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth().height(260.dp).padding(horizontal = 16.dp),
            ) {
                Box {
                    Text(
                        script.ifBlank { stringResource(R.string.teleprompter_script_empty_placeholder) },
                        color = textColor,
                        fontSize = fontSize.sp,
                        lineHeight = (fontSize * 1.45f).sp,
                        modifier = Modifier.fillMaxSize().verticalScroll(scrollState).padding(20.dp, 54.dp, 20.dp, 180.dp),
                    )
                    IconButton(onClick = { showScriptEditor = true }, modifier = Modifier.align(Alignment.TopEnd)) {
                        Icon(Icons.Outlined.Edit, stringResource(R.string.teleprompter_action_edit_script), tint = Color.White)
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            if (controller.clips.isNotEmpty()) LazyRow(
                Modifier.fillMaxWidth().padding(horizontal = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                itemsIndexed(controller.clips, key = { _, clip -> clip.id }) { index, clip ->
                    Surface(color = Color.Black.copy(alpha = 0.7f), shape = RoundedCornerShape(10.dp)) {
                        Column(Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(stringResource(R.string.teleprompter_clip_format, index + 1, formatDuration(clip.durationMillis)), color = Color.White)
                            Row {
                                IconButton(onClick = { controller.moveClip(index, index - 1) }, enabled = index > 0) {
                                    Icon(
                                        Icons.AutoMirrored.Outlined.ArrowBack,
                                        stringResource(R.string.teleprompter_clip_move_left),
                                        tint = Color.White,
                                    )
                                }
                                IconButton(onClick = { controller.removeClip(clip) }) { Icon(Icons.Outlined.Delete, stringResource(R.string.teleprompter_clip_delete), tint = Color.White) }
                                IconButton(onClick = { controller.moveClip(index, index + 1) }, enabled = index < controller.clips.lastIndex) {
                                    Icon(
                                        Icons.AutoMirrored.Outlined.ArrowForward,
                                        stringResource(R.string.teleprompter_clip_move_right),
                                        tint = Color.White,
                                    )
                                }
                            }
                        }
                    }
                }
            }
            controller.exportedFile?.let { file ->
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { TeleprompterVideoFiles.preview(context, file) }, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.teleprompter_action_preview)) }
                    Button(onClick = {
                        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
                            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingSaveFile = file
                            storagePermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        } else {
                            saveMessage = if (TeleprompterVideoFiles.saveToGallery(context, file)) savedText else saveFailedText
                        }
                    }, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.teleprompter_preview_save_to_gallery)) }
                    IconButton(onClick = { TeleprompterVideoFiles.share(context, file) }) { Icon(Icons.Outlined.Share, stringResource(R.string.teleprompter_preview_share), tint = Color.White) }
                }
            }
            if (controller.exporting) Row(
                Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) { CircularProgressIndicator(); Spacer(Modifier.width(8.dp)); Text(stringResource(R.string.teleprompter_export_processing), color = Color.White) }
            saveMessage?.let { Text(it, color = Color.White, modifier = Modifier.align(Alignment.CenterHorizontally).padding(6.dp)) }
            Row(
                Modifier.fillMaxWidth().padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                if (controller.clips.isNotEmpty() && !controller.isRecording) Button(
                    onClick = { scope.launch { controller.export() } }, enabled = !controller.exporting,
                ) { Text(stringResource(R.string.teleprompter_action_preview)) }
                Spacer(Modifier.width(24.dp))
                IconButton(
                    onClick = {
                        if (countdownJob?.isActive == true) {
                            countdownJob?.cancel(); countdownJob = null; countdownValue = null
                        } else if (controller.isRecording) controller.stopRecording() else {
                            countdownJob = scope.launch {
                                for (value in countdownSeconds downTo 1) { countdownValue = value; delay(1_000) }
                                countdownValue = null
                                scrollState.scrollTo(0)
                                controller.startRecording()
                            }
                        }
                    },
                    modifier = Modifier.size(78.dp).background(Color.White, CircleShape),
                ) {
                    Icon(
                        if (controller.isRecording || countdownJob?.isActive == true) Icons.Outlined.Stop else Icons.Outlined.CameraAlt,
                        stringResource(if (controller.isRecording) R.string.teleprompter_stop_recording else R.string.teleprompter_start_recording),
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(34.dp),
                    )
                }
            }
        }
        countdownValue?.let { value ->
            Text(value.toString(), color = Color.White, fontSize = 92.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
    }
    if (showScriptEditor) AlertDialog(
        onDismissRequest = { showScriptEditor = false },
        title = { Text(stringResource(R.string.teleprompter_action_edit_script)) },
        text = { OutlinedTextField(script, { script = it }, minLines = 10, modifier = Modifier.fillMaxWidth()) },
        confirmButton = { TextButton(onClick = { showScriptEditor = false }) { Text(stringResource(R.string.common_done)) } },
    )
    if (permissionDenied) AlertDialog(
        onDismissRequest = onClose,
        title = { Text(stringResource(R.string.teleprompter_permission_title)) },
        text = { Text(stringResource(R.string.teleprompter_permission_message)) },
        confirmButton = { TextButton(onClick = {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
        }) { Text(stringResource(R.string.teleprompter_permission_open_settings)) } },
        dismissButton = { TextButton(onClick = onClose) { Text(stringResource(R.string.common_cancel)) } },
    )
    controller.errorMessage?.let { error ->
        AlertDialog(
            onDismissRequest = { controller.errorMessage = null },
            title = { Text(stringResource(R.string.teleprompter_title)) },
            text = { Text(error) },
            confirmButton = { TextButton(onClick = { controller.errorMessage = null }) { Text(stringResource(R.string.common_close)) } },
        )
    }
}

@Composable
private fun CameraAndPromptSettings(
    speed: Float, onSpeed: (Float) -> Unit,
    fontSize: Float, onFontSize: (Float) -> Unit,
    textColor: Color, onTextColor: (Color) -> Unit,
    countdownSeconds: Int, onCountdown: (Int) -> Unit,
    quality: Quality, onQuality: (Quality) -> Unit,
) {
    Surface(color = Color.Black.copy(alpha = 0.72f), shape = RoundedCornerShape(12.dp), modifier = Modifier.padding(horizontal = 16.dp)) {
        Column(Modifier.padding(12.dp)) {
            Text(stringResource(R.string.teleprompter_prompt_speed), color = Color.White)
            Slider(speed, onSpeed, valueRange = 0f..50f)
            Text(stringResource(R.string.teleprompter_prompt_font_size), color = Color.White)
            Slider(fontSize, onFontSize, valueRange = 16f..36f)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                item { Text(stringResource(R.string.teleprompter_camera_countdown), color = Color.White, modifier = Modifier.padding(top = 10.dp)) }
                itemsIndexed(listOf(0, 3, 5)) { _, seconds ->
                    FilterChip(seconds == countdownSeconds, { onCountdown(seconds) }, { Text(stringResource(when (seconds) {
                        0 -> R.string.teleprompter_countdown_none
                        3 -> R.string.teleprompter_countdown_three
                        else -> R.string.teleprompter_countdown_five
                    })) })
                }
                item { Text(stringResource(R.string.teleprompter_camera_resolution), color = Color.White, modifier = Modifier.padding(top = 10.dp)) }
                itemsIndexed(listOf(Quality.HD, Quality.FHD)) { _, option ->
                    FilterChip(option == quality, { onQuality(option) }, { Text(if (option == Quality.HD) "720p" else "1080p") })
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.teleprompter_prompt_text_color), color = Color.White)
                listOf(Color.White, Color.Yellow, Color.Cyan).forEach { option ->
                    IconButton(onClick = { onTextColor(option) }) {
                        Box(Modifier.size(if (textColor == option) 30.dp else 24.dp).background(option, CircleShape))
                    }
                }
            }
        }
    }
}

@Composable
private fun CircleButton(onClick: () -> Unit, enabled: Boolean = true, content: @Composable () -> Unit) {
    IconButton(onClick = onClick, enabled = enabled, modifier = Modifier.background(Color.Black.copy(alpha = 0.5f), CircleShape), content = content)
}

private fun formatDuration(milliseconds: Long): String {
    val totalSeconds = milliseconds / 1_000
    return "%02d:%02d".format(totalSeconds / 60, totalSeconds % 60)
}
