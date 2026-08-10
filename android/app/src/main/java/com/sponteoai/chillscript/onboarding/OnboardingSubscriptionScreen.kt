package com.sponteoai.chillscript.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingProduct
import com.sponteoai.chillscript.billing.BillingUiState

@Composable
fun OnboardingSubscriptionScreen(
    billingState: BillingUiState,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onDismiss: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    var page by remember { mutableIntStateOf(0) }
    val yearlyProduct = billingState.products.firstOrNull { it.id.contains("year", true) }
        ?: billingState.products.firstOrNull()
    Column(
        Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            IconButton(onClick = onDismiss) { Icon(Icons.Outlined.Close, stringResource(R.string.common_close)) }
        }
        Column(
            Modifier.weight(1f).padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Outlined.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary)
            if (page == 0) {
                Text(stringResource(R.string.subscription_onboarding_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 28.dp))
                Text(stringResource(R.string.subscription_onboarding_no_payment), color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 22.dp))
            } else if (billingState.loading) {
                CircularProgressIndicator(modifier = Modifier.padding(top = 28.dp))
            } else if (yearlyProduct == null) {
                Text(billingState.error ?: stringResource(R.string.subscription_products_unavailable), textAlign = TextAlign.Center, modifier = Modifier.padding(top = 28.dp))
            } else {
                Text(
                    stringResource(if (yearlyProduct.hasFreeTrial) R.string.subscription_onboarding_trial_title else R.string.subscription_upgrade_title),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 28.dp),
                )
                Text(
                    stringResource(
                        if (yearlyProduct.hasFreeTrial) R.string.subscription_onboarding_annual_price
                        else R.string.subscription_onboarding_annual_price_no_trial,
                        yearlyProduct.formattedPrice,
                    ),
                    modifier = Modifier.padding(top = 10.dp),
                )
                Column(Modifier.fillMaxWidth().padding(top = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("✓ " + stringResource(R.string.subscription_onboarding_feature_video))
                    Text("✓ " + stringResource(R.string.subscription_onboarding_feature_capture))
                    Text("✓ " + stringResource(R.string.subscription_onboarding_feature_skills))
                }
            }
        }
        if (page == 1 && yearlyProduct?.hasFreeTrial == true) {
            Text(stringResource(R.string.subscription_onboarding_no_payment), color = MaterialTheme.colorScheme.primary)
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { if (page == 0) page = 1 else yearlyProduct?.let(onPurchase) },
            enabled = page == 0 || yearlyProduct != null,
            modifier = Modifier.fillMaxWidth().height(54.dp),
        ) {
            Text(stringResource(
                if (page == 0) R.string.common_next
                else if (yearlyProduct?.hasFreeTrial == true) R.string.subscription_onboarding_start_trial
                else R.string.subscription_cta_start_annual,
            ))
        }
        TextButton(onClick = onRestore, enabled = !billingState.restoring) {
            if (billingState.restoring) CircularProgressIndicator() else Text(stringResource(R.string.subscription_restore_purchases))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
            TextButton(onClick = { onOpenUrl("https://www.chillnoteai.com/terms") }) { Text(stringResource(R.string.settings_terms)) }
            TextButton(onClick = { onOpenUrl("https://www.chillnoteai.com/privacy") }) { Text(stringResource(R.string.settings_privacy_policy)) }
        }
    }
}
