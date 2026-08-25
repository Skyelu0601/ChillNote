package com.sponteoai.chillscript.ui.skills

import androidx.annotation.StringRes
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.preferences.BrandVoicePreferences
import com.sponteoai.chillscript.preferences.CaptionPackGoal
import com.sponteoai.chillscript.preferences.CaptionPackOutputStyle
import com.sponteoai.chillscript.preferences.CaptionPackPreferences
import com.sponteoai.chillscript.preferences.CaptionPackTone
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import com.sponteoai.chillscript.preferences.RepurposePackPreferences
import com.sponteoai.chillscript.preferences.RepurposeThreadLength
import com.sponteoai.chillscript.preferences.TimedScriptDuration
import com.sponteoai.chillscript.preferences.TimedScriptPreferences
import com.sponteoai.chillscript.ui.theme.ChillColors

internal val configurableCreatorSkillIds = setOf(
    "caption_pack",
    "repurpose_pack",
    "style_match",
    "timed_script",
)

@Composable
internal fun CreatorSkillSettingsDialog(
    recipeId: String,
    onDismiss: () -> Unit,
) {
    when (recipeId) {
        "caption_pack" -> CaptionPackSettingsSheet(onDismiss)
        "repurpose_pack" -> RepurposePackSettingsSheet(onDismiss)
        "style_match" -> BrandVoiceSettingsSheet(onDismiss)
        "timed_script" -> TimedScriptSettingsSheet(onDismiss)
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
        settingsSection(
            title = R.string.caption_pack_settings_goal,
            content = {
                SettingsChoiceCard(
                    values = CaptionPackGoal.entries,
                    selected = preferences.goal,
                    title = { it.titleRes },
                    onSelect = { update(preferences.copy(goal = it)) },
                )
            },
        )
        settingsSection(
            title = R.string.caption_pack_settings_tone,
            content = {
                SettingsChoiceCard(
                    values = CaptionPackTone.entries,
                    selected = preferences.tone,
                    title = { it.titleRes },
                    onSelect = { update(preferences.copy(tone = it)) },
                )
            },
        )
        settingsSection(
            title = R.string.caption_pack_settings_output_style,
            content = {
                SettingsSegmentedControl(
                    values = CaptionPackOutputStyle.entries,
                    selected = preferences.outputStyle,
                    title = { it.titleRes },
                    onSelect = { update(preferences.copy(outputStyle = it)) },
                )
            },
        )
    }
}

@Composable
private fun TimedScriptSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.timedScript()) }

    SettingsSheetFrame(
        title = R.string.timed_script_settings_title,
        onDismiss = onDismiss,
    ) {
        settingsSection(
            title = R.string.timed_script_settings_duration,
            content = {
                SettingsSegmentedControl(
                    values = TimedScriptDuration.entries,
                    selected = preferences.duration,
                    title = { it.titleRes },
                    onSelect = { duration ->
                        preferences = TimedScriptPreferences(duration)
                        CreatorSkillPreferences.saveTimedScript(preferences)
                    },
                )
            },
        )
    }
}

@Composable
private fun BrandVoiceSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.brandVoice()) }

    fun update(next: BrandVoicePreferences) {
        preferences = next
        CreatorSkillPreferences.saveBrandVoice(next)
    }

    SettingsSheetFrame(
        title = R.string.brand_voice_settings_title,
        onDismiss = onDismiss,
    ) {
        item {
            BrandVoiceTextSection(
                title = R.string.brand_voice_settings_tone_label,
                placeholder = R.string.brand_voice_settings_tone_placeholder,
                help = R.string.brand_voice_settings_tone_help,
                value = preferences.tone,
                minLines = 1,
                maxLines = 3,
                onValueChange = { update(preferences.copy(tone = it)) },
            )
        }
        item {
            BrandVoiceTextSection(
                title = R.string.brand_voice_settings_audience_label,
                placeholder = R.string.brand_voice_settings_audience_placeholder,
                help = R.string.brand_voice_settings_audience_help,
                value = preferences.audience,
                minLines = 1,
                maxLines = 3,
                onValueChange = { update(preferences.copy(audience = it)) },
            )
        }
        item {
            BrandVoiceTextSection(
                title = R.string.brand_voice_settings_cta_label,
                placeholder = R.string.brand_voice_settings_cta_placeholder,
                help = R.string.brand_voice_settings_cta_help,
                value = preferences.cta,
                minLines = 1,
                maxLines = 3,
                onValueChange = { update(preferences.copy(cta = it)) },
            )
        }
        item {
            BrandVoiceTextSection(
                title = R.string.brand_voice_settings_avoid_label,
                help = R.string.brand_voice_settings_avoid_help,
                value = preferences.avoid,
                minLines = 4,
                maxLines = 8,
                onValueChange = { update(preferences.copy(avoid = it)) },
            )
        }
        item {
            BrandVoiceTextSection(
                title = R.string.brand_voice_settings_sample_label,
                help = R.string.brand_voice_settings_sample_help,
                value = preferences.sample,
                minLines = 6,
                maxLines = 12,
                onValueChange = { update(preferences.copy(sample = it)) },
            )
        }
    }
}

@Composable
private fun RepurposePackSettingsSheet(onDismiss: () -> Unit) {
    var preferences by remember { mutableStateOf(CreatorSkillPreferences.repurposePack()) }

    fun update(next: RepurposePackPreferences) {
        val hasSelectedFormat = listOf(
            next.includeXPost,
            next.includeLinkedIn,
            next.includeThreads,
            next.includeFacebookPage,
            next.includeNewsletter,
            next.includeInstagramCarousel,
            next.includePinterestPin,
            next.includeYouTubeCommunity,
        ).any { it }
        if (!hasSelectedFormat) return
        preferences = next
        CreatorSkillPreferences.saveRepurposePack(next)
    }

    val selectedFormatCount = listOf(
        preferences.includeXPost,
        preferences.includeLinkedIn,
        preferences.includeThreads,
        preferences.includeFacebookPage,
        preferences.includeNewsletter,
        preferences.includeInstagramCarousel,
        preferences.includePinterestPin,
        preferences.includeYouTubeCommunity,
    ).count { it }

    SettingsSheetFrame(
        title = R.string.repurpose_pack_settings_title,
        onDismiss = onDismiss,
    ) {
        settingsSection(
            title = R.string.repurpose_pack_settings_formats,
            content = {
                SettingsToggleCard(
                    listOf(
                        SettingsToggleOption(R.string.repurpose_pack_format_x_post, preferences.includeXPost) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeXPost = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_linkedin, preferences.includeLinkedIn) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeLinkedIn = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_threads, preferences.includeThreads) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeThreads = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_facebook_page, preferences.includeFacebookPage) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeFacebookPage = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_newsletter, preferences.includeNewsletter) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeNewsletter = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_instagram_carousel, preferences.includeInstagramCarousel) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeInstagramCarousel = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_pinterest_pin, preferences.includePinterestPin) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includePinterestPin = enabled))
                        },
                        SettingsToggleOption(R.string.repurpose_pack_format_youtube_community, preferences.includeYouTubeCommunity) { enabled ->
                            if (enabled || selectedFormatCount > 1) update(preferences.copy(includeYouTubeCommunity = enabled))
                        },
                    ),
                )
            },
        )
        if (preferences.includeThreads) {
            settingsSection(
                title = R.string.repurpose_pack_settings_thread_length,
                content = {
                    SettingsSegmentedControl(
                        values = RepurposeThreadLength.entries,
                        selected = preferences.threadLength,
                        title = { it.titleRes },
                        onSelect = { update(preferences.copy(threadLength = it)) },
                    )
                },
            )
        }
        settingsSection(
            title = R.string.repurpose_pack_settings_tone,
            content = {
                SettingsChoiceCard(
                    values = CaptionPackTone.entries,
                    selected = preferences.tone,
                    title = { it.titleRes },
                    onSelect = { update(preferences.copy(tone = it)) },
                )
            },
        )
        item {
            Spacer(Modifier.height(2.dp))
            SettingsToggleCard(
                listOf(
                    SettingsToggleOption(
                        R.string.repurpose_pack_settings_cta,
                        preferences.includeCTA,
                    ) { update(preferences.copy(includeCTA = it)) },
                ),
            )
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
            modifier = Modifier.padding(start = 4.dp, bottom = 7.dp),
            color = ChillColors.TextSub,
            fontSize = 13.sp,
            lineHeight = 17.sp,
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
                    SettingsNavigationBar(
                        title = stringResource(title),
                        onDone = onDismiss,
                    )
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 18.dp),
                        verticalArrangement = Arrangement.spacedBy(20.dp),
                        content = content,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsNavigationBar(
    title: String,
    onDone: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .background(ChillColors.BackgroundSecondary),
    ) {
        Text(
            text = title,
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 64.dp),
            color = ChillColors.TextMain,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        TextButton(
            onClick = onDone,
            modifier = Modifier.align(Alignment.CenterEnd),
        ) {
            Text(
                text = stringResource(R.string.common_done),
                color = ChillColors.BrandBlueText,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private data class SettingsToggleOption(
    @StringRes val title: Int,
    val checked: Boolean,
    val onCheckedChange: (Boolean) -> Unit,
)

@Composable
private fun SettingsToggleCard(options: List<SettingsToggleOption>) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = ChillColors.CardBackground,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, ChillColors.BorderSubtle),
    ) {
        Column {
            options.forEachIndexed { index, option ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 50.dp)
                        .padding(start = 16.dp, end = 10.dp, top = 6.dp, bottom = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = stringResource(option.title),
                        modifier = Modifier.weight(1f),
                        color = ChillColors.TextMain,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Switch(
                        checked = option.checked,
                        onCheckedChange = option.onCheckedChange,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = ChillColors.BrandTeal,
                        ),
                    )
                }
                if (index < options.lastIndex) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        color = ChillColors.Separator,
                    )
                }
            }
        }
    }
}

@Composable
private fun <T> SettingsChoiceCard(
    values: List<T>,
    selected: T,
    title: (T) -> Int,
    onSelect: (T) -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = ChillColors.CardBackground,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, ChillColors.BorderSubtle),
    ) {
        Column {
            values.forEachIndexed { index, value ->
                Surface(
                    onClick = { onSelect(value) },
                    color = Color.Transparent,
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = stringResource(title(value)),
                            modifier = Modifier.weight(1f),
                            color = ChillColors.TextMain,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        if (value == selected) {
                            Icon(
                                imageVector = Icons.Outlined.Check,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = ChillColors.BrandBlueText,
                            )
                        }
                    }
                }
                if (index < values.lastIndex) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        color = ChillColors.Separator,
                    )
                }
            }
        }
    }
}

@Composable
private fun <T> SettingsSegmentedControl(
    values: List<T>,
    selected: T,
    title: (T) -> Int,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(ChillColors.TextSub.copy(alpha = 0.12f), RoundedCornerShape(10.dp))
            .padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        values.forEach { value ->
            val isSelected = value == selected
            Surface(
                onClick = { onSelect(value) },
                modifier = Modifier
                    .weight(1f)
                    .height(34.dp),
                color = if (isSelected) ChillColors.CardBackground else Color.Transparent,
                shape = RoundedCornerShape(8.dp),
                shadowElevation = if (isSelected) 1.dp else 0.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        text = stringResource(title(value)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                        color = ChillColors.TextMain,
                        fontSize = 13.sp,
                        lineHeight = 16.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun BrandVoiceTextSection(
    @StringRes title: Int,
    @StringRes help: Int,
    value: String,
    minLines: Int,
    maxLines: Int,
    onValueChange: (String) -> Unit,
    @StringRes placeholder: Int? = null,
) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(
            text = stringResource(title),
            modifier = Modifier.padding(start = 4.dp),
            color = ChillColors.TextSub,
            fontSize = 13.sp,
            lineHeight = 17.sp,
            fontWeight = FontWeight.SemiBold,
        )
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = if (minLines >= 6) 140.dp else if (minLines >= 4) 90.dp else 52.dp),
            placeholder = {
                if (placeholder != null) {
                    Text(
                        text = stringResource(placeholder),
                        color = ChillColors.TextSub.copy(alpha = 0.72f),
                    )
                }
            },
            minLines = minLines,
            maxLines = maxLines,
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = ChillColors.CardBackground,
                unfocusedContainerColor = ChillColors.CardBackground,
                focusedBorderColor = ChillColors.BrandBlueText,
                unfocusedBorderColor = ChillColors.BorderSubtle,
            ),
        )
        Text(
            text = stringResource(help),
            modifier = Modifier.padding(horizontal = 4.dp),
            color = ChillColors.TextSub,
            fontSize = 12.sp,
            lineHeight = 16.sp,
        )
    }
}
