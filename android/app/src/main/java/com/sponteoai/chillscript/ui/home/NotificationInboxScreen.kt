package com.sponteoai.chillscript.ui.home

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.CardGiftcard
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.data.remote.InboxNotification
import com.sponteoai.chillscript.ui.theme.ChillColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@Composable
fun NotificationInboxScreen(
    notifications: List<InboxNotification>,
    loading: Boolean,
    failed: Boolean,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onRead: (String) -> Unit,
) {
    BackHandler(onBack = onBack)
    LaunchedEffect(Unit) { onRefresh() }
    Column(Modifier.fillMaxSize().background(ChillColors.BackgroundPrimary).statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.common_back), tint = ChillColors.TextMain)
            }
            Text(stringResource(R.string.notifications_title), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ChillColors.TextMain)
        }
        LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (loading && notifications.isEmpty()) item { Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
            if (failed) item {
                Column {
                    Text(stringResource(R.string.notifications_error), color = ChillColors.TextSub)
                    TextButton(onClick = onRefresh) { Text(stringResource(R.string.notifications_retry)) }
                }
            }
            if (!loading && !failed && notifications.isEmpty()) item {
                Text(stringResource(R.string.notifications_empty), color = ChillColors.TextSub, modifier = Modifier.padding(top = 32.dp))
            }
            items(notifications, key = { it.id }) { notification ->
                LaunchedEffect(notification.id, loading) { if (!loading) onRead(notification.id) }
                Row(
                    Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(20.dp)).padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.size(48.dp).background(ChillColors.BackgroundPrimary, CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.CardGiftcard, null, tint = ChillColors.TextMain, modifier = Modifier.size(26.dp))
                        if (notification.readAt == null) {
                            Box(Modifier.align(Alignment.TopStart).size(7.dp).background(ChillColors.BrandBlue, CircleShape))
                        }
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            if (notification.kind == "welcome_credits") stringResource(R.string.notifications_credits_title, notification.amount ?: 0)
                            else stringResource(R.string.notifications_pro_title),
                            color = ChillColors.TextMain, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                        )
                        Text(stringResource(if (notification.kind == "welcome_credits") R.string.notifications_credits_body else R.string.notifications_pro_body),
                            color = ChillColors.TextSub, fontSize = 15.sp)
                        val date = remember(notification.createdAt) {
                            runCatching { DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).format(Instant.parse(notification.createdAt).atZone(ZoneId.systemDefault())) }.getOrNull()
                        }
                        if (date != null) Text(date, color = ChillColors.TextSub, fontSize = 12.sp)
                    }
                }
            }
        }
        Text(stringResource(R.string.notifications_footer), fontSize = 13.sp, color = ChillColors.TextSub,
            modifier = Modifier.align(Alignment.CenterHorizontally).padding(24.dp))
    }
}
