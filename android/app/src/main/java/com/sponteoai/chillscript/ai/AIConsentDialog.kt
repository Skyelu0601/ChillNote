package com.sponteoai.chillscript.ai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors

/** One-to-one presentation of iOS `AIConsentSheet`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIConsentDialog(
    prompt: AIConsentPrompt,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onOpenPrivacyPolicy: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDecline,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.Transparent,
        contentColor = ChillColors.TextMain,
        dragHandle = { BottomSheetDefaults.DragHandle(color = ChillColors.TextTertiary) },
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .navigationBarsPadding()
                .clip(RoundedCornerShape(24.dp))
                .background(Color.White.copy(alpha = 0.96f))
                .padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = stringResource(R.string.ai_consent_title),
                    color = ChillColors.TextMain,
                    fontSize = 17.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = stringResource(
                        if (prompt.trigger == AIConsentTrigger.Audio) R.string.ai_consent_audio_summary
                        else R.string.ai_consent_text_summary,
                    ),
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = stringResource(R.string.ai_consent_data_usage),
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                )
                Text(
                    text = stringResource(R.string.ai_consent_raw_audio),
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = stringResource(R.string.ai_consent_not_now),
                    color = ChillColors.TextMain,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(16.dp))
                        .background(ChillColors.BackgroundSecondary)
                        .border(1.dp, Color.Black.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
                        .clickable(role = Role.Button, onClick = onDecline)
                        .padding(vertical = 13.dp),
                )
                Text(
                    text = stringResource(R.string.ai_consent_agree),
                    color = Color.White,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            Brush.horizontalGradient(
                                listOf(ChillColors.BrandBlue, ChillColors.BrandBlue.copy(alpha = 0.88f)),
                            ),
                        )
                        .clickable(role = Role.Button, onClick = onAccept)
                        .padding(vertical = 13.dp),
                )
            }

            Text(
                text = stringResource(R.string.ai_consent_privacy_policy),
                color = ChillColors.BrandBlueText,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                textDecoration = TextDecoration.Underline,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(role = Role.Button, onClick = onOpenPrivacyPolicy)
                    .padding(vertical = 2.dp),
            )
        }
    }
}
