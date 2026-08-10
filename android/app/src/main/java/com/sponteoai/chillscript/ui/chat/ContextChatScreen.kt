package com.sponteoai.chillscript.ui.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.ContextChatUiState
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.ChatMessage
import com.sponteoai.chillscript.ai.ChatRole

@Composable
fun ContextChatScreen(
    state: ContextChatUiState,
    onClose: () -> Unit,
    onClear: () -> Unit,
    onSend: (String) -> Unit,
    onSave: (ChatMessage) -> Unit,
    onDismissError: () -> Unit,
) {
    var input by remember { mutableStateOf("") }
    var contextExpanded by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(
            Modifier.fillMaxWidth().padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onClose) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back)) }
            Text(stringResource(R.string.ai_chat_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            IconButton(onClick = onClear, enabled = state.messages.isNotEmpty()) {
                Icon(Icons.Outlined.Delete, stringResource(R.string.ai_chat_clear))
            }
        }
        Surface(
            modifier = Modifier.fillMaxWidth().clickable { contextExpanded = !contextExpanded },
            color = MaterialTheme.colorScheme.surfaceVariant,
        ) {
            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                Text(pluralStringResource(R.plurals.ai_chat_context_notes, state.contextNotes.size, state.contextNotes.size), fontWeight = FontWeight.SemiBold)
                Text(stringResource(if (contextExpanded) R.string.ai_chat_context_collapse else R.string.ai_chat_context_expand), style = MaterialTheme.typography.bodySmall)
            }
        }
        if (contextExpanded) LazyRow(
            Modifier.fillMaxWidth().padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(state.contextNotes, key = { it.id }) { note ->
                Surface(shape = RoundedCornerShape(12.dp), tonalElevation = 2.dp, modifier = Modifier.width(160.dp).height(105.dp)) {
                    Text(note.previewPlainText.ifBlank { note.content }, modifier = Modifier.padding(10.dp), maxLines = 4, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth()) {
            if (state.messages.isEmpty()) Column(
                Modifier.fillMaxSize().padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(stringResource(R.string.ai_chat_empty_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text(stringResource(R.string.ai_chat_empty_message), style = MaterialTheme.typography.bodyMedium)
            } else LazyColumn(
                Modifier.fillMaxSize().padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(state.messages, key = { it.id }) { message ->
                    ChatBubble(message, state.savedMessageId == message.id, onSave)
                }
                if (state.processing) item {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CircularProgressIndicator(modifier = Modifier.width(22.dp).height(22.dp))
                        Text(stringResource(R.string.ai_chat_thinking))
                    }
                }
            }
        }
        state.errorMessage?.let { error ->
            Row(
                Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.errorContainer).padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.ai_chat_error_format, error), modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer)
                TextButton(onClick = onDismissError) { Text(stringResource(R.string.ai_chat_error_dismiss)) }
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                placeholder = { Text(stringResource(R.string.ai_chat_input_placeholder)) },
                minLines = 1,
                maxLines = 5,
                modifier = Modifier.weight(1f),
            )
            IconButton(
                onClick = { val message = input.trim(); if (message.isNotEmpty()) { onSend(message); input = "" } },
                enabled = input.isNotBlank() && !state.processing,
            ) { Icon(Icons.AutoMirrored.Outlined.Send, stringResource(R.string.ai_chat_send)) }
        }
    }
}

@Composable
private fun ChatBubble(message: ChatMessage, saved: Boolean, onSave: (ChatMessage) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (message.role == ChatRole.USER) Arrangement.End else Arrangement.Start) {
        Column(horizontalAlignment = if (message.role == ChatRole.USER) Alignment.End else Alignment.Start) {
            Text(
                message.content,
                modifier = Modifier
                    .fillMaxWidth(if (message.role == ChatRole.USER) 0.78f else 1f)
                    .background(
                        if (message.role == ChatRole.USER) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                        RoundedCornerShape(16.dp),
                    )
                    .padding(12.dp),
            )
            if (message.role == ChatRole.ASSISTANT) {
                Button(onClick = { onSave(message) }, enabled = !saved, modifier = Modifier.padding(top = 5.dp)) {
                    Text(stringResource(if (saved) R.string.ai_chat_saved else R.string.ai_chat_save_as_note))
                }
            }
        }
    }
}
