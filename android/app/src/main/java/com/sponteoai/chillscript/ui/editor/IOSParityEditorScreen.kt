package com.sponteoai.chillscript.ui.editor

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForwardIos
import androidx.compose.material.icons.automirrored.outlined.Redo
import androidx.compose.material.icons.automirrored.outlined.Undo
import androidx.compose.material.icons.outlined.AddLink
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckBox
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.KeyboardHide
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarData
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.VoiceNoteProcessingStage
import com.sponteoai.chillscript.VoiceNoteState
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.BuiltInRecipes
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.sourceMetadata
import com.sponteoai.chillscript.ui.skills.recipeName
import com.sponteoai.chillscript.ui.skills.CreatorSkillIcon
import com.sponteoai.chillscript.ui.markdown.EditableRichMarkdown
import com.sponteoai.chillscript.ui.source.NoteSourceCard
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.home.HomeFirstActionGuideState
import com.sponteoai.chillscript.ui.home.HomeFirstActionStage

enum class IOSNoteWorkspace { NOTE, CREATE, RECORD }

/** Mirrors the current iOS NoteDetailView rather than embedding an editor in Home. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun IOSParityEditorScreen(
    note: NoteEntity?,
    text: TextFieldValue,
    selectedTags: List<TagEntity>,
    recipes: List<AgentRecipe>,
    canUseAISkills: Boolean,
    canEdit: Boolean,
    canUndo: Boolean,
    canRedo: Boolean,
    onTextChange: (TextFieldValue) -> Unit,
    onBack: () -> Unit,
    onRestore: () -> Unit,
    onAddTopic: () -> Unit,
    onExport: () -> Unit,
    onDelete: () -> Unit,
    onOpenSource: (String) -> Unit,
    onRemoveTag: (TagEntity) -> Unit,
    onSelectRecipe: (AgentRecipe) -> Unit,
    onManageSkills: () -> Unit,
    onStartRecording: () -> Unit,
    onBold: () -> Unit,
    onChecklist: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    voiceNoteState: VoiceNoteState? = null,
    onShowOriginalVoiceResult: () -> Unit = {},
    onDismissVoiceFailure: () -> Unit = {},
    snackbarHostState: SnackbarHostState? = null,
    showAIActions: Boolean = false,
    isAIRetrying: Boolean = false,
    onAIRetry: () -> Unit = {},
    onAIUndo: () -> Unit = {},
    onAISave: () -> Unit = {},
    firstActionGuideState: HomeFirstActionGuideState = HomeFirstActionGuideState(),
    onReviewTranscript: () -> Unit = {},
    onOpenCreateTab: () -> Unit = {},
    onOpenAISkill: () -> Unit = {},
    onOpenRecordTab: () -> Unit = {},
    onOpenTeleprompter: () -> Unit = {},
    onDismissFirstActionGuide: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    var workspace by remember { mutableStateOf(IOSNoteWorkspace.NOTE) }
    var menuOpen by remember { mutableStateOf(false) }
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val density = LocalDensity.current
    val imeVisible = WindowInsets.ime.getBottom(density) > 0
    val isDeleted = note?.deletedAt != null
    val guideApplies = note != null && note.id == firstActionGuideState.targetNoteId
    val guideStage = if (guideApplies) firstActionGuideState.stage else HomeFirstActionStage.Inactive
    var createTabBounds by remember { mutableStateOf<Rect?>(null) }
    var firstSkillBounds by remember { mutableStateOf<Rect?>(null) }
    var recordTabBounds by remember { mutableStateOf<Rect?>(null) }
    var teleprompterBounds by remember { mutableStateOf<Rect?>(null) }
    val workspaceRecipes = if (
        guideStage == HomeFirstActionStage.TapAISkills && recipes.isEmpty()
    ) {
        BuiltInRecipes.all.filter { it.id == "hook_generator" }
    } else {
        recipes
    }

    LaunchedEffect(guideStage) {
        val guidedWorkspace = when (guideStage) {
            HomeFirstActionStage.ReviewTranscript,
            HomeFirstActionStage.TapCreateTab -> IOSNoteWorkspace.NOTE
            HomeFirstActionStage.TapAISkills,
            HomeFirstActionStage.WaitingForAISkillsDismissal,
            HomeFirstActionStage.TapRecordTab -> IOSNoteWorkspace.CREATE
            HomeFirstActionStage.TapTeleprompter -> IOSNoteWorkspace.RECORD
            else -> workspace
        }
        if (guidedWorkspace != IOSNoteWorkspace.NOTE) focusManager.clearFocus()
        workspace = guidedWorkspace
    }

    Box(modifier.fillMaxSize().background(ChillColors.BackgroundSecondary)) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Row(
                Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 20.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                IconButton(onClick = onBack, modifier = Modifier.size(44.dp)) {
                    Icon(
                        Icons.AutoMirrored.Outlined.ArrowBack,
                        contentDescription = stringResource(R.string.note_header_accessibility_back),
                        tint = ChillColors.TextMain,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(Modifier.weight(1f))
                if (isDeleted) {
                    Surface(
                        onClick = onRestore,
                        shape = CircleShape,
                        color = ChillColors.BrandBlue.copy(alpha = 0.10f),
                        modifier = Modifier.height(44.dp),
                    ) {
                        Row(
                            Modifier.padding(horizontal = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(7.dp),
                        ) {
                            Icon(Icons.Outlined.Restore, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(18.dp))
                            Text(stringResource(R.string.note_header_restore_action), color = ChillColors.BrandBlue, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                } else {
                    Box {
                        IconButton(onClick = { menuOpen = true }, modifier = Modifier.size(44.dp)) {
                            Icon(
                                Icons.Outlined.MoreHoriz,
                                contentDescription = stringResource(R.string.note_header_accessibility_more_actions),
                                tint = ChillColors.TextMain,
                            )
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            IOSNoteMenuItem(R.string.note_header_add_topic, Icons.Outlined.Tag) {
                                menuOpen = false
                                onAddTopic()
                            }
                            if (note != null) {
                                IOSNoteMenuItem(R.string.note_header_export_markdown, Icons.Outlined.Share) {
                                    menuOpen = false
                                    onExport()
                                }
                            }
                            IOSNoteMenuItem(R.string.note_header_delete_note, Icons.Outlined.Delete, destructive = true) {
                                menuOpen = false
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
            }

            BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
                val minimumContentHeight = (maxHeight - 56.dp).coerceAtLeast(120.dp)
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = if (guideStage == HomeFirstActionStage.ReviewTranscript) 156.dp else 0.dp),
                ) {
                    if (isDeleted) {
                        item(key = "trash-countdown") {
                            IOSTrashCountdown(note?.deletedAt)
                        }
                    }
                    item(key = "note-context") {
                        IOSNoteContext(
                            note = note,
                            tags = selectedTags,
                            isDeleted = isDeleted,
                            onOpenSource = onOpenSource,
                            onRemoveTag = onRemoveTag,
                        )
                    }
                    stickyHeader(key = "workspace-picker") {
                        IOSWorkspacePicker(
                            selected = workspace,
                            createEnabled = canUseAISkills && !isDeleted,
                            guideStage = guideStage,
                            onCreateBounds = { createTabBounds = it },
                            onRecordBounds = { recordTabBounds = it },
                            onSelect = { page ->
                                if (page != IOSNoteWorkspace.NOTE) focusManager.clearFocus()
                                workspace = page
                                when {
                                    guideStage == HomeFirstActionStage.TapCreateTab && page == IOSNoteWorkspace.CREATE -> onOpenCreateTab()
                                    guideStage == HomeFirstActionStage.TapRecordTab && page == IOSNoteWorkspace.RECORD -> onOpenRecordTab()
                                }
                            },
                        )
                    }
                    item(key = workspace.name) {
                        when (workspace) {
                            IOSNoteWorkspace.NOTE -> IOSNoteEditor(
                                value = text,
                                enabled = canEdit && !isDeleted,
                                onValueChange = onTextChange,
                                onOpenLink = onOpenSource,
                                focusRequester = focusRequester,
                                modifier = Modifier.heightIn(min = minimumContentHeight),
                            )
                            IOSNoteWorkspace.CREATE -> IOSCreateWorkspace(
                                recipes = workspaceRecipes,
                                enabled = canUseAISkills && !isDeleted,
                                onSelect = onSelectRecipe,
                                onManageSkills = onManageSkills,
                                minimumHeight = minimumContentHeight,
                                onFirstSkillBounds = { firstSkillBounds = it },
                                onFirstSkillSelected = onOpenAISkill,
                                guideStage = guideStage,
                            )
                            IOSNoteWorkspace.RECORD -> IOSRecordWorkspace(
                                script = text.text,
                                enabled = canEdit && !isDeleted,
                                onStartRecording = onStartRecording,
                                minimumHeight = minimumContentHeight,
                                onStartBounds = { teleprompterBounds = it },
                                onFirstActionStart = onOpenTeleprompter,
                                guideStage = guideStage,
                            )
                        }
                    }
                }
            }
        }

        if (workspace == IOSNoteWorkspace.NOTE && imeVisible) {
            IOSKeyboardToolbar(
                canUndo = canUndo,
                canRedo = canRedo,
                onBold = onBold,
                onChecklist = onChecklist,
                onUndo = onUndo,
                onRedo = onRedo,
                onHideKeyboard = { focusManager.clearFocus() },
                modifier = Modifier.align(Alignment.BottomCenter).imePadding(),
            )
        }

        when (val state = voiceNoteState) {
            is VoiceNoteState.Processing -> IOSVoiceProcessingWorkflow(
                stage = state.stage,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 20.dp, vertical = 20.dp)
                    .imePadding(),
            )
            is VoiceNoteState.Completed -> IOSVoiceRefinedOverlay(
                onShowOriginal = onShowOriginalVoiceResult,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 40.dp)
                    .imePadding(),
            )
            else -> Unit
        }

        if (guideStage == HomeFirstActionStage.ReviewTranscript) {
            IOSFirstActionTranscriptReviewPrompt(
                onContinue = onReviewTranscript,
                onDismiss = onDismissFirstActionGuide,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }

        val spotlight = when (guideStage) {
            HomeFirstActionStage.TapCreateTab -> Triple(createTabBounds, R.string.onboarding_first_action_create_tab, 4)
            HomeFirstActionStage.TapAISkills -> Triple(firstSkillBounds, R.string.onboarding_first_action_ai_skills, 5)
            HomeFirstActionStage.TapRecordTab -> Triple(recordTabBounds, R.string.onboarding_first_action_record_tab, 6)
            HomeFirstActionStage.TapTeleprompter -> Triple(teleprompterBounds, R.string.onboarding_first_action_teleprompter, 7)
            else -> null
        }
        spotlight?.let { (bounds, messageResource, step) ->
            bounds?.let {
                IOSFirstActionEditorSpotlight(
                    targetBounds = it,
                    message = stringResource(messageResource),
                    step = step,
                    onDismiss = onDismissFirstActionGuide,
                )
            }
        }

        snackbarHostState?.let { hostState ->
            IOSParityEditorSnackbarHost(
                hostState = hostState,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp)
                    .padding(bottom = if (showAIActions) 96.dp else 40.dp)
                    .imePadding(),
            )
        }

        if (showAIActions) {
            IOSAIAppliedActionBar(
                retrying = isAIRetrying,
                onRetry = onAIRetry,
                onUndo = onAIUndo,
                onSave = onAISave,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 20.dp)
                    .imePadding(),
            )
        }
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.note_detail_delete_confirmation_title)) },
            text = { Text(stringResource(R.string.note_detail_delete_confirmation_message)) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirmation = false
                    onDelete()
                }) {
                    Text(
                        stringResource(R.string.common_delete),
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }

    val voiceFailure = voiceNoteState as? VoiceNoteState.Failed
    if (voiceFailure != null) {
        AlertDialog(
            onDismissRequest = onDismissVoiceFailure,
            title = { Text(stringResource(R.string.transcription_failure_title)) },
            text = { Text(voiceFailure.message) },
            confirmButton = {
                TextButton(onClick = onDismissVoiceFailure) {
                    Text(stringResource(R.string.common_ok))
                }
            },
        )
    }
}

@Composable
private fun IOSVoiceProcessingWorkflow(
    stage: VoiceNoteProcessingStage,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .shadow(
                20.dp,
                RoundedCornerShape(24.dp),
                ambientColor = Color.Black.copy(alpha = 0.10f),
                spotColor = Color.Black.copy(alpha = 0.10f),
            )
            .background(ChillColors.BackgroundSecondary, RoundedCornerShape(24.dp))
            .border(1.dp, Color.White.copy(alpha = 0.20f), RoundedCornerShape(24.dp)),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            IOSVoiceProcessingRow(
                title = stringResource(R.string.voice_processing_stage_transcribing_title),
                subtitle = stringResource(R.string.voice_processing_stage_transcribing_subtitle),
                icon = Icons.Outlined.GraphicEq,
                active = stage == VoiceNoteProcessingStage.Transcribing,
                completed = stage == VoiceNoteProcessingStage.Refining,
            )
            IOSVoiceProcessingRow(
                title = stringResource(R.string.voice_processing_stage_refining_title),
                subtitle = stringResource(R.string.voice_processing_stage_refining_subtitle),
                icon = Icons.Outlined.AutoAwesome,
                active = stage == VoiceNoteProcessingStage.Refining,
                completed = false,
            )
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(ChillColors.BorderSubtle))
        Row(
            Modifier.fillMaxWidth().background(ChillColors.TextMain.copy(alpha = 0.02f)).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Outlined.AutoAwesome,
                contentDescription = null,
                tint = ChillColors.TextSub,
                modifier = Modifier.size(14.dp),
            )
            Text(
                stringResource(R.string.voice_processing_persistent_hint),
                color = ChillColors.TextSub,
                fontSize = 12.sp,
                lineHeight = 16.sp,
            )
        }
    }
}

@Composable
private fun IOSVoiceProcessingRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    active: Boolean,
    completed: Boolean,
) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 58.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(24.dp).background(
                when {
                    completed -> Color(0xFF2E9B59)
                    active -> ChillColors.BrandBlue
                    else -> ChillColors.TextSub.copy(alpha = 0.10f)
                },
                CircleShape,
            ),
            contentAlignment = Alignment.Center,
        ) {
            if (active) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp,
                )
            } else {
                Icon(
                    if (completed) Icons.Outlined.Check else icon,
                    contentDescription = null,
                    tint = if (completed) Color.White else ChillColors.TextSub.copy(alpha = 0.45f),
                    modifier = Modifier.size(12.dp),
                )
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                title,
                color = if (active || completed) ChillColors.TextMain else ChillColors.TextSub.copy(alpha = 0.65f),
                fontSize = 15.sp,
                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
            )
            Text(
                subtitle,
                color = ChillColors.TextSub,
                fontSize = 12.sp,
                lineHeight = 16.sp,
            )
        }
    }
}

@Composable
private fun IOSVoiceRefinedOverlay(
    onShowOriginal: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .shadow(
                10.dp,
                CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.10f),
                spotColor = Color.Black.copy(alpha = 0.10f),
            )
            .background(Color.White.copy(alpha = 0.96f), CircleShape)
            .border(1.5.dp, ChillColors.BrandBlue.copy(alpha = 0.34f), CircleShape)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.AutoAwesome,
            contentDescription = null,
            tint = ChillColors.BrandBlue,
            modifier = Modifier.size(14.dp),
        )
        Text(
            stringResource(R.string.voice_refined),
            color = ChillColors.TextMain,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Box(Modifier.width(1.dp).height(16.dp).background(ChillColors.TextMain.copy(alpha = 0.10f)))
        Text(
            stringResource(R.string.voice_show_original),
            color = ChillColors.BrandBlueText,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable(onClick = onShowOriginal),
        )
    }
}

@Composable
private fun IOSParityEditorSnackbarHost(
    hostState: SnackbarHostState,
    modifier: Modifier = Modifier,
) {
    SnackbarHost(
        hostState = hostState,
        modifier = modifier,
    ) { data ->
        if (data.visuals.actionLabel != null) {
            IOSRefinedSnackbar(data)
        } else {
            Snackbar(
                snackbarData = data,
                shape = RoundedCornerShape(14.dp),
                containerColor = ChillColors.TextMain,
                contentColor = Color.White,
            )
        }
    }
}

@Composable
private fun IOSRefinedSnackbar(data: SnackbarData) {
    val shape = CircleShape
    Row(
        Modifier
            .shadow(
                elevation = 10.dp,
                shape = shape,
                ambientColor = Color.Black.copy(alpha = 0.10f),
                spotColor = Color.Black.copy(alpha = 0.10f),
            )
            .background(Color.White.copy(alpha = 0.97f), shape)
            .border(
                width = 1.5.dp,
                brush = Brush.horizontalGradient(
                    listOf(
                        ChillColors.BrandBlue.copy(alpha = 0.40f),
                        Color(0xFFAF52DE).copy(alpha = 0.40f),
                    ),
                ),
                shape = shape,
            )
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            Icons.Outlined.AutoAwesome,
            contentDescription = null,
            tint = ChillColors.BrandBlue,
            modifier = Modifier.size(15.dp),
        )
        Text(
            data.visuals.message,
            color = ChillColors.TextMain,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Box(
            Modifier
                .padding(horizontal = 4.dp)
                .width(1.dp)
                .height(16.dp)
                .background(ChillColors.TextMain.copy(alpha = 0.10f)),
        )
        Text(
            data.visuals.actionLabel.orEmpty(),
            color = ChillColors.BrandBlueText,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable { data.performAction() },
        )
    }
}

@Composable
private fun IOSAIAppliedActionBar(
    retrying: Boolean,
    onRetry: () -> Unit,
    onUndo: () -> Unit,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier
            .height(60.dp)
            .widthIn(max = 360.dp)
            .shadow(
                elevation = 12.dp,
                shape = shape,
                ambientColor = Color.Black.copy(alpha = 0.10f),
                spotColor = Color.Black.copy(alpha = 0.10f),
            )
            .clip(shape)
            .background(
                Brush.horizontalGradient(
                    listOf(
                        ChillColors.BrandTealSoft.copy(alpha = 0.45f),
                        ChillColors.BrandTeal.copy(alpha = 0.08f),
                        Color.White,
                    ),
                ),
            )
            .padding(end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        IOSAIAction(
            icon = Icons.Outlined.Refresh,
            label = stringResource(R.string.common_retry),
            enabled = !retrying,
            showProgress = retrying,
            onClick = onRetry,
        )
        IOSAIActionDivider()
        IOSAIAction(
            icon = Icons.AutoMirrored.Outlined.Undo,
            label = stringResource(R.string.common_undo),
            enabled = !retrying,
            onClick = onUndo,
        )
        IOSAIActionDivider()
        IOSAIAction(
            icon = Icons.Outlined.Check,
            label = stringResource(R.string.common_save),
            enabled = !retrying,
            onClick = onSave,
        )
    }
}

@Composable
private fun IOSAIAction(
    icon: ImageVector,
    label: String,
    enabled: Boolean,
    showProgress: Boolean = false,
    onClick: () -> Unit,
) {
    Column(
        Modifier
            .width(60.dp)
            .height(50.dp)
            .clickable(enabled = enabled, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (showProgress) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = ChillColors.BrandTealText,
                strokeWidth = 2.dp,
            )
        } else {
            Icon(
                icon,
                contentDescription = null,
                tint = ChillColors.BrandTealText.copy(alpha = if (enabled) 1f else 0.35f),
                modifier = Modifier.size(18.dp),
            )
        }
        Text(
            label,
            color = ChillColors.BrandTealText.copy(alpha = if (enabled) 1f else 0.35f),
            fontSize = 10.sp,
            lineHeight = 12.sp,
        )
    }
}

@Composable
private fun IOSAIActionDivider() {
    Box(
        Modifier
            .width(1.dp)
            .height(30.dp)
            .background(ChillColors.TextSub.copy(alpha = 0.20f)),
    )
}

@Composable
private fun IOSTrashCountdown(deletedAt: String?) {
    val days = deletedAt?.let(TrashPolicy::daysRemaining) ?: return
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .background(Color.Red.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Outlined.Delete, contentDescription = null, tint = Color.Red.copy(alpha = 0.8f), modifier = Modifier.size(16.dp))
        Text(
            if (days == 0L) stringResource(R.string.note_detail_trash_deleted_today)
            else stringResource(R.string.note_detail_trash_deleted_in_days, days),
            color = ChillColors.TextSub,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun IOSNoteContext(
    note: NoteEntity?,
    tags: List<TagEntity>,
    isDeleted: Boolean,
    onOpenSource: (String) -> Unit,
    onRemoveTag: (TagEntity) -> Unit,
) {
    if (note == null || (note.sourceUrl == null && tags.isEmpty() && note.importStatus == null)) return
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        note.sourceMetadata()?.let { source ->
            Box(Modifier.alpha(if (isDeleted) 0.5f else 1f)) {
                NoteSourceCard(source = source, onOpen = { if (!isDeleted) onOpenSource(source.url) })
            }
        }
        when (note.importStatus) {
            "queued", "processing" -> IOSImportBanner(R.string.link_import_processing, Icons.Outlined.AddLink)
            "failed" -> IOSImportBanner(R.string.link_import_failed, Icons.Outlined.Warning)
        }
        if (tags.isNotEmpty()) {
            Row(
                modifier = Modifier.alpha(if (isDeleted) 0.5f else 1f),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                tags.take(4).forEach { tag ->
                    val normalized = remember(tag.colorHex) { TagColors.normalize(tag.colorHex) }
                    val color = remember(normalized) { runCatching { Color(android.graphics.Color.parseColor(normalized)) }.getOrDefault(ChillColors.BrandBlue) }
                    Text(
                        tag.name,
                        color = color,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .background(color.copy(alpha = 0.12f), CircleShape)
                            .clickable(enabled = !isDeleted) { onRemoveTag(tag) }
                            .padding(horizontal = 9.dp, vertical = 5.dp),
                    )
                }
            }
        }
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(ChillColors.BorderSubtle))
}

@Composable
private fun IOSImportBanner(textResource: Int, icon: ImageVector) {
    Row(
        Modifier.fillMaxWidth().background(ChillColors.BrandBlue.copy(alpha = 0.08f), RoundedCornerShape(8.dp)).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(15.dp))
        Text(stringResource(textResource), color = ChillColors.TextSub, fontSize = 13.sp)
    }
}

@Composable
private fun IOSWorkspacePicker(
    selected: IOSNoteWorkspace,
    createEnabled: Boolean,
    guideStage: HomeFirstActionStage,
    onCreateBounds: (Rect) -> Unit,
    onRecordBounds: (Rect) -> Unit,
    onSelect: (IOSNoteWorkspace) -> Unit,
) {
    val pages = listOf(
        IOSNoteWorkspace.NOTE to R.string.note_workspace_note,
        IOSNoteWorkspace.CREATE to R.string.note_workspace_create,
        IOSNoteWorkspace.RECORD to R.string.note_workspace_record,
    )
    Row(
        Modifier.fillMaxWidth().height(56.dp).background(ChillColors.BackgroundSecondary),
        verticalAlignment = Alignment.Bottom,
    ) {
        pages.forEach { (page, title) ->
            val requiredPage = when (guideStage) {
                HomeFirstActionStage.ReviewTranscript -> IOSNoteWorkspace.NOTE
                HomeFirstActionStage.TapCreateTab,
                HomeFirstActionStage.TapAISkills,
                HomeFirstActionStage.WaitingForAISkillsDismissal -> IOSNoteWorkspace.CREATE
                HomeFirstActionStage.TapRecordTab,
                HomeFirstActionStage.TapTeleprompter -> IOSNoteWorkspace.RECORD
                else -> null
            }
            val enabled = (page != IOSNoteWorkspace.CREATE || createEnabled) && (requiredPage == null || page == requiredPage)
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .onGloballyPositioned { coordinates ->
                        when (page) {
                            IOSNoteWorkspace.CREATE -> onCreateBounds(coordinates.boundsInRoot())
                            IOSNoteWorkspace.RECORD -> onRecordBounds(coordinates.boundsInRoot())
                            else -> Unit
                        }
                    }
                    .clickable(enabled = enabled, role = Role.Tab) { onSelect(page) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom,
            ) {
                Spacer(Modifier.weight(1f))
                Text(
                    stringResource(title),
                    color = if (!enabled) ChillColors.TextSub.copy(alpha = 0.45f)
                    else if (selected == page) ChillColors.BrandBlueText else ChillColors.TextMain,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(14.dp))
                Box(
                    Modifier.width(96.dp).height(3.dp).background(
                        if (selected == page) ChillColors.BrandBlue else Color.Transparent,
                        CircleShape,
                    ),
                )
            }
        }
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(ChillColors.BorderSubtle))
}

@Composable
private fun IOSNoteEditor(
    value: TextFieldValue,
    enabled: Boolean,
    onValueChange: (TextFieldValue) -> Unit,
    onOpenLink: (String) -> Unit,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
) {
    EditableRichMarkdown(
        value = value,
        enabled = enabled,
        placeholder = stringResource(R.string.note_editor_placeholder),
        onValueChange = onValueChange,
        onOpenLink = onOpenLink,
        modifier = modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp).focusRequester(focusRequester),
    )
}

@Composable
private fun IOSCreateWorkspace(
    recipes: List<AgentRecipe>,
    enabled: Boolean,
    onSelect: (AgentRecipe) -> Unit,
    onManageSkills: () -> Unit,
    minimumHeight: androidx.compose.ui.unit.Dp,
    onFirstSkillBounds: (Rect) -> Unit,
    onFirstSkillSelected: () -> Unit,
    guideStage: HomeFirstActionStage,
) {
    if (recipes.isEmpty()) {
        Column(
            Modifier.fillMaxWidth().heightIn(min = minimumHeight).padding(20.dp),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(Icons.Outlined.AutoAwesome, contentDescription = null, tint = ChillColors.BrandTeal, modifier = Modifier.size(28.dp))
            Text(stringResource(R.string.note_detail_ai_skills_empty_title), color = ChillColors.TextMain, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.note_detail_ai_skills_empty_message), color = ChillColors.TextSub, fontSize = 17.sp, lineHeight = 24.sp)
            IOSManageSkillsButton(onManageSkills, Modifier.padding(top = 4.dp))
        }
    } else {
        Column(
            Modifier.fillMaxWidth().heightIn(min = minimumHeight).padding(start = 20.dp, top = 14.dp, end = 20.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            recipes.forEachIndexed { index, recipe ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = ChillColors.Shadow, spotColor = ChillColors.Shadow)
                    .background(ChillColors.BackgroundSecondary, RoundedCornerShape(16.dp))
                    .border(1.dp, ChillColors.BorderSubtle, RoundedCornerShape(16.dp))
                    .onGloballyPositioned { coordinates -> if (index == 0) onFirstSkillBounds(coordinates.boundsInRoot()) }
                    .clickable(enabled = enabled) {
                        if (index == 0 && guideStage == HomeFirstActionStage.TapAISkills) onFirstSkillSelected()
                        onSelect(recipe)
                    }
                    .padding(horizontal = 14.dp)
                    .height(64.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                CreatorSkillIcon(
                    recipe = recipe,
                    container = 44.dp,
                    iconSize = 20.dp,
                )
                Text(
                    recipeName(recipe),
                    color = ChillColors.TextMain,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    modifier = Modifier.weight(1f),
                )
                Icon(Icons.AutoMirrored.Outlined.ArrowForwardIos, contentDescription = null, tint = ChillColors.TextSub, modifier = Modifier.size(15.dp))
            }
        }
            IOSManageSkillsButton(onManageSkills, Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
private fun IOSManageSkillsButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .fillMaxWidth()
            .height(54.dp)
            .background(ChillColors.BrandBlueSoft, RoundedCornerShape(16.dp))
            .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.22f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Outlined.Settings, contentDescription = null, tint = ChillColors.BrandBlueText, modifier = Modifier.size(21.dp))
        Text(
            stringResource(R.string.note_workspace_manage_skills),
            color = ChillColors.BrandBlueText,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Icon(Icons.AutoMirrored.Outlined.ArrowForwardIos, contentDescription = null, tint = ChillColors.BrandBlueText.copy(alpha = 0.72f), modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun IOSRecordWorkspace(
    script: String,
    enabled: Boolean,
    onStartRecording: () -> Unit,
    minimumHeight: androidx.compose.ui.unit.Dp,
    onStartBounds: (Rect) -> Unit,
    onFirstActionStart: () -> Unit,
    guideStage: HomeFirstActionStage,
) {
    val emptyScript = stringResource(R.string.teleprompter_script_empty_placeholder)
    val pages = remember(script, emptyScript) { teleprompterPages(script, emptyScript) }
    val pagerState = rememberPagerState(pageCount = { pages.size })
    Column(
        Modifier.fillMaxWidth().heightIn(min = minimumHeight).padding(horizontal = 28.dp).padding(top = 22.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            Modifier
                .width(220.dp)
                .height(318.dp)
                .shadow(10.dp, RoundedCornerShape(20.dp), ambientColor = Color.Black.copy(alpha = 0.14f), spotColor = Color.Black.copy(alpha = 0.14f))
                .background(Color(0xFF111418), RoundedCornerShape(20.dp))
                .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(20.dp))
                .clip(RoundedCornerShape(20.dp)),
        ) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { index ->
                    Text(
                        pages[index],
                        color = Color.White,
                        fontSize = 18.sp,
                        lineHeight = 30.sp,
                        fontWeight = FontWeight.Medium,
                        maxLines = 9,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp).padding(top = 34.dp, bottom = 18.dp),
                    )
                }
                Box(
                    Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(118.dp).background(
                        Brush.verticalGradient(listOf(Color.Transparent, Color(0xFF111418).copy(alpha = 0.66f), Color(0xFF111418))),
                    ),
                )
            }
            Row(
                Modifier.fillMaxWidth().height(28.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                pages.indices.forEach { index ->
                    Box(
                        Modifier.size(6.dp).background(
                            if (index == pagerState.currentPage) Color.White else Color.White.copy(alpha = 0.28f),
                            CircleShape,
                        ),
                    )
                }
            }
        }
        Row(
            Modifier.padding(top = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Outlined.Check, contentDescription = null, tint = Color(0xFF2E9B59), modifier = Modifier.size(21.dp))
            Text(stringResource(R.string.note_workspace_script_ready), color = ChillColors.TextMain, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
        Surface(
            onClick = {
                if (guideStage == HomeFirstActionStage.TapTeleprompter) onFirstActionStart()
                onStartRecording()
            },
            enabled = enabled,
            color = ChillColors.BrandBlue.copy(alpha = if (enabled) 1f else 0.5f),
            shape = CircleShape,
            modifier = Modifier
                .padding(top = 18.dp)
                .fillMaxWidth()
                .height(56.dp)
                .onGloballyPositioned { onStartBounds(it.boundsInRoot()) },
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.note_workspace_start_recording), color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(
            stringResource(R.string.note_workspace_record_metadata),
            color = ChillColors.TextSub,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(top = 12.dp),
        )
    }
}

@Composable
private fun IOSKeyboardToolbar(
    canUndo: Boolean,
    canRedo: Boolean,
    onBold: () -> Unit,
    onChecklist: () -> Unit,
    onUndo: () -> Unit,
    onRedo: () -> Unit,
    onHideKeyboard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier.fillMaxWidth().height(48.dp).background(Color(0xFFF9F9F7)).border(1.dp, ChillColors.BorderSubtle),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        Text(
            stringResource(R.string.markdown_toolbar_bold),
            color = ChillColors.TextMain,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.clickable(onClick = onBold).padding(12.dp),
        )
        IOSKeyboardTool(Icons.Outlined.CheckBox, R.string.markdown_toolbar_checklist, true, onChecklist)
        IOSKeyboardTool(Icons.AutoMirrored.Outlined.Undo, R.string.markdown_toolbar_undo, canUndo, onUndo)
        IOSKeyboardTool(Icons.AutoMirrored.Outlined.Redo, R.string.markdown_toolbar_redo, canRedo, onRedo)
        IOSKeyboardTool(Icons.Outlined.KeyboardHide, R.string.note_workspace_hide_keyboard, true, onHideKeyboard)
    }
}

@Composable
private fun IOSKeyboardTool(icon: ImageVector, label: Int, enabled: Boolean, onClick: () -> Unit) {
    IconButton(onClick = onClick, enabled = enabled) {
        Icon(icon, contentDescription = stringResource(label), tint = ChillColors.TextMain.copy(alpha = if (enabled) 1f else 0.3f))
    }
}

@Composable
private fun IOSNoteMenuItem(title: Int, icon: ImageVector, destructive: Boolean = false, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(stringResource(title), color = if (destructive) MaterialTheme.colorScheme.error else ChillColors.TextMain) },
        leadingIcon = { Icon(icon, contentDescription = null, tint = if (destructive) MaterialTheme.colorScheme.error else ChillColors.TextSub) },
        onClick = onClick,
    )
}

private fun teleprompterPages(script: String, emptyScript: String): List<String> {
    val words = script.trim().split(Regex("\\s+")).filter(String::isNotBlank)
    if (words.isEmpty()) return listOf(emptyScript)
    val pageCount = ((words.size + 69) / 70).coerceIn(1, 3)
    val pageSize = (words.size + pageCount - 1) / pageCount
    return words.chunked(pageSize).map { it.joinToString(" ") }
}
