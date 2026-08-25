package com.sponteoai.chillscript.ui.home

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.remember
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme

/** Debug-only visual QA host. It is not packaged in release builds. */
class FirstActionGuidePreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val stage = intent.getStringExtra("stage")
            ?.let { raw -> HomeFirstActionStage.entries.firstOrNull { it.name == raw } }
            ?: HomeFirstActionStage.SharePrompt
        val targetNoteId = "visual-qa-imported-note"
        val note = NoteEntity(
            id = targetNoteId,
            userId = "visual-qa",
            content = "## Transcript\nTurn any useful video into a clean note you can create from.",
            previewPlainText = "Turn any useful video into a clean note you can create from.",
            createdAt = "2026-08-25T00:00:00Z",
            updatedAt = "2026-08-25T00:00:00Z",
            sourceUrl = "https://www.tiktok.com/visual-qa",
            sourceTitle = "A creator workflow worth saving",
            sourcePlatformId = "tiktok",
            sourcePlatformName = "TikTok",
            sourceAuthorName = "Creator",
            importStatus = "completed",
        )
        val previewNotes = if (stage == HomeFirstActionStage.OpenImportedNote) listOf(note) else emptyList()
        setContent {
            ChillScriptTheme {
                IOSParityHomeScreen(
                    notes = previewNotes,
                    allNotes = previewNotes,
                    tags = emptyList(),
                    noteTags = emptyList(),
                    selectedSection = "inbox",
                    selectedTagId = null,
                    headerTitle = "ChillScript",
                    showSectionPicker = true,
                    searchVisible = false,
                    searchQuery = "",
                    isSelectionMode = false,
                    selectedNoteIds = emptySet(),
                    isRecording = false,
                    isVoiceProcessing = false,
                    initialNotesSyncing = false,
                    hasLoadedNotesAtLeastOnce = true,
                    pendingRecordingsCount = 0,
                    subscriptionTier = "free",
                    creditBalance = 10,
                    snackbarHostState = remember { SnackbarHostState() },
                    onSelectSection = {},
                    onToggleSearch = {},
                    onSearchQueryChange = {},
                    onOpenNote = {},
                    onToggleNoteSelection = {},
                    onEnterSelectionMode = {},
                    onExitSelectionMode = {},
                    onSelectAll = {},
                    onDeleteSelection = {},
                    onStartAIChat = {},
                    onPin = {},
                    onManageTags = {},
                    onMove = { _, _ -> },
                    onDelete = {},
                    onRestore = {},
                    onPermanentDelete = {},
                    onOpenSource = {},
                    onEmptyTrash = {},
                    onCreateBlankNote = {},
                    onStartVoiceRecording = {},
                    onCancelVoiceRecording = {},
                    onConfirmVoiceRecording = {},
                    onPasteLink = { done -> done(false) },
                    onOpenSubscription = {},
                    onOpenWeeklyTopics = {},
                    onOpenPendingRecordings = {},
                    onOpenSettings = {},
                    onSelectTag = {},
                    onMoveTag = { _, _ -> },
                    onDeleteTag = {},
                    firstActionGuideState = HomeFirstActionGuideState(
                        stage = stage,
                        targetNoteId = if (stage == HomeFirstActionStage.OpenImportedNote) targetNoteId else null,
                    ),
                    onAcknowledgeFirstActionShare = {},
                    onDismissFirstActionGuide = {},
                    onOpenFirstActionTarget = {},
                )
            }
        }
    }
}
