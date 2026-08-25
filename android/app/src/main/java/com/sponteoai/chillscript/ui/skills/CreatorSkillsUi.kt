package com.sponteoai.chillscript.ui.skills

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ClosedCaption
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.FindReplace
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.Public
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.VerticalAlignBottom
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.AISkillApplyMode
import com.sponteoai.chillscript.ai.AISkillTextApplication
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.TextSelection
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import com.sponteoai.chillscript.ui.markdown.MarkdownText
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

@Composable
fun recipeName(recipe: AgentRecipe): String {
    if (recipe.isCustom) return recipe.name
    val resource = when (recipe.id) {
        "why_viral" -> R.string.recipe_why_viral_name
        "summarize" -> R.string.recipe_summarize_name
        "translate" -> R.string.recipe_translate_name
        "humanizer" -> R.string.recipe_humanizer_name
        "rewrite" -> R.string.recipe_rewrite_name
        "style_match" -> R.string.recipe_style_match_name
        "hook_generator" -> R.string.recipe_hook_generator_name
        "caption_pack" -> R.string.recipe_caption_pack_name
        "timed_script" -> R.string.recipe_timed_script_name
        "repurpose_pack" -> R.string.recipe_repurpose_pack_name
        else -> null
    }
    return resource?.let { stringResource(it) } ?: recipe.name
}

@Composable
fun recipeDescription(recipe: AgentRecipe): String {
    if (recipe.isCustom) return stringResource(R.string.creator_skills_custom_description)
    val resource = when (recipe.id) {
        "why_viral" -> R.string.recipe_why_viral_description
        "summarize" -> R.string.recipe_summarize_description
        "translate" -> R.string.recipe_translate_description
        "humanizer" -> R.string.recipe_humanizer_description
        "rewrite" -> R.string.recipe_rewrite_description
        "style_match" -> R.string.recipe_style_match_description
        "hook_generator" -> R.string.recipe_hook_generator_description
        "caption_pack" -> R.string.recipe_caption_pack_description
        "timed_script" -> R.string.recipe_timed_script_description
        "repurpose_pack" -> R.string.recipe_repurpose_pack_description
        else -> null
    }
    return resource?.let { stringResource(it) } ?: recipe.description
}

@Composable
fun CreatorSkillIcon(
    recipe: AgentRecipe,
    modifier: Modifier = Modifier,
    iconSize: Dp = 18.dp,
    container: Dp = 40.dp,
) {
    val tint = creatorSkillTint(recipe)
    Surface(
        modifier = modifier.size(container),
        color = tint.copy(alpha = 0.11f),
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, tint.copy(alpha = 0.22f)),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = creatorSkillImage(recipe),
                contentDescription = null,
                modifier = Modifier.size(iconSize),
                tint = tint,
            )
        }
    }
}

@Composable
fun CreatorSkillsRail(
    recipes: List<AgentRecipe>,
    onRecipe: (AgentRecipe) -> Unit,
    onAddMore: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (recipes.isEmpty()) return
    LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(recipes, key = { it.id }) { recipe ->
            Surface(
                onClick = { onRecipe(recipe) },
                color = ChillColors.CardBackground,
                contentColor = ChillColors.TextMain,
                shape = RoundedCornerShape(10.dp),
                border = BorderStroke(1.dp, ChillColors.BorderSubtle),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 11.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                ) {
                    CreatorSkillIcon(recipe = recipe, container = 28.dp, iconSize = 13.dp)
                    Text(
                        text = recipeName(recipe),
                        style = MaterialTheme.typography.labelMedium,
                        maxLines = 1,
                    )
                }
            }
        }
        item {
            Surface(
                onClick = onAddMore,
                modifier = Modifier.size(44.dp),
                color = ChillColors.CardBackground,
                shape = RoundedCornerShape(10.dp),
                border = BorderStroke(1.dp, ChillColors.BorderSubtle),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.Add,
                        contentDescription = stringResource(R.string.creator_skills_add_more),
                        modifier = Modifier.size(20.dp),
                        tint = ChillColors.TextSub,
                    )
                }
            }
        }
    }
}

@Composable
fun CreatorSkillPickerDialog(
    recipes: List<AgentRecipe>,
    onDismiss: () -> Unit,
    onSelect: (AgentRecipe) -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.84f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SheetNavigationBar(
                        title = stringResource(R.string.note_detail_ai_skills_title),
                        leadingText = stringResource(R.string.common_cancel),
                        onLeading = onDismiss,
                    )

                    if (recipes.isEmpty()) {
                        AISkillsEmptyState()
                    } else {
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(minSize = 130.dp),
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(16.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            gridItems(recipes, key = { it.id }) { recipe ->
                                SkillPickerCard(
                                    recipe = recipe,
                                    onClick = {
                                        onDismiss()
                                        onSelect(recipe)
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SkillPickerCard(recipe: AgentRecipe, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 142.dp),
        color = ChillColors.CardBackground,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, Color.Black.copy(alpha = 0.04f)),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            CreatorSkillIcon(recipe = recipe)
            Text(
                text = recipeName(recipe),
                color = ChillColors.TextMain,
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = recipeDescription(recipe),
                color = ChillColors.TextSub,
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Normal),
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun AISkillsEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Outlined.AutoAwesome,
            contentDescription = null,
            modifier = Modifier.size(36.dp),
            tint = ChillColors.BrandTeal,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            text = stringResource(R.string.note_detail_ai_skills_empty_title),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.note_detail_ai_skills_empty_message),
            color = ChillColors.TextSub,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun CreatorSkillNotePickerDialog(
    recipe: AgentRecipe,
    notes: List<NoteEntity>,
    onDismiss: () -> Unit,
    onSelect: (NoteEntity) -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.72f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SheetNavigationBar(
                        title = stringResource(R.string.creator_skills_choose_note),
                        leadingText = stringResource(R.string.common_cancel),
                        onLeading = onDismiss,
                    )

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CreatorSkillIcon(recipe = recipe, container = 48.dp, iconSize = 22.dp)
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(
                                text = recipeName(recipe),
                                color = ChillColors.TextMain,
                                style = MaterialTheme.typography.titleMedium,
                            )
                            Text(
                                text = stringResource(R.string.creator_skills_choose_note_message),
                                color = ChillColors.TextSub,
                                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Normal),
                            )
                        }
                    }

                    if (notes.isEmpty()) {
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth()
                                .padding(32.dp),
                            verticalArrangement = Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = stringResource(R.string.creator_skills_no_notes),
                                color = ChillColors.TextSub,
                                style = MaterialTheme.typography.bodyLarge,
                                textAlign = TextAlign.Center,
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .weight(1f)
                                .padding(horizontal = 20.dp),
                        ) {
                            items(notes, key = { it.id }) { note ->
                                NotePickerRow(
                                    note = note,
                                    onClick = { onSelect(note) },
                                )
                                HorizontalDivider(color = ChillColors.Separator)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotePickerRow(note: NoteEntity, onClick: () -> Unit) {
    val locale = LocalLocale.current.platformLocale
    val dateLabel = remember(note.createdAt, locale) { formatShortDate(note.createdAt, locale) }
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = Color.Transparent,
    ) {
        Row(
            modifier = Modifier.padding(vertical = 13.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.AddCircleOutline,
                contentDescription = null,
                modifier = Modifier.size(22.dp),
                tint = ChillColors.TextSub.copy(alpha = 0.42f),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(
                    text = dateLabel,
                    color = ChillColors.TextSub,
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Normal),
                )
                Text(
                    text = note.previewPlainText.ifBlank { note.content }.ifBlank { "…" },
                    color = ChillColors.TextMain,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
fun CreatorSkillsLibrary(
    available: List<AgentRecipe>,
    installed: List<AgentRecipe>,
    isPro: Boolean,
    onBack: () -> Unit,
    onToggle: (AgentRecipe) -> Unit,
    onRequestCustomUpgrade: () -> Unit,
    onCreateCustom: (String, String) -> Unit,
    onDeleteCustom: (AgentRecipe) -> Unit,
) {
    CreatorSkillPreferences.initialize(LocalContext.current)
    var showCreate by rememberSaveable { mutableStateOf(false) }
    var configuredRecipeId by rememberSaveable { mutableStateOf<String?>(null) }
    var pendingDelete by remember { mutableStateOf<AgentRecipe?>(null) }
    val installedIds = installed.mapTo(mutableSetOf()) { it.id }
    val availableRecipes = available.filter { !it.isCustom && it.id !in installedIds }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .statusBarsPadding(),
    ) {
        LibraryNavigationBar(onBack = onBack)
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 20.dp,
                top = 14.dp,
                end = 20.dp,
                bottom = 28.dp,
            ),
        ) {
            item {
                SkillSection(
                    title = stringResource(R.string.creator_skills_installed),
                    recipes = installed,
                    installed = true,
                    onToggle = onToggle,
                    onConfigure = { configuredRecipeId = it.id },
                    onDelete = { pendingDelete = it },
                )
            }
            item { Spacer(Modifier.height(22.dp)) }
            item {
                SkillSection(
                    title = stringResource(R.string.creator_skills_available),
                    recipes = availableRecipes,
                    installed = false,
                    onToggle = onToggle,
                    onConfigure = { configuredRecipeId = it.id },
                    onDelete = { pendingDelete = it },
                )
            }
            item { Spacer(Modifier.height(24.dp)) }
            item {
                CreateCustomSkillRow(
                    onClick = {
                        if (isPro) showCreate = true else onRequestCustomUpgrade()
                    },
                )
            }
            item { Spacer(Modifier.height(24.dp).navigationBarsPadding()) }
        }
    }

    if (showCreate) {
        CustomRecipeDialog(
            onDismiss = { showCreate = false },
            onCreate = { name, prompt ->
                onCreateCustom(name, prompt)
                showCreate = false
            },
        )
    }

    configuredRecipeId?.let { recipeId ->
        CreatorSkillSettingsDialog(
            recipeId = recipeId,
            onDismiss = { configuredRecipeId = null },
        )
    }

    pendingDelete?.let { recipe ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text(stringResource(R.string.recipes_delete_skill_title)) },
            text = { Text(stringResource(R.string.recipes_delete_skill_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDeleteCustom(recipe)
                        pendingDelete = null
                    },
                ) {
                    Text(
                        text = stringResource(R.string.common_delete),
                        color = Color(0xFFC33B45),
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }
}

@Composable
private fun LibraryNavigationBar(onBack: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(ChillColors.BackgroundSecondary),
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier.align(Alignment.CenterStart),
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Outlined.ArrowBack,
                contentDescription = stringResource(R.string.common_back),
                tint = ChillColors.TextMain,
            )
        }
        Text(
            text = stringResource(R.string.recipes_title),
            modifier = Modifier.align(Alignment.Center),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun SkillSection(
    title: String,
    recipes: List<AgentRecipe>,
    installed: Boolean,
    onToggle: (AgentRecipe) -> Unit,
    onConfigure: (AgentRecipe) -> Unit,
    onDelete: (AgentRecipe) -> Unit,
) {
    val locale = LocalLocale.current.platformLocale
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title.uppercase(locale),
            modifier = Modifier.padding(horizontal = 4.dp),
            color = ChillColors.TextSub,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.4.sp,
        )
        if (recipes.isNotEmpty()) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(
                        elevation = 10.dp,
                        shape = RoundedCornerShape(16.dp),
                        ambientColor = ChillColors.Shadow.copy(alpha = 0.45f),
                        spotColor = ChillColors.Shadow.copy(alpha = 0.45f),
                    ),
                color = ChillColors.CardBackground,
                shape = RoundedCornerShape(16.dp),
                border = BorderStroke(1.dp, ChillColors.BorderSubtle),
            ) {
                Column {
                    recipes.forEachIndexed { index, recipe ->
                        SkillManagementRow(
                            recipe = recipe,
                            installed = installed,
                            onToggle = { onToggle(recipe) },
                            onConfigure = if (recipe.id in configurableCreatorSkillIds) {
                                { onConfigure(recipe) }
                            } else {
                                null
                            },
                            onDelete = if (recipe.isCustom) {
                                { onDelete(recipe) }
                            } else {
                                null
                            },
                        )
                        if (index < recipes.lastIndex) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 68.dp),
                                color = ChillColors.Separator,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SkillManagementRow(
    recipe: AgentRecipe,
    installed: Boolean,
    onToggle: () -> Unit,
    onConfigure: (() -> Unit)?,
    onDelete: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 64.dp)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CreatorSkillIcon(recipe = recipe)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                text = recipeName(recipe),
                color = ChillColors.TextMain,
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = recipeDescription(recipe),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
                lineHeight = 17.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        if (onConfigure != null) {
            IconButton(
                onClick = onConfigure,
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Tune,
                    contentDescription = stringResource(configurationTitleRes(recipe.id)),
                    modifier = Modifier.size(20.dp),
                    tint = ChillColors.TextSub.copy(alpha = 0.75f),
                )
            }
        }

        if (onDelete != null) {
            Surface(
                onClick = onDelete,
                modifier = Modifier.size(28.dp),
                color = ChillColors.BackgroundPrimary,
                shape = CircleShape,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.MoreHoriz,
                        contentDescription = stringResource(R.string.common_delete),
                        modifier = Modifier.size(17.dp),
                        tint = ChillColors.TextSub,
                    )
                }
            }
        } else {
            IconButton(
                onClick = onToggle,
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    imageVector = if (installed) Icons.Outlined.CheckCircle
                    else Icons.Outlined.AddCircleOutline,
                    contentDescription = stringResource(
                        if (installed) R.string.creator_skills_remove else R.string.creator_skills_add,
                    ),
                    modifier = Modifier.size(23.dp),
                    tint = if (installed) {
                        ChillColors.BrandTeal
                    } else {
                        ChillColors.TextSub.copy(alpha = 0.55f)
                    },
                )
            }
        }
    }
}

@StringRes
private fun configurationTitleRes(recipeId: String): Int = when (recipeId) {
    "caption_pack" -> R.string.caption_pack_settings_title
    "repurpose_pack" -> R.string.repurpose_pack_settings_title
    "style_match" -> R.string.brand_voice_settings_title
    "timed_script" -> R.string.timed_script_settings_title
    else -> R.string.recipes_title
}

@Composable
private fun CreateCustomSkillRow(onClick: () -> Unit) {
    val tint = Color(0xFF8069B0)
    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(16.dp),
                ambientColor = ChillColors.Shadow.copy(alpha = 0.45f),
                spotColor = ChillColors.Shadow.copy(alpha = 0.45f),
            ),
        color = ChillColors.CardBackground,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, ChillColors.BorderSubtle),
    ) {
        Row(
            modifier = Modifier
                .heightIn(min = 64.dp)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Surface(
                modifier = Modifier.size(40.dp),
                color = tint.copy(alpha = 0.11f),
                shape = RoundedCornerShape(8.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.AutoAwesome,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = tint,
                    )
                }
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = stringResource(R.string.creator_skills_custom_create),
                        color = ChillColors.TextMain,
                        fontSize = 15.sp,
                        lineHeight = 19.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                    )
                    Surface(
                        color = tint.copy(alpha = 0.11f),
                        contentColor = tint,
                        shape = CircleShape,
                    ) {
                        Text(
                            text = stringResource(R.string.creator_skills_custom_badge),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            fontSize = 11.sp,
                            lineHeight = 13.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
                Text(
                    text = stringResource(R.string.creator_skills_custom_subtitle),
                    color = ChillColors.TextSub,
                    fontSize = 13.sp,
                    lineHeight = 17.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Icon(
                imageVector = Icons.Outlined.AddCircleOutline,
                contentDescription = null,
                modifier = Modifier.size(23.dp),
                tint = tint,
            )
        }
    }
}

@Composable
private fun CustomRecipeDialog(
    onDismiss: () -> Unit,
    onCreate: (String, String) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf("") }
    var prompt by rememberSaveable { mutableStateOf("") }
    val canSave = name.isNotBlank() && prompt.isNotBlank()

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.68f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SheetNavigationBar(
                        title = stringResource(R.string.creator_skills_custom_create),
                        leadingText = stringResource(R.string.common_cancel),
                        onLeading = onDismiss,
                        trailingText = stringResource(R.string.common_save),
                        trailingEnabled = canSave,
                        onTrailing = { onCreate(name.trim(), prompt.trim()) },
                    )
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it },
                            modifier = Modifier.fillMaxWidth(),
                            label = { Text(stringResource(R.string.creator_skills_custom_name)) },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                        )
                        OutlinedTextField(
                            value = prompt,
                            onValueChange = { prompt = it },
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 140.dp),
                            label = { Text(stringResource(R.string.creator_skills_custom_instruction)) },
                            minLines = 5,
                            shape = RoundedCornerShape(12.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun TranslateTargetDialog(onDismiss: () -> Unit, onRun: (String) -> Unit) {
    var language by rememberSaveable { mutableStateOf("") }
    val canRun = language.isNotBlank()

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.45f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SheetNavigationBar(
                        title = stringResource(R.string.creator_skills_translate_title),
                        leadingText = stringResource(R.string.common_cancel),
                        onLeading = onDismiss,
                        trailingText = stringResource(R.string.creator_skills_run),
                        trailingEnabled = canRun,
                        onTrailing = { onRun(language.trim()) },
                    )
                    Column(
                        modifier = Modifier.padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Language,
                            contentDescription = null,
                            modifier = Modifier.size(40.dp),
                            tint = Color(0xFF7866AD),
                        )
                        OutlinedTextField(
                            value = language,
                            onValueChange = { language = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text(stringResource(R.string.creator_skills_translate_placeholder)) },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AISkillPreviewDialog(
    recipe: AgentRecipe,
    result: String,
    selection: TextSelection,
    onDismiss: () -> Unit,
    onApply: (AISkillApplyMode) -> Unit,
    modes: List<AISkillApplyMode> = AISkillTextApplication.availableModes(selection),
) {
    var showsCopyToast by remember { mutableStateOf(false) }
    var copyEvent by remember { mutableIntStateOf(0) }

    LaunchedEffect(copyEvent) {
        if (copyEvent == 0) return@LaunchedEffect
        delay(5_000)
        showsCopyToast = false
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
        ),
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.96f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SheetNavigationBar(
                        title = stringResource(R.string.ai_skill_preview_title),
                        leadingText = stringResource(R.string.common_cancel),
                        onLeading = onDismiss,
                    )
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            CreatorSkillIcon(recipe = recipe)
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    text = recipeName(recipe),
                                    color = ChillColors.TextMain,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(
                                    text = stringResource(
                                        if (selection.isCollapsed) {
                                            R.string.ai_skill_preview_context_note
                                        } else {
                                            R.string.ai_skill_preview_context_selection
                                        },
                                    ),
                                    color = ChillColors.TextSub,
                                    style = MaterialTheme.typography.labelMedium.copy(
                                        fontWeight = FontWeight.Normal,
                                    ),
                                )
                            }
                        }

                        ActionableSkillResult(
                            recipe = recipe,
                            result = result,
                            onCopied = {
                                showsCopyToast = true
                                copyEvent += 1
                            },
                        )
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(ChillColors.BackgroundPrimary)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        modes.forEach { mode ->
                            SkillActionButton(
                                label = stringResource(mode.title),
                                icon = applyModeIcon(mode),
                                onClick = { onApply(mode) },
                            )
                        }
                    }
                }
            }

            AnimatedVisibility(
                visible = showsCopyToast,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp, vertical = 82.dp),
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
            ) {
                SkillResultCopyToast(onDismiss = { showsCopyToast = false })
            }
        }
    }
}

@Composable
private fun SkillActionButton(
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = ChillColors.CardBackground,
        contentColor = ChillColors.TextMain,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, Color.Black.copy(alpha = 0.05f)),
    ) {
        Row(
            modifier = Modifier.padding(vertical = 13.dp, horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = label,
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun ActionableSkillResult(
    recipe: AgentRecipe,
    result: String,
    onCopied: () -> Unit,
) {
    val blocks = remember(recipe.id, result) {
        actionableResultBlocks(recipe.id, result)
    }
    val context = LocalContext.current
    val clipboard = remember(context) {
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }
    val copyLabel = stringResource(R.string.ai_skills_result_copy_action)
    var copiedBlockId by remember(result) { mutableStateOf<Int?>(null) }

    LaunchedEffect(copiedBlockId) {
        if (copiedBlockId == null) return@LaunchedEffect
        delay(1_600)
        copiedBlockId = null
    }

    if (blocks.isEmpty()) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = ChillColors.BackgroundSecondary,
            shape = RoundedCornerShape(12.dp),
        ) {
            SelectionContainer {
                MarkdownText(
                    markdown = result,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    style = MaterialTheme.typography.bodyLarge.copy(color = ChillColors.TextMain),
                )
            }
        }
    } else {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = ChillColors.BackgroundSecondary,
            shape = RoundedCornerShape(16.dp),
            border = BorderStroke(1.dp, ChillColors.BorderSubtle),
        ) {
            Column {
                blocks.forEachIndexed { index, block ->
                    ActionableResultRow(
                        block = block,
                        copied = copiedBlockId == block.id,
                        onCopy = {
                            clipboard.setPrimaryClip(
                                ClipData.newPlainText(copyLabel, block.content),
                            )
                            copiedBlockId = block.id
                            onCopied()
                        },
                    )
                    if (index < blocks.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 16.dp),
                            color = ChillColors.Separator,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ActionableResultRow(
    block: ActionableResultBlock,
    copied: Boolean,
    onCopy: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = block.label.uppercase(),
                color = ChillColors.TextSub,
                fontSize = 12.sp,
                lineHeight = 15.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.4.sp,
            )
            SelectionContainer {
                MarkdownText(
                    markdown = block.content,
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 12,
                    style = MaterialTheme.typography.bodyLarge.copy(color = ChillColors.TextMain),
                )
            }
        }

        Surface(
            onClick = onCopy,
            modifier = Modifier.size(44.dp),
            color = if (copied) ChillColors.BrandTeal else ChillColors.BackgroundPrimary,
            contentColor = if (copied) Color.White else ChillColors.BrandTealText,
            shape = RoundedCornerShape(12.dp),
            border = if (copied) null else BorderStroke(1.dp, ChillColors.BorderSubtle),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = if (copied) Icons.Outlined.Check else Icons.Outlined.ContentCopy,
                    contentDescription = stringResource(R.string.ai_skills_result_copy_action),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@Composable
private fun SkillResultCopyToast(onDismiss: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 12.dp,
                shape = RoundedCornerShape(16.dp),
                ambientColor = Color.Black.copy(alpha = 0.06f),
                spotColor = Color.Black.copy(alpha = 0.06f),
            ),
        color = ChillColors.BrandTealSoft,
        contentColor = ChillColors.BrandTealText,
        shape = RoundedCornerShape(16.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(start = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
            )
            Text(
                text = stringResource(R.string.ai_skills_result_copied),
                modifier = Modifier.weight(1f),
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.Medium,
            )
            IconButton(
                onClick = onDismiss,
                modifier = Modifier.size(44.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.common_close),
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

@Composable
fun AISkillProcessingDialog(recipe: AgentRecipe) {
    Dialog(
        onDismissRequest = {},
        properties = DialogProperties(
            dismissOnBackPress = false,
            dismissOnClickOutside = false,
        ),
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = ChillColors.CardBackground,
            shape = RoundedCornerShape(20.dp),
            shadowElevation = 16.dp,
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                CreatorSkillIcon(recipe = recipe, container = 44.dp, iconSize = 20.dp)
                CircularProgressIndicator(
                    modifier = Modifier.size(28.dp),
                    color = ChillColors.BrandTeal,
                    strokeWidth = 3.dp,
                )
                Text(
                    text = stringResource(R.string.creator_skills_running_format, recipeName(recipe)),
                    color = ChillColors.TextMain,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun SheetNavigationBar(
    title: String,
    leadingText: String,
    onLeading: () -> Unit,
    trailingText: String? = null,
    trailingEnabled: Boolean = true,
    onTrailing: (() -> Unit)? = null,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(ChillColors.BackgroundSecondary),
    ) {
        TextButton(
            onClick = onLeading,
            modifier = Modifier.align(Alignment.CenterStart),
        ) {
            Text(
                text = leadingText,
                color = ChillColors.BrandBlueText,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        Text(
            text = title,
            modifier = Modifier.align(Alignment.Center),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        if (trailingText != null && onTrailing != null) {
            TextButton(
                onClick = onTrailing,
                enabled = trailingEnabled,
                modifier = Modifier.align(Alignment.CenterEnd),
            ) {
                Text(
                    text = trailingText,
                    color = if (trailingEnabled) {
                        ChillColors.BrandBlueText
                    } else {
                        ChillColors.TextTertiary
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

private data class ActionableResultBlock(
    val id: Int,
    val label: String,
    val content: String,
)

private fun actionableResultBlocks(recipeId: String, markdown: String): List<ActionableResultBlock> =
    when (recipeId) {
        "hook_generator" -> hookBlocks(markdown)
        "caption_pack", "repurpose_pack" -> sectionBlocks(markdown)
        else -> emptyList()
    }

private fun hookBlocks(markdown: String): List<ActionableResultBlock> {
    val normalized = markdown.replace("\r\n", "\n")
    val paragraphs = normalized
        .split(Regex("""\n\s*\n"""))
        .flatMap(::splitHookParagraphIfNeeded)
        .map(String::trim)
        .filter(String::isNotEmpty)

    val blocks = paragraphs.mapIndexedNotNull { index, paragraph ->
        val cleaned = paragraph.replace(
            Regex("""^\s*(?:#{1,6}\s+|[-*•]\s+|\d+[.)]\s+)"""),
            "",
        )
        val plain = cleaned
            .replace("**", "")
            .replace("__", "")
            .trim()
        if (plain.isEmpty()) return@mapIndexedNotNull null
        val parts = splitLabelAndContent(plain)
        ActionableResultBlock(
            id = index,
            label = parts?.first ?: (index + 1).toString().padStart(2, '0'),
            content = parts?.second ?: plain,
        )
    }
    return if (blocks.size >= 2) blocks.mapIndexed { index, block -> block.copy(id = index) }
    else emptyList()
}

private fun sectionBlocks(markdown: String): List<ActionableResultBlock> {
    val lines = markdown.replace("\r\n", "\n").lines()
    val sections = mutableListOf<Pair<String, List<String>>>()
    var currentLabel: String? = null
    var currentLines = mutableListOf<String>()

    fun appendCurrent() {
        val label = currentLabel ?: return
        sections += label to currentLines.toList()
    }

    lines.forEach { line ->
        val trimmedStart = line.trimStart()
        if (trimmedStart.startsWith("## ") && !trimmedStart.startsWith("### ")) {
            appendCurrent()
            currentLabel = trimmedStart
                .removePrefix("## ")
                .replace("**", "")
                .trim()
            currentLines = mutableListOf()
        } else if (currentLabel != null) {
            currentLines += line
        }
    }
    appendCurrent()

    return sections.mapIndexedNotNull { index, section ->
        val content = section.second.joinToString("\n").trim()
        if (section.first.isBlank() || content.isBlank()) null
        else ActionableResultBlock(index, section.first, content)
    }
}

private fun splitHookParagraphIfNeeded(paragraph: String): List<String> {
    val lines = paragraph.lines().map(String::trim).filter(String::isNotEmpty)
    if (lines.size <= 1) return listOf(paragraph)
    val individualHooks = lines.filter { line ->
        HOOK_PREFIX.containsMatchIn(line) ||
            splitLabelAndContent(line.replace("**", "")) != null
    }
    return if (individualHooks.size == lines.size) lines else listOf(paragraph)
}

private fun splitLabelAndContent(text: String): Pair<String, String>? {
    LABEL_DELIMITERS.forEach { delimiter ->
        val index = text.indexOf(delimiter)
        if (index < 0) return@forEach
        val label = text.substring(0, index).trim()
        val content = text.substring(index + delimiter.length).trim()
        if (label.isNotEmpty() && label.length <= 40 && content.isNotEmpty()) {
            return label to content
        }
    }
    return null
}

private fun creatorSkillImage(recipe: AgentRecipe): ImageVector = when (recipe.id) {
    "why_viral" -> Icons.Outlined.TrendingUp
    "summarize" -> Icons.Outlined.Description
    "translate" -> Icons.Outlined.Public
    "humanizer" -> Icons.Outlined.PersonOutline
    "rewrite" -> Icons.Outlined.Edit
    "style_match" -> Icons.Outlined.GraphicEq
    "hook_generator" -> Icons.Outlined.Link
    "caption_pack" -> Icons.Outlined.ClosedCaption
    "timed_script" -> Icons.Outlined.Timer
    "repurpose_pack" -> Icons.Outlined.Layers
    else -> Icons.Outlined.AutoAwesome
}

private fun creatorSkillTint(recipe: AgentRecipe): Color = when (recipe.id) {
    "why_viral" -> Color(0xFFC46B54)
    "summarize" -> Color(0xFF5F7394)
    "translate" -> Color(0xFF7866AD)
    "humanizer" -> Color(0xFFB56C82)
    "rewrite" -> Color(0xFF38886F)
    "style_match" -> Color(0xFF8A69A5)
    "hook_generator" -> ChillColors.BrandBlue
    "caption_pack" -> Color(0xFFB77A2D)
    "timed_script" -> Color(0xFF68758A)
    "repurpose_pack" -> Color(0xFFC76655)
    else -> CUSTOM_SKILL_TINTS[stableColorIndex(recipe.id)]
}

private fun stableColorIndex(recipeId: String): Int =
    recipeId.fold(0) { result, character ->
        (result * 31 + character.code) % CUSTOM_SKILL_TINTS.size
    }

private fun applyModeIcon(mode: AISkillApplyMode): ImageVector = when (mode) {
    AISkillApplyMode.APPEND_TO_END -> Icons.Outlined.VerticalAlignBottom
    AISkillApplyMode.REPLACE_ALL -> Icons.Outlined.FindReplace
}

private fun formatShortDate(rawValue: String, locale: Locale): String {
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

private val CUSTOM_SKILL_TINTS = listOf(
    ChillColors.BrandBlue,
    Color(0xFFA06B9A),
    Color(0xFFB77A2D),
    Color(0xFF3F8174),
    Color(0xFFB86655),
    Color(0xFF63758F),
)
private val HOOK_PREFIX = Regex("""^(?:[-*•]\s+|\d+[.)]\s+)""")
private val LABEL_DELIMITERS = listOf(":", "：", " — ", " – ")
