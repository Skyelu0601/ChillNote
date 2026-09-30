package com.sponteoai.chillscript.ui.editor

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.NoteConversationController
import com.sponteoai.chillscript.ui.markdown.MarkdownText
import com.sponteoai.chillscript.ui.skills.CreatorSkillsSheet
import com.sponteoai.chillscript.ui.skills.CreatorSkillIcon
import com.sponteoai.chillscript.ui.skills.recipeName
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteConversationWorkspace(
    controller: NoteConversationController,
    content: String,
    recipes: List<AgentRecipe>,
    expanded: Boolean,
    onToggleExpanded: () -> Unit,
    enabled: Boolean,
    onReplace: suspend (String) -> Boolean,
    onSkillSelected: () -> Unit,
    onFirstSkillBounds: (Rect) -> Unit,
    skillsPanelContent: @Composable (onDismiss: () -> Unit, onSelect: (AgentRecipe) -> Unit) -> Unit,
    onConversationSettled: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val state by controller.state.collectAsState()
    val preferred = listOf("rewrite", "hook_generator", "caption_pack", "repurpose_pack")
    val quickSkills = (preferred.mapNotNull { id -> recipes.firstOrNull { it.id == id } } + recipes.filterNot { it.id in preferred }).take(4)
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current
    val focus = LocalFocusManager.current
    val list = rememberLazyListState()
    val input = state.input
    var showSkills by remember { mutableStateOf(false) }
    fun skill(recipe: AgentRecipe) {
        if (!enabled || state.busy || state.applying) return
        focus.clearFocus(); showSkills = false; onSkillSelected()
        controller.send(content, recipe.name, recipe)
    }
    LaunchedEffect(state.turns.size, state.busy) {
        val count = list.layoutInfo.totalItemsCount
        if (count > 0 && state.turns.isNotEmpty()) list.animateScrollToItem(count - 1)
    }
    LaunchedEffect(state.busy, state.turns) {
        if (!state.busy) onConversationSettled(state.turns.any { it.answer != null })
    }
    Column(modifier.fillMaxSize()) {
        if (expanded) Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onToggleExpanded, modifier = Modifier.size(44.dp)) {
                Icon(if (expanded) Icons.Outlined.FullscreenExit else Icons.Outlined.Fullscreen,
                    stringResource(if (expanded) R.string.note_chat_collapse else R.string.note_chat_expand),
                    tint = ChillColors.TextSub, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.weight(1f))
            if (expanded) {
                Text(stringResource(R.string.chillo_title), fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.size(44.dp))
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth()) {
        LazyColumn(
            state = list, modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            if (state.turns.isEmpty()) item {
                Column(Modifier.padding(top = 32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.note_chat_welcome_title), modifier = Modifier.weight(1f), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = ChillColors.TextMain)
                        IconButton(onClick = { focus.clearFocus(); showSkills = true }, enabled = enabled && !state.busy) {
                            Icon(Icons.Outlined.MoreHoriz, stringResource(R.string.note_chat_all_skills), tint = ChillColors.TextSub)
                        }
                    }
                    Text(stringResource(R.string.note_chat_welcome_message), color = ChillColors.TextSub)
                    quickSkills.chunked(2).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            row.forEach { recipe ->
                                Surface(
                                    onClick = { skill(recipe) }, enabled = enabled && !state.busy,
                                    shape = RoundedCornerShape(14.dp), color = ChillColors.BackgroundSecondary,
                                    border = BorderStroke(1.dp, ChillColors.BorderSubtle),
                                    modifier = Modifier.weight(1f).onGloballyPositioned {
                                        if (recipe.id == quickSkills.firstOrNull()?.id) onFirstSkillBounds(it.boundsInRoot())
                                    },
                                ) {
                                    Row(Modifier.padding(12.dp).heightIn(min = 36.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        CreatorSkillIcon(recipe, iconSize = 18.dp, container = 32.dp)
                                        Text(recipeName(recipe), fontSize = 14.sp, color = ChillColors.TextMain)
                                    }
                                }
                            }
                            if (row.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
            items(state.turns, key = { it.id }) { turn ->
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Surface(shape = RoundedCornerShape(16.dp), color = ChillColors.BrandBlue.copy(alpha = 0.10f), modifier = Modifier.widthIn(max = 330.dp)) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                if (turn.recipe != null) {
                                    CreatorSkillIcon(turn.recipe, iconSize = 16.dp, container = 26.dp)
                                    Text(recipeName(turn.recipe), fontWeight = FontWeight.Medium)
                                    Text(stringResource(R.string.note_chat_skill_badge), fontSize = 11.sp, color = ChillColors.TextSub)
                                } else SelectionContainer { Text(turn.message) }
                            }
                        }
                    }
                    if (turn.answer != null) {
                        SelectionContainer { MarkdownText(turn.answer) }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { scope.launch { controller.replace(turn, content, onReplace) } }, enabled = enabled && !state.busy, shape = RoundedCornerShape(10.dp)) {
                                Icon(Icons.Outlined.Sync, null, Modifier.size(17.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(stringResource(R.string.note_chat_replace), fontSize = 13.sp)
                            }
                            IconButton(onClick = { clipboard.setText(AnnotatedString(turn.answer)) }) {
                                Icon(Icons.Outlined.ContentCopy, stringResource(R.string.chillo_copy), Modifier.size(19.dp))
                            }
                        }
                    } else if (turn.failed) {
                        Text(stringResource(R.string.note_chat_failed), color = ChillColors.TextSub)
                        if (turn.id == state.turns.lastOrNull()?.id) TextButton(
                            onClick = { controller.retry(content, turn) }, enabled = enabled && !state.busy,
                        ) { Text(stringResource(R.string.chillo_retry)) }
                    }
                }
            }
            if (state.busy && state.turns.lastOrNull()?.answer == null) item {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    Text(stringResource(R.string.chillo_working), color = ChillColors.TextSub)
                }
            }
            item { Spacer(Modifier.height(1.dp)) }
        }
            if (!expanded) {
                IconButton(onClick = onToggleExpanded,
                    modifier = Modifier.align(Alignment.TopStart).padding(start = 8.dp).size(44.dp)) {
                    Icon(Icons.Outlined.Fullscreen, stringResource(R.string.note_chat_expand),
                        tint = ChillColors.TextSub, modifier = Modifier.size(20.dp))
                }
            }
        }
        Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (state.storageError || state.saveError) {
                Text(stringResource(when {
                    state.saveError -> R.string.note_chat_save_error
                    else -> R.string.note_chat_history_error
                }), color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
            }
            if (state.undoContent != null && state.appliedContent == content) TextButton(
                onClick = { scope.launch { controller.undo(content, onReplace) } },
                enabled = enabled && !state.busy, modifier = Modifier.align(Alignment.End),
            ) { Text(stringResource(R.string.common_undo)) }
            OutlinedTextField(
                value = input, onValueChange = controller::input, enabled = enabled,
                modifier = Modifier.fillMaxWidth(), maxLines = 5, shape = RoundedCornerShape(26.dp),
                placeholder = { Text(stringResource(R.string.chillo_placeholder)) },
                leadingIcon = if (state.turns.isNotEmpty()) {
                    {
                        IconButton(
                            onClick = { focus.clearFocus(); showSkills = true },
                            enabled = enabled && !state.busy,
                            modifier = Modifier.onGloballyPositioned { onFirstSkillBounds(it.boundsInRoot()) },
                        ) {
                            Icon(Icons.Outlined.AutoAwesome, stringResource(R.string.note_chat_all_skills),
                                modifier = Modifier.size(20.dp), tint = ChillColors.TextSub)
                        }
                    }
                } else null,
                trailingIcon = {
                    Row {
                        IconButton(onClick = {
                            if (state.busy) controller.cancel()
                            else {
                                focus.clearFocus()
                                controller.send(content, input)
                            }
                        }, enabled = enabled && !state.applying && (state.busy || input.isNotBlank())) {
                            Icon(if (state.busy) Icons.Outlined.Stop else Icons.Outlined.ArrowUpward,
                                stringResource(if (state.busy) R.string.common_cancel else R.string.chillo_send), tint = ChillColors.BrandBlue)
                        }
                    }
                },
            )
        }
    }
    if (showSkills) {
        CreatorSkillsSheet(onDismiss = { showSkills = false }) {
            skillsPanelContent({ showSkills = false }, ::skill)
        }
    }
}
