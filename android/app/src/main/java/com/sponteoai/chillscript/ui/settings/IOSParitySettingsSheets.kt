package com.sponteoai.chillscript.ui.settings

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.export.NotesExportProgress
import com.sponteoai.chillscript.export.NotesExportStage
import com.sponteoai.chillscript.preferences.VoiceLanguageSettings
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.delay
import java.util.Locale

/** One-to-one Compose rendering of iOS `ExportAllNotesSheet`. */
@Composable
fun IOSParityExportAllNotesSheet(
    noteCount: Int,
    exporting: Boolean,
    progress: NotesExportProgress?,
    statusMessage: String?,
    onStart: () -> Unit,
    onCancel: () -> Unit,
    onClose: () -> Unit,
    applyTopInset: Boolean = true,
    modifier: Modifier = Modifier,
) {
    var elapsedSeconds by remember(exporting) { mutableIntStateOf(0) }
    LaunchedEffect(exporting) {
        while (exporting) {
            delay(1_000)
            elapsedSeconds += 1
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .then(if (applyTopInset) Modifier.statusBarsPadding() else Modifier),
    ) {
        SettingsSheetHeader(
            title = stringResource(R.string.settings_export_nav_title),
            action = stringResource(R.string.common_close),
            actionEnabled = !exporting,
            onAction = onClose,
        )

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item {
                ExportHeroCard(noteCount = noteCount)
            }

            if (exporting || (progress?.processed ?: 0) > 0) {
                item {
                    ExportProgressCard(
                        exporting = exporting,
                        progress = progress,
                        elapsedSeconds = elapsedSeconds,
                        onCancel = onCancel,
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )
                }
            } else if (statusMessage != null) {
                item {
                    Row(
                        modifier = Modifier
                            .padding(horizontal = 20.dp)
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color(0xFF34C759).copy(alpha = 0.10f))
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = Color(0xFF34C759),
                            modifier = Modifier.size(22.dp),
                        )
                        Text(
                            text = statusMessage,
                            color = ChillColors.TextMain,
                            fontSize = 15.sp,
                            lineHeight = 20.sp,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            } else if (noteCount == 0) {
                item {
                    Text(
                        text = stringResource(R.string.settings_export_no_notes),
                        color = ChillColors.TextSub,
                        fontSize = 15.sp,
                        lineHeight = 20.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp, vertical = 10.dp),
                    )
                }
            }

            item {
                ExportBenefits()
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(ChillColors.BackgroundPrimary)
                .navigationBarsPadding(),
        ) {
            Spacer(Modifier.fillMaxWidth().height(1.dp).background(ChillColors.BorderSubtle))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp)
                    .height(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (noteCount > 0 && !exporting) ChillColors.BrandBlue
                        else Color.Gray.copy(alpha = 0.30f),
                    )
                    .clickable(
                        enabled = noteCount > 0 && !exporting,
                        role = Role.Button,
                        onClick = onStart,
                    ),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (exporting) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = stringResource(
                        if (exporting) R.string.settings_export_sheet_exporting
                        else R.string.settings_export_cta,
                    ),
                    color = Color.White,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun ExportHeroCard(noteCount: Int) {
    Column(
        modifier = Modifier
            .padding(horizontal = 20.dp)
            .padding(top = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color.White, ChillColors.BrandBlue.copy(alpha = 0.05f)),
                ),
            )
            .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.08f), RoundedCornerShape(28.dp))
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = stringResource(R.string.settings_export_title),
                color = ChillColors.TextMain,
                fontSize = 30.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.settings_export_subtitle),
                color = ChillColors.TextSub,
                fontSize = 15.sp,
                lineHeight = 21.sp,
                textAlign = TextAlign.Center,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ExportFactCard(
                icon = Icons.Outlined.Description,
                title = stringResource(R.string.settings_export_total_notes),
                value = noteCount.toString(),
                modifier = Modifier.weight(1f),
            )
            ExportFactCard(
                icon = Icons.Outlined.Code,
                title = stringResource(R.string.settings_export_format),
                value = stringResource(R.string.settings_export_format_markdown),
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ExportFactCard(
    icon: ImageVector,
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.90f))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(18.dp))
        Text(text = title, color = ChillColors.TextSub, fontSize = 12.sp, lineHeight = 16.sp)
        Text(
            text = value,
            color = ChillColors.TextMain,
            fontSize = 20.sp,
            lineHeight = 25.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ExportProgressCard(
    exporting: Boolean,
    progress: NotesExportProgress?,
    elapsedSeconds: Int,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val total = progress?.total ?: 0
    val processed = progress?.processed ?: 0
    val percent = if (total <= 0) 0 else ((progress?.fraction ?: 0f) * 100).toInt()
    val stage = when (progress?.stage) {
        NotesExportStage.WRITING -> stringResource(R.string.settings_export_progress_writing)
        NotesExportStage.PACKAGING -> stringResource(R.string.settings_export_progress_packaging)
        NotesExportStage.FINISHING -> stringResource(R.string.export_progress_complete)
        else -> stringResource(R.string.settings_export_progress_preparing)
    }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stage, color = ChillColors.TextMain, fontSize = 15.sp, lineHeight = 20.sp)
                Text(
                    text = stringResource(
                        R.string.export_progress_summary_format,
                        processed,
                        total,
                        "$percent%",
                    ),
                    color = ChillColors.TextSub,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                )
            }
            Text(
                text = "%02d:%02d".format(elapsedSeconds / 60, elapsedSeconds % 60),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = FontFamily.Monospace,
            )
        }
        LinearProgressIndicator(
            progress = { progress?.fraction ?: 0f },
            color = ChillColors.BrandBlue,
            trackColor = ChillColors.BorderSubtle,
            modifier = Modifier.fillMaxWidth(),
        )
        if (exporting) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .border(1.dp, Color(0xFFD14343).copy(alpha = 0.50f), RoundedCornerShape(10.dp))
                    .clickable(role = Role.Button, onClick = onCancel),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.common_cancel),
                    color = Color(0xFFD14343),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

@Composable
private fun ExportBenefits() {
    Column(
        modifier = Modifier.padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            text = stringResource(R.string.settings_export_benefits_title),
            color = ChillColors.TextSub,
            fontSize = 12.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.sp,
        )
        ExportBenefitRow(
            icon = Icons.Outlined.LockOpen,
            title = stringResource(R.string.settings_export_benefit_portable_title),
            body = stringResource(R.string.settings_export_benefit_portable_body),
        )
        ExportBenefitRow(
            icon = Icons.Outlined.AutoAwesome,
            title = stringResource(R.string.settings_export_benefit_ai_title),
            body = stringResource(R.string.settings_export_benefit_ai_body),
        )
        ExportBenefitRow(
            icon = Icons.Outlined.FileUpload,
            title = stringResource(R.string.settings_export_benefit_move_title),
            body = stringResource(R.string.settings_export_benefit_move_body),
        )
    }
}

@Composable
private fun ExportBenefitRow(icon: ImageVector, title: String, body: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White)
            .border(1.dp, Color.Black.copy(alpha = 0.04f), RoundedCornerShape(18.dp))
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(ChillColors.BrandBlue.copy(alpha = 0.10f), RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(18.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = ChillColors.TextMain, fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold)
            Text(body, color = ChillColors.TextSub, fontSize = 12.sp, lineHeight = 16.sp)
        }
    }
}

/** One-to-one Compose rendering of iOS `VoiceLanguagePreferenceSheet`. */
@Composable
fun IOSParityVoiceLanguageSheet(
    settings: VoiceLanguageSettings,
    onUpdate: (mode: String, languageHint: String) -> Unit,
    onClose: () -> Unit,
    applyTopInset: Boolean = true,
    modifier: Modifier = Modifier,
) {
    var mode by remember(settings.mode) { mutableStateOf(settings.mode) }
    var hint by remember(settings.languageHint) { mutableStateOf(settings.languageHint) }
    var search by remember { mutableStateOf("") }
    val locale = LocalConfiguration.current.locales[0]
    val languageCodes = remember {
        listOf(
            "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es",
            "ar", "bn", "bg", "hr", "cs", "da", "nl", "et", "fi", "el", "he", "hi", "hu", "id",
            "it", "lv", "lt", "no", "pl", "pt", "ro", "ru", "sr", "sk", "sl", "sw", "sv", "th", "tr",
            "uk", "vi",
        )
    }
    val filtered = remember(languageCodes, locale, search) {
        val query = search.trim()
        languageCodes.filter { code ->
            val name = Locale.forLanguageTag(code).getDisplayName(locale)
            query.isBlank() || code.contains(query, ignoreCase = true) || name.contains(query, ignoreCase = true)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .then(if (applyTopInset) Modifier.statusBarsPadding() else Modifier)
            .navigationBarsPadding(),
    ) {
        SettingsSheetHeader(
            title = stringResource(R.string.settings_voice_title),
            leadingAction = stringResource(R.string.common_close),
            onLeadingAction = onClose,
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .height(36.dp)
                    .clip(RoundedCornerShape(9.dp))
                    .background(ChillColors.BorderSubtle)
                    .padding(2.dp),
            ) {
                VoiceModeSegment(
                    text = stringResource(R.string.settings_voice_auto),
                    selected = mode == "auto",
                    modifier = Modifier.weight(1f),
                    onClick = {
                        mode = "auto"
                        onUpdate(mode, hint)
                    },
                )
                VoiceModeSegment(
                    text = stringResource(R.string.settings_voice_prefer),
                    selected = mode == "prefer",
                    modifier = Modifier.weight(1f),
                    onClick = {
                        mode = "prefer"
                        onUpdate(mode, hint)
                    },
                )
            }

            Text(
                text = stringResource(
                    if (mode == "auto") R.string.settings_voice_auto_help
                    else R.string.settings_voice_preferred_help,
                ),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                modifier = Modifier.padding(horizontal = 20.dp),
            )

            if (mode == "prefer") {
                BasicTextField(
                    value = search,
                    onValueChange = { search = it },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp)
                        .height(44.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White)
                        .padding(horizontal = 12.dp),
                    textStyle = TextStyle(color = ChillColors.TextMain, fontSize = 15.sp, lineHeight = 20.sp),
                    cursorBrush = SolidColor(ChillColors.BrandBlue),
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.None,
                        imeAction = ImeAction.Search,
                    ),
                    decorationBox = { innerField ->
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.CenterStart) {
                            if (search.isBlank()) {
                                Text(
                                    stringResource(R.string.settings_voice_search),
                                    color = ChillColors.TextSub.copy(alpha = 0.65f),
                                    fontSize = 15.sp,
                                )
                            }
                            innerField()
                        }
                    },
                )

                LazyColumn(Modifier.fillMaxSize()) {
                    items(filtered, key = { it }) { code ->
                        val name = Locale.forLanguageTag(code).getDisplayName(locale).ifBlank { code }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(role = Role.Button) {
                                    hint = code
                                    onUpdate("prefer", code)
                                }
                                .padding(horizontal = 20.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(name, color = ChillColors.TextMain, fontSize = 15.sp, lineHeight = 20.sp)
                                Text(code, color = ChillColors.TextSub, fontSize = 12.sp, lineHeight = 16.sp)
                            }
                            if (hint.equals(code, ignoreCase = true)) {
                                Icon(
                                    Icons.Outlined.Check,
                                    contentDescription = null,
                                    tint = ChillColors.BrandBlue,
                                    modifier = Modifier.size(20.dp),
                                )
                            }
                        }
                        Spacer(
                            Modifier
                                .fillMaxWidth()
                                .padding(start = 20.dp)
                                .height(1.dp)
                                .background(ChillColors.BorderSubtle),
                        )
                    }
                }
            } else {
                Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun VoiceModeSegment(
    text: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(7.dp))
            .background(if (selected) Color.White else Color.Transparent)
            .clickable(role = Role.Tab, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = ChillColors.TextMain,
            fontSize = 13.sp,
            lineHeight = 18.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun SettingsSheetHeader(
    title: String,
    action: String? = null,
    actionEnabled: Boolean = true,
    onAction: () -> Unit = {},
    leadingAction: String? = null,
    onLeadingAction: () -> Unit = {},
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        leadingAction?.let {
            Text(
                text = it,
                color = ChillColors.BrandBlue,
                fontSize = 15.sp,
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .clickable(role = Role.Button, onClick = onLeadingAction)
                    .padding(8.dp),
            )
        }
        Text(
            text = title,
            color = ChillColors.TextMain,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
        )
        action?.let {
            Text(
                text = it,
                color = ChillColors.BrandBlue.copy(alpha = if (actionEnabled) 1f else 0.35f),
                fontSize = 15.sp,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .clickable(enabled = actionEnabled, role = Role.Button, onClick = onAction)
                    .padding(8.dp),
            )
        }
    }
}
