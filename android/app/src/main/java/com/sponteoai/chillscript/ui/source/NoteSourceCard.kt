package com.sponteoai.chillscript.ui.source

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.domain.NoteSourceMetadata

@Composable
fun NoteSourceCard(source: NoteSourceMetadata, compact: Boolean = false, onOpen: () -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .clickable(onClick = onOpen)
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(14.dp))
            .padding(horizontal = if (compact) 10.dp else 12.dp, vertical = if (compact) 9.dp else 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(if (compact) 30.dp else 34.dp).background(platformColor(source.platformId), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(platformInitials(source.platformId), color = Color.White, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
        }
        Column(Modifier.padding(start = 10.dp).weight(1f)) {
            Text(source.platformName, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            Text(source.title, style = if (compact) MaterialTheme.typography.bodySmall else MaterialTheme.typography.bodyMedium, maxLines = if (compact) 1 else 2, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.size(8.dp))
        Icon(Icons.AutoMirrored.Outlined.OpenInNew, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun platformInitials(id: String): String = when (id) {
    "xiaohongshu" -> "小红书"; "youtube" -> "YT"; "tiktok" -> "TT"; "instagram" -> "IG"
    "threads" -> "TH"; "reddit" -> "RD"; "pinterest" -> "PI"; "linkedin" -> "IN"
    "facebook" -> "FB"; "vimeo" -> "VI"; "twitch" -> "TW"; "product_hunt" -> "PH"
    "hacker_news" -> "HN"; "bilibili" -> "B"; "x" -> "X"; else -> "↗"
}

private fun platformColor(id: String): Color = when (id) {
    "xiaohongshu" -> Color(0xFFF52E40); "youtube" -> Color(0xFFFF0000); "tiktok" -> Color(0xFF0D0F14)
    "instagram" -> Color(0xFFD13F8C); "threads", "x" -> Color(0xFF141417); "reddit" -> Color(0xFFFF4500)
    "pinterest" -> Color(0xFFE60023); "linkedin" -> Color(0xFF0077B5); "facebook" -> Color(0xFF1877F2)
    "vimeo" -> Color(0xFF1AB7EA); "twitch" -> Color(0xFF6441A5); "product_hunt" -> Color(0xFFDA552F)
    "hacker_news" -> Color(0xFFFF6600); "bilibili" -> Color(0xFF00A1D6); "spotify" -> Color(0xFF1DB954)
    else -> Color(0xFF5EAFA5)
}
