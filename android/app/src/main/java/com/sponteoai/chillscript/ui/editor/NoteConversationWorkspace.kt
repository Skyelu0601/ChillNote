package com.sponteoai.chillscript.ui.editor

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import com.sponteoai.chillscript.ui.skills.recipeDescription
import androidx.compose.foundation.lazy.LazyRow
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
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun NoteConversationWorkspace(
    controller: NoteConversationController,
    content: String,
    recipes: List<AgentRecipe>,
    enabled: Boolean,
    onReplace: suspend (String) -> Boolean,
    onSkillSelected: () -> Unit,
    onFirstSkillBounds: (Rect) -> Unit,
    skillsPanelContent: @Composable (onDismiss: () -> Unit) -> Unit,
    onConversationSettled: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val state by controller.state.collectAsState()
    val quickSkills = recipes.take(4)
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current
    val focus = LocalFocusManager.current
    val list = rememberLazyListState()
    val input = state.input
    var showSkills by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var showClearConfirmation by remember { mutableStateOf(false) }
    var inputFocused by remember { mutableStateOf(false) }
    val inputFocus = remember { FocusRequester() }
    fun skill(recipe: AgentRecipe) {
        if (!enabled || state.busy || state.applying) return
        focus.clearFocus(); showSkills = false; onSkillSelected()
        controller.send(content, recipe.name, recipe)
    }
    LaunchedEffect(state.turns.size, state.busy, inputFocused) {
        val count = list.layoutInfo.totalItemsCount
        if (count > 0 && state.turns.isNotEmpty()) list.animateScrollToItem(count - 1)
    }
    LaunchedEffect(state.busy, state.turns) {
        if (!state.busy) onConversationSettled(state.turns.any { it.answer != null })
    }
    Column(modifier.fillMaxSize().background(ChillColors.BackgroundSecondary)) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
        LazyColumn(
            state = list, modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = if (state.turns.isEmpty()) 12.dp else 20.dp), verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            if (state.turns.isEmpty()) item {
                Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(R.string.note_chat_welcome_title), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ChillColors.TextMain)
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        quickSkills.forEach { recipe ->
                            val first = recipe.id == quickSkills.firstOrNull()?.id
                            Surface(
                                onClick = { skill(recipe) }, enabled = enabled && !state.busy,
                                shape = RoundedCornerShape(14.dp),
                                color = if (first) ChillColors.BrandBlueSoft else ChillColors.BackgroundSecondary,
                                border = BorderStroke(1.dp, if (first) ChillColors.BrandBlue.copy(alpha = 0.12f) else ChillColors.BorderSubtle),
                                modifier = Modifier.fillMaxWidth().onGloballyPositioned {
                                    if (first) onFirstSkillBounds(it.boundsInRoot())
                                },
                            ) {
                                Row(Modifier.heightIn(min = 60.dp).padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                    CreatorSkillIcon(recipe, iconSize = 20.dp, container = 36.dp)
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                        Text(recipeName(recipe), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = ChillColors.TextMain)
                                        Text(quickSkillDescription(recipe), fontSize = 13.sp, color = ChillColors.TextSub)
                                    }
                                    Icon(Icons.Outlined.ChevronRight, null, Modifier.size(18.dp), tint = ChillColors.TextSub)
                                }
                            }
                        }
                    }
                    Text(stringResource(R.string.note_chat_suggestions_title), modifier = Modifier.padding(top = 8.dp), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ChillColors.TextMain)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(R.string.note_chat_suggestions_script, R.string.note_chat_suggestions_hooks).forEach { resource ->
                            val prompt = stringResource(resource)
                            Surface(onClick = { controller.input(prompt); inputFocus.requestFocus() }, enabled = enabled && !state.busy,
                                shape = RoundedCornerShape(50), color = ChillColors.BackgroundPrimary,
                                border = BorderStroke(1.dp, ChillColors.BorderSubtle)) {
                                Text(prompt, Modifier.padding(horizontal = 12.dp, vertical = 10.dp), fontSize = 12.sp, color = ChillColors.TextSub)
                            }
                        }
                    }
                }
            }

            items(state.turns, key = { it.id }) { turn ->
                Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Surface(shape = RoundedCornerShape(16.dp), color = ChillColors.BrandBlueSoft, modifier = Modifier.widthIn(max = 330.dp)) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                if (turn.recipe != null) {
                                    CreatorSkillIcon(turn.recipe, iconSize = 16.dp, container = 26.dp)
                                    Text(recipeName(turn.recipe), fontWeight = FontWeight.Medium)
                                    Text(stringResource(R.string.note_chat_skill_badge), fontSize = 11.sp, color = ChillColors.TextSub, modifier = Modifier.background(ChillColors.BrandBlue.copy(alpha = 0.08f), RoundedCornerShape(4.dp)).padding(horizontal = 5.dp, vertical = 3.dp))
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
                            if (state.appliedTurnId == turn.id && state.undoContent != null && state.appliedContent == content) {
                                TextButton(onClick = { scope.launch { controller.undo(content, onReplace) } }, enabled = enabled && !state.busy) {
                                    Text(stringResource(R.string.common_undo))
                                }
                            }
                            NoteConversationCopyButton(answer = turn.answer) {
                                clipboard.setText(AnnotatedString(turn.answer))
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
        }
        Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (state.turns.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(quickSkills, key = { it.id }) { recipe ->
                        Surface(onClick = { skill(recipe) }, enabled = enabled && !state.busy && !state.applying,
                            color = ChillColors.BrandBlueSoft, shape = RoundedCornerShape(50),
                            modifier = Modifier.onGloballyPositioned {
                                if (recipe.id == quickSkills.firstOrNull()?.id) onFirstSkillBounds(it.boundsInRoot())
                            }) {
                            Text(recipeName(recipe), Modifier.padding(horizontal = 12.dp, vertical = 8.dp), fontSize = 13.sp, color = ChillColors.TextMain)
                        }
                    }
                }
            }
            if (state.storageError || state.saveError || state.clearError) {
                Text(stringResource(when {
                    state.clearError -> R.string.note_chat_clear_error
                    state.saveError -> R.string.note_chat_save_error
                    else -> R.string.note_chat_history_error
                }), color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
            }
            OutlinedTextField(
                value = input, onValueChange = controller::input, enabled = enabled,
                modifier = Modifier.fillMaxWidth().focusRequester(inputFocus).onFocusChanged { inputFocused = it.isFocused }, maxLines = 5, shape = RoundedCornerShape(26.dp),
                placeholder = { Text(stringResource(R.string.note_chat_input_placeholder)) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = ChillColors.BorderSubtle,
                    unfocusedBorderColor = ChillColors.BorderSubtle,
                ),
                leadingIcon = {
                    Box {
                        IconButton(onClick = { focus.clearFocus(); menuOpen = true }, enabled = enabled) {
                            Icon(Icons.Outlined.MoreHoriz, stringResource(R.string.note_chat_menu), modifier = Modifier.size(20.dp), tint = ChillColors.TextSub)
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(text = { Text(stringResource(R.string.note_chat_all_skills)) },
                                leadingIcon = { Icon(Icons.Outlined.AutoAwesome, null) }, enabled = !state.busy,
                                onClick = { menuOpen = false; showSkills = true })
                            if (state.turns.isNotEmpty()) DropdownMenuItem(
                                text = { Text(stringResource(R.string.note_chat_clear_action), color = MaterialTheme.colorScheme.error) },
                                leadingIcon = { Icon(Icons.Outlined.DeleteOutline, null, tint = MaterialTheme.colorScheme.error) },
                                enabled = !state.applying,
                                onClick = { menuOpen = false; showClearConfirmation = true })
                        }
                    }
                },
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
                                stringResource(if (state.busy) R.string.common_cancel else R.string.chillo_send), tint = androidx.compose.ui.graphics.Color.White,
                                modifier = Modifier.size(40.dp).background(if (state.busy || input.isNotBlank()) ChillColors.BrandBlue else ChillColors.TextSub.copy(alpha = 0.4f), CircleShape).padding(10.dp))
                        }
                    }
                },
            )
        }
    }
    if (showClearConfirmation) {
        AlertDialog(onDismissRequest = { showClearConfirmation = false },
            title = { Text(stringResource(R.string.note_chat_clear_title)) },
            text = { Text(stringResource(R.string.note_chat_clear_message)) },
            confirmButton = { TextButton(onClick = { controller.clearConversation(); showClearConfirmation = false }) {
                Text(stringResource(R.string.note_chat_clear_action), color = MaterialTheme.colorScheme.error)
            } },
            dismissButton = { TextButton(onClick = { showClearConfirmation = false }) { Text(stringResource(R.string.common_cancel)) } })
    }
    if (showSkills) {
        CreatorSkillsSheet(onDismiss = { showSkills = false }) {
            skillsPanelContent { showSkills = false }
        }
    }
}

@Composable
private fun NoteConversationCopyButton(answer: String, onCopy: () -> Unit) {
    var isCopied by remember(answer) { mutableStateOf(false) }
    var copyRevision by remember(answer) { mutableIntStateOf(0) }
    LaunchedEffect(copyRevision) {
        if (copyRevision == 0) return@LaunchedEffect
        delay(2_000)
        isCopied = false
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        IconButton(onClick = {
            onCopy()
            isCopied = true
            copyRevision++
        }) {
            Icon(
                if (isCopied) Icons.Outlined.Check else Icons.Outlined.ContentCopy,
                stringResource(if (isCopied) R.string.ai_skills_result_copied else R.string.chillo_copy),
                Modifier.size(19.dp), tint = if (isCopied) ChillColors.BrandTealText else ChillColors.TextMain,
            )
        }
        if (isCopied) Text(stringResource(R.string.ai_skills_result_copied), fontSize = 13.sp, color = ChillColors.BrandTealText)
    }
}

@Composable
private fun quickSkillDescription(recipe: AgentRecipe): String {
    val resource = if (recipe.isCustom) null else when (recipe.id) {
        "rewrite" -> R.string.note_chat_quick_skill_rewrite_description
        "hook_generator" -> R.string.note_chat_quick_skill_hook_generator_description
        "caption_pack" -> R.string.note_chat_quick_skill_caption_pack_description
        "repurpose_pack" -> R.string.note_chat_quick_skill_repurpose_pack_description
        else -> null
    }
    return resource?.let { stringResource(it) } ?: recipeDescription(recipe)
}
