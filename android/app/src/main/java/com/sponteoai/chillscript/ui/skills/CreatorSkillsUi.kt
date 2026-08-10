package com.sponteoai.chillscript.ui.skills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.AISkillApplyMode
import com.sponteoai.chillscript.ai.AgentRecipe
import com.sponteoai.chillscript.ai.RecipeCategory
import com.sponteoai.chillscript.ai.TextSelection
import com.sponteoai.chillscript.ai.AISkillTextApplication
import com.sponteoai.chillscript.data.local.NoteEntity

@Composable
fun recipeName(recipe: AgentRecipe): String = if (recipe.isCustom) recipe.name else stringResource(
    when (recipe.id) {
        "why_viral" -> R.string.recipe_why_viral_name
        "summarize" -> R.string.recipe_summarize_name
        "translate" -> R.string.recipe_translate_name
        "humanizer" -> R.string.recipe_humanizer_name
        "rewrite" -> R.string.recipe_rewrite_name
        "style_match" -> R.string.recipe_style_match_name
        "hook_generator" -> R.string.recipe_hook_generator_name
        "caption_pack" -> R.string.recipe_caption_pack_name
        "timed_script" -> R.string.recipe_timed_script_name
        else -> R.string.recipe_repurpose_pack_name
    },
)

@Composable
fun recipeDescription(recipe: AgentRecipe): String = if (recipe.isCustom) {
    stringResource(R.string.creator_skills_custom_description)
} else stringResource(
    when (recipe.id) {
        "why_viral" -> R.string.recipe_why_viral_description
        "summarize" -> R.string.recipe_summarize_description
        "translate" -> R.string.recipe_translate_description
        "humanizer" -> R.string.recipe_humanizer_description
        "rewrite" -> R.string.recipe_rewrite_description
        "style_match" -> R.string.recipe_style_match_description
        "hook_generator" -> R.string.recipe_hook_generator_description
        "caption_pack" -> R.string.recipe_caption_pack_description
        "timed_script" -> R.string.recipe_timed_script_description
        else -> R.string.recipe_repurpose_pack_description
    },
)

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
            OutlinedButton(onClick = { onRecipe(recipe) }, shape = RoundedCornerShape(10.dp)) {
                Icon(Icons.Outlined.AutoAwesome, null)
                Spacer(Modifier.width(7.dp))
                Text(recipeName(recipe), maxLines = 1)
            }
        }
        item {
            OutlinedButton(onClick = onAddMore, shape = RoundedCornerShape(10.dp)) {
                Icon(Icons.Outlined.Add, stringResource(R.string.creator_skills_add_more))
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
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.creator_skills_title)) },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(recipes, key = { it.id }) { recipe ->
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable { onSelect(recipe) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Text(recipeName(recipe), fontWeight = FontWeight.SemiBold)
                            Text(recipeDescription(recipe), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
fun CreatorSkillNotePickerDialog(
    recipe: AgentRecipe,
    notes: List<NoteEntity>,
    onDismiss: () -> Unit,
    onSelect: (NoteEntity) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.creator_skills_choose_note)) },
        text = {
            Column {
                Text(recipeName(recipe), fontWeight = FontWeight.SemiBold)
                Text(stringResource(R.string.creator_skills_choose_note_message), style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(10.dp))
                if (notes.isEmpty()) Text(stringResource(R.string.creator_skills_no_notes)) else LazyColumn {
                    items(notes, key = { it.id }) { note ->
                        Text(
                            note.previewPlainText.ifBlank { note.content }.lineSequence().firstOrNull().orEmpty().ifBlank { "…" },
                            modifier = Modifier.fillMaxWidth().clickable { onSelect(note) }.padding(vertical = 13.dp),
                            maxLines = 2,
                        )
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
fun CreatorSkillsLibrary(
    available: List<AgentRecipe>,
    installed: List<AgentRecipe>,
    onBack: () -> Unit,
    onToggle: (AgentRecipe) -> Unit,
    onCreateCustom: (String, String) -> Unit,
    onDeleteCustom: (AgentRecipe) -> Unit,
) {
    var showCreate by remember { mutableStateOf(false) }
    val installedIds = installed.mapTo(mutableSetOf()) { it.id }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(
            Modifier.fillMaxWidth().padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back)) }
            Text(stringResource(R.string.creator_skills_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        LazyColumn(
            Modifier.fillMaxSize().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Button(onClick = { showCreate = true }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Outlined.Add, null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.creator_skills_custom_create))
                }
            }
            RecipeCategory.entries.forEach { category ->
                item {
                    Text(
                        stringResource(when (category) {
                            RecipeCategory.THINK -> R.string.creator_skills_category_think
                            RecipeCategory.SHAPE -> R.string.creator_skills_category_shape
                            RecipeCategory.PUBLISH -> R.string.creator_skills_category_publish
                        }),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                }
                items(available.filter { it.category == category }, key = { it.id }) { recipe ->
                    Card(Modifier.fillMaxWidth()) {
                        Row(
                            Modifier.fillMaxWidth().padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Outlined.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary)
                            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                                Text(recipeName(recipe), fontWeight = FontWeight.SemiBold)
                                Text(recipeDescription(recipe), style = MaterialTheme.typography.bodySmall)
                            }
                            if (recipe.isCustom) {
                                TextButton(onClick = { onDeleteCustom(recipe) }) { Text(stringResource(R.string.common_delete)) }
                            } else {
                                TextButton(onClick = { onToggle(recipe) }) {
                                    Text(stringResource(if (recipe.id in installedIds) R.string.creator_skills_remove else R.string.creator_skills_add))
                                }
                            }
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
    if (showCreate) CustomRecipeDialog(
        onDismiss = { showCreate = false },
        onCreate = { name, prompt -> onCreateCustom(name, prompt); showCreate = false },
    )
}

@Composable
private fun CustomRecipeDialog(onDismiss: () -> Unit, onCreate: (String, String) -> Unit) {
    var name by remember { mutableStateOf("") }
    var prompt by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.creator_skills_custom_create)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.creator_skills_custom_name)) })
                OutlinedTextField(prompt, { prompt = it }, label = { Text(stringResource(R.string.creator_skills_custom_instruction)) }, minLines = 4)
            }
        },
        confirmButton = {
            TextButton(onClick = { onCreate(name, prompt) }, enabled = name.isNotBlank() && prompt.isNotBlank()) {
                Text(stringResource(R.string.creator_skills_add))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
fun TranslateTargetDialog(onDismiss: () -> Unit, onRun: (String) -> Unit) {
    var language by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.creator_skills_translate_title)) },
        text = { OutlinedTextField(language, { language = it }, placeholder = { Text(stringResource(R.string.creator_skills_translate_placeholder)) }) },
        confirmButton = {
            TextButton(onClick = { onRun(language) }, enabled = language.isNotBlank()) { Text(stringResource(R.string.creator_skills_run)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
fun AISkillPreviewDialog(
    recipe: AgentRecipe,
    result: String,
    selection: TextSelection,
    onDismiss: () -> Unit,
    onApply: (AISkillApplyMode) -> Unit,
    onSaveDraft: () -> Unit,
    modes: List<AISkillApplyMode> = AISkillTextApplication.availableModes(selection),
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(stringResource(R.string.ai_skill_preview_title))
                Text(recipeName(recipe), style = MaterialTheme.typography.bodySmall)
            }
        },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                item {
                    Text(stringResource(if (selection.isCollapsed) R.string.ai_skill_preview_context_note else R.string.ai_skill_preview_context_selection), style = MaterialTheme.typography.labelMedium)
                    Spacer(Modifier.height(8.dp))
                    Text(result)
                }
                items(modes) { mode ->
                    OutlinedButton(onClick = { onApply(mode) }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(mode.title))
                    }
                }
                item {
                    OutlinedButton(onClick = onSaveDraft, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.ai_skill_save_as_draft))
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
fun AISkillProcessingDialog(recipe: AgentRecipe) {
    AlertDialog(
        onDismissRequest = {},
        title = { Text(stringResource(R.string.creator_skills_title)) },
        text = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CircularProgressIndicator()
                Text(stringResource(R.string.creator_skills_running_format, recipeName(recipe)))
            }
        },
        confirmButton = {},
    )
}
