package com.sponteoai.chillscript.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingReminderStore
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.theme.ChillTypography
import kotlinx.coroutines.delay

@Composable
internal fun BillingIssueReminder(
    userId: String?,
    hasBillingIssue: Boolean,
    hasProAccess: Boolean,
    enabled: Boolean,
    store: BillingReminderStore,
    onFixPayment: () -> Unit,
) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var resumed by remember(lifecycle) {
        mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, _ ->
            resumed = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    var nextReminderAt by remember(userId, hasBillingIssue) {
        mutableStateOf(userId?.let(store::nextReminderAt) ?: 0L)
    }
    var visible by remember(userId) { mutableStateOf(false) }
    val canShow = !userId.isNullOrBlank() && hasBillingIssue && enabled && resumed
    LaunchedEffect(canShow, userId, nextReminderAt) {
        visible = false
        if (canShow) {
            delay((nextReminderAt - System.currentTimeMillis()).coerceAtLeast(0L))
            visible = true
        }
    }
    if (visible && canShow) {
        val snooze = {
            userId?.let { nextReminderAt = store.snooze(it) }
            visible = false
        }
        BillingIssueSheet(
            hasProAccess = hasProAccess,
            onDismiss = snooze,
            onFixPayment = {
                // Opening Google Play is not confirmation that the payment succeeded.
                snooze()
                onFixPayment()
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BillingIssueSheet(
    hasProAccess: Boolean,
    onDismiss: () -> Unit,
    onFixPayment: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        containerColor = ChillColors.CardBackground,
        scrimColor = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.46f),
        dragHandle = {
            Box(
                Modifier.padding(top = 14.dp, bottom = 28.dp)
                    .size(width = 44.dp, height = 4.dp)
                    .background(ChillColors.BorderSubtle, RoundedCornerShape(2.dp)),
            )
        },
    ) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 28.dp),
        ) {
            Box(
                Modifier.size(64.dp).background(ChillColors.BrandHoneySoft, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Outlined.CreditCard, contentDescription = null,
                    tint = ChillColors.BrandHoney, modifier = Modifier.size(36.dp),
                )
            }
            Spacer(Modifier.height(24.dp))
            Text(
                stringResource(if (hasProAccess) R.string.subscription_billing_issue_title else R.string.subscription_billing_issue_paused_title),
                style = ChillTypography.headlineLarge,
                color = ChillColors.TextMain,
                modifier = Modifier.semantics { heading() },
            )
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(if (hasProAccess) R.string.subscription_billing_issue_message else R.string.subscription_billing_issue_paused_message),
                style = ChillTypography.bodyLarge,
                color = ChillColors.TextSub,
            )
            Spacer(Modifier.height(36.dp))
            Button(
                onClick = onFixPayment,
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = ChillColors.BrandBlue),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
            ) {
                Text(stringResource(R.string.subscription_billing_issue_action), style = ChillTypography.labelLarge)
            }
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) {
                Text(
                    stringResource(R.string.subscription_billing_issue_later),
                    style = ChillTypography.labelLarge, color = ChillColors.TextSub,
                )
            }
            Spacer(Modifier.height(28.dp))
        }
    }
}
