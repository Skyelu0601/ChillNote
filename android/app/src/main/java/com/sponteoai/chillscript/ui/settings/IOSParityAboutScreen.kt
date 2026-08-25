package com.sponteoai.chillscript.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Autorenew
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors

/** One-to-one Compose rendering of the current iOS `AboutView`. */
@Composable
fun IOSParityAboutScreen(
    onClose: () -> Unit,
    applyTopInset: Boolean = true,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ChillColors.BackgroundPrimary)
            .then(if (applyTopInset) Modifier.statusBarsPadding() else Modifier),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.settings_about),
                color = ChillColors.TextMain,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
            )
            IconButton(
                onClick = onClose,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .size(44.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.common_close),
                    tint = ChillColors.TextSub.copy(alpha = 0.5f),
                    modifier = Modifier
                        .size(24.dp)
                        .background(ChillColors.TextSub.copy(alpha = 0.10f), CircleShape)
                        .padding(4.dp),
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(top = 12.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(32.dp),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = stringResource(R.string.about_brand),
                    color = ChillColors.TextMain,
                    fontSize = 36.sp,
                    lineHeight = 43.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = stringResource(R.string.about_subtitle),
                    color = ChillColors.TextSub,
                    fontSize = 20.sp,
                    lineHeight = 25.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = stringResource(R.string.about_tagline),
                    color = ChillColors.BrandBlue,
                    fontSize = 17.sp,
                    lineHeight = 23.sp,
                    fontStyle = FontStyle.Italic,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp, start = 16.dp, end = 16.dp),
                )
            }

            AboutMarkdownBody(stringResource(R.string.about_intro))
            AboutDivider()

            AboutCreatorSection(
                number = "01",
                title = stringResource(R.string.about_section_1_title),
                quote = stringResource(R.string.about_section_1_quote),
                bodies = listOf(
                    stringResource(R.string.about_section_1_body_1),
                    stringResource(R.string.about_section_1_body_2),
                    stringResource(R.string.about_section_1_body_3),
                ),
            )
            AboutCreatorSection(
                number = "02",
                title = stringResource(R.string.about_section_2_title),
                quote = stringResource(R.string.about_section_2_quote),
                bodies = listOf(
                    stringResource(R.string.about_section_2_body_1),
                    stringResource(R.string.about_section_2_body_2),
                    stringResource(R.string.about_section_2_body_3),
                ),
            )
            AboutCreatorSection(
                number = "03",
                title = stringResource(R.string.about_section_3_title),
                quote = stringResource(R.string.about_section_3_quote),
                bodies = listOf(
                    stringResource(R.string.about_section_3_body_1),
                    stringResource(R.string.about_section_3_body_2),
                    stringResource(R.string.about_section_3_body_3),
                ),
            )
            AboutCreatorSection(
                number = "04",
                title = stringResource(R.string.about_section_4_title),
                quote = stringResource(R.string.about_section_4_quote),
                bodies = listOf(
                    stringResource(R.string.about_section_4_body_1),
                    stringResource(R.string.about_section_4_body_2),
                    stringResource(R.string.about_section_4_body_3),
                ),
            )

            AboutDivider()
            Column(
                modifier = Modifier.padding(vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Text(
                    text = stringResource(R.string.about_workflow_title),
                    color = ChillColors.TextMain,
                    fontSize = 22.sp,
                    lineHeight = 28.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = stringResource(R.string.about_workflow_subtitle),
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                )
                AboutWorkflowPoint(
                    icon = Icons.Outlined.Download,
                    title = stringResource(R.string.about_workflow_capture_title),
                    body = stringResource(R.string.about_workflow_capture_body),
                )
                AboutWorkflowPoint(
                    icon = Icons.Outlined.AutoAwesome,
                    title = stringResource(R.string.about_workflow_ai_title),
                    body = stringResource(R.string.about_workflow_ai_body),
                )
                AboutWorkflowPoint(
                    icon = Icons.Outlined.Autorenew,
                    title = stringResource(R.string.about_workflow_reuse_title),
                    body = stringResource(R.string.about_workflow_reuse_body),
                )
            }

            AboutDivider()
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp, bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = stringResource(R.string.about_vision_title).uppercase(),
                    color = ChillColors.TextSub,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = stringResource(R.string.about_vision_body),
                    color = ChillColors.TextMain,
                    fontSize = 17.sp,
                    lineHeight = 23.sp,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun AboutCreatorSection(
    number: String,
    title: String,
    quote: String,
    bodies: List<String>,
) {
    Column(
        modifier = Modifier.padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = number,
                color = ChillColors.BrandBlue.copy(alpha = 0.20f),
                fontSize = 40.sp,
                lineHeight = 43.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            Text(
                text = title,
                color = ChillColors.TextMain,
                fontSize = 20.sp,
                lineHeight = 25.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 3.dp),
            )
        }
        Text(
            text = quote,
            color = ChillColors.BrandBlue,
            fontSize = 15.sp,
            lineHeight = 20.sp,
            fontStyle = FontStyle.Italic,
            modifier = Modifier.padding(start = 4.dp, bottom = 4.dp),
        )
        bodies.forEach { body ->
            AboutMarkdownBody(body, modifier = Modifier.padding(bottom = 4.dp))
        }
    }
}

@Composable
private fun AboutMarkdownBody(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = buildAnnotatedString {
            var cursor = 0
            val boldPattern = Regex("\\*\\*([^*]+)\\*\\*")
            boldPattern.findAll(text).forEach { match ->
                append(text.substring(cursor, match.range.first))
                pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                append(match.groupValues[1])
                pop()
                cursor = match.range.last + 1
            }
            append(text.substring(cursor))
        },
        color = ChillColors.TextMain.copy(alpha = 0.90f),
        fontSize = 17.sp,
        lineHeight = 23.sp,
        modifier = modifier,
    )
}

@Composable
private fun AboutWorkflowPoint(
    icon: ImageVector,
    title: String,
    body: String,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = ChillColors.BrandBlue,
            modifier = Modifier.size(24.dp),
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = title,
                color = ChillColors.TextMain,
                fontSize = 17.sp,
                lineHeight = 22.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = body,
                color = ChillColors.TextSub,
                fontSize = 15.sp,
                lineHeight = 20.sp,
            )
        }
    }
}

@Composable
private fun AboutDivider() {
    Spacer(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ChillColors.BorderSubtle),
    )
}
