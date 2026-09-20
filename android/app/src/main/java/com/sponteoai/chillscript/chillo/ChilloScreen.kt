package com.sponteoai.chillscript.chillo

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.markdown.markdownAnnotatedString
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChilloScreen(
    controller: ChilloController,
    onBack: () -> Unit,
    onOpenNote: suspend (String) -> Boolean,
    onInsufficientCredits: () -> Unit,
) {
    val state by controller.state.collectAsState()
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current
    val focus = LocalFocusManager.current
    val list = rememberLazyListState()
    var sheet by remember { mutableStateOf<String?>(null) }
    var sourceTurn by remember { mutableStateOf<ChilloTurn?>(null) }
    var deletion by remember { mutableStateOf<String?>(null) }
    var localError by remember { mutableStateOf<Int?>(null) }
    val voice = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.let {
                controller.input(listOf(state.input, it).filter(String::isNotBlank).joinToString(" "))
            }
        }
    }
    fun open(id: String) { scope.launch { if (!onOpenNote(id)) localError = R.string.chillo_note_unavailable } }
    BackHandler(onBack = onBack)
    LaunchedEffect(controller) { controller.load(); controller.reload(); controller.poll() }
    LaunchedEffect(state.turns.lastOrNull()?.id) { if (state.turns.isNotEmpty()) list.animateScrollToItem(list.layoutInfo.totalItemsCount.coerceAtLeast(1) - 1) }
    val latestCreditError = state.error == "INSUFFICIENT_CREDITS" ||
        state.turns.lastOrNull()?.errorCode == "INSUFFICIENT_CREDITS"
    LaunchedEffect(latestCreditError) {
        if (latestCreditError) onInsufficientCredits()
    }
    MaterialTheme(colorScheme = lightColorScheme(primary = Color(0xFF3387FF), background = Color.White, surface = Color.White, onSurface = Color.Black)) {
        Column(Modifier.fillMaxSize().background(Color.White).statusBarsPadding().navigationBarsPadding().imePadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back), tint = Color.Black) }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { focus.clearFocus(); sheet = "history" }) {
                    Text(stringResource(R.string.chillo_title), color = Color.Black, fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
                    Icon(Icons.Outlined.ExpandMore, stringResource(R.string.chillo_history), Modifier.size(16.dp), tint = Color.Gray)
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = controller::newConversation, enabled = !state.busy) { Icon(Icons.Outlined.Edit, stringResource(R.string.chillo_new), tint = Color.Black) }
            }
            LazyColumn(state = list, modifier = Modifier.weight(1f), contentPadding = PaddingValues(horizontal = 22.dp, vertical = 26.dp), verticalArrangement = Arrangement.spacedBy(26.dp)) {
                if (state.turns.isEmpty()) item {
                    Column(Modifier.padding(top = 68.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        Text(stringResource(R.string.chillo_empty_title), fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
                        Text(stringResource(R.string.chillo_empty_body), color = Color.Gray, fontSize = 15.sp, lineHeight = 22.sp)
                        if (state.library != null && state.needsConsent) {
                            Text(stringResource(R.string.chillo_consent_body), color = Color.Gray, fontSize = 13.sp, lineHeight = 19.sp)
                            Button(
                                onClick = { scope.launch { controller.consent(true) } },
                                shape = RoundedCornerShape(16.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = ChillColors.BrandBlue,
                                    contentColor = Color.White,
                                ),
                            ) {
                                Text(stringResource(R.string.chillo_consent_accept))
                            }
                        } else {
                            listOf(R.string.chillo_suggestion_ideas, R.string.chillo_suggestion_connect).forEach { key ->
                                val text = stringResource(key)
                                OutlinedButton(onClick = { controller.input(text) }) { Text(text, color = Color.Black, fontSize = 14.sp) }
                            }
                        }
                    }
                }
                if (state.olderCursor != null) item { TextButton(onClick = { scope.launch { controller.older() } }) { Text(stringResource(R.string.chillo_more)) } }
                items(state.turns, key = { it.id }) { turn ->
                    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            SelectionContainer { Text(turn.request, Modifier.widthIn(max = 300.dp).background(Color(0xFFEEF5FF), RoundedCornerShape(21.dp)).padding(horizontal = 17.dp, vertical = 13.dp), fontSize = 16.sp, lineHeight = 23.sp) }
                        }
                        when {
                            turn.active -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                                Text(stringResource(R.string.chillo_working), color = Color.Gray, fontSize = 14.sp)
                            }
                            turn.sourcesChanged -> Text(stringResource(R.string.chillo_sources_changed), color = Color.Gray)
                            turn.answer.isNotEmpty() -> {
                                ChilloAnswer(turn.answer)
                                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                    if (turn.sources.isNotEmpty()) TextButton(onClick = { sourceTurn = turn; sheet = "sources" }, contentPadding = PaddingValues(0.dp)) {
                                        Text(stringResource(R.string.chillo_sources_count, turn.sources.map { it.noteId }.distinct().size), fontSize = 12.sp)
                                    }
                                    Spacer(Modifier.weight(1f))
                                    IconButton(onClick = { clipboard.setText(AnnotatedString(stripChilloCitations(turn.answer))) }) { Icon(Icons.Outlined.ContentCopy, stringResource(R.string.chillo_copy), Modifier.size(18.dp), tint = Color.Gray) }
                                    IconButton(onClick = { scope.launch { controller.action("draft", turn)?.let(::open) } }, enabled = !state.busy) {
                                        Icon(if (turn.draftNoteId == null) Icons.Outlined.SaveAlt else Icons.Outlined.Check, stringResource(if (turn.draftNoteId == null) R.string.chillo_save else R.string.chillo_open_draft), Modifier.size(18.dp), tint = Color.Gray)
                                    }
                                }
                            }
                            else -> {
                                Text(stringResource(if (turn.status == "cancelled") R.string.chillo_stopped else chilloError(turn.errorCode)), color = Color.Gray, fontSize = 14.sp)
                                if (turn.id == state.turns.lastOrNull()?.id) TextButton(onClick = { scope.launch { controller.action("retry", turn) } }, enabled = !state.busy) { Text(stringResource(R.string.chillo_retry)) }
                            }
                        }
                    }
                }
                if (state.error != null || localError != null) item {
                    Text(stringResource(localError ?: chilloError(state.error)), color = Color.Gray, fontSize = 13.sp)
                    TextButton(onClick = { localError = null; scope.launch { controller.load(); controller.reload() } }) { Text(stringResource(R.string.chillo_retry)) }
                }
            }
            Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().border(1.dp, Color(0xFFE0E0E0), RoundedCornerShape(27.dp)).padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.Bottom) {
                IconButton(onClick = { focus.clearFocus(); sheet = "library" }) { Icon(Icons.Outlined.Add, stringResource(R.string.chillo_library)) }
                BasicTextField(value = state.input, onValueChange = controller::input, enabled = !state.busy, modifier = Modifier.weight(1f).padding(vertical = 13.dp), maxLines = 6, textStyle = TextStyle(color = Color.Black, fontSize = 16.sp), decorationBox = { inner ->
                    if (state.input.isEmpty()) Text(stringResource(R.string.chillo_placeholder), color = Color.Gray, fontSize = 16.sp)
                    inner()
                })
                IconButton(onClick = {
                    runCatching { voice.launch(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)) }
                        .onFailure { localError = R.string.chillo_dictate_unavailable }
                }, enabled = !state.busy && !state.generating, modifier = Modifier.size(40.dp)) { Icon(Icons.Outlined.Mic, stringResource(R.string.chillo_dictate), Modifier.size(21.dp)) }
                IconButton(onClick = {
                    focus.clearFocus()
                    scope.launch {
                        val activeTurn = state.turns.lastOrNull()?.takeIf { it.active }
                        if (activeTurn != null) controller.action("cancel", activeTurn) else controller.send()
                    }
                }, enabled = !state.busy && (state.generating || (!state.needsConsent && state.input.isNotBlank() && state.input.length <= 16000)), modifier = Modifier.padding(3.dp).size(36.dp).background(Color.Black, CircleShape)) {
                    Icon(if (state.generating) Icons.Outlined.Stop else Icons.Outlined.ArrowUpward, stringResource(if (state.generating) R.string.chillo_stop else R.string.chillo_send), tint = Color.White, modifier = Modifier.size(21.dp))
                }
            }
        }
        if (sheet != null) ModalBottomSheet(onDismissRequest = { sheet = null }, containerColor = Color.White) {
            LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 22.dp), verticalArrangement = Arrangement.spacedBy(18.dp), contentPadding = PaddingValues(bottom = 32.dp)) {
                item { Text(stringResource(when (sheet) { "history" -> R.string.chillo_history; "sources" -> R.string.chillo_sources; else -> R.string.chillo_library }), fontSize = 19.sp, fontWeight = FontWeight.SemiBold) }
                when (sheet) {
                    "history" -> {
                        items(state.history, key = { it.id }) { conversation ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                TextButton(onClick = { sheet = null; scope.launch { controller.open(conversation.id) } }, modifier = Modifier.weight(1f)) { Text(conversation.title.ifBlank { stringResource(R.string.chillo_new) }, color = Color.Black) }
                                IconButton(onClick = { deletion = conversation.id }) { Icon(Icons.Outlined.DeleteOutline, stringResource(R.string.common_delete)) }
                            }
                        }
                        if (state.historyCursor != null) item { TextButton(onClick = { scope.launch { controller.moreHistory() } }) { Text(stringResource(R.string.chillo_more)) } }
                    }
                    "sources" -> items(uniqueChilloSources(sourceTurn?.sources.orEmpty()), key = { it.noteId }) { source ->
                        TextButton(onClick = { sheet = null; open(source.noteId) }, enabled = source.availability != "unavailable") { Text(source.title, fontWeight = FontWeight.SemiBold) }
                        SelectionContainer { Text(if (source.availability == "active") source.excerpt else stringResource(R.string.chillo_sources_changed), fontSize = 14.sp, color = Color.Gray) }
                        TextButton(onClick = { scope.launch { controller.exclude(source); sheet = null } }, enabled = !state.generating) { Text(stringResource(R.string.chillo_exclude)) }
                    }
                    else -> {
                        state.library?.let { library ->
                            item { Text(stringResource(R.string.chillo_library_summary, library.available, library.total)) }
                            item { Text(stringResource(R.string.chillo_library_index, library.indexed, library.available), color = Color.Gray) }
                        }
                        item { Text(stringResource(R.string.chillo_library_scope), color = Color.Gray) }
                        item { Text(stringResource(R.string.chillo_consent_body), fontSize = 13.sp, color = Color.Gray) }
                        item { TextButton(onClick = { scope.launch { controller.consent(state.needsConsent); sheet = null } }) { Text(stringResource(if (state.needsConsent) R.string.chillo_consent_accept else R.string.chillo_consent_revoke)) } }
                    }
                }
            }
        }
        if (deletion != null) AlertDialog(onDismissRequest = { deletion = null }, title = { Text(stringResource(R.string.chillo_delete_title)) }, text = { Text(stringResource(R.string.chillo_delete_body)) }, confirmButton = {
            TextButton(onClick = { val id = deletion; deletion = null; if (id != null) scope.launch { controller.delete(id) } }) { Text(stringResource(R.string.common_delete)) }
        }, dismissButton = { TextButton(onClick = { deletion = null }) { Text(stringResource(R.string.common_cancel)) } })
    }
}

internal fun chilloError(code: String?): Int = when (code) {
    "CONSENT_REQUIRED" -> R.string.chillo_consent_body
    "INSUFFICIENT_CREDITS" -> R.string.chillo_error_credits
    "BUSY" -> R.string.chillo_working
    "SOURCES_CHANGED" -> R.string.chillo_sources_changed
    "DRAFT_DELETED" -> R.string.chillo_draft_deleted
    else -> R.string.chillo_error_connection
}

@Composable
private fun ChilloAnswer(answer: String) {
    val text = remember(answer) {
        markdownAnnotatedString(stripChilloCitations(answer), Color(0xFF3387FF), Color.Gray)
    }
    SelectionContainer { Text(text, style = TextStyle(fontSize = 16.sp, lineHeight = 24.sp, color = Color.Black)) }
}

/** Converts legacy/internal citation links to the platform-neutral visible form. */
internal fun normalizeChilloCitations(answer: String): String = answer.replace(
    Regex("\\[(\\d+)]\\(\\s*chillo-source://\\d+\\s*\\)", RegexOption.IGNORE_CASE),
    "[$1]",
)

private val citationGroupRegex = Regex("\\[\\s*(\\d+(?:\\s*,\\s*\\d+)*)\\s*]")

internal fun stripChilloCitations(answer: String): String = citationGroupRegex
    .replace(normalizeChilloCitations(answer), "")
    .replace(Regex("[ \\t]+([,.;:!?])"), "$1")
    .replace(Regex("[ \\t]{2,}"), " ")
    .trim()

internal fun uniqueChilloSources(sources: List<ChilloSource>): List<ChilloSource> =
    sources.distinctBy(ChilloSource::noteId)
