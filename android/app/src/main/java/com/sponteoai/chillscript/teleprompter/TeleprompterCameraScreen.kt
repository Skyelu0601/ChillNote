package com.sponteoai.chillscript.teleprompter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.Settings as AndroidSettings
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.video.Quality
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.outlined.Cameraswitch
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FileDownload
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors
import java.io.File
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val TeleprompterAccent = ChillColors.BrandBlue
private val PreviewSheetBackground = Color(0xFF1C1C1E)

private data class PromptColorOption(
    val color: Color,
    val labelResource: Int,
)

@Composable
fun TeleprompterCameraScreen(initialScript: String, onClose: () -> Unit) {
    val context = LocalContext.current
    val hostView = LocalView.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val density = LocalDensity.current
    val controller = remember { TeleprompterCameraController(context, lifecycleOwner) }
    val scope = rememberCoroutineScope()
    val scriptScrollState = rememberScrollState()

    var script by remember { mutableStateOf(initialScript.trim()) }
    var speed by remember { mutableFloatStateOf(24f) }
    var fontSize by remember { mutableFloatStateOf(24f) }
    var textColor by remember { mutableStateOf(Color.White) }
    var showCameraSettings by remember { mutableStateOf(false) }
    var showPromptSettings by remember { mutableStateOf(false) }
    var showScriptEditor by remember { mutableStateOf(false) }
    var countdownSeconds by remember { mutableIntStateOf(3) }
    var countdownValue by remember { mutableStateOf<Int?>(null) }
    var countdownJob by remember { mutableStateOf<Job?>(null) }
    var permissionDenied by remember { mutableStateOf(false) }
    var previewFile by remember { mutableStateOf<File?>(null) }
    var saveMessage by remember { mutableStateOf<String?>(null) }
    var pendingSaveFile by remember { mutableStateOf<File?>(null) }

    val savedText = stringResource(R.string.teleprompter_preview_saved)
    val saveFailedText = stringResource(R.string.teleprompter_preview_save_failed)
    val savePermissionDeniedText = stringResource(R.string.teleprompter_preview_save_permission_denied)
    val permissions = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
    val isCountingDown = countdownJob != null
    val controlsLocked = controller.isRecording || isCountingDown

    fun saveVideo(file: File) {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingSaveFile = file
        } else {
            saveMessage = if (TeleprompterVideoFiles.saveToGallery(context, file)) savedText else saveFailedText
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
        permissionDenied = permissions.any { result[it] != true }
        if (!permissionDenied) controller.onPermissionsGranted()
    }
    val storagePermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val file = pendingSaveFile
        pendingSaveFile = null
        saveMessage = when {
            !granted -> savePermissionDeniedText
            file != null && TeleprompterVideoFiles.saveToGallery(context, file) -> savedText
            else -> saveFailedText
        }
    }

    LaunchedEffect(Unit) {
        if (permissions.any { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }) {
            permissionLauncher.launch(permissions)
        }
    }
    LaunchedEffect(controller.isRecording, speed) {
        var previousNanos = System.nanoTime()
        while (controller.isRecording && isActive) {
            delay(16)
            val now = System.nanoTime()
            val seconds = (now - previousNanos) / 1_000_000_000f
            previousNanos = now
            scriptScrollState.scrollBy(with(density) { speed.dp.toPx() } * seconds)
        }
    }
    LaunchedEffect(previewFile) {
        saveMessage = null
    }
    LaunchedEffect(script) {
        scriptScrollState.scrollTo(0)
    }
    DisposableEffect(context, hostView) {
        val window = context.findActivity()?.window
        if (window == null) {
            onDispose { }
        } else {
            val insetsController = WindowCompat.getInsetsController(window, hostView)
            val previousLightStatusBars = insetsController.isAppearanceLightStatusBars
            val previousLightNavigationBars = insetsController.isAppearanceLightNavigationBars
            val previousStatusBarColor = window.statusBarColor
            val previousNavigationBarColor = window.navigationBarColor
            insetsController.isAppearanceLightStatusBars = false
            insetsController.isAppearanceLightNavigationBars = false
            window.statusBarColor = Color.Transparent.toArgb()
            window.navigationBarColor = Color.Black.toArgb()
            onDispose {
                insetsController.isAppearanceLightStatusBars = previousLightStatusBars
                insetsController.isAppearanceLightNavigationBars = previousLightNavigationBars
                window.statusBarColor = previousStatusBarColor
                window.navigationBarColor = previousNavigationBarColor
            }
        }
    }
    DisposableEffect(lifecycleOwner, controller) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                countdownJob?.cancel()
                countdownJob = null
                countdownValue = null
                controller.handleAppDeactivation()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            countdownJob?.cancel()
            controller.cleanup()
        }
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        val targetRatio = 9f / 16f
        val containerRatio = maxWidth.value / maxHeight.value
        val captureWidth: Dp
        val captureHeight: Dp
        if (containerRatio > targetRatio) {
            captureHeight = maxHeight
            captureWidth = maxHeight * targetRatio
        } else {
            captureWidth = maxWidth
            captureHeight = maxWidth / targetRatio
        }

        AndroidView(
            factory = {
                PreviewView(it).apply {
                    scaleType = PreviewView.ScaleType.FILL_CENTER
                }.also(controller::attach)
            },
            modifier = Modifier
                .align(Alignment.Center)
                .size(captureWidth, captureHeight)
                .clipToBounds()
                .border(1.dp, Color.White.copy(alpha = 0.18f)),
        )

        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .statusBarsPadding(),
        ) {
            TeleprompterTopBar(
                elapsedText = formatDuration(controller.recordedMillis),
                isRecording = controller.isRecording,
                controlsLocked = controlsLocked,
                onClose = onClose,
                onSwitchCamera = controller::switchCamera,
                onToggleCameraSettings = {
                    showCameraSettings = !showCameraSettings
                    showPromptSettings = false
                },
            )
            AnimatedVisibility(
                visible = showCameraSettings,
                enter = fadeIn() + slideInVertically { -it / 3 },
                exit = fadeOut() + slideOutVertically { -it / 3 },
            ) {
                CameraSettingsPanel(
                    countdownSeconds = countdownSeconds,
                    onCountdown = { countdownSeconds = it },
                    quality = controller.quality,
                    supportedQualities = controller.supportedQualities,
                    onQuality = controller::updateQuality,
                    enabled = !controlsLocked,
                    modifier = Modifier
                        .padding(horizontal = 18.dp)
                        .padding(top = 10.dp),
                )
            }
        }

        FloatingPromptPanel(
            script = script.ifBlank { stringResource(R.string.teleprompter_script_empty_placeholder) },
            fontSize = fontSize,
            textColor = textColor,
            screenWidth = maxWidth,
            screenHeight = maxHeight,
            cameraSettingsVisible = showCameraSettings,
            scrollState = scriptScrollState,
            onEdit = { showScriptEditor = true },
            onPromptSettings = {
                showPromptSettings = !showPromptSettings
                showCameraSettings = false
            },
            modifier = Modifier.align(Alignment.TopCenter),
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .navigationBarsPadding(),
        ) {
            AnimatedVisibility(
                visible = showPromptSettings,
                enter = fadeIn() + slideInVertically { it / 3 },
                exit = fadeOut() + slideOutVertically { it / 3 },
            ) {
                PromptSettingsPanel(
                    speed = speed,
                    onSpeed = { speed = it },
                    fontSize = fontSize,
                    onFontSize = { fontSize = it },
                    textColor = textColor,
                    onTextColor = { textColor = it },
                    modifier = Modifier
                        .padding(horizontal = 18.dp)
                        .padding(bottom = 18.dp),
                )
            }

            ClipStrip(
                clips = controller.clips,
                onPreview = { previewFile = it.file },
                onDelete = controller::removeClip,
                onMove = controller::moveClip,
                modifier = Modifier
                    .padding(horizontal = 18.dp)
                    .padding(bottom = 18.dp),
            )

            RecordControls(
                hasClips = controller.clips.isNotEmpty(),
                isRecording = controller.isRecording,
                isCountingDown = isCountingDown,
                isExporting = controller.exporting,
                onRecord = {
                    when {
                        isCountingDown -> {
                            countdownJob?.cancel()
                            countdownJob = null
                            countdownValue = null
                        }
                        controller.isRecording -> controller.stopRecording()
                        else -> {
                            val job = scope.launch(start = CoroutineStart.LAZY) {
                                try {
                                    if (countdownSeconds > 0) {
                                        for (value in countdownSeconds downTo 1) {
                                            countdownValue = value
                                            delay(1_000)
                                        }
                                    }
                                    countdownValue = null
                                    scriptScrollState.scrollTo(0)
                                    controller.startRecording()
                                } finally {
                                    countdownValue = null
                                    countdownJob = null
                                }
                            }
                            countdownJob = job
                            job.start()
                        }
                    }
                },
                onPreview = {
                    scope.launch {
                        controller.export()?.let { previewFile = it }
                    }
                },
                modifier = Modifier.padding(bottom = 26.dp),
            )
        }

        AnimatedContent(
            targetState = countdownValue,
            transitionSpec = {
                (fadeIn(spring()) + scaleIn(spring(), initialScale = 0.72f)) togetherWith
                    (fadeOut(spring()) + scaleOut(spring(), targetScale = 1.18f))
            },
            contentAlignment = Alignment.Center,
            label = "teleprompterCountdown",
            modifier = Modifier.align(Alignment.Center),
        ) { value ->
            if (value != null) {
                Text(
                    text = value.toString(),
                    color = Color.White,
                    fontSize = 92.sp,
                    fontWeight = FontWeight.Bold,
                    style = TextStyle(
                        shadow = Shadow(
                            color = Color.Black.copy(alpha = 0.45f),
                            offset = Offset(0f, 3f),
                            blurRadius = 8f,
                        ),
                    ),
                )
            }
        }

        if (controller.exporting) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .size(116.dp)
                    .background(Color.Black.copy(alpha = 0.72f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(
                    color = Color.White,
                    strokeWidth = 4.dp,
                    modifier = Modifier.size(42.dp),
                )
            }
        }
    }

    if (showScriptEditor) {
        ScriptEditorDialog(
            script = script,
            onScriptChange = { script = it },
            onDone = { showScriptEditor = false },
        )
    }

    previewFile?.let { file ->
        ExportPreviewSheet(
            file = file,
            saveMessage = saveMessage,
            onSave = {
                saveVideo(file)
                if (pendingSaveFile != null) {
                    storagePermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            },
            onDismiss = {
                if (file == controller.exportedFile) controller.clearExport()
                previewFile = null
            },
        )
    }

    if (permissionDenied) {
        AlertDialog(
            onDismissRequest = onClose,
            containerColor = PreviewSheetBackground,
            titleContentColor = Color.White,
            textContentColor = Color.White,
            title = { Text(stringResource(R.string.teleprompter_permission_title)) },
            text = { Text(stringResource(R.string.teleprompter_permission_message)) },
            confirmButton = {
                TextButton(onClick = {
                    context.startActivity(
                        Intent(
                            AndroidSettings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${context.packageName}"),
                        ),
                    )
                    onClose()
                }) {
                    Text(stringResource(R.string.teleprompter_permission_open_settings))
                }
            },
            dismissButton = {
                TextButton(onClick = onClose) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }

    controller.errorMessage?.let { error ->
        AlertDialog(
            onDismissRequest = { controller.errorMessage = null },
            containerColor = PreviewSheetBackground,
            titleContentColor = Color.White,
            textContentColor = Color.White,
            title = { Text(stringResource(R.string.teleprompter_error_title)) },
            text = { Text(error) },
            confirmButton = {
                TextButton(onClick = { controller.errorMessage = null }) {
                    Text(stringResource(R.string.common_ok))
                }
            },
        )
    }
}

@Composable
private fun TeleprompterTopBar(
    elapsedText: String,
    isRecording: Boolean,
    controlsLocked: Boolean,
    onClose: () -> Unit,
    onSwitchCamera: () -> Unit,
    onToggleCameraSettings: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .padding(top = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircleIconButton(
                icon = Icons.Outlined.Close,
                contentDescription = stringResource(R.string.teleprompter_accessibility_close),
                onClick = onClose,
                iconSize = 18.dp,
            )
            Spacer(Modifier.weight(1f))
            CircleIconButton(
                icon = Icons.Outlined.Cameraswitch,
                contentDescription = stringResource(R.string.teleprompter_camera_switch),
                onClick = onSwitchCamera,
                enabled = !controlsLocked,
                iconSize = 17.dp,
            )
            CircleIconButton(
                icon = Icons.Outlined.Tune,
                contentDescription = stringResource(R.string.teleprompter_accessibility_camera_settings),
                onClick = onToggleCameraSettings,
                enabled = !controlsLocked,
                iconSize = 17.dp,
            )
        }

        if (isRecording) {
            Surface(
                color = Color.Black.copy(alpha = 0.46f),
                shape = RoundedCornerShape(999.dp),
                modifier = Modifier.align(Alignment.Center),
            ) {
                Text(
                    text = elapsedText,
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                )
            }
        }
    }
}

@Composable
private fun CircleIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    iconSize: Dp,
) {
    IconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .size(42.dp)
            .alpha(if (enabled) 1f else 0.45f)
            .background(Color.Black.copy(alpha = 0.48f), CircleShape),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = Color.White,
            modifier = Modifier.size(iconSize),
        )
    }
}

@Composable
private fun CameraSettingsPanel(
    countdownSeconds: Int,
    onCountdown: (Int) -> Unit,
    quality: Quality,
    supportedQualities: List<Quality>,
    onQuality: (Quality) -> Unit,
    enabled: Boolean,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = Color.Black.copy(alpha = 0.56f),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            SegmentedSetting(
                title = stringResource(R.string.teleprompter_camera_countdown),
                choices = listOf(
                    0 to stringResource(R.string.teleprompter_countdown_none),
                    3 to stringResource(R.string.teleprompter_countdown_three),
                    5 to stringResource(R.string.teleprompter_countdown_five),
                ),
                selected = countdownSeconds,
                onSelected = onCountdown,
                enabled = enabled,
            )
            SegmentedSetting(
                title = stringResource(R.string.teleprompter_camera_resolution),
                choices = supportedQualities.map { candidate ->
                    candidate to teleprompterQualityLabel(candidate)
                },
                selected = quality,
                onSelected = onQuality,
                enabled = enabled,
            )
        }
    }
}

private fun teleprompterQualityLabel(quality: Quality): String = when (quality) {
    Quality.HD -> "720P"
    Quality.FHD -> "1080P"
    Quality.UHD -> "4K"
    else -> error("Unsupported teleprompter quality: $quality")
}

@Composable
private fun <T> SegmentedSetting(
    title: String,
    choices: List<Pair<T, String>>,
    selected: T,
    onSelected: (T) -> Unit,
    enabled: Boolean,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.alpha(if (enabled) 1f else 0.45f),
    ) {
        Text(
            text = title,
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            choices.forEach { (value, label) ->
                val isSelected = value == selected
                Surface(
                    onClick = { onSelected(value) },
                    enabled = enabled,
                    color = if (isSelected) Color.White else Color.White.copy(alpha = 0.14f),
                    shape = RoundedCornerShape(7.dp),
                    modifier = Modifier
                        .height(34.dp)
                        .semantics { this.selected = isSelected },
                ) {
                    Box(
                        modifier = Modifier.padding(horizontal = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = label,
                            color = if (isSelected) Color.Black else Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FloatingPromptPanel(
    script: String,
    fontSize: Float,
    textColor: Color,
    screenWidth: Dp,
    screenHeight: Dp,
    cameraSettingsVisible: Boolean,
    scrollState: androidx.compose.foundation.ScrollState,
    onEdit: () -> Unit,
    onPromptSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val panelWidth = screenWidth - 32.dp
    val panelHeight = (screenHeight * 0.34f).coerceIn(220.dp, 330.dp)
    val baseTop = screenHeight * 0.3f - panelHeight / 2
    val cameraShiftTarget = if (cameraSettingsVisible) {
        (screenHeight * 0.18f).coerceIn(120.dp, 170.dp)
    } else {
        0.dp
    }
    val cameraShift by animateDpAsState(cameraShiftTarget, label = "teleprompterCameraPanelShift")
    var panelScale by remember { mutableFloatStateOf(1f) }
    var panelOffset by remember { mutableStateOf(Offset.Zero) }
    val horizontalLimit = with(density) { maxOf(screenWidth * 0.38f, 80.dp).toPx() }
    val verticalLimit = with(density) { maxOf(screenHeight * 0.3f, 120.dp).toPx() }

    Surface(
        color = Color.Black.copy(alpha = 0.62f),
        shape = RoundedCornerShape(8.dp),
        modifier = modifier
            .offset { IntOffset(0, with(density) { baseTop.roundToPx() }) }
            .size(panelWidth, panelHeight)
            .graphicsLayer {
                scaleX = panelScale
                scaleY = panelScale
                translationX = panelOffset.x
                translationY = panelOffset.y + with(density) { cameraShift.toPx() }
            }
            .pointerInput(screenWidth, screenHeight) {
                detectTransformGestures { _, pan, zoom, _ ->
                    panelScale = (panelScale * zoom).coerceIn(0.78f, 1.35f)
                    panelOffset = Offset(
                        x = (panelOffset.x + pan.x).coerceIn(-horizontalLimit, horizontalLimit),
                        y = (panelOffset.y + pan.y).coerceIn(-verticalLimit, verticalLimit),
                    )
                }
            },
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp, bottom = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 42.dp, height = 5.dp)
                        .background(Color.White.copy(alpha = 0.7f), RoundedCornerShape(999.dp)),
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 22.dp)
                    .clipToBounds(),
            ) {
                Text(
                    text = script,
                    color = textColor,
                    fontSize = fontSize.sp,
                    lineHeight = (fontSize * 1.45f).sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(scrollState)
                        .padding(bottom = 40.dp),
                )
            }

            Row(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(36.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                PromptPanelAction(
                    icon = Icons.Outlined.Edit,
                    description = stringResource(R.string.teleprompter_action_edit_script),
                    onClick = onEdit,
                )
                PromptPanelAction(
                    icon = Icons.Outlined.Settings,
                    description = stringResource(R.string.teleprompter_action_prompt_settings),
                    onClick = onPromptSettings,
                )
            }
        }
    }
}

@Composable
private fun PromptPanelAction(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .semantics {
                contentDescription = description
                role = Role.Button
            }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(24.dp),
        )
    }
}

@Composable
private fun PromptSettingsPanel(
    speed: Float,
    onSpeed: (Float) -> Unit,
    fontSize: Float,
    onFontSize: (Float) -> Unit,
    textColor: Color,
    onTextColor: (Color) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = listOf(
        PromptColorOption(Color.White, R.string.teleprompter_text_color_white),
        PromptColorOption(Color.Yellow, R.string.teleprompter_text_color_yellow),
        PromptColorOption(Color.Black, R.string.teleprompter_text_color_black),
        PromptColorOption(Color(0xFFFF5C80), R.string.teleprompter_text_color_pink),
        PromptColorOption(Color(0xFF59E66B), R.string.teleprompter_text_color_green),
        PromptColorOption(Color(0xFF45C2F2), R.string.teleprompter_text_color_blue),
        PromptColorOption(Color(0xFF947AE6), R.string.teleprompter_text_color_purple),
    )

    Surface(
        color = Color.Black.copy(alpha = 0.62f),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            PromptSliderRow(
                title = stringResource(R.string.teleprompter_prompt_speed),
                leading = stringResource(R.string.teleprompter_prompt_slow),
                trailing = stringResource(R.string.teleprompter_prompt_fast),
                value = speed,
                onValueChange = onSpeed,
                range = 0f..50f,
            )
            PromptSliderRow(
                title = stringResource(R.string.teleprompter_prompt_font_size),
                leading = stringResource(R.string.teleprompter_prompt_small),
                trailing = stringResource(R.string.teleprompter_prompt_large),
                value = fontSize,
                onValueChange = onFontSize,
                range = 16f..36f,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(R.string.teleprompter_prompt_text_color),
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.width(88.dp),
                )
                Spacer(Modifier.width(10.dp))
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    colors.forEach { option ->
                        val isSelected = textColor == option.color
                        val description = stringResource(option.labelResource)
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .background(option.color, CircleShape)
                                .border(
                                    width = if (isSelected) 3.dp else 0.dp,
                                    color = if (isSelected) Color.White else Color.Transparent,
                                    shape = CircleShape,
                                )
                                .semantics {
                                    contentDescription = description
                                    selected = isSelected
                                    role = Role.Button
                                }
                                .clickable(
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null,
                                ) { onTextColor(option.color) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PromptSliderRow(
    title: String,
    leading: String,
    trailing: String,
    value: Float,
    onValueChange: (Float) -> Unit,
    range: ClosedFloatingPointRange<Float>,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = value.roundToInt().toString(),
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.End,
                modifier = Modifier.width(34.dp),
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = leading,
                color = Color.White.copy(alpha = 0.64f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
            )
            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = range,
                colors = SliderDefaults.colors(
                    thumbColor = TeleprompterAccent,
                    activeTrackColor = TeleprompterAccent,
                    inactiveTrackColor = Color.White.copy(alpha = 0.26f),
                ),
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = title },
            )
            Text(
                text = trailing,
                color = Color.White.copy(alpha = 0.64f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
private fun ClipStrip(
    clips: List<TeleprompterClip>,
    onPreview: (TeleprompterClip) -> Unit,
    onDelete: (TeleprompterClip) -> Unit,
    onMove: (Int, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val moveEarlier = stringResource(R.string.teleprompter_clip_move_left)
    val moveLater = stringResource(R.string.teleprompter_clip_move_right)

    LazyRow(
        modifier = modifier
            .fillMaxWidth()
            .animateContentSize(animationSpec = spring())
            .height(if (clips.isEmpty()) 0.dp else 84.dp),
        contentPadding = PaddingValues(start = 2.dp, end = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        itemsIndexed(clips, key = { _, clip -> clip.id }) { index, clip ->
            var dragDistance by remember(clip.id) { mutableFloatStateOf(0f) }
            val step = with(density) { 68.dp.toPx() }
            ClipThumbnail(
                clip = clip,
                index = index,
                onPreview = { onPreview(clip) },
                onDelete = { onDelete(clip) },
                modifier = Modifier
                    .semantics {
                        customActions = buildList {
                            if (index > 0) add(CustomAccessibilityAction(moveEarlier) {
                                onMove(index, index - 1)
                                true
                            })
                            if (index < clips.lastIndex) add(CustomAccessibilityAction(moveLater) {
                                onMove(index, index + 1)
                                true
                            })
                        }
                    }
                    .pointerInput(clip.id, clips.size) {
                        detectDragGesturesAfterLongPress(
                            onDragStart = { dragDistance = 0f },
                            onDragEnd = { dragDistance = 0f },
                            onDragCancel = { dragDistance = 0f },
                        ) { change, dragAmount ->
                            change.consume()
                            dragDistance += dragAmount.x
                            if (abs(dragDistance) >= step) {
                                val current = clips.indexOfFirst { it.id == clip.id }
                                if (current >= 0) {
                                    val target = if (dragDistance > 0) current + 1 else current - 1
                                    if (target in clips.indices) onMove(current, target)
                                }
                                dragDistance = 0f
                            }
                        }
                    },
            )
        }
    }
}

@Composable
private fun ClipThumbnail(
    clip: TeleprompterClip,
    index: Int,
    onPreview: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val durationSeconds = (clip.durationMillis / 1_000f).roundToInt()
    val deleteDescription = stringResource(R.string.teleprompter_clip_delete)
    Box(
        modifier = modifier
            .padding(top = 10.dp, end = 7.dp)
            .size(width = 61.dp, height = 73.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .size(width = 54.dp, height = 66.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(Color.Black.copy(alpha = 0.5f))
                .clickable(onClick = onPreview),
            contentAlignment = Alignment.Center,
        ) {
            clip.thumbnail?.let { bitmap ->
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } ?: Icon(
                imageVector = Icons.Filled.Videocam,
                contentDescription = null,
                tint = Color.White,
            )
            Icon(
                imageVector = Icons.Outlined.PlayCircle,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.92f),
                modifier = Modifier.size(22.dp),
            )
            Surface(
                color = Color.Black.copy(alpha = 0.55f),
                shape = RoundedCornerShape(999.dp),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(4.dp),
            ) {
                Text(
                    text = stringResource(R.string.teleprompter_clip_format, index + 1, durationSeconds),
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
                )
            }
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(18.dp)
                .background(Color.White, CircleShape)
                .semantics {
                    contentDescription = deleteDescription
                    role = Role.Button
                }
                .clickable(onClick = onDelete),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Close,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(9.dp),
            )
        }
    }
}

@Composable
private fun RecordControls(
    hasClips: Boolean,
    isRecording: Boolean,
    isCountingDown: Boolean,
    isExporting: Boolean,
    onRecord: () -> Unit,
    onPreview: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(78.dp),
    ) {
        IconButton(
            onClick = onRecord,
            enabled = !isExporting,
            modifier = Modifier
                .align(Alignment.Center)
                .size(78.dp)
                .background(Color.White, CircleShape),
        ) {
            Icon(
                imageVector = if (isRecording || isCountingDown) Icons.Filled.Stop else Icons.Filled.Videocam,
                contentDescription = stringResource(
                    if (isRecording) R.string.teleprompter_stop_recording else R.string.teleprompter_start_recording,
                ),
                tint = TeleprompterAccent,
                modifier = Modifier.size(if (isRecording || isCountingDown) 24.dp else 22.dp),
            )
        }

        if (hasClips) {
            val enabled = !isRecording && !isCountingDown && !isExporting
            IconButton(
                onClick = onPreview,
                enabled = enabled,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .size(52.dp)
                    .alpha(if (enabled) 1f else 0.45f)
                    .background(TeleprompterAccent, CircleShape),
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = stringResource(R.string.teleprompter_action_preview),
                    tint = Color.White,
                    modifier = Modifier.size(21.dp),
                )
            }
        }
    }
}

@Composable
private fun ScriptEditorDialog(
    script: String,
    onScriptChange: (String) -> Unit,
    onDone: () -> Unit,
) {
    Dialog(
        onDismissRequest = onDone,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Surface(
            color = PreviewSheetBackground,
            modifier = Modifier.fillMaxSize(),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .navigationBarsPadding()
                    .imePadding(),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp),
                ) {
                    Text(
                        text = stringResource(R.string.teleprompter_editor_title),
                        color = Color.White,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.align(Alignment.Center),
                    )
                    TextButton(
                        onClick = onDone,
                        modifier = Modifier.align(Alignment.CenterEnd),
                    ) {
                        Text(
                            text = stringResource(R.string.common_done),
                            color = TeleprompterAccent,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
                androidx.compose.foundation.text.BasicTextField(
                    value = script,
                    onValueChange = onScriptChange,
                    textStyle = TextStyle(
                        color = Color.White,
                        fontSize = 17.sp,
                        lineHeight = 22.sp,
                    ),
                    cursorBrush = SolidColor(TeleprompterAccent),
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(14.dp),
                )
            }
        }
    }
}

@Composable
private fun ExportPreviewSheet(
    file: File,
    saveMessage: String?,
    onSave: () -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.48f)),
        ) {
            Surface(
                color = PreviewSheetBackground,
                shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .fillMaxHeight(0.94f),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .navigationBarsPadding(),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(56.dp),
                    ) {
                        Text(
                            text = stringResource(R.string.teleprompter_preview_title),
                            color = Color.White,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.align(Alignment.Center),
                        )
                        IconButton(
                            onClick = onDismiss,
                            modifier = Modifier
                                .align(Alignment.CenterEnd)
                                .padding(end = 8.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Outlined.Close,
                                contentDescription = stringResource(R.string.teleprompter_accessibility_close),
                                tint = Color.White.copy(alpha = 0.64f),
                                modifier = Modifier
                                    .size(26.dp)
                                    .background(Color.White.copy(alpha = 0.16f), CircleShape)
                                    .padding(5.dp),
                            )
                        }
                    }

                    FittedVideoPreview(
                        file = file,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .padding(horizontal = 18.dp),
                    )

                    saveMessage?.let { message ->
                        Text(
                            text = message,
                            color = Color.White.copy(alpha = 0.64f),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 18.dp, vertical = 9.dp),
                        )
                    }

                    Button(
                        onClick = onSave,
                        colors = ButtonDefaults.buttonColors(containerColor = TeleprompterAccent),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 18.dp)
                            .padding(top = 18.dp, bottom = 18.dp)
                            .height(50.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.FileDownload,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.teleprompter_preview_save_to_gallery),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FittedVideoPreview(file: File, modifier: Modifier = Modifier) {
    val aspectRatio by produceState(initialValue = 9f / 16f, key1 = file.absolutePath) {
        value = withContext(Dispatchers.IO) { detectVideoAspectRatio(file) }
    }
    BoxWithConstraints(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        val containerRatio = maxWidth.value / maxHeight.value
        val videoWidth: Dp
        val videoHeight: Dp
        if (containerRatio > aspectRatio) {
            videoHeight = maxHeight
            videoWidth = maxHeight * aspectRatio
        } else {
            videoWidth = maxWidth
            videoHeight = maxWidth / aspectRatio
        }
        VideoFilePreview(
            file = file,
            modifier = Modifier
                .size(videoWidth, videoHeight)
                .clip(RoundedCornerShape(8.dp))
                .background(Color.Black),
        )
    }
}

@Composable
private fun VideoFilePreview(file: File, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val videoView = remember(file.absolutePath) { VideoView(context) }
    DisposableEffect(videoView) {
        onDispose { videoView.stopPlayback() }
    }
    AndroidView(
        factory = { videoView },
        update = { view ->
            if (view.tag != file.absolutePath) {
                view.tag = file.absolutePath
                view.setVideoURI(Uri.fromFile(file))
                view.setOnPreparedListener { player ->
                    player.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT)
                    view.start()
                }
            }
        },
        modifier = modifier,
    )
}

private fun formatDuration(milliseconds: Long): String {
    val totalSeconds = milliseconds / 1_000
    return "%02d:%02d".format(totalSeconds / 60, totalSeconds % 60)
}

private fun detectVideoAspectRatio(file: File): Float {
    val retriever = MediaMetadataRetriever()
    return try {
        runCatching {
            retriever.setDataSource(file.absolutePath)
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloatOrNull()
                ?: return@runCatching 9f / 16f
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloatOrNull()
                ?: return@runCatching 9f / 16f
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            when {
                width <= 0f || height <= 0f -> 9f / 16f
                rotation % 180 != 0 -> height / width
                else -> width / height
            }
        }.getOrDefault(9f / 16f)
    } finally {
        retriever.release()
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
