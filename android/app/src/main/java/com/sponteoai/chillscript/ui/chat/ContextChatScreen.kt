package com.sponteoai.chillscript.ui.chat

import android.text.format.DateFormat
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowUpward
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.SaveAlt
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.ContextChatUiState
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.ChatMessage
import com.sponteoai.chillscript.ai.ChatRole
import com.sponteoai.chillscript.ai.ContextChatPrompt
import com.sponteoai.chillscript.ai.RecipeStore
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.ui.markdown.markdownAnnotatedString
import com.sponteoai.chillscript.ui.skills.CreatorSkillIcon
import com.sponteoai.chillscript.ui.skills.recipeDescription
import com.sponteoai.chillscript.ui.skills.recipeName
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Date
import java.util.Locale

private data class SlashCommandMatch(
    val start: Int,
    val end: Int,
    val recipes: List<AgentRecipe>,
)

@Composable
fun ContextChatScreen(
    state: ContextChatUiState,
    onClose: () -> Unit,
    onClear: () -> Unit,
    onSend: (String) -> Unit,
    onSave: (ChatMessage) -> Unit,
    onDismissError: () -> Unit,
) {
    var input by rememberSaveable { mutableStateOf("") }
    var contextExpanded by rememberSaveable { mutableStateOf(false) }
    var inputFocused by remember { mutableStateOf(false) }
    var highlightedNoteId by remember { mutableStateOf<String?>(null) }
    val focusRequester = remember { FocusRequester() }
    val scope = rememberCoroutineScope()
    val appContext = LocalContext.current.applicationContext
    val recipeStore = remember(appContext) { RecipeStore(appContext) }
    val installedRecipes by recipeStore.installed.collectAsState()
    val localizedRecipeNames = installedRecipes.associate { recipe ->
        recipe.id to recipeName(recipe)
    }
    val chatListState = rememberLazyListState()
    val slashMatch = remember(input, inputFocused, installedRecipes, localizedRecipeNames) {
        if (inputFocused) {
            detectSlashCommand(input, installedRecipes, localizedRecipeNames)
        } else {
            null
        }
    }

    val sendInput: () -> Unit = {
        val message = input.trim()
        if (message.isNotEmpty() && !state.processing) {
            onSend(message)
            input = ""
        }
    }

    LaunchedEffect(state.messages.size, state.processing) {
        val itemCount = state.messages.size + if (state.processing) 1 else 0
        if (itemCount > 0) chatListState.animateScrollToItem(itemCount - 1)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .statusBarsPadding(),
    ) {
        ChatNavigationBar(
            canClear = state.messages.isNotEmpty(),
            onClose = onClose,
            onClear = onClear,
        )

        ContextPreview(
            notes = state.contextNotes,
            expanded = contextExpanded,
            highlightedNoteId = highlightedNoteId,
            onToggle = { contextExpanded = !contextExpanded },
        )

        HorizontalDivider(color = ChillColors.TextSub.copy(alpha = 0.2f))

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(ChillColors.BackgroundPrimary),
        ) {
            if (state.messages.isEmpty() && !state.processing) {
                ChatEmptyState(hasContext = state.contextNotes.isNotEmpty())
            } else {
                LazyColumn(
                    state = chatListState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        top = 40.dp,
                        end = 16.dp,
                        bottom = 16.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    items(state.messages, key = { it.id }) { message ->
                        ChatBubble(
                            message = message,
                            saved = state.savedMessageId == message.id,
                            contextNoteCount = state.contextNotes.size,
                            onSave = onSave,
                            onCitation = { citationNumber ->
                                state.contextNotes.getOrNull(citationNumber - 1)?.let { note ->
                                    contextExpanded = true
                                    highlightedNoteId = note.id
                                    scope.launch {
                                        delay(2_000)
                                        if (highlightedNoteId == note.id) highlightedNoteId = null
                                    }
                                }
                            },
                        )
                    }
                    if (state.processing) {
                        item(key = "thinking") { ThinkingBubble() }
                    }
                }
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding(),
        ) {
            ChatInputDock(
                input = input,
                inputFocused = inputFocused,
                enabled = !state.processing,
                slashMatch = slashMatch,
                installedRecipesEmpty = installedRecipes.isEmpty(),
                focusRequester = focusRequester,
                onInputChange = { input = it },
                onFocusChange = { inputFocused = it },
                onSelectRecipe = { recipe ->
                    slashMatch?.let { match ->
                        input = input.replaceRange(match.start, match.end, "/${recipe.id} ")
                        focusRequester.requestFocus()
                    }
                },
                onSend = sendInput,
            )

            state.errorMessage?.let { error ->
                ChatErrorBanner(
                    message = error,
                    onDismiss = onDismissError,
                )
            }
        }
    }
}

@Composable
private fun ChatNavigationBar(
    canClear: Boolean,
    onClose: () -> Unit,
    onClear: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(ChillColors.BackgroundSecondary),
    ) {
        TextButton(
            onClick = onClose,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .heightIn(min = 50.dp),
        ) {
            Text(
                text = stringResource(R.string.common_close),
                color = ChillColors.BrandBlueText,
                style = MaterialTheme.typography.bodyMedium,
            )
        }

        Text(
            text = stringResource(R.string.ai_chat_title),
            modifier = Modifier.align(Alignment.Center),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )

        IconButton(
            onClick = onClear,
            enabled = canClear,
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .heightIn(min = 50.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.DeleteOutline,
                contentDescription = stringResource(R.string.ai_chat_clear),
                tint = if (canClear) ChillColors.TextSub else ChillColors.TextTertiary.copy(alpha = 0.45f),
            )
        }
    }
}

@Composable
private fun ContextPreview(
    notes: List<NoteEntity>,
    expanded: Boolean,
    highlightedNoteId: String?,
    onToggle: () -> Unit,
) {
    val listState = rememberLazyListState()

    LaunchedEffect(highlightedNoteId) {
        val index = notes.indexOfFirst { it.id == highlightedNoteId }
        if (index >= 0) listState.animateScrollToItem(index)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 2.dp,
                ambientColor = Color.Black.copy(alpha = 0.05f),
                spotColor = Color.Black.copy(alpha = 0.05f),
            )
            .background(ChillColors.BackgroundSecondary),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle)
                .background(ChillColors.BackgroundSecondary)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Outlined.Description,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = ChillColors.BrandTealText,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.ai_chat_context_notes_format, notes.size),
                modifier = Modifier.weight(1f),
                color = ChillColors.TextMain,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
            )
            Icon(
                imageVector = Icons.Outlined.ExpandMore,
                contentDescription = stringResource(
                    if (expanded) R.string.ai_chat_context_collapse else R.string.ai_chat_context_expand,
                ),
                modifier = Modifier
                    .size(18.dp)
                    .rotate(if (expanded) 180f else 0f),
                tint = ChillColors.TextSub,
            )
        }

        AnimatedVisibility(
            visible = expanded,
            enter = slideInVertically { -it / 2 } + fadeIn(),
            exit = slideOutVertically { -it / 2 } + fadeOut(),
        ) {
            LazyRow(
                state = listState,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(ChillColors.BackgroundPrimary.copy(alpha = 0.5f)),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(notes, key = { it.id }) { note ->
                    ContextNoteCard(
                        note = note,
                        highlighted = note.id == highlightedNoteId,
                    )
                }
            }
        }
    }
}

@Composable
private fun ContextNoteCard(note: NoteEntity, highlighted: Boolean) {
    val locale = LocalLocale.current.platformLocale
    val dateLabel = remember(note.createdAt, locale) { formatNoteDate(note.createdAt, locale) }

    Column(
        modifier = Modifier
            .scale(if (highlighted) 1.03f else 1f)
            .width(140.dp)
            .height(100.dp)
            .shadow(
                elevation = if (highlighted) 10.dp else 4.dp,
                shape = RoundedCornerShape(12.dp),
                ambientColor = if (highlighted) {
                    ChillColors.BrandTeal.copy(alpha = 0.18f)
                } else {
                    Color.Black.copy(alpha = 0.03f)
                },
                spotColor = if (highlighted) {
                    ChillColors.BrandTeal.copy(alpha = 0.18f)
                } else {
                    Color.Black.copy(alpha = 0.03f)
                },
            )
            .background(
                color = if (highlighted) ChillColors.BrandTealSoft else ChillColors.CardBackground,
                shape = RoundedCornerShape(12.dp),
            )
            .border(
                width = if (highlighted) 2.dp else 1.dp,
                color = if (highlighted) {
                    ChillColors.BrandTeal.copy(alpha = 0.75f)
                } else {
                    Color.Black.copy(alpha = 0.05f)
                },
                shape = RoundedCornerShape(12.dp),
            )
            .padding(10.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = note.previewPlainText.ifBlank { note.content },
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Normal),
            maxLines = 3,
        )
        Text(
            text = dateLabel,
            color = ChillColors.TextSub,
            fontSize = 9.sp,
            lineHeight = 11.sp,
        )
    }
}

@Composable
private fun ChatEmptyState(hasContext: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(
                if (hasContext) R.string.ai_chat_empty_title else R.string.ai_chat_empty_no_notes_title,
            ),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = stringResource(
                if (hasContext) R.string.ai_chat_empty_message else R.string.ai_chat_empty_no_notes_message,
            ),
            color = ChillColors.TextSub,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ChatBubble(
    message: ChatMessage,
    saved: Boolean,
    contextNoteCount: Int,
    onSave: (ChatMessage) -> Unit,
    onCitation: (Int) -> Unit,
) {
    val isUser = message.role == ChatRole.USER
    val context = LocalContext.current
    val timeLabel = remember(message.id, message.createdAt) {
        DateFormat.getTimeFormat(context).format(Date(message.createdAt))
    }
    val content = remember(message.content, message.role) {
        if (isUser) message.content else ContextChatPrompt.sanitize(message.content)
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Column(
            modifier = if (isUser) Modifier.widthIn(max = 280.dp) else Modifier.fillMaxWidth(),
            horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(horizontalAlignment = if (isUser) Alignment.End else Alignment.Start) {
                if (isUser) {
                    Text(
                        text = content,
                        modifier = Modifier
                            .background(ChillColors.BrandTealSoft, RoundedCornerShape(16.dp))
                            .padding(12.dp),
                        color = ChillColors.TextMain,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                } else {
                    AssistantMessageContent(
                        content = content,
                        contextNoteCount = contextNoteCount,
                        onCitation = onCitation,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(ChillColors.BackgroundSecondary, RoundedCornerShape(16.dp))
                            .padding(12.dp),
                    )
                }
                Text(
                    text = timeLabel,
                    modifier = Modifier.padding(top = 4.dp),
                    color = ChillColors.TextSub,
                    fontSize = 10.sp,
                    lineHeight = 12.sp,
                )
            }

            if (!isUser) {
                Surface(
                    onClick = { onSave(message) },
                    enabled = !saved,
                    color = if (saved) Color(0xFF2E9B63).copy(alpha = 0.10f)
                    else ChillColors.BrandTeal.copy(alpha = 0.10f),
                    contentColor = if (saved) Color(0xFF2E9B63) else ChillColors.BrandTealText,
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Icon(
                            imageVector = if (saved) Icons.Outlined.CheckCircle else Icons.Outlined.SaveAlt,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                        )
                        Text(
                            text = stringResource(
                                if (saved) R.string.ai_chat_saved else R.string.ai_chat_save_as_note,
                            ),
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AssistantMessageContent(
    content: String,
    contextNoteCount: Int,
    onCitation: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val base = markdownAnnotatedString(
        markdown = content,
        primary = ChillColors.BrandTealText,
        secondary = ChillColors.TextSub,
    )
    val annotated = remember(base, contextNoteCount) {
        annotateCitations(base, contextNoteCount)
    }

    ClickableText(
        text = annotated,
        modifier = modifier,
        style = MaterialTheme.typography.bodyMedium.copy(color = ChillColors.TextMain),
        onClick = { offset ->
            annotated.getStringAnnotations(
                tag = CITATION_TAG,
                start = offset,
                end = offset,
            ).firstOrNull()?.item?.toIntOrNull()?.let(onCitation)
        },
    )
}

@Composable
private fun ThinkingBubble() {
    val transition = rememberInfiniteTransition(label = "thinking-dots")
    Row(
        modifier = Modifier
            .background(ChillColors.BackgroundSecondary, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.AutoAwesome,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = ChillColors.BrandTealText,
        )
        Text(
            text = stringResource(R.string.ai_chat_thinking),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.bodyMedium,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            repeat(3) { index ->
                val emphasis by transition.animateFloat(
                    initialValue = 0.25f,
                    targetValue = 1f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(durationMillis = 450, delayMillis = index * 150),
                        repeatMode = RepeatMode.Reverse,
                    ),
                    label = "thinking-dot-$index",
                )
                Box(
                    modifier = Modifier
                        .scale(0.9f + emphasis * 0.25f)
                        .size(6.dp)
                        .background(
                            color = ChillColors.BrandTeal.copy(alpha = emphasis),
                            shape = CircleShape,
                        ),
                )
            }
        }
    }
}

@Composable
private fun ChatErrorBanner(message: String, onDismiss: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFFFFEDEE))
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Warning,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = Color(0xFFC33B45),
        )
        Text(
            text = message,
            modifier = Modifier.weight(1f),
            color = Color(0xFFC33B45),
            style = MaterialTheme.typography.labelMedium,
        )
        TextButton(onClick = onDismiss) {
            Text(
                text = stringResource(R.string.ai_chat_error_dismiss),
                color = Color(0xFFC33B45),
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun ChatInputDock(
    input: String,
    inputFocused: Boolean,
    enabled: Boolean,
    slashMatch: SlashCommandMatch?,
    installedRecipesEmpty: Boolean,
    focusRequester: FocusRequester,
    onInputChange: (String) -> Unit,
    onFocusChange: (Boolean) -> Unit,
    onSelectRecipe: (AgentRecipe) -> Unit,
    onSend: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChillColors.BackgroundPrimary.copy(alpha = 0.995f))
            .padding(horizontal = 16.dp)
            .padding(top = 10.dp, bottom = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AnimatedVisibility(
            visible = inputFocused && slashMatch != null,
            enter = slideInVertically { it / 2 } + fadeIn(),
            exit = slideOutVertically { it / 2 } + fadeOut(),
        ) {
            slashMatch?.let {
                SlashSkillsPanel(
                    recipes = it.recipes,
                    emptyLibrary = installedRecipesEmpty,
                    onSelect = onSelectRecipe,
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            BasicTextField(
                value = input,
                onValueChange = onInputChange,
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(focusRequester)
                    .onFocusChanged { onFocusChange(it.isFocused) },
                enabled = enabled,
                minLines = 1,
                maxLines = 5,
                textStyle = MaterialTheme.typography.bodyMedium.copy(color = ChillColors.TextMain),
                cursorBrush = SolidColor(ChillColors.BrandTeal),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSend() }),
                decorationBox = { innerTextField ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 44.dp)
                            .shadow(
                                elevation = 8.dp,
                                shape = RoundedCornerShape(22.dp),
                                ambientColor = ChillColors.Shadow.copy(alpha = 0.55f),
                                spotColor = ChillColors.Shadow.copy(alpha = 0.55f),
                            )
                            .background(ChillColors.BackgroundSecondary, RoundedCornerShape(22.dp))
                            .border(
                                width = 1.dp,
                                color = ChillColors.TextSub.copy(alpha = 0.14f),
                                shape = RoundedCornerShape(22.dp),
                            )
                            .padding(horizontal = 14.dp, vertical = 11.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (input.isEmpty()) {
                            Text(
                                text = stringResource(R.string.ai_chat_input_placeholder),
                                color = ChillColors.TextTertiary,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                        innerTextField()
                    }
                },
            )

            val canSend = input.isNotBlank() && enabled
            Surface(
                onClick = onSend,
                enabled = canSend,
                modifier = Modifier.size(36.dp),
                shape = CircleShape,
                color = if (canSend) ChillColors.BrandTeal else ChillColors.TextSub.copy(alpha = 0.20f),
                shadowElevation = if (canSend) 6.dp else 0.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.ArrowUpward,
                        contentDescription = stringResource(R.string.ai_chat_send),
                        modifier = Modifier.size(18.dp),
                        tint = if (canSend) Color.White else ChillColors.TextSub.copy(alpha = 0.50f),
                    )
                }
            }
        }
    }
}

@Composable
private fun SlashSkillsPanel(
    recipes: List<AgentRecipe>,
    emptyLibrary: Boolean,
    onSelect: (AgentRecipe) -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(18.dp),
                ambientColor = Color.Black.copy(alpha = 0.08f),
                spotColor = Color.Black.copy(alpha = 0.08f),
            ),
        color = ChillColors.BackgroundSecondary.copy(alpha = 0.98f),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = stringResource(R.string.ai_chat_skills_title),
                color = ChillColors.TextSub,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )

            if (emptyLibrary) {
                Text(
                    text = stringResource(R.string.ai_chat_skills_empty),
                    color = ChillColors.TextSub,
                    style = MaterialTheme.typography.bodyMedium,
                )
            } else {
                LazyColumn(
                    modifier = Modifier.heightIn(max = 220.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(recipes, key = { it.id }) { recipe ->
                        Surface(
                            onClick = { onSelect(recipe) },
                            modifier = Modifier.fillMaxWidth(),
                            color = ChillColors.CardBackground,
                            shape = RoundedCornerShape(14.dp),
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                CreatorSkillIcon(recipe = recipe, container = 36.dp, iconSize = 18.dp)
                                Column(
                                    modifier = Modifier.weight(1f),
                                    verticalArrangement = Arrangement.spacedBy(2.dp),
                                ) {
                                    Text(
                                        text = "/${recipe.id}",
                                        color = ChillColors.TextMain,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    Text(
                                        text = recipeDescription(recipe),
                                        color = ChillColors.TextSub,
                                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Normal),
                                        maxLines = 2,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun detectSlashCommand(
    input: String,
    recipes: List<AgentRecipe>,
    localizedNames: Map<String, String>,
): SlashCommandMatch? {
    if (input.isEmpty()) return null
    val slash = input.lastIndexOf('/')
    if (slash < 0) return null
    if (slash > 0 && !input[slash - 1].isWhitespace()) return null

    val token = input.substring(slash)
    if (token.any { it.isWhitespace() }) return null
    val query = token.drop(1).trim()
    val matches = recipes.filter { recipe ->
        query.isEmpty() ||
            recipe.id.contains(query, ignoreCase = true) ||
            localizedNames[recipe.id].orEmpty().contains(query, ignoreCase = true)
    }
    if (recipes.isNotEmpty() && matches.isEmpty()) return null
    return SlashCommandMatch(start = slash, end = input.length, recipes = matches)
}

private fun annotateCitations(base: AnnotatedString, contextNoteCount: Int): AnnotatedString {
    val builder = AnnotatedString.Builder(base)
    CITATION_PATTERN.findAll(base.text).forEach { match ->
        val number = match.groupValues.getOrNull(1)?.toIntOrNull() ?: return@forEach
        if (number !in 1..contextNoteCount) return@forEach
        builder.addStringAnnotation(
            tag = CITATION_TAG,
            annotation = number.toString(),
            start = match.range.first,
            end = match.range.last + 1,
        )
        builder.addStyle(
            style = SpanStyle(
                color = ChillColors.BrandTealText,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            ),
            start = match.range.first,
            end = match.range.last + 1,
        )
    }
    return builder.toAnnotatedString()
}

private fun formatNoteDate(rawValue: String, locale: Locale): String {
    val date = runCatching {
        Instant.parse(rawValue).atZone(ZoneId.systemDefault()).toLocalDate()
    }.recoverCatching {
        OffsetDateTime.parse(rawValue).toLocalDate()
    }.recoverCatching {
        LocalDate.parse(rawValue.take(10))
    }.getOrNull() ?: return rawValue.take(10)

    return DateTimeFormatter
        .ofLocalizedDate(FormatStyle.MEDIUM)
        .withLocale(locale)
        .format(date)
}

private const val CITATION_TAG = "citation"
private val CITATION_PATTERN = Regex("""\[(\d+)]""")
