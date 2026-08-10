package com.sponteoai.chillscript.ai

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.R

@Composable
fun AIConsentDialog(
    prompt: AIConsentPrompt,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onOpenPrivacyPolicy: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDecline,
        title = { Text(stringResource(R.string.ai_consent_title)) },
        text = {
            Column {
                Text(stringResource(if (prompt.trigger == AIConsentTrigger.Audio) R.string.ai_consent_audio_summary else R.string.ai_consent_text_summary))
                Text(stringResource(R.string.ai_consent_data_usage), modifier = Modifier.padding(top = 16.dp))
                Text(stringResource(R.string.ai_consent_raw_audio), modifier = Modifier.padding(top = 10.dp))
                TextButton(onClick = onOpenPrivacyPolicy, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                    Text(stringResource(R.string.ai_consent_privacy_policy))
                }
            }
        },
        confirmButton = { Button(onClick = onAccept) { Text(stringResource(R.string.ai_consent_agree)) } },
        dismissButton = { TextButton(onClick = onDecline) { Text(stringResource(R.string.ai_consent_not_now)) } },
    )
}
