package com.sponteoai.chillscript.weekly

import android.app.TimePickerDialog
import android.text.format.DateFormat as AndroidDateFormat
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.text.DateFormatSymbols
import java.util.Calendar
import java.util.Locale

/** Full-screen free-tier preview matching the current iOS WeeklyTopicsPreviewView. */
@Composable
fun WeeklyTopicsPreviewScreen(
    onBack: () -> Unit,
    onTry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = onBack)
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .statusBarsPadding(),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 24.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            IconButton(onClick = onBack, modifier = Modifier.size(34.dp)) {
                Icon(
                    Icons.AutoMirrored.Outlined.ArrowBack,
                    contentDescription = stringResource(R.string.common_back),
                    tint = ChillColors.TextMain,
                    modifier = Modifier.size(27.dp),
                )
            }
            Text(
                stringResource(R.string.weekly_topics_preview_title),
                color = ChillColors.TextMain,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        Column(
            modifier = Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(38.dp))
            WeeklyTopicsPreviewHeadline(Modifier.padding(horizontal = 32.dp))
            Spacer(Modifier.height(22.dp))
            WeeklyTopicsPreviewIllustration(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp).height(304.dp),
            )
            Spacer(Modifier.height(22.dp))
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(ChillColors.BackgroundPrimary)
                .padding(horizontal = 24.dp)
                .padding(top = 12.dp, bottom = 16.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .background(ChillColors.BrandBlue, RoundedCornerShape(16.dp))
                    .clickable(onClick = onTry),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.weekly_topics_preview_try_action),
                    color = Color.White,
                    fontSize = 19.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Text(
                stringResource(R.string.weekly_topics_preview_skip_action),
                color = ChillColors.BrandBlue,
                fontSize = 17.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.clickable(onClick = onBack).padding(horizontal = 20.dp, vertical = 6.dp),
            )
        }
    }
}

@Composable
private fun WeeklyTopicsPreviewHeadline(modifier: Modifier = Modifier) {
    val headline = stringResource(R.string.weekly_topics_preview_headline)
    val highlight = stringResource(R.string.weekly_topics_preview_headline_highlight)
    val start = headline.indexOf(highlight)
    val styled = buildAnnotatedString {
        if (start < 0) {
            append(headline)
        } else {
            append(headline.substring(0, start))
            withStyle(SpanStyle(color = ChillColors.BrandBlue)) { append(highlight) }
            append(headline.substring(start + highlight.length))
        }
    }
    Text(
        styled,
        modifier = modifier,
        color = ChillColors.TextMain,
        fontSize = 26.sp,
        lineHeight = 32.sp,
        fontWeight = FontWeight.Bold,
        textAlign = TextAlign.Center,
    )
}

@Composable
private fun WeeklyTopicsPreviewIllustration(modifier: Modifier = Modifier) {
    val accessibility = stringResource(R.string.weekly_topics_preview_illustration_accessibility)
    BoxWithConstraints(
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = accessibility },
    ) {
        val sourceWidth = minOf(132.dp, maxWidth * 0.38f)
        val resultWidth = minOf(148.dp, maxWidth * 0.42f)

        Box(
            Modifier
                .fillMaxWidth()
                .height(270.dp)
                .offset(y = (-8).dp)
                .background(
                    Brush.radialGradient(
                        listOf(ChillColors.BrandBlueSoft.copy(alpha = 0.82f), Color.Transparent),
                    ),
                ),
        )
        Canvas(Modifier.fillMaxWidth().height(270.dp)) {
            val sourceTrailing = sourceWidth.toPx() - 4.dp.toPx()
            val resultLeading = size.width - resultWidth.toPx()
            val joinX = sourceTrailing + ((resultLeading - sourceTrailing) * 0.62f)
            val centerY = 122.dp.toPx()
            val connector = Path()
            listOf(42.dp, 122.dp, 202.dp).forEach { sourceY ->
                connector.moveTo(sourceTrailing, sourceY.toPx())
                connector.cubicTo(
                    sourceTrailing + 30.dp.toPx(), sourceY.toPx(),
                    joinX - 24.dp.toPx(), centerY,
                    joinX, centerY,
                )
            }
            val arrowEnd = resultLeading - 5.dp.toPx()
            connector.moveTo(joinX, centerY)
            connector.lineTo(arrowEnd, centerY)
            connector.moveTo(arrowEnd - 10.dp.toPx(), centerY - 10.dp.toPx())
            connector.lineTo(arrowEnd, centerY)
            connector.lineTo(arrowEnd - 10.dp.toPx(), centerY + 10.dp.toPx())
            drawPath(
                connector,
                color = ChillColors.BrandBlue.copy(alpha = 0.50f),
                style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
            )
        }

        Column(
            modifier = Modifier.width(sourceWidth).offset(y = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            WeeklyTopicsSourcePreviewCard(Icons.Outlined.ChatBubbleOutline, ChillColors.BrandBlueSoft.copy(alpha = 0.72f))
            WeeklyTopicsSourcePreviewCard(Icons.Outlined.Link, ChillColors.BrandBlueSoft.copy(alpha = 0.72f))
            WeeklyTopicsSourcePreviewCard(Icons.Outlined.Edit, ChillColors.BrandBlueSoft.copy(alpha = 0.72f))
        }

        Column(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(y = 8.dp)
                .width(resultWidth)
                .height(228.dp)
                .shadow(18.dp, RoundedCornerShape(24.dp), ambientColor = ChillColors.BrandBlue.copy(alpha = 0.13f), spotColor = ChillColors.BrandBlue.copy(alpha = 0.13f))
                .background(Color.White, RoundedCornerShape(24.dp))
                .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.20f), RoundedCornerShape(24.dp))
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(Icons.Outlined.Lightbulb, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(46.dp))
            Spacer(Modifier.height(14.dp))
            Text(
                stringResource(R.string.weekly_topics_preview_illustration_label),
                color = ChillColors.BrandBlueText,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(14.dp))
            listOf(86.dp, 68.dp, 86.dp).forEach { lineWidth ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(Modifier.size(7.dp).background(ChillColors.BrandBlue.copy(alpha = 0.18f), CircleShape))
                    Box(Modifier.width(lineWidth).height(7.dp).background(ChillColors.BrandBlue.copy(alpha = 0.13f), CircleShape))
                }
            }
        }

        Text(
            stringResource(R.string.weekly_topics_preview_sources_label),
            modifier = Modifier.width(sourceWidth).offset(y = 260.dp),
            color = ChillColors.TextMain,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
        Text(
            stringResource(R.string.weekly_topics_preview_result_label),
            modifier = Modifier.align(Alignment.TopEnd).width(resultWidth).offset(y = 260.dp),
            color = ChillColors.TextMain,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun WeeklyTopicsSourcePreviewCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    background: Color,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(68.dp)
            .shadow(10.dp, RoundedCornerShape(16.dp), ambientColor = ChillColors.Shadow, spotColor = ChillColors.Shadow)
            .background(background, RoundedCornerShape(16.dp))
            .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.14f), RoundedCornerShape(16.dp))
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = ChillColors.BrandBlue, modifier = Modifier.size(26.dp))
        Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Box(Modifier.fillMaxWidth().height(7.dp).background(ChillColors.TextSub.copy(alpha = 0.26f), CircleShape))
            Box(Modifier.width(54.dp).height(7.dp).background(ChillColors.TextSub.copy(alpha = 0.17f), CircleShape))
        }
    }
}

/** Schedule/settings overlay matching the two current iOS weekly-topic flows. */
@Composable
fun WeeklyTopicsSettingsOverlay(
    settings: WeeklyTopicSettings?,
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onSave: (enabled: Boolean, weekday: Int, hour: Int, minute: Int) -> Unit,
    applyTopInset: Boolean = true,
    modifier: Modifier = Modifier,
) {
    val locale = LocalLocale.current.platformLocale
    var enabled by remember(settings) { mutableStateOf(settings?.enabled ?: true) }
    var weekday by remember(settings) { mutableStateOf(settings?.weekday ?: 1) }
    var hour by remember(settings) { mutableStateOf(settings?.hour ?: 9) }
    var minute by remember(settings) { mutableStateOf(settings?.minute ?: 0) }
    val firstSchedule = settings?.enabled != true

    BackHandler(enabled = !isSaving, onBack = onDismiss)
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .then(if (applyTopInset) Modifier.statusBarsPadding() else Modifier),
    ) {
        if (firstSchedule) {
            WeeklyTopicsScheduleHeader(onDismiss)
            Column(
                modifier = Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(
                    Icons.Outlined.CalendarMonth,
                    contentDescription = null,
                    tint = ChillColors.BrandHoney,
                    modifier = Modifier.size(42.dp),
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.weekly_topics_schedule_message),
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(20.dp))
                WeeklyTopicsScheduleCard(
                    enabled = true,
                    weekday = weekday,
                    hour = hour,
                    minute = minute,
                    locale = locale,
                    isSaving = isSaving,
                    onWeekday = { weekday = it },
                    onHour = { hour = it },
                    onMinute = { minute = it },
                )
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .padding(top = 12.dp, bottom = 16.dp)
                    .navigationBarsPadding()
                    .height(58.dp)
                    .background(ChillColors.BrandBlue.copy(alpha = if (isSaving) 0.55f else 1f), RoundedCornerShape(16.dp))
                    .clickable(enabled = !isSaving) { onSave(true, weekday, hour, minute) },
                contentAlignment = Alignment.Center,
            ) {
                if (isSaving) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                else Text(
                    stringResource(R.string.weekly_topics_schedule_action),
                    color = Color.White,
                    fontSize = 19.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        } else {
            WeeklyTopicsSettingsHeader(
                isSaving = isSaving,
                onCancel = onDismiss,
                onSave = { onSave(enabled, weekday, hour, minute) },
            )
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 24.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                item {
                    Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(16.dp))) {
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(stringResource(R.string.weekly_topics_settings_enabled), color = ChillColors.TextMain, fontSize = 17.sp, modifier = Modifier.weight(1f))
                            Switch(checked = enabled, onCheckedChange = { enabled = it }, enabled = !isSaving)
                        }
                        HorizontalDivider(Modifier.padding(start = 18.dp), color = ChillColors.Separator)
                        WeeklyTopicsScheduleCardRows(
                            enabled = enabled,
                            weekday = weekday,
                            hour = hour,
                            minute = minute,
                            locale = locale,
                            isSaving = isSaving,
                            onWeekday = { weekday = it },
                            onHour = { hour = it },
                            onMinute = { minute = it },
                        )
                    }
                }
                item {
                    Text(
                        stringResource(R.string.weekly_topics_settings_source_scope),
                        color = ChillColors.TextSub,
                        fontSize = 13.sp,
                        lineHeight = 18.sp,
                        modifier = Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(16.dp)).padding(18.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun WeeklyTopicsScheduleHeader(onBack: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
        IconButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart).size(44.dp)) {
            Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.common_back), tint = ChillColors.TextMain)
        }
        Text(
            stringResource(R.string.weekly_topics_schedule_title),
            color = ChillColors.TextMain,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun WeeklyTopicsSettingsHeader(
    isSaving: Boolean,
    onCancel: () -> Unit,
    onSave: () -> Unit,
) {
    Box(Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 12.dp), contentAlignment = Alignment.Center) {
        Text(
            stringResource(R.string.common_cancel),
            color = ChillColors.BrandHoneyText.copy(alpha = if (isSaving) 0.45f else 1f),
            fontSize = 17.sp,
            modifier = Modifier.align(Alignment.CenterStart).clickable(enabled = !isSaving, onClick = onCancel).padding(12.dp),
        )
        Text(
            stringResource(R.string.weekly_topics_settings_title),
            color = ChillColors.TextMain,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
        )
        if (isSaving) {
            CircularProgressIndicator(Modifier.align(Alignment.CenterEnd).padding(12.dp).size(18.dp), color = ChillColors.BrandHoneyText, strokeWidth = 2.dp)
        } else {
            Text(
                stringResource(R.string.common_save),
                color = ChillColors.BrandHoneyText,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.CenterEnd).clickable(onClick = onSave).padding(12.dp),
            )
        }
    }
}

@Composable
private fun WeeklyTopicsScheduleCard(
    enabled: Boolean,
    weekday: Int,
    hour: Int,
    minute: Int,
    locale: Locale,
    isSaving: Boolean,
    onWeekday: (Int) -> Unit,
    onHour: (Int) -> Unit,
    onMinute: (Int) -> Unit,
) {
    Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(18.dp))) {
        WeeklyTopicsScheduleCardRows(enabled, weekday, hour, minute, locale, isSaving, onWeekday, onHour, onMinute)
    }
}

@Composable
private fun WeeklyTopicsScheduleCardRows(
    enabled: Boolean,
    weekday: Int,
    hour: Int,
    minute: Int,
    locale: Locale,
    isSaving: Boolean,
    onWeekday: (Int) -> Unit,
    onHour: (Int) -> Unit,
    onMinute: (Int) -> Unit,
) {
    var weekdayMenuOpen by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val formattedTime = remember(hour, minute, locale) {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
        }
        AndroidDateFormat.getTimeFormat(context).format(calendar.time)
    }
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(stringResource(R.string.weekly_topics_settings_weekday), color = ChillColors.TextMain, fontSize = 17.sp, modifier = Modifier.weight(1f))
        Box {
            Text(
                weeklyTopicsWeekdayLabel(weekday, locale),
                color = ChillColors.BrandHoneyText.copy(alpha = if (enabled) 1f else 0.4f),
                fontSize = 17.sp,
                modifier = Modifier.clickable(enabled = enabled && !isSaving) { weekdayMenuOpen = true }.padding(8.dp),
            )
            DropdownMenu(expanded = weekdayMenuOpen, onDismissRequest = { weekdayMenuOpen = false }) {
                (1..7).forEach { value ->
                    DropdownMenuItem(
                        text = { Text(weeklyTopicsWeekdayLabel(value, locale)) },
                        onClick = {
                            onWeekday(value)
                            weekdayMenuOpen = false
                        },
                    )
                }
            }
        }
    }
    HorizontalDivider(Modifier.padding(start = 18.dp), color = ChillColors.Separator)
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled && !isSaving) {
                TimePickerDialog(
                    context,
                    { _, selectedHour, selectedMinute ->
                        onHour(selectedHour)
                        onMinute(selectedMinute)
                    },
                    hour,
                    minute,
                    AndroidDateFormat.is24HourFormat(context),
                ).show()
            }
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(stringResource(R.string.weekly_topics_settings_time), color = ChillColors.TextMain, fontSize = 17.sp, modifier = Modifier.weight(1f))
        Text(
            formattedTime,
            color = ChillColors.BrandHoneyText.copy(alpha = if (enabled) 1f else 0.4f),
            fontSize = 17.sp,
            modifier = Modifier.padding(8.dp),
        )
    }
}

private fun weeklyTopicsWeekdayLabel(weekday: Int, locale: Locale): String {
    val calendarIndex = if (weekday == 7) 1 else weekday + 1
    return DateFormatSymbols.getInstance(locale).weekdays[calendarIndex]
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeeklyTopicsRoute(
    controller: WeeklyTopicsController,
    onBack: () -> Unit,
    onConfigureWeeklyTopics: () -> Unit,
    onOpenSource: (WeeklyTopicSource) -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by controller.state.collectAsStateWithLifecycle()
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(controller) {
        controller.loadDashboard()
    }

    val visibleReport = when (state.destination) {
        WeeklyTopicsDestination.DASHBOARD -> state.dashboard?.latestReport
        WeeklyTopicsDestination.REPORT -> state.selectedReport
        WeeklyTopicsDestination.HISTORY -> null
    }
    LaunchedEffect(visibleReport?.id, visibleReport?.readAt) {
        visibleReport?.takeIf(WeeklyTopicReport::isUnread)?.let { controller.markRead(it) }
    }

    val handleBack: () -> Unit = {
        if (!controller.navigateBack()) onBack()
    }
    BackHandler(onBack = handleBack)

    val screen: @Composable (WeeklyTopicsUiState, Modifier) -> Unit = { screenState, screenModifier ->
        WeeklyTopicsScreen(
            state = screenState,
            onBack = handleBack,
            onRetry = { coroutineScope.launch { controller.refreshCurrent() } },
            onOpenHistory = { coroutineScope.launch { controller.openHistory() } },
            onOpenReport = { reportId -> coroutineScope.launch { controller.openReport(reportId) } },
            onConfigureWeeklyTopics = onConfigureWeeklyTopics,
            onOpenSource = onOpenSource,
            onRegenerate = { report -> coroutineScope.launch { controller.regenerate(report) } },
            onDismissFailure = controller::clearFailure,
            modifier = screenModifier,
        )
    }

    Box(modifier.fillMaxSize()) {
        if (state.destination == WeeklyTopicsDestination.DASHBOARD) {
            screen(state, Modifier.fillMaxSize())
        } else {
            // iOS keeps the dashboard in place and presents History as a sheet;
            // report details then navigate inside that same sheet.
            screen(
                state.copy(
                    destination = WeeklyTopicsDestination.DASHBOARD,
                    selectedReportId = null,
                    failure = null,
                    isRegenerating = false,
                ),
                Modifier.fillMaxSize(),
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.18f))
                    .clickable(onClick = handleBack),
            )
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxSize()
                    .padding(top = 12.dp),
                shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
                color = ChillColors.BackgroundPrimary,
                shadowElevation = 18.dp,
            ) {
                Box(Modifier.fillMaxSize()) {
                    screen(state, Modifier.fillMaxSize())
                    Box(
                        Modifier
                            .align(Alignment.TopCenter)
                            .padding(top = 8.dp)
                            .size(width = 36.dp, height = 5.dp)
                            .background(ChillColors.TextSub.copy(alpha = 0.28f), CircleShape),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeeklyTopicsScreen(
    state: WeeklyTopicsUiState,
    onBack: () -> Unit,
    onRetry: () -> Unit,
    onOpenHistory: () -> Unit,
    onOpenReport: (String) -> Unit,
    onConfigureWeeklyTopics: () -> Unit,
    onOpenSource: (WeeklyTopicSource) -> Unit,
    onRegenerate: (WeeklyTopicReport) -> Unit,
    onDismissFailure: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var pendingRegeneration by remember { mutableStateOf<WeeklyTopicReport?>(null) }
    val title = when (state.destination) {
        WeeklyTopicsDestination.HISTORY -> stringResource(R.string.weekly_topics_history_title)
        else -> stringResource(R.string.weekly_topics_title)
    }
    val showInlineFailure = when (state.destination) {
        WeeklyTopicsDestination.DASHBOARD -> state.dashboard == null && !state.isInitialLoading
        WeeklyTopicsDestination.HISTORY -> !state.hasLoadedHistory && !state.isHistoryLoading
        WeeklyTopicsDestination.REPORT -> state.selectedReport == null && !state.isDetailLoading
    } && state.failure != null

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = if (state.destination == WeeklyTopicsDestination.HISTORY) {
            ChillColors.BackgroundPrimary
        } else {
            Color.White
        },
        topBar = {
            val dashboardReport = state.dashboard?.latestReport
            WeeklyTopicsHeader(
                title = title,
                isHistory = state.destination == WeeklyTopicsDestination.HISTORY,
                showActions = state.destination == WeeklyTopicsDestination.DASHBOARD &&
                    state.dashboard?.settings?.enabled == true,
                canRegenerate = dashboardReport?.canRegenerate == true,
                onBack = onBack,
                onOpenHistory = onOpenHistory,
                onOpenSettings = onConfigureWeeklyTopics,
                onRegenerate = { dashboardReport?.let { pendingRegeneration = it } },
            )
        },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when (state.destination) {
                WeeklyTopicsDestination.DASHBOARD -> WeeklyTopicsDashboardContent(
                    state = state,
                    onRetry = onRetry,
                    onConfigureWeeklyTopics = onConfigureWeeklyTopics,
                    onOpenSource = onOpenSource,
                )
                WeeklyTopicsDestination.HISTORY -> WeeklyTopicsHistoryContent(
                    state = state,
                    onRetry = onRetry,
                    onOpenReport = onOpenReport,
                )
                WeeklyTopicsDestination.REPORT -> WeeklyTopicsReportDetailContent(
                    state = state,
                    onRetry = onRetry,
                    onOpenSource = onOpenSource,
                )
            }

            if (state.isRegenerating) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = Color.White.copy(alpha = 0.94f),
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        CircularProgressIndicator()
                        Spacer(Modifier.height(14.dp))
                        Text(
                            stringResource(R.string.weekly_topics_regenerate_progress),
                            color = ChillColors.TextSub,
                            fontSize = 15.sp,
                        )
                    }
                }
            }
        }
    }

    pendingRegeneration?.let { report ->
        AlertDialog(
            onDismissRequest = { pendingRegeneration = null },
            title = { Text(stringResource(R.string.weekly_topics_regenerate_confirm_title)) },
            text = { Text(stringResource(R.string.weekly_topics_regenerate_confirm_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        pendingRegeneration = null
                        onRegenerate(report)
                    },
                ) {
                    Text(stringResource(R.string.weekly_topics_regenerate_action))
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingRegeneration = null }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        )
    }

    if (state.failure != null && !showInlineFailure) {
        AlertDialog(
            onDismissRequest = onDismissFailure,
            title = { Text(stringResource(R.string.weekly_topics_error_title)) },
            text = { Text(stringResource(failureMessageResource(state.failure.operation))) },
            confirmButton = {
                TextButton(onClick = onDismissFailure) {
                    Text(stringResource(R.string.common_ok))
                }
            },
        )
    }
}

@Composable
private fun WeeklyTopicsHeader(
    title: String,
    isHistory: Boolean,
    showActions: Boolean,
    canRegenerate: Boolean,
    onBack: () -> Unit,
    onOpenHistory: () -> Unit,
    onOpenSettings: () -> Unit,
    onRegenerate: () -> Unit,
) {
    var menuExpanded by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().background(ChillColors.BackgroundPrimary).statusBarsPadding()) {
        Box(
            Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (isHistory) {
                Text(
                    stringResource(R.string.common_close),
                    color = ChillColors.BrandHoneyText,
                    fontSize = 17.sp,
                    modifier = Modifier.align(Alignment.CenterStart).clickable(onClick = onBack).padding(12.dp),
                )
            } else {
                IconButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart).size(44.dp)) {
                    Icon(
                        Icons.AutoMirrored.Outlined.ArrowBack,
                        contentDescription = stringResource(R.string.common_back),
                        tint = ChillColors.TextMain,
                    )
                }
            }
            Text(
                title,
                color = ChillColors.TextMain,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 100.dp),
            )
            if (showActions) {
                Row(Modifier.align(Alignment.CenterEnd)) {
                    IconButton(onClick = onOpenHistory, modifier = Modifier.size(44.dp)) {
                        Icon(
                            Icons.Outlined.History,
                            contentDescription = stringResource(R.string.weekly_topics_history_title),
                            tint = ChillColors.BrandHoneyText,
                        )
                    }
                    Box {
                        IconButton(onClick = { menuExpanded = true }, modifier = Modifier.size(44.dp)) {
                            Icon(
                                Icons.Outlined.MoreHoriz,
                                contentDescription = stringResource(R.string.weekly_topics_more_actions),
                                tint = ChillColors.BrandHoneyText,
                            )
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            if (canRegenerate) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.weekly_topics_regenerate_action)) },
                                    onClick = {
                                        menuExpanded = false
                                        onRegenerate()
                                    },
                                )
                            }
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.weekly_topics_settings_title)) },
                                onClick = {
                                    menuExpanded = false
                                    onOpenSettings()
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyTopicsDashboardContent(
    state: WeeklyTopicsUiState,
    onRetry: () -> Unit,
    onConfigureWeeklyTopics: () -> Unit,
    onOpenSource: (WeeklyTopicSource) -> Unit,
) {
    when {
        state.isInitialLoading && state.dashboard == null -> CenteredLoading()
        state.dashboard == null -> WeeklyTopicsLoadFailure(onRetry)
        !state.dashboard.settings.enabled -> WeeklyTopicsEnableContent(onConfigureWeeklyTopics)
        state.dashboard.latestReport != null -> WeeklyTopicReportContent(
            report = state.dashboard.latestReport,
            onOpenSource = onOpenSource,
        )
        else -> WeeklyTopicsWaitingContent(state.dashboard)
    }
}

@Composable
private fun WeeklyTopicsHistoryContent(
    state: WeeklyTopicsUiState,
    onRetry: () -> Unit,
    onOpenReport: (String) -> Unit,
) {
    when {
        state.isHistoryLoading && !state.hasLoadedHistory -> CenteredLoading()
        !state.hasLoadedHistory -> WeeklyTopicsLoadFailure(onRetry)
        state.reports.isEmpty() -> CenteredMessage(
            icon = { Icon(Icons.Outlined.History, contentDescription = null, modifier = Modifier.size(38.dp)) },
            title = stringResource(R.string.weekly_topics_history_empty),
        )
        else -> LazyColumn(modifier = Modifier.fillMaxSize().background(Color.White)) {
            itemsIndexed(state.reports, key = { _, report -> report.id }) { index, report ->
                WeeklyTopicHistoryRow(report = report, onClick = { onOpenReport(report.id) })
                if (index < state.reports.lastIndex) HorizontalDivider(Modifier.padding(start = 24.dp), color = ChillColors.Separator)
            }
        }
    }
}

@Composable
private fun WeeklyTopicsReportDetailContent(
    state: WeeklyTopicsUiState,
    onRetry: () -> Unit,
    onOpenSource: (WeeklyTopicSource) -> Unit,
) {
    val selectedReport = state.selectedReport
    when {
        state.isDetailLoading && selectedReport == null -> CenteredLoading()
        selectedReport == null -> WeeklyTopicsLoadFailure(onRetry)
        else -> WeeklyTopicReportContent(
            report = selectedReport,
            onOpenSource = onOpenSource,
        )
    }
}

@Composable
private fun WeeklyTopicsEnableContent(onConfigureWeeklyTopics: () -> Unit) {
    Column(Modifier.fillMaxSize().background(ChillColors.BackgroundPrimary)) {
        Column(
            modifier = Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(38.dp))
            WeeklyTopicsPreviewHeadline(Modifier.padding(horizontal = 32.dp))
            Spacer(Modifier.height(22.dp))
            WeeklyTopicsPreviewIllustration(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp).height(304.dp),
            )
            Spacer(Modifier.height(22.dp))
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 12.dp, bottom = 16.dp)
                .height(58.dp)
                .background(ChillColors.BrandBlue, RoundedCornerShape(16.dp))
                .clickable(onClick = onConfigureWeeklyTopics),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                stringResource(R.string.weekly_topics_schedule_action),
                color = Color.White,
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun WeeklyTopicsWaitingContent(dashboard: WeeklyTopicDashboard) {
    CenteredMessage(
        icon = { Icon(Icons.Outlined.Description, contentDescription = null, tint = ChillColors.BrandHoney, modifier = Modifier.size(40.dp)) },
        title = stringResource(R.string.weekly_topics_waiting_title),
        message = stringResource(
            if (dashboard.currentSourceCount < dashboard.minimumSourceCount) {
                R.string.weekly_topics_waiting_no_sources
            } else {
                R.string.weekly_topics_waiting_ready
            },
        ),
    )
}

@Composable
private fun WeeklyTopicsLoadFailure(onRetry: () -> Unit) {
    CenteredMessage(
        icon = { Icon(Icons.Outlined.Refresh, contentDescription = null, modifier = Modifier.size(40.dp)) },
        title = stringResource(R.string.weekly_topics_error_title),
        message = stringResource(R.string.weekly_topics_error_load),
        action = {
            Button(onClick = onRetry) {
                Text(stringResource(R.string.common_retry))
            }
        },
    )
}

@Composable
private fun CenteredLoading() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun CenteredMessage(
    icon: @Composable () -> Unit,
    title: String,
    message: String? = null,
    action: (@Composable () -> Unit)? = null,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        icon()
        Spacer(Modifier.height(14.dp))
        Text(title, color = ChillColors.TextMain, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        message?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = ChillColors.TextSub, fontSize = 15.sp, lineHeight = 20.sp, textAlign = TextAlign.Center)
        }
        action?.let {
            Spacer(Modifier.height(18.dp))
            it()
        }
    }
}

@Composable
private fun WeeklyTopicHistoryRow(report: WeeklyTopicReport, onClick: () -> Unit) {
    val locale = currentLocale()
    Row(
        modifier = Modifier.fillMaxWidth().background(Color.White).clickable(onClick = onClick).padding(horizontal = 24.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                formatWeeklyTopicLongDate(report.periodEnd, locale),
                color = ChillColors.TextMain,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                stringResource(
                    R.string.weekly_topics_history_summary,
                    report.topics.size,
                    report.sourceNoteCount,
                ),
                color = ChillColors.TextSub,
                fontSize = 15.sp,
            )
        }
        Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null, tint = ChillColors.TextTertiary, modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun WeeklyTopicReportContent(
    report: WeeklyTopicReport,
    onOpenSource: (WeeklyTopicSource) -> Unit,
) {
    var expandedTopicIds by remember(report.id) {
        mutableStateOf(report.topics.firstOrNull()?.let { setOf(it.id) }.orEmpty())
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
    ) {
        item {
            WeeklyTopicReportHeader(report)
        }
        items(report.topics, key = WeeklyTopicItem::id) { topic ->
            val index = report.topics.indexOf(topic)
            WeeklyTopicRow(
                topic = topic,
                index = index,
                isExpanded = topic.id in expandedTopicIds,
                onToggle = {
                    expandedTopicIds = if (topic.id in expandedTopicIds) {
                        expandedTopicIds - topic.id
                    } else {
                        expandedTopicIds + topic.id
                    }
                },
                onOpenSource = onOpenSource,
            )
            if (index < report.topics.lastIndex) HorizontalDivider(Modifier.padding(start = 24.dp))
        }
    }
}

@Composable
private fun WeeklyTopicReportHeader(report: WeeklyTopicReport) {
    val locale = currentLocale()
    Box(Modifier.fillMaxWidth().background(ChillColors.BrandHoneySoft)) {
        Icon(
            Icons.AutoMirrored.Outlined.MenuBook,
            contentDescription = null,
            tint = ChillColors.BrandHoney.copy(alpha = 0.10f),
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 20.dp, bottom = 18.dp).size(76.dp),
        )
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(top = 26.dp, bottom = 32.dp)) {
            Text(
                stringResource(R.string.weekly_topics_report_inspiration_label),
                color = ChillColors.BrandHoneyText,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.background(Color.White.copy(alpha = 0.70f), RoundedCornerShape(9.dp)).padding(horizontal = 10.dp, vertical = 6.dp),
            )
            Spacer(Modifier.height(14.dp))
            Text(
                highlightedReportSummary(report.topics.size, report.sourceNoteCount),
                color = ChillColors.TextMain,
                fontSize = 30.sp,
                lineHeight = 36.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(14.dp))
            Text(
                stringResource(
                    R.string.weekly_topics_report_date_range,
                    formatWeeklyTopicMonthDay(report.periodStart, locale),
                    formatWeeklyTopicMonthDay(report.periodEnd, locale),
                ),
                color = ChillColors.TextSub,
                fontSize = 13.sp,
            )
        }
    }
}

@Composable
private fun highlightedReportSummary(topicCount: Int, sourceCount: Int): AnnotatedString {
    val summary = stringResource(R.string.weekly_topics_report_summary, topicCount, sourceCount)
    return buildAnnotatedString {
        val topicText = topicCount.toString()
        val sourceText = sourceCount.toString()
        var cursor = 0
        listOf(topicText, sourceText).forEach { needle ->
            val index = summary.indexOf(needle, startIndex = cursor)
            if (index >= 0) {
                append(summary.substring(cursor, index))
                withStyle(SpanStyle(color = ChillColors.BrandHoneyText)) { append(needle) }
                cursor = index + needle.length
            }
        }
        append(summary.substring(cursor))
    }
}

@Composable
private fun WeeklyTopicRow(
    topic: WeeklyTopicItem,
    index: Int,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    onOpenSource: (WeeklyTopicSource) -> Unit,
) {
    val expansionHint = stringResource(
        if (isExpanded) R.string.weekly_topics_topic_collapse_hint
        else R.string.weekly_topics_topic_expand_hint,
    )
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle)
                .semantics(mergeDescendants = true) { stateDescription = expansionHint }
                .padding(horizontal = 24.dp, vertical = 22.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                stringResource(R.string.weekly_topics_topic_progress, index + 1),
                color = ChillColors.BrandHoneyText,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.width(40.dp),
            )
            Spacer(Modifier.width(16.dp))
            Text(
                topic.title,
                color = ChillColors.TextMain,
                fontSize = 18.sp,
                lineHeight = 23.sp,
                fontWeight = FontWeight.Normal,
                modifier = Modifier.weight(1f),
            )
            Icon(
                Icons.Outlined.ExpandMore,
                contentDescription = null,
                tint = ChillColors.TextTertiary,
                modifier = Modifier.padding(top = 4.dp).size(16.dp).rotate(if (isExpanded) 180f else 0f),
            )
        }
        AnimatedVisibility(visible = isExpanded) {
            Column(Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, bottom = 20.dp)) {
                Text(
                    stringResource(R.string.weekly_topics_topic_related_sources),
                    color = ChillColors.TextMain,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(8.dp))
                topic.sources.forEachIndexed { sourceIndex, source ->
                    if (sourceIndex > 0) HorizontalDivider(Modifier.padding(start = 54.dp))
                    WeeklyTopicSourceRow(source = source, onOpenSource = onOpenSource)
                }
            }
        }
    }
}

@Composable
private fun WeeklyTopicSourceRow(
    source: WeeklyTopicSource,
    onOpenSource: (WeeklyTopicSource) -> Unit,
) {
    val isDeleted = source.resolvedAvailability == WeeklyTopicSourceAvailability.DELETED
    val openLabel = stringResource(R.string.weekly_topics_source_open)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !isDeleted) { onOpenSource(source) }
            .semantics(mergeDescendants = true) {
                if (!isDeleted) stateDescription = openLabel
            }
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        WeeklyTopicPlatformMark(source)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (isDeleted) {
                Text(
                    stringResource(R.string.weekly_topics_source_deleted),
                    color = ChillColors.TextTertiary,
                    fontSize = 13.sp,
                )
            } else {
                Text(
                    source.noteTitle,
                    color = ChillColors.TextMain,
                    fontSize = 13.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (source.excerpt.isNotBlank()) {
                    Text(
                        source.excerpt,
                        color = ChillColors.TextSub,
                        fontSize = 12.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (source.resolvedAvailability == WeeklyTopicSourceAvailability.TRASHED) {
                    Text(
                        stringResource(R.string.weekly_topics_source_in_trash),
                        color = ChillColors.BrandHoneyText,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
        if (!isDeleted) {
            Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null, tint = ChillColors.TextTertiary, modifier = Modifier.size(12.dp))
        }
    }
}

@Composable
private fun WeeklyTopicPlatformMark(source: WeeklyTopicSource) {
    val isDeleted = source.resolvedAvailability == WeeklyTopicSourceAvailability.DELETED
    val normalized = source.platformName.orEmpty().lowercase(Locale.ROOT)
    Box(
        modifier = Modifier.size(42.dp).background(Color.White, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            isDeleted -> Icon(Icons.Outlined.DeleteForever, contentDescription = null, tint = ChillColors.TextTertiary, modifier = Modifier.size(18.dp))
            "youtube" in normalized -> Icon(painterResource(R.drawable.weekly_youtube_logo), contentDescription = null, tint = Color.Red, modifier = Modifier.size(22.dp))
            "tiktok" in normalized -> Icon(painterResource(R.drawable.weekly_tiktok_logo), contentDescription = null, tint = Color.Black, modifier = Modifier.size(22.dp))
            "instagram" in normalized -> Icon(painterResource(R.drawable.weekly_instagram_logo), contentDescription = null, tint = Color(0xFFD4338C), modifier = Modifier.size(22.dp))
            else -> Icon(Icons.Outlined.Description, contentDescription = null, tint = ChillColors.BrandTeal, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun currentLocale(): Locale {
    return LocalLocale.current.platformLocale
}

internal fun formatWeeklyTopicDate(
    instant: Instant,
    locale: Locale = Locale.getDefault(),
    zoneId: ZoneId = ZoneId.systemDefault(),
): String = DateTimeFormatter
    .ofLocalizedDate(FormatStyle.MEDIUM)
    .withLocale(locale)
    .withZone(zoneId)
    .format(instant)

private fun formatWeeklyTopicLongDate(
    instant: Instant,
    locale: Locale,
    zoneId: ZoneId = ZoneId.systemDefault(),
): String = DateTimeFormatter
    .ofLocalizedDate(FormatStyle.LONG)
    .withLocale(locale)
    .withZone(zoneId)
    .format(instant)

private fun formatWeeklyTopicMonthDay(
    instant: Instant,
    locale: Locale,
    zoneId: ZoneId = ZoneId.systemDefault(),
): String = DateTimeFormatter
    .ofPattern(AndroidDateFormat.getBestDateTimePattern(locale, "MMMd"), locale)
    .withZone(zoneId)
    .format(instant)

private fun failureMessageResource(operation: WeeklyTopicsOperation): Int = when (operation) {
    WeeklyTopicsOperation.LOAD -> R.string.weekly_topics_error_load
    WeeklyTopicsOperation.SAVE_SETTINGS -> R.string.weekly_topics_error_save
    WeeklyTopicsOperation.REGENERATE -> R.string.weekly_topics_error_regenerate
}
