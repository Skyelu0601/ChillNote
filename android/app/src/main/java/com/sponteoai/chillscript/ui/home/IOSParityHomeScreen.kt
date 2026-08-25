package com.sponteoai.chillscript.ui.home

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete as FilledDelete
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Error
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Menu
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.outlined.Restore
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarData
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TagHierarchy
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.MarkdownImages
import com.sponteoai.chillscript.domain.sourceMetadata
import com.sponteoai.chillscript.ui.markdown.MarkdownText
import com.sponteoai.chillscript.ui.source.NoteSourceCard
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/**
 * The Android rendering of the current iOS HomeView shell.
 *
 * The SwiftUI HomeHeaderView, HomeSectionPicker, HomeNotesListView,
 * ChatInputBar, and SidebarView remain the source of truth. This component is
 * intentionally callback driven so Android data and business logic do not
 * leak Material defaults back into the visible product.
 */
@Composable
fun IOSParityHomeScreen(
    notes: List<NoteEntity>,
    allNotes: List<NoteEntity>,
    tags: List<TagEntity>,
    noteTags: List<NoteTagCrossRef>,
    selectedSection: String,
    selectedTagId: String?,
    headerTitle: String,
    showSectionPicker: Boolean,
    searchVisible: Boolean,
    searchQuery: String,
    isSelectionMode: Boolean,
    selectedNoteIds: Set<String>,
    isRecording: Boolean,
    isVoiceProcessing: Boolean,
    initialNotesSyncing: Boolean,
    hasLoadedNotesAtLeastOnce: Boolean,
    pendingRecordingsCount: Int,
    subscriptionTier: String,
    creditBalance: Int?,
    snackbarHostState: SnackbarHostState,
    onSelectSection: (String) -> Unit,
    onToggleSearch: () -> Unit,
    onSearchQueryChange: (String) -> Unit,
    onOpenNote: (NoteEntity) -> Unit,
    onToggleNoteSelection: (NoteEntity) -> Unit,
    onEnterSelectionMode: () -> Unit,
    onExitSelectionMode: () -> Unit,
    onSelectAll: () -> Unit,
    onDeleteSelection: () -> Unit,
    onStartAIChat: () -> Unit,
    onPin: (NoteEntity) -> Unit,
    onManageTags: (NoteEntity) -> Unit,
    onMove: (NoteEntity, String) -> Unit,
    onDelete: (NoteEntity) -> Unit,
    onRestore: (NoteEntity) -> Unit,
    onPermanentDelete: (NoteEntity) -> Unit,
    onOpenSource: (String) -> Unit,
    onEmptyTrash: () -> Unit,
    onCreateBlankNote: () -> Unit,
    onStartVoiceRecording: () -> Unit,
    onCancelVoiceRecording: () -> Unit,
    onConfirmVoiceRecording: () -> Unit,
    onPasteLink: (((Boolean) -> Unit) -> Unit),
    onOpenSubscription: () -> Unit,
    onOpenWeeklyTopics: () -> Unit,
    onOpenPendingRecordings: () -> Unit,
    onOpenSettings: () -> Unit,
    onSelectTag: (TagEntity) -> Unit,
    onMoveTag: (TagEntity, String?) -> Unit,
    onDeleteTag: (TagEntity) -> Unit,
    firstActionGuideState: HomeFirstActionGuideState,
    onAcknowledgeFirstActionShare: () -> Unit,
    onDismissFirstActionGuide: () -> Unit,
    onOpenFirstActionTarget: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var sidebarOpen by remember { mutableStateOf(false) }
    var guideTargetBounds by remember(firstActionGuideState.targetNoteId) { mutableStateOf<Rect?>(null) }
    val isTrash = selectedSection == "trash"
    val locale = LocalLocale.current.platformLocale
    val density = LocalDensity.current
    val haptics = androidx.compose.ui.platform.LocalHapticFeedback.current
    val sidebarOpenEdgeWidthPx = with(density) { 110.dp.toPx() }
    val sidebarOpenGestureDistancePx = with(density) { 16.dp.toPx() }
    val sidebarOpenMinTranslationPx = with(density) { 36.dp.toPx() }
    val sidebarHorizontalBiasPx = with(density) { 12.dp.toPx() }

    BackHandler(enabled = sidebarOpen) { sidebarOpen = false }

    Box(
        modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .observeHorizontalSwipe(
                enabled = !sidebarOpen,
                edgeWidthPx = sidebarOpenEdgeWidthPx,
                minimumGestureDistancePx = sidebarOpenGestureDistancePx,
                minimumTranslationPx = sidebarOpenMinTranslationPx,
                horizontalBiasPx = sidebarHorizontalBiasPx,
                direction = HorizontalSwipeDirection.Right,
            ) {
                sidebarOpen = true
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            },
    ) {
        Column(Modifier.fillMaxSize()) {
            IOSHomeHeader(
                isSelectionMode = isSelectionMode,
                isTrash = isTrash,
                isSearchVisible = searchVisible,
                isRecording = isRecording,
                headerTitle = headerTitle,
                selectedCount = selectedNoteIds.size,
                visibleCount = notes.size,
                hasPendingRecordings = pendingRecordingsCount > 0,
                onSidebar = { sidebarOpen = true },
                onToggleSearch = onToggleSearch,
                onExitSelection = onExitSelectionMode,
                onSelectAll = onSelectAll,
                onDeleteSelection = onDeleteSelection,
                onEmptyTrash = onEmptyTrash,
            )

            AnimatedVisibility(
                visible = searchVisible,
                enter = fadeIn() + slideInHorizontally(initialOffsetX = { it / 8 }),
                exit = fadeOut() + slideOutHorizontally(targetOffsetX = { it / 8 }),
            ) {
                IOSHomeSearchBar(
                    value = searchQuery,
                    onValueChange = onSearchQueryChange,
                    modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 16.dp),
                )
            }

            if (!isTrash && showSectionPicker) {
                IOSHomeSectionPicker(
                    selectedSection = selectedSection,
                    onSelectSection = onSelectSection,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                )
            }

            Box(Modifier.weight(1f)) {
                if (notes.isEmpty() && !hasLoadedNotesAtLeastOnce) {
                    IOSHomeNotesLoadingView(Modifier.fillMaxSize())
                } else if (notes.isEmpty() && initialNotesSyncing) {
                    IOSHomeNotesSyncingView(Modifier.fillMaxSize())
                } else if (isVoiceProcessing && notes.isEmpty()) {
                    Row(
                        Modifier.align(Alignment.Center).padding(horizontal = 32.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(22.dp),
                            color = ChillColors.BrandBlue,
                            strokeWidth = 2.5.dp,
                        )
                        Text(
                            stringResource(R.string.voice_processing),
                            color = ChillColors.TextSub,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                } else if (notes.isEmpty() && firstActionGuideState.stage != HomeFirstActionStage.SharePrompt) {
                    IOSHomeEmptyState(
                        section = selectedSection,
                        hasActiveSearch = searchQuery.isNotBlank(),
                        modifier = Modifier.fillMaxSize(),
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            start = 24.dp,
                            top = 4.dp,
                            end = 24.dp,
                            bottom = when {
                                isSelectionMode -> 116.dp
                                isTrash || searchVisible -> 28.dp
                                else -> 106.dp
                            },
                        ),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        items(notes, key = { it.id }) { note ->
                            IOSNoteCard(
                                note = note,
                                tags = tagsForNote(note.id, tags, noteTags),
                                searchQuery = searchQuery,
                                isTrash = isTrash,
                                isSelectionMode = isSelectionMode,
                                isSelected = note.id in selectedNoteIds,
                                locale = locale,
                                onClick = {
                                    if (isSelectionMode) {
                                        onToggleNoteSelection(note)
                                    } else {
                                        if (note.id == firstActionGuideState.targetNoteId) onOpenFirstActionTarget()
                                        onOpenNote(note)
                                    }
                                },
                                onToggleSelection = { onToggleNoteSelection(note) },
                                onEnterSelectionMode = onEnterSelectionMode,
                                onPin = { onPin(note) },
                                onManageTags = { onManageTags(note) },
                                onMove = { onMove(note, it) },
                                onDelete = { onDelete(note) },
                                onRestore = { onRestore(note) },
                                onPermanentDelete = { onPermanentDelete(note) },
                                onOpenSource = onOpenSource,
                                modifier = if (note.id == firstActionGuideState.targetNoteId) {
                                    Modifier.onGloballyPositioned { guideTargetBounds = it.boundsInRoot() }
                                } else Modifier,
                            )
                        }
                    }
                }
            }
        }

        if (!isTrash && !isSelectionMode && !searchVisible) {
            IOSQuickCaptureDock(
                isRecording = isRecording,
                isVoiceProcessing = isVoiceProcessing,
                isLinkProcessing = allNotes.any {
                    it.deletedAt == null && it.sourceUrl != null && it.importStatus in setOf("queued", "processing")
                },
                onStartRecording = onStartVoiceRecording,
                onCancelRecording = onCancelVoiceRecording,
                onConfirmRecording = onConfirmVoiceRecording,
                onPasteLink = onPasteLink,
                onCreateText = onCreateBlankNote,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .imePadding()
                    .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 4.dp),
            )
        }

        if (isSelectionMode) {
            IOSSelectionAIAction(
                hasSelection = selectedNoteIds.isNotEmpty(),
                onClick = onStartAIChat,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 24.dp)
                    .padding(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 12.dp),
            )
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 24.dp)
                .padding(
                    bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() +
                        if (isSelectionMode || (!isTrash && !searchVisible)) 96.dp else 12.dp,
                ),
        ) { data -> IOSHomeSnackbar(data) }

        IOSHomeSidebar(
            visible = sidebarOpen,
            notes = allNotes,
            tags = tags,
            selectedSection = if (showSectionPicker || isTrash) selectedSection else "",
            selectedTagId = selectedTagId,
            pendingRecordingsCount = pendingRecordingsCount,
            subscriptionTier = subscriptionTier,
            creditBalance = creditBalance,
            locale = locale,
            onDismiss = { sidebarOpen = false },
            onSelectSection = {
                onSelectSection(it)
                sidebarOpen = false
            },
            onOpenSubscription = {
                sidebarOpen = false
                onOpenSubscription()
            },
            onOpenWeeklyTopics = {
                sidebarOpen = false
                onOpenWeeklyTopics()
            },
            onOpenPendingRecordings = {
                sidebarOpen = false
                onOpenPendingRecordings()
            },
            onOpenSettings = {
                sidebarOpen = false
                onOpenSettings()
            },
            onSelectTag = { tag ->
                sidebarOpen = false
                onSelectTag(tag)
            },
            onMoveTag = onMoveTag,
            onDeleteTag = onDeleteTag,
        )

        AnimatedVisibility(
            visible = firstActionGuideState.stage == HomeFirstActionStage.SharePrompt,
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = slideInVertically(
                animationSpec = spring(dampingRatio = 0.86f, stiffness = Spring.StiffnessMediumLow),
                initialOffsetY = { it },
            ) + fadeIn(animationSpec = spring(dampingRatio = 0.86f, stiffness = Spring.StiffnessMediumLow)),
            exit = slideOutVertically(
                animationSpec = spring(dampingRatio = 0.86f, stiffness = Spring.StiffnessMediumLow),
                targetOffsetY = { it },
            ) + fadeOut(animationSpec = spring(dampingRatio = 0.86f, stiffness = Spring.StiffnessMediumLow)),
        ) {
            IOSFirstActionSharePrompt(
                onAcknowledge = onAcknowledgeFirstActionShare,
                onDismiss = onDismissFirstActionGuide,
                modifier = Modifier.padding(
                    bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 104.dp,
                ),
            )
        }

        if (firstActionGuideState.stage == HomeFirstActionStage.OpenImportedNote) {
            guideTargetBounds?.let { bounds ->
                IOSFirstActionImportedNoteSpotlight(
                    targetBounds = bounds,
                    onDismiss = onDismissFirstActionGuide,
                )
            }
        }
    }
}

private enum class HorizontalSwipeDirection { Left, Right }

/**
 * Observes a horizontal swipe without consuming it, so a vertical note/tag
 * list keeps its native scrolling behavior. The projected end mirrors the
 * predicted-end check used by the iOS DragGesture implementation.
 */
private fun Modifier.observeHorizontalSwipe(
    enabled: Boolean,
    edgeWidthPx: Float? = null,
    minimumGestureDistancePx: Float,
    minimumTranslationPx: Float,
    horizontalBiasPx: Float,
    direction: HorizontalSwipeDirection,
    onSwipe: () -> Unit,
): Modifier = pointerInput(
    enabled,
    edgeWidthPx,
    minimumGestureDistancePx,
    minimumTranslationPx,
    horizontalBiasPx,
    direction,
) {
    if (!enabled) return@pointerInput
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        if (edgeWidthPx != null && down.position.x > edgeWidthPx) return@awaitEachGesture

        val velocityTracker = VelocityTracker()
        velocityTracker.addPosition(down.uptimeMillis, down.position)
        var lastPosition = down.position
        var stillPressed = true
        while (stillPressed) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull { it.id == down.id } ?: break
            lastPosition = change.position
            velocityTracker.addPosition(change.uptimeMillis, change.position)
            stillPressed = change.pressed
        }

        val translation = lastPosition - down.position
        val velocity = velocityTracker.calculateVelocity()
        val projectedHorizontal = translation.x + velocity.x * 0.12f
        if (translation.getDistance() < minimumGestureDistancePx) return@awaitEachGesture
        val enoughDistance = when (direction) {
            HorizontalSwipeDirection.Right ->
                translation.x >= minimumTranslationPx || projectedHorizontal >= minimumTranslationPx * 1.3f
            HorizontalSwipeDirection.Left ->
                translation.x <= -minimumTranslationPx || projectedHorizontal <= -minimumTranslationPx * 1.3f
        }
        val correctDirection = when (direction) {
            HorizontalSwipeDirection.Right -> translation.x > 0f
            HorizontalSwipeDirection.Left -> translation.x < 0f
        }
        val mostlyHorizontal = abs(translation.x) > abs(translation.y) + horizontalBiasPx
        if (enoughDistance && correctDirection && mostlyHorizontal) onSwipe()
    }
}

@Composable
private fun IOSHomeNotesLoadingView(modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 24.dp,
            end = 24.dp,
            bottom = 100.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        items(4) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .background(ChillColors.CardBackground, RoundedCornerShape(16.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier
                        .width(90.dp)
                        .height(10.dp)
                        .background(ChillColors.TextSub.copy(alpha = 0.25f), RoundedCornerShape(4.dp)),
                )
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(14.dp)
                        .background(ChillColors.TextSub.copy(alpha = 0.20f), RoundedCornerShape(6.dp)),
                )
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(14.dp)
                        .background(ChillColors.TextSub.copy(alpha = 0.16f), RoundedCornerShape(6.dp)),
                )
                Box(
                    Modifier
                        .width(140.dp)
                        .height(14.dp)
                        .background(ChillColors.TextSub.copy(alpha = 0.12f), RoundedCornerShape(6.dp)),
                )
            }
        }
    }
}

@Composable
private fun IOSHomeNotesSyncingView(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(top = 92.dp, bottom = 180.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(24.dp),
            color = ChillColors.BrandBlue,
            strokeWidth = 2.5.dp,
        )
        Text(
            stringResource(R.string.home_notes_syncing),
            color = ChillColors.TextSub,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun IOSHomeSnackbar(data: SnackbarData) {
    Surface(
        color = ChillColors.TextMain.copy(alpha = 0.94f),
        shape = RoundedCornerShape(14.dp),
        shadowElevation = 8.dp,
    ) {
        Row(
            Modifier.padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                data.visuals.message,
                color = ChillColors.BackgroundPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f),
            )
            data.visuals.actionLabel?.let { actionLabel ->
                TextButton(onClick = data::performAction) {
                    Text(
                        actionLabel,
                        color = ChillColors.BrandBlue,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSSelectionAIAction(
    hasSelection: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var shouldShowSelectionHint by remember(hasSelection) { mutableStateOf(false) }
    val warningOrange = Color(0xFFFF9500)

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        AnimatedVisibility(
            visible = shouldShowSelectionHint && !hasSelection,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(warningOrange.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
                    .border(1.dp, warningOrange.copy(alpha = 0.22f), RoundedCornerShape(16.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Outlined.Error,
                    contentDescription = null,
                    tint = warningOrange,
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    stringResource(R.string.home_selection_overlay_select_notes_hint),
                    color = ChillColors.TextMain,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        Box(
            Modifier
                .fillMaxWidth()
                .height(56.dp)
                .shadow(
                    elevation = 10.dp,
                    shape = CircleShape,
                    ambientColor = ChillColors.BrandBlue.copy(alpha = 0.22f),
                    spotColor = ChillColors.BrandBlue.copy(alpha = 0.35f),
                )
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(
                        listOf(
                            ChillColors.BrandBlue,
                            ChillColors.BrandBlue.copy(alpha = 0.90f),
                        ),
                    ),
                )
                .clickable(role = Role.Button) {
                    if (hasSelection) onClick() else shouldShowSelectionHint = true
                },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                stringResource(R.string.ai_chat_start),
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun IOSHomeHeader(
    isSelectionMode: Boolean,
    isTrash: Boolean,
    isSearchVisible: Boolean,
    isRecording: Boolean,
    headerTitle: String,
    selectedCount: Int,
    visibleCount: Int,
    hasPendingRecordings: Boolean,
    onSidebar: () -> Unit,
    onToggleSearch: () -> Unit,
    onExitSelection: () -> Unit,
    onSelectAll: () -> Unit,
    onDeleteSelection: () -> Unit,
    onEmptyTrash: () -> Unit,
) {
    val sidebarDescription = stringResource(R.string.home_accessibility_open_sidebar)
    val searchDescription = stringResource(R.string.home_accessibility_search)
    val emptyTrashDescription = stringResource(R.string.home_accessibility_empty_recycle_bin)

    Box(
        Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(start = 24.dp, top = 20.dp, end = 24.dp, bottom = 2.dp)
            .height(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (isSelectionMode) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.common_cancel),
                    modifier = Modifier.clickable(onClick = onExitSelection).padding(vertical = 10.dp),
                    color = ChillColors.TextSub,
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    stringResource(
                        if (selectedCount < visibleCount) R.string.home_select_all else R.string.home_deselect_all,
                    ),
                    modifier = Modifier.clickable(onClick = onSelectAll).padding(10.dp),
                    color = ChillColors.BrandBlue,
                    style = MaterialTheme.typography.bodyMedium,
                )
                IconButton(onClick = onDeleteSelection, enabled = selectedCount > 0) {
                    Icon(
                        Icons.Outlined.Delete,
                        contentDescription = stringResource(R.string.home_batch_delete_action),
                        tint = Color(0xFFCC3A3A).copy(alpha = if (selectedCount > 0) 0.8f else 0.3f),
                    )
                }
            }
        } else {
            IOSRoundHeaderButton(
                icon = Icons.Outlined.Menu,
                contentDescription = sidebarDescription,
                onClick = onSidebar,
                modifier = Modifier.align(Alignment.CenterStart),
                badge = hasPendingRecordings,
            )

            IOSHomeWordmark(headerTitle)

            Row(
                modifier = Modifier.align(Alignment.CenterEnd),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                IOSRoundHeaderButton(
                    icon = Icons.Outlined.Search,
                    contentDescription = searchDescription,
                    onClick = onToggleSearch,
                    tint = if (isSearchVisible) ChillColors.BrandBlue else ChillColors.TextMain,
                    enabled = !isRecording,
                )
                if (isTrash) {
                    IOSRoundHeaderButton(
                        icon = Icons.Outlined.DeleteSweep,
                        contentDescription = emptyTrashDescription,
                        onClick = onEmptyTrash,
                        tint = Color(0xFFD14343),
                        bordered = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSRoundHeaderButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = ChillColors.TextMain,
    badge: Boolean = false,
    bordered: Boolean = false,
    enabled: Boolean = true,
) {
    Box(modifier.size(44.dp), contentAlignment = Alignment.Center) {
        IconButton(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxSize()) {
            Icon(
                icon,
                contentDescription,
                tint = tint.copy(alpha = if (enabled) 1f else 0.3f),
                modifier = Modifier.size(if (bordered) 18.dp else 24.dp),
            )
        }
        if (bordered) {
            Box(
                Modifier
                    .matchParentSize()
                    .padding(4.dp)
                    .border(1.dp, ChillColors.BorderSubtle, CircleShape),
            )
        }
        if (badge) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 6.dp, end = 5.dp)
                    .size(8.dp)
                    .background(Color.Red, CircleShape),
            )
        }
    }
}

@Composable
private fun IOSHomeWordmark(title: String) {
    if (title == "ChillScript") {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Chill",
                color = Color.Black,
                fontFamily = FontFamily.Serif,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Script",
                color = ChillColors.BrandBlue,
                fontFamily = FontFamily.Serif,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    } else {
        Text(
            text = title,
            color = Color.Black,
            fontFamily = FontFamily.Serif,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun IOSHomeSearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current
    LaunchedEffect(focusRequester) {
        focusRequester.requestFocus()
        keyboardController?.show()
    }
    Row(
        modifier
            .fillMaxWidth()
            .height(48.dp)
            .background(ChillColors.TextSub.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.Black.copy(alpha = 0.03f), RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Outlined.Search, contentDescription = null, tint = ChillColors.TextSub, modifier = Modifier.size(18.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f).focusRequester(focusRequester),
            textStyle = TextStyle(
                color = ChillColors.TextMain,
                fontSize = 15.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium,
            ),
            singleLine = true,
            cursorBrush = SolidColor(ChillColors.BrandBlue),
            decorationBox = { inner ->
                if (value.isEmpty()) {
                    Text(
                        stringResource(R.string.home_search_placeholder),
                        color = ChillColors.TextSub,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
                inner()
            },
        )
        if (value.isNotEmpty()) {
            IconButton(onClick = { onValueChange("") }, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.home_search_clear_accessibility),
                    tint = ChillColors.TextSub,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

@Composable
private fun IOSHomeSectionPicker(
    selectedSection: String,
    onSelectSection: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val sections = listOf(
        "inbox" to R.string.home_section_inbox,
        "drafts" to R.string.home_section_drafts,
        "published" to R.string.home_section_published,
    )
    Row(
        modifier.fillMaxWidth().height(52.dp).border(
            width = 0.dp,
            color = Color.Transparent,
            shape = RoundedCornerShape(0.dp),
        ),
    ) {
        sections.forEach { (section, title) ->
            val selected = selectedSection == section
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clickable(role = Role.Tab) {
                        if (!selected) onSelectSection(section)
                    },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom,
            ) {
                Spacer(Modifier.weight(1f))
                Text(
                    stringResource(title),
                    color = ChillColors.TextMain.copy(alpha = if (selected) 1f else 0.62f),
                    fontSize = 16.sp,
                    fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(10.dp))
                Box(
                    Modifier
                        .width(when (section) { "inbox" -> 64.dp; "drafts" -> 68.dp; else -> 96.dp })
                        .height(3.dp)
                        .background(if (selected) ChillColors.BrandBlue else Color.Transparent, CircleShape),
                )
            }
        }
    }
    Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp).height(1.dp).background(ChillColors.Separator.copy(alpha = 0.72f)))
}

@Composable
private fun IOSNoteCard(
    note: NoteEntity,
    tags: List<TagEntity>,
    searchQuery: String,
    isTrash: Boolean,
    isSelectionMode: Boolean,
    isSelected: Boolean,
    locale: Locale,
    onClick: () -> Unit,
    onToggleSelection: () -> Unit,
    onEnterSelectionMode: () -> Unit,
    onPin: () -> Unit,
    onManageTags: () -> Unit,
    onMove: (String) -> Unit,
    onDelete: () -> Unit,
    onRestore: () -> Unit,
    onPermanentDelete: () -> Unit,
    onOpenSource: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box {
            Row(
                Modifier
                    .fillMaxWidth()
                    .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = ChillColors.Shadow, spotColor = ChillColors.Shadow)
                    .background(ChillColors.CardBackground, RoundedCornerShape(16.dp))
                    .clickable(onClick = onClick)
                    .padding(16.dp),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (isSelectionMode) {
                    Icon(
                        if (isSelected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                        contentDescription = null,
                        tint = if (isSelected) ChillColors.BrandBlue else ChillColors.TextSub,
                        modifier = Modifier
                            .size(22.dp)
                            .semantics { role = Role.Checkbox }
                            .clickable(onClick = onToggleSelection),
                    )
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            relativeDate(note.createdAt, locale),
                            color = ChillColors.TextSub,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        if (note.pinnedAt != null) {
                            Icon(
                                Icons.Outlined.PushPin,
                                contentDescription = stringResource(R.string.note_pinned_accessibility),
                                tint = ChillColors.BrandBlue,
                                modifier = Modifier.padding(start = 4.dp).size(13.dp),
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        if (!isSelectionMode) Spacer(Modifier.width(28.dp))
                    }

                    when (note.importStatus) {
                        "queued", "processing" -> IOSLinkImportPreparingView()
                        else -> if (note.content.isNotBlank()) {
                            if (searchQuery.isBlank()) {
                                MarkdownText(
                                    markdown = note.content,
                                    maxLines = 5,
                                    modifier = Modifier.fillMaxWidth(),
                                )
                            } else {
                                Text(
                                    text = highlightedSearchPreview(note.content, searchQuery),
                                    color = ChillColors.TextMain,
                                    style = MaterialTheme.typography.bodyMedium,
                                    maxLines = 5,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.fillMaxWidth(),
                                )
                            }
                        }
                    }

                    if (tags.isNotEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            tags.take(3).forEach { tag -> IOSTagPill(tag, searchQuery) }
                            if (tags.size > 3) {
                                Text(
                                    "+${tags.size - 3}",
                                    color = ChillColors.TextSub,
                                    fontSize = 13.sp,
                                    modifier = Modifier.align(Alignment.CenterVertically),
                                )
                            }
                        }
                    }

                    note.sourceMetadata()?.let { source ->
                        NoteSourceCard(source = source, compact = true, onOpen = { onOpenSource(source.url) })
                    }

                    if (note.importStatus == "failed") {
                        Text(
                            stringResource(R.string.link_import_failed),
                            color = MaterialTheme.colorScheme.error,
                            fontSize = 13.sp,
                        )
                    }
                }
            }

            if (!isSelectionMode) {
                IconButton(
                    onClick = { menuOpen = true },
                    modifier = Modifier.align(Alignment.TopEnd).padding(top = 6.dp, end = 6.dp),
                ) {
                    Icon(
                        Icons.Outlined.MoreVert,
                        contentDescription = stringResource(R.string.note_actions),
                        tint = ChillColors.TextSub,
                    )
                }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    if (isTrash) {
                        IOSMenuItem(R.string.note_restore, Icons.AutoMirrored.Outlined.ArrowBack) {
                            menuOpen = false
                            onRestore()
                        }
                        IOSMenuItem(R.string.trash_delete_permanently, Icons.Outlined.DeleteSweep, destructive = true) {
                            menuOpen = false
                            onPermanentDelete()
                        }
                    } else {
                        IOSMenuItem(R.string.home_select_notes, Icons.Outlined.CheckCircle) {
                            menuOpen = false
                            onEnterSelectionMode()
                        }
                        IOSMenuItem(R.string.home_batch_tag_title, Icons.Outlined.Tag) {
                            menuOpen = false
                            onManageTags()
                        }
                        IOSMenuItem(
                            if (note.pinnedAt == null) R.string.note_pin_action else R.string.note_unpin_action,
                            Icons.Outlined.PushPin,
                        ) {
                            menuOpen = false
                            onPin()
                        }
                        listOf("inbox", "drafts", "published").filter { it != note.section }.forEach { section ->
                            IOSMenuItem(section.moveResource(), Icons.Outlined.Description) {
                                menuOpen = false
                                onMove(section)
                            }
                        }
                        IOSMenuItem(R.string.common_delete, Icons.Outlined.Delete, destructive = true) {
                            menuOpen = false
                            onDelete()
                        }
                    }
                }
            }
        }
        if (isTrash) {
            val days = note.deletedAt?.let(TrashPolicy::daysRemaining) ?: 0
            Text(
                if (days == 0L) stringResource(R.string.trash_expires_today)
                else androidx.compose.ui.res.pluralStringResource(
                    R.plurals.trash_days_left,
                    days.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(),
                    days,
                ),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
                modifier = Modifier.padding(horizontal = 8.dp),
            )
        }
    }
}

@Composable
private fun IOSLinkImportPreparingView() {
    var dotCount by remember { mutableStateOf(1) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(420)
            dotCount = dotCount % 3 + 1
        }
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(20.dp),
            color = ChillColors.BrandBlue,
            strokeWidth = 2.5.dp,
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                stringResource(R.string.quick_capture_link_import_card_title),
                color = ChillColors.TextMain,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                stringResource(R.string.quick_capture_link_import_card_body),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
                lineHeight = 18.sp,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                repeat(3) { index ->
                    Box(
                        Modifier.size(5.dp).background(
                            ChillColors.BrandBlue.copy(alpha = if (index < dotCount) 0.9f else 0.25f),
                            CircleShape,
                        ),
                    )
                }
            }
        }
    }
}

private fun normalizedSearchTokens(query: String): List<String> = query
    .replace(Regex("[\"'`]+"), " ")
    .trim()
    .split(Regex("\\s+"))
    .filter(String::isNotBlank)
    .sortedByDescending(String::length)

private fun noteSearchPlainText(markdown: String): String = MarkdownImages.removingImages(markdown)
    .replace(Regex("(?m)^#{1,6}\\s+"), "")
    .replace("**", "")
    .replace("*", "")
    .replace("`", "")
    .replace(Regex("(?m)^- \\[ \\]\\s*"), "☐ ")
    .replace(Regex("(?m)^- \\[[xX]\\]\\s*"), "☑ ")
    .replace(Regex("\\[([^]]+)]\\([^)]+\\)")) { match -> match.groupValues[1] }
    .replace(Regex("(?m)^[\\-•]\\s+"), "")
    .trim()

private fun highlightedSearchPreview(markdown: String, query: String, radius: Int = 48): AnnotatedString {
    val plain = noteSearchPlainText(markdown)
    val tokens = normalizedSearchTokens(query)
    if (plain.isBlank() || tokens.isEmpty()) return AnnotatedString(plain)

    val folded = plain.lowercase(Locale.ROOT)
    val firstMatch = tokens.firstNotNullOfOrNull { token ->
        folded.indexOf(token.lowercase(Locale.ROOT)).takeIf { it >= 0 }?.let { it to token.length }
    }
    val excerpt = if (firstMatch == null) {
        plain
    } else {
        val start = (firstMatch.first - radius).coerceAtLeast(0)
        val end = (firstMatch.first + firstMatch.second + radius).coerceAtMost(plain.length)
        buildString {
            if (start > 0) append('…')
            append(plain.substring(start, end).trim())
            if (end < plain.length) append('…')
        }
    }
    return highlightedMatches(
        text = excerpt,
        query = query,
        baseColor = ChillColors.TextMain,
        highlightBackground = ChillColors.BrandBlue.copy(alpha = 0.18f),
        highlightWeight = FontWeight.SemiBold,
    )
}

private fun highlightedMatches(
    text: String,
    query: String,
    baseColor: Color,
    highlightBackground: Color,
    highlightWeight: FontWeight,
): AnnotatedString = buildAnnotatedString {
    append(text)
    addStyle(SpanStyle(color = baseColor), 0, text.length)
    val folded = text.lowercase(Locale.ROOT)
    normalizedSearchTokens(query).forEach { token ->
        val foldedToken = token.lowercase(Locale.ROOT)
        var searchFrom = 0
        while (searchFrom < folded.length) {
            val matchStart = folded.indexOf(foldedToken, startIndex = searchFrom)
            if (matchStart < 0) break
            val matchEnd = (matchStart + token.length).coerceAtMost(text.length)
            addStyle(
                SpanStyle(
                    color = baseColor,
                    background = highlightBackground,
                    fontWeight = highlightWeight,
                ),
                matchStart,
                matchEnd,
            )
            searchFrom = matchEnd.coerceAtLeast(matchStart + 1)
        }
    }
}

@Composable
private fun IOSTagPill(tag: TagEntity, searchQuery: String) {
    val normalized = remember(tag.colorHex) { TagColors.normalize(tag.colorHex) }
    val color = remember(normalized) { runCatching { Color(android.graphics.Color.parseColor(normalized)) }.getOrDefault(ChillColors.BrandBlue) }
    val label = remember(tag.name, searchQuery, color) {
        highlightedMatches(
            text = tag.name,
            query = searchQuery,
            baseColor = color,
            highlightBackground = Color.White.copy(alpha = 0.45f),
            highlightWeight = FontWeight.SemiBold,
        )
    }
    Text(
        text = label,
        color = color,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        maxLines = 1,
        modifier = Modifier
            .background(color.copy(alpha = 0.12f), CircleShape)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

@Composable
private fun IOSMenuItem(
    title: Int,
    icon: ImageVector,
    destructive: Boolean = false,
    onClick: () -> Unit,
) {
    DropdownMenuItem(
        text = { Text(stringResource(title), color = if (destructive) MaterialTheme.colorScheme.error else ChillColors.TextMain) },
        leadingIcon = { Icon(icon, contentDescription = null, tint = if (destructive) MaterialTheme.colorScheme.error else ChillColors.TextSub) },
        onClick = onClick,
    )
}

@Composable
private fun IOSQuickCaptureDock(
    isRecording: Boolean,
    isVoiceProcessing: Boolean,
    isLinkProcessing: Boolean,
    onStartRecording: () -> Unit,
    onCancelRecording: () -> Unit,
    onConfirmRecording: () -> Unit,
    onPasteLink: (((Boolean) -> Unit) -> Unit),
    onCreateText: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dockShape = RoundedCornerShape(999.dp)
    var recordingSeconds by remember(isRecording) { mutableStateOf(0) }
    var waveformPhase by remember(isRecording) { mutableStateOf(0) }
    var missingLinkToken by remember { mutableStateOf(0) }
    var showMissingLink by remember { mutableStateOf(false) }

    LaunchedEffect(isRecording) {
        if (!isRecording) return@LaunchedEffect
        while (recordingSeconds < 600) {
            delay(1_000)
            recordingSeconds += 1
        }
        onConfirmRecording()
    }
    LaunchedEffect(isRecording) {
        if (!isRecording) return@LaunchedEffect
        while (true) {
            delay(1_000)
            waveformPhase = (waveformPhase + 1) % 5
        }
    }
    LaunchedEffect(missingLinkToken) {
        if (missingLinkToken == 0) return@LaunchedEffect
        showMissingLink = true
        delay(3_000)
        showMissingLink = false
    }

    Column(
        modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (!isRecording && showMissingLink) IOSMissingClipboardLinkHint()

        when {
            isRecording -> Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .height(64.dp)
                    .shadow(
                        15.dp,
                        dockShape,
                        ambientColor = ChillColors.BrandBlue.copy(alpha = 0.20f),
                        spotColor = ChillColors.BrandBlue.copy(alpha = 0.28f),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .background(Color.White.copy(alpha = 0.98f), dockShape)
                        .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.12f), dockShape)
                        .padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(
                        onClick = onCancelRecording,
                        modifier = Modifier.size(36.dp).background(ChillColors.TextMain.copy(alpha = 0.07f), CircleShape),
                    ) {
                        Icon(
                            Icons.Outlined.Close,
                            contentDescription = stringResource(R.string.common_cancel),
                            tint = ChillColors.TextSub,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    Column(
                        Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Row(
                            Modifier.height(24.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            repeat(5) { index ->
                                val height by animateDpAsState(
                                    targetValue = (4 + ((index + waveformPhase) % 5) * 4).dp,
                                    animationSpec = spring(stiffness = 420f),
                                    label = "recordingWave$index",
                                )
                                Box(Modifier.width(4.dp).height(height).background(ChillColors.BrandBlue, CircleShape))
                            }
                        }
                        Text(
                            stringResource(
                                R.string.note_detail_recording_duration_progress,
                                formatRecordingDuration(recordingSeconds),
                                formatRecordingDuration(600),
                            ),
                            color = ChillColors.BrandBlue,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    IconButton(
                        onClick = onConfirmRecording,
                        modifier = Modifier.size(36.dp).background(ChillColors.BrandBlue, CircleShape),
                    ) {
                        Icon(
                            Icons.Outlined.ArrowUpward,
                            contentDescription = stringResource(R.string.voice_stop),
                            tint = Color.White,
                            modifier = Modifier.size(19.dp),
                        )
                    }
                }
            }

            else -> Box(
                Modifier
                    .shadow(14.dp, dockShape, ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.08f))
                    .graphicsLayer { alpha = if (isLinkProcessing) 0.55f else 1f }
                    .background(Color.White.copy(alpha = 0.96f), dockShape)
                    .border(1.dp, Color.Black.copy(alpha = 0.04f), dockShape),
            ) {
                Row(
                    Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    IOSQuickCaptureButton(
                        icon = Icons.Outlined.Mic,
                        description = stringResource(R.string.voice_start),
                        onClick = onStartRecording,
                        enabled = !isVoiceProcessing && !isLinkProcessing,
                    )
                    Surface(
                        onClick = {
                            onPasteLink { accepted ->
                                if (!accepted) missingLinkToken += 1
                            }
                        },
                        enabled = !isVoiceProcessing && !isLinkProcessing,
                        shape = RoundedCornerShape(999.dp),
                        color = ChillColors.BorderSubtle,
                        modifier = Modifier.width(74.dp).height(50.dp),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                Icons.Outlined.Link,
                                contentDescription = stringResource(R.string.quick_capture_paste_link),
                                tint = ChillColors.BrandBlue,
                                modifier = Modifier.size(25.dp),
                            )
                        }
                    }
                    IOSQuickCaptureButton(
                        icon = Icons.Outlined.Edit,
                        description = stringResource(R.string.quick_capture_text),
                        onClick = onCreateText,
                        enabled = !isVoiceProcessing && !isLinkProcessing,
                    )
                }
                if (isLinkProcessing) {
                    Box(
                        Modifier
                            .matchParentSize()
                            .background(Color.White.copy(alpha = 0.82f), dockShape),
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSMissingClipboardLinkHint() {
    Row(
        Modifier
            .widthIn(max = 340.dp)
            .fillMaxWidth()
            .shadow(12.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.08f))
            .background(Color.White.copy(alpha = 0.92f), CircleShape)
            .border(1.dp, Color.Black.copy(alpha = 0.04f), CircleShape)
            .padding(horizontal = 14.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(28.dp).background(ChillColors.BrandBlue.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.Link, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(16.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                stringResource(R.string.quick_capture_missing_link_title),
                color = ChillColors.TextMain,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                stringResource(R.string.quick_capture_missing_link_subtitle),
                color = ChillColors.TextSub,
                fontSize = 12.sp,
                lineHeight = 17.sp,
            )
        }
    }
}

private fun formatRecordingDuration(totalSeconds: Int): String =
    "%02d:%02d".format(Locale.ROOT, totalSeconds / 60, totalSeconds % 60)

@Composable
private fun IOSQuickCaptureButton(
    icon: ImageVector,
    description: String,
    onClick: () -> Unit,
    enabled: Boolean,
) {
    IconButton(onClick = onClick, enabled = enabled, modifier = Modifier.size(50.dp)) {
        Icon(icon, contentDescription = description, tint = ChillColors.TextMain, modifier = Modifier.size(24.dp))
    }
}

private sealed interface SidebarDropTarget {
    data object Root : SidebarDropTarget
    data object Trash : SidebarDropTarget
    data class Tag(val id: String) : SidebarDropTarget
}

@Composable
private fun IOSHomeSidebar(
    visible: Boolean,
    notes: List<NoteEntity>,
    tags: List<TagEntity>,
    selectedSection: String,
    selectedTagId: String?,
    pendingRecordingsCount: Int,
    subscriptionTier: String,
    creditBalance: Int?,
    locale: Locale,
    onDismiss: () -> Unit,
    onSelectSection: (String) -> Unit,
    onOpenSubscription: () -> Unit,
    onOpenWeeklyTopics: () -> Unit,
    onOpenPendingRecordings: () -> Unit,
    onOpenSettings: () -> Unit,
    onSelectTag: (TagEntity) -> Unit,
    onMoveTag: (TagEntity, String?) -> Unit,
    onDeleteTag: (TagEntity) -> Unit,
) {
    val density = LocalDensity.current
    val haptics = androidx.compose.ui.platform.LocalHapticFeedback.current
    val closeGestureDistancePx = with(density) { 14.dp.toPx() }
    val closeMinTranslationPx = with(density) { 30.dp.toPx() }
    val closeHorizontalBiasPx = with(density) { 12.dp.toPx() }
    val previewHorizontalOffsetPx = with(density) { 12.dp.toPx() }
    val previewVerticalOffsetPx = with(density) { 20.dp.toPx() }
    val autoScrollEdgePx = with(density) { 40.dp.toPx() }
    val autoScrollStepPx = with(density) { 18.dp.toPx() }
    val tagListState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val tagBounds = remember { mutableStateMapOf<String, Rect>() }
    var rootDropZoneBounds by remember { mutableStateOf<Rect?>(null) }
    var tagListBounds by remember { mutableStateOf<Rect?>(null) }
    var trashDropZoneBounds by remember { mutableStateOf<Rect?>(null) }
    var draggedTag by remember { mutableStateOf<TagEntity?>(null) }
    var dragPosition by remember { mutableStateOf<Offset?>(null) }
    var activeDropTarget by remember { mutableStateOf<SidebarDropTarget?>(null) }
    var autoScrollJob by remember { mutableStateOf<Job?>(null) }

    fun updateDragPosition(position: Offset) {
        val dragged = draggedTag ?: return
        dragPosition = position
        activeDropTarget = resolveSidebarDropTarget(
            position = position,
            draggedTag = dragged,
            tags = tags,
            tagBounds = tagBounds,
            rootDropZoneBounds = rootDropZoneBounds,
            tagListBounds = tagListBounds,
            trashDropZoneBounds = trashDropZoneBounds,
        )
        val listBounds = tagListBounds
        val scrollDelta = when {
            listBounds == null || !listBounds.contains(position) -> 0f
            position.y < listBounds.top + autoScrollEdgePx -> -autoScrollStepPx
            position.y > listBounds.bottom - autoScrollEdgePx -> autoScrollStepPx
            else -> 0f
        }
        if (scrollDelta != 0f) {
            autoScrollJob?.cancel()
            autoScrollJob = coroutineScope.launch { tagListState.scrollBy(scrollDelta) }
        }
    }

    fun clearDrag() {
        autoScrollJob?.cancel()
        autoScrollJob = null
        draggedTag = null
        dragPosition = null
        activeDropTarget = null
    }

    fun finishDrag() {
        val tag = draggedTag
        val target = activeDropTarget
        clearDrag()
        if (tag == null) return
        when (target) {
            SidebarDropTarget.Root -> if (tag.parentId != null) {
                onMoveTag(tag, null)
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            }
            SidebarDropTarget.Trash -> {
                onDeleteTag(tag)
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            is SidebarDropTarget.Tag -> {
                onMoveTag(tag, target.id)
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            }
            null -> Unit
        }
    }

    val closeGestureModifier = if (visible) {
        Modifier.observeHorizontalSwipe(
            enabled = true,
            minimumGestureDistancePx = closeGestureDistancePx,
            minimumTranslationPx = closeMinTranslationPx,
            horizontalBiasPx = closeHorizontalBiasPx,
            direction = HorizontalSwipeDirection.Left,
        ) {
            clearDrag()
            onDismiss()
            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
    } else {
        Modifier
    }

    Box(Modifier.fillMaxSize().then(closeGestureModifier)) {
        AnimatedVisibility(visible = visible, enter = fadeIn(), exit = fadeOut()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.15f))
                    .clickable(onClick = onDismiss),
            )
        }
        AnimatedVisibility(
            visible = visible,
            enter = slideInHorizontally(
                animationSpec = spring(
                    dampingRatio = 0.85f,
                    stiffness = Spring.StiffnessMediumLow,
                ),
                initialOffsetX = { -it },
            ),
            exit = slideOutHorizontally(
                animationSpec = spring(
                    dampingRatio = 0.85f,
                    stiffness = Spring.StiffnessMediumLow,
                ),
                targetOffsetX = { -it },
            ),
        ) {
            Column(
                Modifier
                    .fillMaxHeight()
                    .width(320.dp)
                    .background(ChillColors.BackgroundSecondary)
                    .statusBarsPadding()
                    .clickable(enabled = false) { }
                    .padding(top = 20.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IOSMembershipEntry(
                        tier = subscriptionTier,
                        creditBalance = creditBalance,
                        onClick = onOpenSubscription,
                    )
                    Spacer(Modifier.weight(1f))
                    IconButton(
                        onClick = onOpenSettings,
                        modifier = Modifier.size(32.dp).background(ChillColors.TextMain.copy(alpha = 0.05f), CircleShape),
                    ) {
                        Icon(
                            Icons.Outlined.Settings,
                            contentDescription = stringResource(R.string.settings_title),
                            tint = ChillColors.TextMain.copy(alpha = 0.6f),
                            modifier = Modifier.size(19.dp),
                        )
                    }
                }

                IOSSidebarStats(
                    notes = notes.filter { it.deletedAt == null },
                    locale = locale,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )

                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    IOSSidebarItem(
                        Icons.Outlined.Description,
                        stringResource(R.string.home_section_inbox),
                        selectedSection == "inbox",
                    ) { onSelectSection("inbox") }
                    IOSSidebarItem(
                        Icons.Outlined.Lightbulb,
                        stringResource(R.string.weekly_topics_title),
                        false,
                        onClick = onOpenWeeklyTopics,
                    )
                    IOSSidebarItem(
                        Icons.Outlined.Delete,
                        stringResource(R.string.home_section_trash),
                        selectedSection == "trash",
                    ) { onSelectSection("trash") }
                    if (pendingRecordingsCount > 0) {
                        IOSSidebarItem(
                            Icons.Outlined.GraphicEq,
                            stringResource(R.string.pending_recordings_title),
                            false,
                            badge = pendingRecordingsCount,
                            onClick = onOpenPendingRecordings,
                        )
                    }
                }

                Column(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .onGloballyPositioned { rootDropZoneBounds = it.boundsInRoot() }
                            .background(
                                if (activeDropTarget == SidebarDropTarget.Root) ChillColors.BrandBlue.copy(alpha = 0.10f)
                                else Color.Transparent,
                                RoundedCornerShape(8.dp),
                            )
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            stringResource(R.string.sidebar_tags_title),
                            color = ChillColors.TextSub.copy(alpha = 0.4f),
                            fontFamily = FontFamily.Serif,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.2.sp,
                        )
                        Spacer(Modifier.weight(1f))
                        AnimatedVisibility(
                            visible = activeDropTarget == SidebarDropTarget.Root,
                            enter = fadeIn() + slideInHorizontally(initialOffsetX = { it / 2 }),
                            exit = fadeOut() + slideOutHorizontally(targetOffsetX = { it / 2 }),
                        ) {
                            Text(
                                stringResource(R.string.sidebar_tags_release_to_unnest),
                                color = ChillColors.BrandBlue,
                                fontFamily = FontFamily.Serif,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    Box(
                        Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .onGloballyPositioned { tagListBounds = it.boundsInRoot() },
                    ) {
                        if (tags.isEmpty()) {
                            Text(
                                stringResource(R.string.sidebar_tags_empty),
                                color = ChillColors.TextSub.copy(alpha = 0.6f),
                                fontFamily = FontFamily.Serif,
                                fontSize = 13.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(top = 40.dp),
                            )
                        } else {
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                state = tagListState,
                                verticalArrangement = Arrangement.spacedBy(2.dp),
                            ) {
                                items(
                                    tags.filter { it.parentId == null }.sortedWith(
                                        compareBy<TagEntity> { it.sortOrder }.thenBy { it.name.lowercase(locale) },
                                    ),
                                    key = { it.id },
                                ) { tag ->
                                    IOSSidebarTagTreeItem(
                                        tag = tag,
                                        allTags = tags,
                                        selectedTagId = selectedTagId,
                                        locale = locale,
                                        depth = 0,
                                        draggedTagId = draggedTag?.id,
                                        activeDropTarget = activeDropTarget,
                                        onClick = onSelectTag,
                                        onBoundsChanged = { tagId, bounds ->
                                            if (bounds == null) tagBounds.remove(tagId) else tagBounds[tagId] = bounds
                                        },
                                        onDragStart = { tagToDrag, position ->
                                            draggedTag = tagToDrag
                                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                            updateDragPosition(position)
                                        },
                                        onDrag = { delta ->
                                            updateDragPosition((dragPosition ?: Offset.Zero) + delta)
                                        },
                                        onDragEnd = ::finishDrag,
                                        onDragCancel = ::clearDrag,
                                    )
                                }
                                item { Spacer(Modifier.height(100.dp)) }
                            }
                        }
                    }
                }

                IOSTrashTagDropZone(
                    targeted = activeDropTarget == SidebarDropTarget.Trash,
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .onGloballyPositioned { trashDropZoneBounds = it.boundsInRoot() },
                )
            }
        }

        val previewTag = draggedTag
        val previewPosition = dragPosition
        if (visible && previewTag != null && previewPosition != null) {
            Surface(
                color = ChillColors.BackgroundSecondary,
                shape = RoundedCornerShape(8.dp),
                shadowElevation = 4.dp,
                modifier = Modifier
                    .widthIn(max = 240.dp)
                    .graphicsLayer {
                        translationX = previewPosition.x + previewHorizontalOffsetPx
                        translationY = previewPosition.y - previewVerticalOffsetPx
                    },
            ) {
                Text(
                    previewTag.name,
                    color = ChillColors.TextMain,
                    fontFamily = FontFamily.Serif,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                )
            }
        }
    }
}

private fun resolveSidebarDropTarget(
    position: Offset,
    draggedTag: TagEntity,
    tags: List<TagEntity>,
    tagBounds: Map<String, Rect>,
    rootDropZoneBounds: Rect?,
    tagListBounds: Rect?,
    trashDropZoneBounds: Rect?,
): SidebarDropTarget? {
    if (trashDropZoneBounds?.contains(position) == true) return SidebarDropTarget.Trash

    val hitTagId = tagBounds.entries.firstOrNull { (_, bounds) -> bounds.contains(position) }?.key
    if (hitTagId != null) {
        val validParentIds = TagHierarchy.validParents(draggedTag.id, tags).mapTo(mutableSetOf()) { it.id }
        return hitTagId.takeIf(validParentIds::contains)?.let(SidebarDropTarget::Tag)
    }

    if (rootDropZoneBounds?.contains(position) == true || tagListBounds?.contains(position) == true) {
        return SidebarDropTarget.Root
    }
    return null
}

@Composable
private fun IOSTrashTagDropZone(targeted: Boolean, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .background(
                if (targeted) Color.Red.copy(alpha = 0.08f) else Color.Transparent,
                RoundedCornerShape(12.dp),
            ),
    ) {
        Canvas(Modifier.matchParentSize()) {
            drawRoundRect(
                color = if (targeted) Color.Red.copy(alpha = 0.30f) else ChillColors.TextMain.copy(alpha = 0.10f),
                cornerRadius = CornerRadius(12.dp.toPx()),
                style = Stroke(
                    width = 1.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())),
                ),
            )
        }
        Row(
            Modifier.fillMaxWidth().padding(vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(
                if (targeted) Icons.Filled.FilledDelete else Icons.Outlined.Delete,
                contentDescription = null,
                tint = if (targeted) Color.Red else ChillColors.TextMain.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(10.dp))
            Text(
                stringResource(
                    if (targeted) R.string.sidebar_trash_release_to_delete
                    else R.string.sidebar_trash_drag_to_delete,
                ),
                color = if (targeted) Color.Red else ChillColors.TextMain.copy(alpha = 0.4f),
                fontFamily = FontFamily.Serif,
                fontSize = 14.sp,
                fontWeight = if (targeted) FontWeight.Bold else FontWeight.Medium,
            )
        }
    }
}

@Composable
private fun IOSMembershipEntry(tier: String, creditBalance: Int?, onClick: () -> Unit) {
    val isPro = tier.equals("pro", ignoreCase = true)
    Row(
        Modifier
            .clip(CircleShape)
            .background(if (isPro) ChillColors.BrandBlue else ChillColors.TextMain.copy(alpha = 0.04f))
            .clickable(onClick = onClick)
            .padding(start = 14.dp, end = if (isPro) 14.dp else 6.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                stringResource(if (isPro) R.string.subscription_current_pro else R.string.subscription_free),
                color = if (isPro) Color.White else ChillColors.TextMain.copy(alpha = 0.9f),
                fontFamily = FontFamily.Serif,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            )
            if (!isPro) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Icon(
                        if ((creditBalance ?: 0) == 0) Icons.Outlined.Lock else Icons.Outlined.WorkspacePremium,
                        contentDescription = null,
                        tint = creditColor(creditBalance),
                        modifier = Modifier.size(10.dp),
                    )
                    Text(
                        if ((creditBalance ?: 0) == 0) stringResource(R.string.sidebar_credits_locked)
                        else stringResource(R.string.sidebar_credits_remaining, creditBalance ?: 0),
                        color = creditColor(creditBalance),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
        if (!isPro) {
            Text(
                stringResource(R.string.sidebar_membership_upgrade),
                color = Color.White,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.background(ChillColors.BrandBlue, CircleShape).padding(horizontal = 10.dp, vertical = 4.dp),
            )
        }
    }
}

private fun creditColor(balance: Int?): Color = when {
    (balance ?: 0) <= 0 -> Color(0xFFD14343)
    balance!! <= 10 -> Color(0xFFE58B2A)
    else -> Color(0xFF2E9B59)
}

@Composable
private fun IOSSidebarStats(notes: List<NoteEntity>, locale: Locale, modifier: Modifier = Modifier) {
    val snapshot = remember(notes, locale) { SidebarStats.from(notes) }
    val streakText = stringResource(R.string.sidebar_stats_streak, snapshot.streakDays)
    val streakCountText = snapshot.streakDays.toString()
    val styledStreak = remember(streakText, streakCountText) {
        buildAnnotatedString {
            append(streakText)
            val start = streakText.indexOf(streakCountText)
            if (start >= 0) {
                addStyle(
                    SpanStyle(
                        color = ChillColors.BrandBlue,
                        fontFamily = FontFamily.Serif,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    start,
                    start + streakCountText.length,
                )
            }
        }
    }
    val weekSummary = when (snapshot.trend) {
        SidebarTrend.Up -> stringResource(R.string.sidebar_stats_week_up, snapshot.weekCount, snapshot.percent)
        SidebarTrend.Down -> stringResource(R.string.sidebar_stats_week_down, snapshot.weekCount, snapshot.percent)
        SidebarTrend.New -> stringResource(R.string.sidebar_stats_week_new_start, snapshot.weekCount)
        SidebarTrend.Same -> stringResource(R.string.sidebar_stats_week_same, snapshot.weekCount)
    }
    val styledWeekSummary = remember(weekSummary, snapshot) {
        buildAnnotatedString {
            append(weekSummary)
            val countText = snapshot.weekCount.toString()
            val countStart = weekSummary.indexOf(countText)
            if (countStart >= 0) {
                addStyle(
                    SpanStyle(
                        color = ChillColors.BrandBlue,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    countStart,
                    countStart + countText.length,
                )
            }
            val trendCandidates = when (snapshot.trend) {
                SidebarTrend.Up -> listOf("+${snapshot.percent}%", "+${snapshot.percent} %", "+${snapshot.percent}\u00A0%")
                SidebarTrend.Down -> listOf("${snapshot.percent}%", "${snapshot.percent} %", "${snapshot.percent}\u00A0%")
                SidebarTrend.New, SidebarTrend.Same -> emptyList()
            }
            val trendText = trendCandidates.firstOrNull { weekSummary.contains(it) }
            if (trendText != null) {
                val trendStart = weekSummary.indexOf(trendText)
                addStyle(
                    SpanStyle(
                        color = if (snapshot.trend == SidebarTrend.Up) ChillColors.BrandTeal else Color(0xFFE58B2A),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    trendStart,
                    trendStart + trendText.length,
                )
            }
        }
    }
    Column(
        modifier
            .fillMaxWidth()
            .background(
                androidx.compose.ui.graphics.Brush.linearGradient(
                    listOf(ChillColors.BrandBlue.copy(alpha = 0.11f), ChillColors.BackgroundSecondary.copy(alpha = 0.96f)),
                ),
                RoundedCornerShape(12.dp),
            )
            .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .padding(start = 14.dp, top = 14.dp, end = 14.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            styledStreak,
            color = ChillColors.TextMain,
            fontFamily = FontFamily.Serif,
            fontSize = 21.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
        Text(
            styledWeekSummary,
            color = ChillColors.TextSub,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
        )
        IOSSidebarActivityChart(
            counts = snapshot.dailyCounts,
            locale = locale,
            modifier = Modifier.fillMaxWidth().height(110.dp),
        )
    }
}

@Composable
private fun IOSSidebarActivityChart(counts: List<Int>, locale: Locale, modifier: Modifier = Modifier) {
    val today = remember { LocalDate.now() }
    val todayLabel = stringResource(R.string.sidebar_stats_today)
    val dayLabels = remember(today, locale, counts.size) {
        val formatter = DateTimeFormatter.ofPattern("EEEEE", locale)
        counts.indices.map { index ->
            today.minusDays((counts.lastIndex - index).toLong()).format(formatter)
        }
    }
    Box(modifier) {
        Canvas(Modifier.fillMaxSize()) {
            if (counts.isEmpty()) return@Canvas
            val maxValue = max(1, counts.maxOrNull() ?: 1)
            val chartHeight = max(size.height - 24.dp.toPx(), 1f)
            val horizontalInset = 7.dp.toPx()
            val step = if (counts.size <= 1) 0f else (size.width - horizontalInset * 2f) / (counts.size - 1)
            val usableHeight = max(chartHeight - 16.dp.toPx(), 1f)
            val points = counts.mapIndexed { index, count ->
                Offset(
                    x = horizontalInset + index * step,
                    y = chartHeight - 5.dp.toPx() - (count.toFloat() / maxValue) * usableHeight,
                )
            }
            val area = Path().apply {
                moveTo(points.first().x, chartHeight)
                lineTo(points.first().x, points.first().y)
                points.indices.drop(1).forEach { index ->
                    val previous = points[index - 1]
                    val point = points[index]
                    val midpointX = (previous.x + point.x) / 2f
                    cubicTo(midpointX, previous.y, midpointX, point.y, point.x, point.y)
                }
                lineTo(points.last().x, chartHeight)
                close()
            }
            drawPath(
                area,
                Brush.verticalGradient(
                    listOf(ChillColors.BrandBlue.copy(alpha = 0.28f), ChillColors.BrandBlue.copy(alpha = 0.02f)),
                    endY = chartHeight,
                ),
            )
            val line = Path().apply {
                moveTo(points.first().x, points.first().y)
                points.indices.drop(1).forEach { index ->
                    val previous = points[index - 1]
                    val point = points[index]
                    val midpointX = (previous.x + point.x) / 2f
                    cubicTo(midpointX, previous.y, midpointX, point.y, point.x, point.y)
                }
            }
            drawPath(
                line,
                ChillColors.BrandBlue,
                style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
            )
            points.forEachIndexed { index, point ->
                val isLast = index == points.lastIndex
                val radius = (if (isLast) 6.5.dp else 4.5.dp).toPx()
                drawCircle(
                    color = if (isLast) ChillColors.BrandBlue else ChillColors.BackgroundSecondary,
                    radius = radius,
                    center = point,
                )
                drawCircle(
                    color = ChillColors.BrandBlue,
                    radius = radius,
                    center = point,
                    style = Stroke(width = (if (isLast) 3.dp else 2.dp).toPx()),
                )
            }
        }
        Row(
            Modifier.fillMaxWidth().align(Alignment.BottomCenter),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            dayLabels.forEachIndexed { index, label ->
                val isToday = index == dayLabels.lastIndex
                Text(
                    if (isToday) todayLabel else label,
                    color = if (isToday) ChillColors.BrandBlue else ChillColors.TextSub,
                    fontSize = 10.sp,
                    fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun IOSSidebarItem(
    icon: ImageVector,
    title: String,
    selected: Boolean,
    badge: Int? = null,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(if (selected) ChillColors.BrandBlueSoft else Color.Transparent, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, contentDescription = null, tint = if (selected) ChillColors.BrandBlue else ChillColors.TextSub, modifier = Modifier.size(21.dp))
        Text(title, color = ChillColors.TextMain, fontSize = 15.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium, modifier = Modifier.weight(1f))
        if (badge != null) {
            Text(
                badge.toString(),
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.background(ChillColors.BrandBlue, CircleShape).padding(horizontal = 7.dp, vertical = 2.dp),
            )
        }
    }
}

@Composable
private fun IOSSidebarTagTreeItem(
    tag: TagEntity,
    allTags: List<TagEntity>,
    selectedTagId: String?,
    locale: Locale,
    depth: Int,
    draggedTagId: String?,
    activeDropTarget: SidebarDropTarget?,
    onClick: (TagEntity) -> Unit,
    onBoundsChanged: (String, Rect?) -> Unit,
    onDragStart: (TagEntity, Offset) -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit,
) {
    val children = remember(tag.id, allTags) {
        allTags.filter { it.parentId == tag.id }
            .sortedWith(compareBy<TagEntity> { it.sortOrder }.thenBy { it.name.lowercase(locale) })
    }
    var expanded by remember(tag.id) { mutableStateOf(true) }
    val selected = tag.id == selectedTagId
    val normalized = remember(tag.colorHex) { TagColors.normalize(tag.colorHex) }
    val tagColor = remember(normalized) {
        runCatching { Color(android.graphics.Color.parseColor(normalized)) }.getOrDefault(ChillColors.BrandBlue)
    }
    var rowBounds by remember(tag.id) { mutableStateOf<Rect?>(null) }
    val isDropTargeted = activeDropTarget == SidebarDropTarget.Tag(tag.id)

    DisposableEffect(tag.id) {
        onDispose { onBoundsChanged(tag.id, null) }
    }

    Row(
        Modifier
            .fillMaxWidth()
            .background(if (selected) ChillColors.TextMain.copy(alpha = 0.04f) else Color.Transparent, RoundedCornerShape(12.dp))
            .then(
                if (isDropTargeted) Modifier.border(
                    2.dp,
                    ChillColors.BrandBlue.copy(alpha = 0.5f),
                    RoundedCornerShape(12.dp),
                ) else Modifier,
            )
            .graphicsLayer { alpha = if (draggedTagId == tag.id) 0.55f else 1f }
            .onGloballyPositioned {
                rowBounds = it.boundsInRoot()
                onBoundsChanged(tag.id, it.boundsInRoot())
            }
            .pointerInput(tag.id) {
                detectDragGesturesAfterLongPress(
                    onDragStart = { localPosition ->
                        val globalPosition = (rowBounds?.topLeft ?: Offset.Zero) + localPosition
                        onDragStart(tag, globalPosition)
                    },
                    onDragEnd = onDragEnd,
                    onDragCancel = onDragCancel,
                ) { change, dragAmount ->
                    change.consume()
                    onDrag(dragAmount)
                }
            }
            .clickable { onClick(tag) }
            .padding(start = (12 + depth * 18).dp, end = 12.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (children.isNotEmpty()) {
            Icon(
                Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = tagColor.copy(alpha = 0.6f),
                modifier = Modifier
                    .size(18.dp)
                    .clickable { expanded = !expanded }
                    .rotate(if (expanded) 90f else 0f),
            )
        } else {
            Box(Modifier.size(18.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(10.dp).background(tagColor.copy(alpha = 0.28f), CircleShape))
                Box(Modifier.size(6.dp).background(tagColor.copy(alpha = 0.92f), CircleShape))
            }
        }
        Text(
            tag.name,
            color = ChillColors.TextMain.copy(alpha = if (selected) 1f else 0.7f),
            fontFamily = FontFamily.Serif,
            fontSize = 15.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (selected) Box(Modifier.size(4.dp).background(ChillColors.BrandBlue, CircleShape))
    }
    if (expanded) {
        children.forEach { child ->
            IOSSidebarTagTreeItem(
                tag = child,
                allTags = allTags,
                selectedTagId = selectedTagId,
                locale = locale,
                depth = depth + 1,
                draggedTagId = draggedTagId,
                activeDropTarget = activeDropTarget,
                onClick = onClick,
                onBoundsChanged = onBoundsChanged,
                onDragStart = onDragStart,
                onDrag = onDrag,
                onDragEnd = onDragEnd,
                onDragCancel = onDragCancel,
            )
        }
    }
}

@Composable
private fun IOSHomeEmptyState(section: String, hasActiveSearch: Boolean, modifier: Modifier = Modifier) {
    val (title, message) = if (hasActiveSearch) {
        R.string.home_no_results_title to R.string.home_no_results_message
    } else when (section) {
        "drafts" -> R.string.home_empty_drafts_title to R.string.home_empty_drafts_message
        "published" -> R.string.home_empty_published_title to R.string.home_empty_published_message
        "trash" -> R.string.home_empty_trash_title to R.string.home_empty_trash_message
        else -> R.string.home_empty_inbox_title to R.string.home_empty_inbox_message
    }
    Column(
        modifier.padding(horizontal = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            Modifier
                .size(112.dp)
                .background(ChillColors.BrandBlue.copy(alpha = 0.10f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                when (section) {
                    "trash" -> Icons.Outlined.Delete
                    "published" -> Icons.Outlined.CheckCircle
                    "drafts" -> Icons.Outlined.Edit
                    else -> Icons.Outlined.Lightbulb
                },
                contentDescription = null,
                tint = ChillColors.BrandBlue,
                modifier = Modifier.size(44.dp),
            )
        }
        Text(
            stringResource(title),
            color = ChillColors.TextMain,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 22.dp),
        )
        Text(
            stringResource(message),
            color = ChillColors.TextSub,
            fontSize = 15.sp,
            lineHeight = 21.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

private data class SidebarStats(
    val streakDays: Int,
    val weekCount: Int,
    val percent: Int,
    val trend: SidebarTrend,
    val dailyCounts: List<Int>,
) {
    companion object {
        fun from(notes: List<NoteEntity>): SidebarStats {
            val zone = ZoneId.systemDefault()
            val today = LocalDate.now(zone)
            val dates = notes.mapNotNull { runCatching { Instant.parse(it.createdAt).atZone(zone).toLocalDate() }.getOrNull() }
            val dateSet = dates.toSet()
            var cursor = if (today in dateSet) today else today.minusDays(1)
            var streak = 0
            while (cursor in dateSet) {
                streak += 1
                cursor = cursor.minusDays(1)
            }
            val weekStart = today.minusDays((today.dayOfWeek.value - 1).toLong())
            val current = dates.count { !it.isBefore(weekStart) && !it.isAfter(today) }
            val previousStart = weekStart.minusWeeks(1)
            val previousEnd = weekStart.minusDays(1)
            val previous = dates.count { !it.isBefore(previousStart) && !it.isAfter(previousEnd) }
            val trend = when {
                previous == 0 && current > 0 -> SidebarTrend.New
                current > previous -> SidebarTrend.Up
                current < previous -> SidebarTrend.Down
                else -> SidebarTrend.Same
            }
            val percent = if (previous == 0) 0 else ((kotlin.math.abs(current - previous).toDouble() / previous) * 100).toInt()
            return SidebarStats(
                streakDays = streak,
                weekCount = current,
                percent = percent,
                trend = trend,
                dailyCounts = (6 downTo 0).map { offset -> dates.count { it == today.minusDays(offset.toLong()) } },
            )
        }
    }
}

private enum class SidebarTrend { Up, Down, Same, New }

private fun tagsForNote(
    noteId: String,
    tags: List<TagEntity>,
    noteTags: List<NoteTagCrossRef>,
): List<TagEntity> {
    val ids = noteTags.asSequence().filter { it.noteId == noteId }.map { it.tagId }.toSet()
    return tags.filter { it.id in ids }
}

private fun relativeDate(rawValue: String, locale: Locale): String {
    val instant = runCatching { Instant.parse(rawValue) }.getOrNull() ?: return rawValue
    val date = instant.atZone(ZoneId.systemDefault()).toLocalDate()
    val today = LocalDate.now()
    val days = java.time.temporal.ChronoUnit.DAYS.between(date, today)
    return when (days) {
        0L -> java.time.format.DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(instant.atZone(ZoneId.systemDefault()))
        1L -> java.text.DateFormatSymbols(locale).shortWeekdays[date.dayOfWeek.value % 7 + 1]
        in 2L..6L -> date.dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, locale)
        else -> DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale).format(date)
    }
}

private fun String.moveResource(): Int = when (this) {
    "drafts" -> R.string.note_move_to_drafts
    "published" -> R.string.note_move_to_published
    else -> R.string.note_move_to_inbox
}
