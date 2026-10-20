package com.sponteoai.chillscript.ui.skills

import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.RecordVoiceOver
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.AlternateEmail
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.preferences.TranslateTargetLanguage
import com.sponteoai.chillscript.preferences.BrandVoicePreferences
import com.sponteoai.chillscript.preferences.CaptionPackGoal
import com.sponteoai.chillscript.preferences.CaptionPackOutputStyle
import com.sponteoai.chillscript.preferences.CaptionPackPreferences
import com.sponteoai.chillscript.preferences.CaptionPackTone
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import com.sponteoai.chillscript.preferences.RepurposeFormat
import com.sponteoai.chillscript.preferences.RepurposePackPreferences
import com.sponteoai.chillscript.preferences.RepurposeThreadLength
import com.sponteoai.chillscript.ui.theme.ChillColors

internal val configurableCreatorSkillIds = setOf(
    "translate",
    "caption_pack",
    "repurpose_pack",
    "style_match",
)

@Composable
internal fun CreatorSkillSettingsDialog(
    recipeId: String,
    onDismiss: () -> Unit,
) {
    when (recipeId) {
        "translate" -> TranslateSettingsSheet(onDismiss)
        "caption_pack" -> CaptionPackSettingsSheet(onDismiss)
        "repurpose_pack" -> RepurposePackSettingsSheet(onDismiss)
        "style_match" -> BrandVoiceSettingsSheet(onDismiss)
    }
}

@Composable
private fun TranslateSettingsSheet(onDismiss: () -> Unit) {
    var language by remember { mutableStateOf(CreatorSkillPreferences.translateTargetLanguage()) }
    SettingsSheetFrame(title = R.string.translate_settings_title, onDismiss = onDismiss) {
        item {
            SettingsChoiceCard(
                values = TranslateTargetLanguage.entries,
                selected = language,
                title = { it.displayName },
                onSelect = {
                    language = it
                    CreatorSkillPreferences.saveTranslateTargetLanguage(it)
                },
            )
        }
        item {
            Text(
                text = stringResource(R.string.translate_settings_help),
                color = ChillColors.TextSub,
                fontSize = 12.sp,
                lineHeight = 16.sp,
            )
        }
    }
}

@Composable
private fun CaptionPackSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.captionPack()) }

    fun update(next: CaptionPackPreferences) {
        val hasSelectedPlatform = listOf(
            next.includeTikTok,
            next.includeInstagramReels,
            next.includeYouTubeShorts,
            next.includeYouTubeLongVideo,
        ).any { it }
        if (!hasSelectedPlatform) return
        preferences = next
        CreatorSkillPreferences.saveCaptionPack(next)
    }

    val selectedPlatformCount = listOf(
        preferences.includeTikTok,
        preferences.includeInstagramReels,
        preferences.includeYouTubeShorts,
        preferences.includeYouTubeLongVideo,
    ).count { it }

    SettingsSheetFrame(
        title = R.string.caption_pack_settings_title,
        onDismiss = onDismiss,
    ) {
        settingsSection(
            title = R.string.caption_pack_settings_platforms,
            content = {
                SettingsToggleCard(
                    listOf(
                        SettingsToggleOption(
                            R.string.caption_pack_platform_tiktok,
                            preferences.includeTikTok,
                        ) { enabled ->
                            if (enabled || selectedPlatformCount > 1) update(preferences.copy(includeTikTok = enabled))
                        },
                        SettingsToggleOption(
                            R.string.caption_pack_platform_instagram_reels,
                            preferences.includeInstagramReels,
                        ) { enabled ->
                            if (enabled || selectedPlatformCount > 1) update(preferences.copy(includeInstagramReels = enabled))
                        },
                        SettingsToggleOption(
                            R.string.caption_pack_platform_youtube_shorts,
                            preferences.includeYouTubeShorts,
                        ) { enabled ->
                            if (enabled || selectedPlatformCount > 1) update(preferences.copy(includeYouTubeShorts = enabled))
                        },
                        SettingsToggleOption(
                            R.string.caption_pack_platform_youtube_long_video,
                            preferences.includeYouTubeLongVideo,
                        ) { enabled ->
                            if (enabled || selectedPlatformCount > 1) update(preferences.copy(includeYouTubeLongVideo = enabled))
                        },
                    ),
                )
            },
        )
        item {
            SettingsMenuRow(
                label = R.string.caption_pack_settings_goal,
                values = CaptionPackGoal.entries,
                selected = preferences.goal,
                title = { stringResource(it.titleRes) },
                onSelect = { update(preferences.copy(goal = it)) },
            )
            SettingsMenuRow(
                label = R.string.caption_pack_settings_tone,
                values = CaptionPackTone.captionOptions,
                selected = preferences.tone,
                title = { stringResource(it.titleRes) },
                onSelect = { update(preferences.copy(tone = it)) },
            )
        }
        settingsSection(
            title = R.string.caption_pack_settings_output_style,
            content = {
                SettingsSegmentedControl(
                    values = CaptionPackOutputStyle.entries,
                    selected = preferences.outputStyle,
                    title = { stringResource(it.titleRes) },
                    onSelect = { update(preferences.copy(outputStyle = it)) },
                )
            },
        )
    }
}

@Composable
private fun BrandVoiceSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.brandVoice()) }
    var editing by remember { mutableStateOf(false) }
    var editingIndex by remember { mutableStateOf<Int?>(null) }
    var draft by remember { mutableStateOf("") }
    fun update(samples: List<String>) {
        preferences = BrandVoicePreferences(samples)
        CreatorSkillPreferences.saveBrandVoice(preferences)
    }

    SettingsSheetFrame(title = R.string.brand_voice_settings_title, onDismiss = onDismiss) {
        item {
            Column {
                HorizontalDivider(color = ChillColors.Separator)
                preferences.samples.forEachIndexed { index, sample ->
                    Row(
                        modifier = Modifier.fillMaxWidth()
                            .clickable { editingIndex = index; draft = sample; editing = true }
                            .heightIn(min = 68.dp).padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(stringResource(R.string.brand_voice_settings_example_title, index + 1),
                            modifier = Modifier.weight(1f), color = ChillColors.TextMain,
                            style = MaterialTheme.typography.bodyLarge)
                        Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null,
                            tint = ChillColors.TextSub)
                    }
                    HorizontalDivider(color = ChillColors.Separator)
                }
                Row(
                    modifier = Modifier.fillMaxWidth()
                        .clickable { editingIndex = null; draft = ""; editing = true }
                        .heightIn(min = 76.dp).padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.Add, contentDescription = null, tint = ChillColors.BrandBlueText)
                    Text(stringResource(R.string.brand_voice_settings_add_example),
                        color = ChillColors.BrandBlueText, style = MaterialTheme.typography.bodyLarge)
                }
                HorizontalDivider(color = ChillColors.Separator)
            }
        }
        item {
            Text(stringResource(R.string.brand_voice_settings_examples_help),
                color = ChillColors.TextSub, style = MaterialTheme.typography.bodyMedium)
        }
    }
    if (editing) {
        AlertDialog(
            onDismissRequest = { editing = false },
            title = { Text(editingIndex?.let { stringResource(R.string.brand_voice_settings_example_title, it + 1) }
                ?: stringResource(R.string.brand_voice_settings_add_example)) },
            text = {
                Column {
                    OutlinedTextField(value = draft, onValueChange = { draft = it },
                        placeholder = { Text(stringResource(R.string.brand_voice_settings_paste_placeholder)) },
                        minLines = 6, maxLines = 12, modifier = Modifier.fillMaxWidth())
                    if (editingIndex != null) {
                        TextButton(onClick = {
                            update(preferences.samples.filterIndexed { index, _ -> index != editingIndex })
                            editing = false
                        }) { Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error) }
                    }
                }
            },
            confirmButton = {
                TextButton(enabled = draft.isNotBlank(), onClick = {
                    val samples = preferences.samples.toMutableList()
                    editingIndex?.let { samples[it] = draft.trim() } ?: samples.add(draft.trim())
                    update(samples)
                    editing = false
                }) { Text(stringResource(R.string.common_save)) }
            },
            dismissButton = {
                TextButton(onClick = { editing = false }) { Text(stringResource(R.string.common_cancel)) }
            },
        )
    }
}

@Composable
private fun RepurposePackSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.repurposePack()) }
    fun update(next: RepurposePackPreferences) {
        if (next.formats.isEmpty()) return
        preferences = next
        CreatorSkillPreferences.saveRepurposePack(next)
    }
    fun options(formats: List<RepurposeFormat>) = formats.map { format ->
        SettingsToggleOption(format.titleRes, format in preferences.selectedFormats) { enabled ->
            val selected = preferences.selectedFormats.toMutableSet()
            if (enabled) selected.add(format) else selected.remove(format)
            update(preferences.copy(formats = RepurposeFormat.entries.filter { it in selected }))
        }
    }
    @Composable
    fun formatRows(formats: List<RepurposeFormat>) {
        Column {
            formats.forEach { format ->
                SettingsToggleCard(options(listOf(format)))
                if (format == RepurposeFormat.YOUTUBE_VIDEO && format in preferences.selectedFormats) {
                    Column(Modifier.padding(start = 44.dp, top = 10.dp, bottom = 18.dp)) {
                        Text(stringResource(R.string.repurpose_pack_settings_long_video_duration),
                            color = ChillColors.TextSub, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.height(10.dp))
                        SettingsSegmentedControl(
                            values = RepurposePackPreferences.longVideoOptions,
                            selected = preferences.longVideoMinutes,
                            title = { stringResource(R.string.repurpose_pack_duration_minutes, it) },
                            onSelect = { update(preferences.copy(longVideoMinutes = it)) },
                        )
                    }
                }
                if (format == RepurposeFormat.THREADS && format in preferences.selectedFormats) {
                    Column(Modifier.padding(start = 44.dp, top = 10.dp, bottom = 18.dp)) {
                        Text(stringResource(R.string.repurpose_pack_settings_thread_length),
                            color = ChillColors.TextSub, style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.height(10.dp))
                        SettingsSegmentedControl(
                            values = RepurposeThreadLength.entries,
                            selected = preferences.threadLength,
                            title = { stringResource(it.titleRes) },
                            onSelect = { update(preferences.copy(threadLength = it)) },
                        )
                    }
                }
            }
        }
    }
    SettingsSheetFrame(title = R.string.repurpose_pack_settings_title, onDismiss = onDismiss) {
        settingsSection(title = R.string.repurpose_pack_settings_formats) {
            formatRows(RepurposeFormat.primaryFormats)
        }
        settingsSection(title = R.string.repurpose_pack_settings_more_platforms) {
            formatRows(RepurposeFormat.additionalFormats)
        }
    }
}

private fun LazyListScope.settingsSection(
    @StringRes title: Int,
    content: @Composable () -> Unit,
) {
    item {
        Text(
            text = stringResource(title),
            modifier = Modifier.padding(bottom = 12.dp).semantics { heading() },
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        content()
    }
}

@Composable
private fun SettingsSheetFrame(
    @StringRes title: Int,
    onDismiss: () -> Unit,
    content: LazyListScope.() -> Unit,
) {
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
                    .fillMaxHeight(0.92f)
                    .navigationBarsPadding(),
                color = ChillColors.BackgroundPrimary,
                shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                shadowElevation = 18.dp,
            ) {
                Column(Modifier.fillMaxSize()) {
                    SettingsNavigationBar(onDone = onDismiss)
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 24.dp, end = 24.dp, top = 8.dp, bottom = 32.dp),
                        verticalArrangement = Arrangement.spacedBy(28.dp),
                    ) {
                        item {
                            Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                                Icon(
                                    imageVector = settingsHeaderIcon(title),
                                    contentDescription = null,
                                    modifier = Modifier.size(28.dp),
                                    tint = ChillColors.BrandTealText,
                                )
                                Text(
                                    text = stringResource(title),
                                    style = MaterialTheme.typography.displayLarge,
                                    color = ChillColors.TextMain,
                                    modifier = Modifier.semantics { heading() },
                                )
                            }
                        }
                        content()
                    }
                }
            }
        }
    }
}

private fun settingsHeaderIcon(@StringRes title: Int): ImageVector = when (title) {
    R.string.translate_settings_title -> Icons.Outlined.Language
    R.string.repurpose_pack_settings_title -> Icons.Outlined.Layers
    R.string.brand_voice_settings_title -> Icons.Outlined.RecordVoiceOver
    else -> Icons.Outlined.Edit
}

@Composable
private fun SettingsNavigationBar(onDone: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(48.dp)) {
        TextButton(onClick = onDone,
            modifier = Modifier.align(Alignment.CenterEnd).padding(end = 12.dp)) {
            Text(stringResource(R.string.common_done), color = ChillColors.BrandBlueText,
                style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun <T> SettingsMenuRow(
    @StringRes label: Int,
    values: List<T>,
    selected: T,
    title: @Composable (T) -> String,
    onSelect: (T) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { expanded = true }
                    .heightIn(min = 64.dp).padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(stringResource(label), modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.titleMedium, color = ChillColors.TextMain)
                Text(title(selected), modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodyMedium, color = ChillColors.TextSub,
                    textAlign = androidx.compose.ui.text.style.TextAlign.End)
                Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null,
                    tint = ChillColors.TextSub, modifier = Modifier.size(20.dp))
            }
            HorizontalDivider(color = ChillColors.Separator)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            values.forEach { value ->
                DropdownMenuItem(
                    text = { Text(title(value)) },
                    trailingIcon = {
                        if (value == selected) Icon(Icons.Outlined.Check, contentDescription = null,
                            tint = ChillColors.BrandBlueText)
                    },
                    onClick = { onSelect(value); expanded = false },
                )
            }
        }
    }
}

private data class SettingsToggleOption(
    @StringRes val title: Int,
    val checked: Boolean,
    val onCheckedChange: (Boolean) -> Unit,
)

@Composable
private fun SettingsPlatformIcon(@StringRes title: Int) {
    val asset = when (title) {
        R.string.caption_pack_platform_tiktok -> R.drawable.source_brand_tiktok
        R.string.caption_pack_platform_instagram_reels -> R.drawable.source_brand_instagram
        R.string.caption_pack_platform_youtube_shorts, R.string.caption_pack_platform_youtube_long_video -> R.drawable.source_brand_youtube
        else -> null
    }
    if (asset != null) {
        Image(painterResource(asset), contentDescription = null, modifier = Modifier.size(28.dp))
    } else {
        val icon = when (title) {
            R.string.repurpose_pack_format_newsletter -> Icons.Outlined.Email
            R.string.repurpose_pack_format_threads -> Icons.Outlined.AlternateEmail
            R.string.repurpose_pack_format_linkedin -> Icons.Outlined.WorkOutline
            else -> Icons.Outlined.ChatBubbleOutline
        }
        Icon(icon, contentDescription = null, modifier = Modifier.size(28.dp), tint = ChillColors.TextMain)
    }
}

@Composable
private fun SettingsToggleCard(options: List<SettingsToggleOption>) {
    Column(Modifier.fillMaxWidth()) {
        options.forEach { option ->
            Row(
                modifier = Modifier.fillMaxWidth()
                    .toggleable(value = option.checked, role = Role.Checkbox, onValueChange = option.onCheckedChange)
                    .heightIn(min = 60.dp).padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SettingsPlatformIcon(option.title)
                Text(stringResource(option.title), modifier = Modifier.weight(1f),
                    color = ChillColors.TextMain, style = MaterialTheme.typography.bodyLarge)
                Checkbox(checked = option.checked, onCheckedChange = null,
                    colors = CheckboxDefaults.colors(checkedColor = ChillColors.BrandBlue,
                        uncheckedColor = ChillColors.TextSub))
            }
            HorizontalDivider(color = ChillColors.Separator)
        }
    }
}

@Composable
private fun <T> SettingsChoiceCard(
    values: List<T>,
    selected: T,
    title: @Composable (T) -> String,
    onSelect: (T) -> Unit,
) {
    Column(Modifier.fillMaxWidth().selectableGroup()) {
        HorizontalDivider(color = ChillColors.Separator)
        values.forEach { value ->
            Row(
                modifier = Modifier.fillMaxWidth()
                    .selectable(selected = value == selected, role = Role.RadioButton, onClick = { onSelect(value) })
                    .heightIn(min = 58.dp).padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(title(value), modifier = Modifier.weight(1f), color = ChillColors.TextMain,
                    style = MaterialTheme.typography.bodyLarge)
                if (value == selected) {
                    Icon(Icons.Outlined.Check, contentDescription = null, modifier = Modifier.size(22.dp),
                        tint = ChillColors.BrandBlueText)
                }
            }
            HorizontalDivider(color = ChillColors.Separator)
        }
    }
}

@Composable
private fun <T> SettingsSegmentedControl(
    values: List<T>,
    selected: T,
    title: @Composable (T) -> String,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChillColors.CardBackground, RoundedCornerShape(10.dp))
            .selectableGroup()
            .padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        values.forEach { value ->
            val isSelected = value == selected
            Surface(
                modifier = Modifier
                    .weight(1f)
                    .selectable(selected = isSelected, role = Role.RadioButton, onClick = { onSelect(value) })
                    .heightIn(min = 44.dp),
                color = if (isSelected) ChillColors.BrandBlueSoft else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
                shadowElevation = 0.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = title(value),
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                        color = if (isSelected) ChillColors.BrandBlueText else ChillColors.TextSub,
                        fontSize = 13.sp,
                        lineHeight = 16.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,

                    )
                }
            }
        }
    }
}
