package com.sponteoai.chillscript.ui.subscription

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.filled.AddBox
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingProduct
import com.sponteoai.chillscript.billing.BillingUiState
import com.sponteoai.chillscript.ui.theme.BrandBackground
import com.sponteoai.chillscript.ui.theme.ChillColors
import com.sponteoai.chillscript.ui.theme.ChillRadius
import com.sponteoai.chillscript.ui.theme.ChillSizes
import com.sponteoai.chillscript.ui.theme.ChillSpacing
import com.sponteoai.chillscript.ui.theme.ChillTypography
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.launch

private const val TermsUrl = "https://www.chillnoteai.com/terms"
private const val PrivacyUrl = "https://www.chillnoteai.com/privacy"

private val IOSGreen = Color(0xFF34C759)
private val IOSTeal = Color(0xFF30B0C7)
private val IOSOrange = Color(0xFFFF9500)
private val IOSChatPurple = Color(0xFF6E70C7)

enum class SubscriptionScreenContext {
    Standard,
    OnboardingTrial,
}

data class SubscriptionDebugPreviewPricing(
    val annualPrice: String,
    val annualWeeklyPrice: String,
    val weeklyPrice: String,
    val annualTrialDayCount: Int,
)

/**
 * One-to-one Compose port of iOS `SubscriptionView`.
 *
 * The host owns billing and membership state. This composable deliberately
 * owns only the same presentation state as SwiftUI: yearly/weekly selection
 * and entrance animation.
 */
@Composable
fun IOSParitySubscriptionScreen(
    context: SubscriptionScreenContext = SubscriptionScreenContext.Standard,
    isPro: Boolean,
    subscriptionExpiresAt: String?,
    activeProductId: String? = null,
    billingState: BillingUiState,
    isPurchasing: Boolean = false,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onRetryProducts: () -> Unit,
    onDismiss: () -> Unit,
    onManage: () -> Unit = {},
    onOpenUrl: (String) -> Unit,
    debugPreviewPricing: SubscriptionDebugPreviewPricing? = null,
    applyTopInset: Boolean = true,
    modifier: Modifier = Modifier,
) {
    var showContent by remember { mutableStateOf(false) }
    var showOnboardingPaywallDetails by rememberSaveable { mutableStateOf(false) }
    val revealProgress by animateFloatAsState(
        targetValue = if (showContent) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = 100f),
        label = "subscription content entrance",
    )

    LaunchedEffect(Unit) { showContent = true }
    BackHandler(onBack = onDismiss)

    val isOnboardingPaywall = context == SubscriptionScreenContext.OnboardingTrial
    val screenContent: @Composable () -> Unit = {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .then(if (applyTopInset) Modifier.statusBarsPadding() else Modifier),
        ) {
            if (isOnboardingPaywall) {
                SubscriptionTopBar(onDismiss = onDismiss)
            } else {
                SubscriptionTopBar(onDismiss = onDismiss)
            }

            Box(modifier = Modifier.weight(1f)) {
                when {
                    isPro -> MemberSubscriptionContent(
                        subscriptionExpiresAt = subscriptionExpiresAt,
                        activeProductId = activeProductId,
                        billingError = billingState.error,
                        onManage = onManage,
                        onRestore = onRestore,
                    )
                    context == SubscriptionScreenContext.OnboardingTrial -> {
                        if (showOnboardingPaywallDetails) {
                            LegacyOnboardingTrialPriceContent(
                                billingState = billingState,
                                isPurchasing = isPurchasing,
                                revealProgress = revealProgress,
                                onPurchase = onPurchase,
                                onRestore = onRestore,
                                onRetryProducts = onRetryProducts,
                                onOpenUrl = onOpenUrl,
                                debugPreviewPricing = debugPreviewPricing,
                            )
                        } else {
                            OnboardingTrialIntroContent(
                                restoreEnabled = !billingState.restoring,
                                revealProgress = revealProgress,
                                onContinue = { showOnboardingPaywallDetails = true },
                                onRestore = onRestore,
                                onOpenUrl = onOpenUrl,
                            )
                        }
                    }
                    else -> StandardUpgradeContent(
                        billingState = billingState,
                        isPurchasing = isPurchasing,
                        revealProgress = revealProgress,
                        onPurchase = onPurchase,
                        onRestore = onRestore,
                        onRetryProducts = onRetryProducts,
                        onOpenUrl = onOpenUrl,
                    )
                }
            }
        }
    }

    BrandBackground(modifier = modifier.fillMaxSize()) {
        screenContent()

        if (isPurchasing || billingState.restoring) {
            SubscriptionLoadingOverlay()
        }
    }
}

@Composable
private fun OnboardingSubscriptionTopBar(
    restoreEnabled: Boolean,
    onDismiss: () -> Unit,
    onRestore: () -> Unit,
) {
    val closeLabel = stringResource(R.string.common_close)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = 8.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .size(44.dp)
                .clip(CircleShape)
                .clickable(role = Role.Button, onClick = onDismiss)
                .semantics { contentDescription = closeLabel },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = null,
                tint = ChillColors.TextMain,
                modifier = Modifier.size(23.dp),
            )
        }

        Text(
            text = stringResource(R.string.subscription_restore_purchases),
            color = ChillColors.TextMain.copy(alpha = if (restoreEnabled) 1f else 0.5f),
            fontSize = 16.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.Normal,
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .clickable(
                    enabled = restoreEnabled,
                    role = Role.Button,
                    onClick = onRestore,
                )
                .padding(horizontal = 8.dp, vertical = 10.dp),
        )
    }
}

@Composable
private fun SubscriptionTopBar(onDismiss: () -> Unit) {
    val closeLabel = stringResource(R.string.common_close)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .padding(end = 16.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .size(32.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.05f))
                .clickable(role = Role.Button, onClick = onDismiss)
                .semantics { contentDescription = closeLabel },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = null,
                tint = ChillColors.TextMain.copy(alpha = 0.5f),
                modifier = Modifier.size(14.dp),
            )
        }
    }
}

@Composable
private fun OnboardingTrialIntroContent(
    restoreEnabled: Boolean,
    revealProgress: Float,
    onContinue: () -> Unit,
    onRestore: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .reveal(revealProgress, 18.dp),
    ) {
        OnboardingTrialIntroPage(
            hasFreeTrial = true,
            modifier = Modifier.weight(1f),
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0f),
                            Color.White,
                            Color.White,
                        ),
                    ),
                )
                .padding(horizontal = ChillSpacing.S4)
                .padding(bottom = 18.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            PrimarySubscriptionButton(
                text = stringResource(R.string.subscription_onboarding_cta_next),
                enabled = true,
                showChevron = true,
                onClick = onContinue,
            )

            OnboardingIntroLegalFooter(
                restoreEnabled = restoreEnabled,
                onRestore = onRestore,
                onOpenUrl = onOpenUrl,
            )
        }
    }
}

@Composable
private fun LegacyOnboardingTrialPriceContent(
    billingState: BillingUiState,
    isPurchasing: Boolean,
    revealProgress: Float,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onRetryProducts: () -> Unit,
    onOpenUrl: (String) -> Unit,
    debugPreviewPricing: SubscriptionDebugPreviewPricing?,
) {
    val yearlyProduct = remember(billingState.products) {
        billingState.products.firstOrNull { it.googlePlaySubscriptionFacts().isAnnual }
            ?: billingState.products.firstOrNull { it.id.contains("year", ignoreCase = true) }
    }
    val displayInfo = yearlyProduct?.let { rememberGooglePlaySubscriptionDisplayInfo(it) }
    val restoreError = billingState.error.takeIf { billingState.products.isNotEmpty() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .reveal(revealProgress, 18.dp),
    ) {
        OnboardingTrialPricePage(
            yearlyProduct = yearlyProduct,
            displayInfo = displayInfo,
            billingState = billingState,
            onRetryProducts = onRetryProducts,
            debugPreviewPricing = debugPreviewPricing,
            modifier = Modifier.weight(1f),
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0f),
                            Color.White,
                            Color.White,
                        ),
                    ),
                )
                .padding(horizontal = ChillSpacing.S4)
                .padding(bottom = 18.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            restoreError?.let { InlineBillingError(it) }

            if (displayInfo?.hasFreeTrial == true || debugPreviewPricing != null) {
                NoPaymentDueNow()
            }

            PrimarySubscriptionButton(
                text = displayInfo?.ctaText
                    ?: stringResource(R.string.subscription_onboarding_start_trial),
                enabled = (yearlyProduct != null || debugPreviewPricing != null) && !isPurchasing,
                showChevron = true,
                onClick = { yearlyProduct?.let(onPurchase) },
            )

            OnboardingIntroLegalFooter(
                restoreEnabled = !billingState.restoring,
                onRestore = onRestore,
                onOpenUrl = onOpenUrl,
            )
        }
    }
}

@Composable
private fun OnboardingTrialContent(
    billingState: BillingUiState,
    isPurchasing: Boolean,
    revealProgress: Float,
    onPurchase: (BillingProduct) -> Unit,
    onRetryProducts: () -> Unit,
    onOpenUrl: (String) -> Unit,
    debugPreviewPricing: SubscriptionDebugPreviewPricing?,
) {
    var isAnnual by rememberSaveable { mutableStateOf(true) }
    val yearlyProduct = remember(billingState.products) {
        billingState.products.firstOrNull { it.googlePlaySubscriptionFacts().isAnnual }
            ?: billingState.products.firstOrNull { it.id.contains("year", ignoreCase = true) }
    }
    val weeklyProduct = remember(billingState.products) {
        billingState.products.firstOrNull { it.googlePlaySubscriptionFacts().isWeekly }
            ?: billingState.products.firstOrNull { it.id.contains("week", ignoreCase = true) }
    }
    val selectedProduct = if (isAnnual) yearlyProduct ?: weeklyProduct else weeklyProduct ?: yearlyProduct
    val selectedDisplayInfo = selectedProduct?.let { rememberGooglePlaySubscriptionDisplayInfo(it) }
    val yearlyDisplayInfo = yearlyProduct?.let { rememberGooglePlaySubscriptionDisplayInfo(it) }
    val weeklyDisplayInfo = weeklyProduct?.let { rememberGooglePlaySubscriptionDisplayInfo(it) }
    val restoreError = billingState.error.takeIf { billingState.products.isNotEmpty() }
    val effectiveTrialDayCount = selectedDisplayInfo?.trialDayCount
        ?: debugPreviewPricing?.annualTrialDayCount?.takeIf { isAnnual }
    val hasSelectedPlan = selectedProduct != null || debugPreviewPricing != null

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp, bottom = 20.dp)
            .navigationBarsPadding()
            .reveal(revealProgress, 18.dp),
        horizontalAlignment = Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text(
            text = stringResource(R.string.subscription_onboarding_paywall_title),
            color = ChillColors.TextMain,
            fontSize = 38.sp,
            lineHeight = 41.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Start,
            modifier = Modifier.fillMaxWidth(),
        )

        OnboardingTrialFeatureList()

        if (debugPreviewPricing != null) {
            OnboardingDebugPlanPicker(
                isAnnual = isAnnual,
                pricing = debugPreviewPricing,
                onAnnualChange = { isAnnual = it },
            )
        } else if (yearlyProduct != null || weeklyProduct != null) {
            OnboardingPlanPicker(
                isAnnual = isAnnual,
                yearlyProduct = yearlyProduct,
                weeklyProduct = weeklyProduct,
                yearlyDisplayInfo = yearlyDisplayInfo,
                weeklyDisplayInfo = weeklyDisplayInfo,
                onAnnualChange = { isAnnual = it },
            )
        } else {
            PaywallProductState(
                loading = billingState.loading,
                error = billingState.error,
                onRetryProducts = onRetryProducts,
                compact = false,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        restoreError?.let { InlineBillingError(it) }

        OnboardingPurchaseButton(
            text = when {
                effectiveTrialDayCount != null -> pluralStringResource(
                    R.plurals.subscription_onboarding_cta_try_free_days,
                    effectiveTrialDayCount,
                    effectiveTrialDayCount,
                )
                selectedDisplayInfo?.isAnnual == true ||
                    (selectedDisplayInfo == null && debugPreviewPricing != null && isAnnual) -> stringResource(
                    R.string.subscription_cta_continue_annual,
                )
                else -> stringResource(R.string.subscription_cta_continue_weekly)
            },
            enabled = hasSelectedPlan && !isPurchasing,
            onClick = { selectedProduct?.let(onPurchase) },
        )

        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = stringResource(
                    if (selectedDisplayInfo?.hasFreeTrial == true || effectiveTrialDayCount != null) {
                        R.string.subscription_onboarding_trust_no_payment_cancel_anytime
                    } else {
                        R.string.subscription_onboarding_trust_cancel_anytime
                    },
                ),
                color = ChillColors.TextMain.copy(alpha = 0.82f),
                fontSize = 14.sp,
                lineHeight = 19.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )

            OnboardingLegalFooter(onOpenUrl = onOpenUrl)
        }
    }
}

@Composable
private fun OnboardingDebugPlanPicker(
    isAnnual: Boolean,
    pricing: SubscriptionDebugPreviewPricing,
    onAnnualChange: (Boolean) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        OnboardingPlanCard(
            title = pluralStringResource(
                R.plurals.subscription_onboarding_plan_annual_trial_days,
                pricing.annualTrialDayCount,
                pricing.annualTrialDayCount,
            ),
            billingText = stringResource(
                R.string.subscription_price_per_year_format,
                pricing.annualPrice,
            ),
            comparisonPrice = pricing.annualWeeklyPrice,
            comparisonPeriod = stringResource(R.string.subscription_billing_period_weekly),
            selected = isAnnual,
            onClick = { onAnnualChange(true) },
        )
        OnboardingPlanCard(
            title = stringResource(R.string.subscription_interval_weekly),
            billingText = null,
            comparisonPrice = pricing.weeklyPrice,
            comparisonPeriod = stringResource(R.string.subscription_billing_period_weekly),
            selected = !isAnnual,
            onClick = { onAnnualChange(false) },
        )
    }
}

@Composable
private fun OnboardingPlanPicker(
    isAnnual: Boolean,
    yearlyProduct: BillingProduct?,
    weeklyProduct: BillingProduct?,
    yearlyDisplayInfo: GooglePlaySubscriptionDisplayInfo?,
    weeklyDisplayInfo: GooglePlaySubscriptionDisplayInfo?,
    onAnnualChange: (Boolean) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (yearlyProduct != null && yearlyDisplayInfo != null) {
            OnboardingPlanCard(
                title = yearlyDisplayInfo.trialDayCount?.let {
                    pluralStringResource(R.plurals.subscription_onboarding_plan_annual_trial_days, it, it)
                } ?: stringResource(R.string.subscription_interval_yearly),
                billingText = stringResource(
                    R.string.subscription_price_per_year_format,
                    yearlyDisplayInfo.displayPrice,
                ),
                comparisonPrice = yearlyDisplayInfo.equivalentWeeklyText
                    ?: yearlyDisplayInfo.displayPrice,
                comparisonPeriod = stringResource(R.string.subscription_billing_period_weekly),
                selected = isAnnual || weeklyProduct == null,
                onClick = { onAnnualChange(true) },
            )
        }

        if (weeklyProduct != null && weeklyDisplayInfo != null) {
            OnboardingPlanCard(
                title = stringResource(R.string.subscription_interval_weekly),
                billingText = null,
                comparisonPrice = weeklyDisplayInfo.displayPrice,
                comparisonPeriod = stringResource(R.string.subscription_billing_period_weekly),
                selected = !isAnnual || yearlyProduct == null,
                onClick = { onAnnualChange(false) },
            )
        }
    }
}

@Composable
private fun OnboardingPlanCard(
    title: String,
    billingText: String?,
    comparisonPrice: String,
    comparisonPeriod: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 86.dp)
            .clip(shape)
            .background(if (selected) ChillColors.BrandBlue.copy(alpha = 0.035f) else Color.White)
            .border(
                width = 1.5.dp,
                color = if (selected) ChillColors.BrandBlue else ChillColors.BorderSubtle,
                shape = shape,
            )
            .clickable(role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(if (selected) ChillColors.BrandBlue else Color.White)
                .border(
                    width = 1.5.dp,
                    color = if (selected) ChillColors.BrandBlue else ChillColors.BorderSubtle,
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = title,
                color = if (selected) ChillColors.BrandBlueText else ChillColors.TextMain,
                fontSize = 15.sp,
                lineHeight = 19.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            billingText?.let {
                Text(
                    text = it,
                    color = ChillColors.TextMain,
                    fontSize = 15.sp,
                    lineHeight = 19.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = comparisonPrice,
                color = ChillColors.TextMain,
                fontSize = 19.sp,
                lineHeight = 23.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = comparisonPeriod,
                color = ChillColors.TextMain.copy(alpha = 0.82f),
                fontSize = 14.sp,
                lineHeight = 18.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun OnboardingPurchaseButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(ChillColors.BrandBlue.copy(alpha = if (enabled) 1f else 0.5f))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = Color.White,
            fontSize = 17.sp,
            lineHeight = 21.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 16.dp),
        )
    }
}

@Composable
private fun OnboardingTrialIntroPage(
    hasFreeTrial: Boolean,
    modifier: Modifier = Modifier,
) {
    val title = if (hasFreeTrial) {
        stringResource(R.string.subscription_onboarding_title)
    } else {
        stringResource(R.string.subscription_upgrade_title)
    }
    val styledTitle = buildAnnotatedString {
        val brandStart = title.indexOf("ChillScript")
        if (brandStart < 0) {
            append(title)
        } else {
            append(title.substring(0, brandStart))
            withStyle(SpanStyle(color = ChillColors.BrandBlue)) {
                append("ChillScript")
            }
            append(title.substring(brandStart + "ChillScript".length))
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp)
            .padding(top = 50.dp, bottom = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        Text(
            text = styledTitle,
            color = ChillColors.TextMain,
            style = ChillTypography.displayLarge.copy(lineHeight = 44.sp),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 4.dp),
        )

        Spacer(
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 10.dp),
        )
        OnboardingTrialLogo(size = 148.dp)
        Spacer(
            modifier = Modifier
                .weight(1f)
                .heightIn(min = 18.dp),
        )
        if (hasFreeTrial) {
            NoPaymentDueNow()
        }
        Spacer(
            modifier = Modifier
                .weight(0.5f)
                .heightIn(min = 22.dp),
        )
    }
}

@Composable
private fun OnboardingTrialPricePage(
    yearlyProduct: BillingProduct?,
    displayInfo: GooglePlaySubscriptionDisplayInfo?,
    billingState: BillingUiState,
    onRetryProducts: () -> Unit,
    debugPreviewPricing: SubscriptionDebugPreviewPricing? = null,
    modifier: Modifier = Modifier,
) {
    if ((yearlyProduct != null && displayInfo != null) || debugPreviewPricing != null) {
        val hasFreeTrial = displayInfo?.hasFreeTrial == true || debugPreviewPricing != null
        val annualPrice = displayInfo?.displayPrice ?: debugPreviewPricing?.annualPrice.orEmpty()
        val weeklyPrice = displayInfo?.equivalentWeeklyText ?: debugPreviewPricing?.annualWeeklyPrice
        val trialTitle = displayInfo?.trialDurationText?.let {
            stringResource(R.string.subscription_onboarding_trial_title_format, it)
        } ?: debugPreviewPricing?.let {
            pluralStringResource(
                R.plurals.subscription_onboarding_cta_try_free_days,
                it.annualTrialDayCount,
                it.annualTrialDayCount,
            )
        } ?: stringResource(R.string.subscription_plan_annual)

        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(horizontal = 28.dp)
                .padding(top = 30.dp, bottom = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            OnboardingTrialLogo(size = 112.dp)

            Column(
                modifier = Modifier.padding(top = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = trialTitle,
                    color = ChillColors.TextMain,
                    style = ChillTypography.headlineLarge,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    if (hasFreeTrial) {
                        weeklyPrice?.let {
                            Text(
                                text = stringResource(
                                    R.string.subscription_onboarding_weekly_price_after_trial_format,
                                    it,
                                ),
                                color = ChillColors.TextMain,
                                style = ChillTypography.headlineMedium,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }

                    Text(
                        text = stringResource(
                            if (hasFreeTrial) {
                                R.string.subscription_onboarding_annual_price
                            } else {
                                R.string.subscription_onboarding_annual_price_no_trial
                            },
                            annualPrice,
                        ),
                        color = ChillColors.TextMain.copy(alpha = 0.78f),
                        style = ChillTypography.bodyLarge,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            OnboardingTrialFeatureList(
                modifier = Modifier.padding(top = 34.dp),
            )
        }
    } else {
        PaywallProductState(
            loading = billingState.loading,
            error = billingState.error,
            onRetryProducts = onRetryProducts,
            modifier = modifier.fillMaxSize(),
            compact = false,
        )
    }
}

@Composable
private fun OnboardingTrialLogo(size: androidx.compose.ui.unit.Dp) {
    Box(
        modifier = Modifier.requiredSize(size * 1.32f),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(size * 1.28f)
                .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.07f), CircleShape),
        )
        Box(
            modifier = Modifier
                .size(size * 1.02f)
                .border(1.dp, ChillColors.BrandBlue.copy(alpha = 0.10f), CircleShape),
        )
        Box(
            modifier = Modifier
                .size(size * 0.74f)
                .blur(size * 0.10f)
                .background(ChillColors.BrandBlue.copy(alpha = 0.12f), CircleShape),
        )
        LightningBallIcon(
            size = size,
            modifier = Modifier.shadow(
                elevation = 18.dp,
                shape = CircleShape,
                ambientColor = ChillColors.BrandBlue.copy(alpha = 0.18f),
                spotColor = ChillColors.BrandBlue.copy(alpha = 0.18f),
            ),
        )
    }
}

@Composable
private fun LightningBallIcon(
    size: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(size)
            .shadow(
                elevation = 5.dp,
                shape = CircleShape,
                ambientColor = ChillColors.Shadow,
                spotColor = ChillColors.Shadow,
            )
            .clip(CircleShape)
            .background(ChillColors.BackgroundSecondary)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        ChillColors.BrandBlue.copy(alpha = 0.10f),
                        Color.White.copy(alpha = 0.02f),
                    ),
                ),
            )
            .border(1.dp, ChillColors.BorderSubtle, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Filled.Bolt,
            contentDescription = null,
            tint = ChillColors.BrandBlue,
            modifier = Modifier
                .size(size * 0.44f)
                .graphicsLayer { rotationZ = 4f },
        )
    }
}

@Composable
private fun NoPaymentDueNow() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Filled.Check,
            contentDescription = null,
            tint = IOSGreen,
            modifier = Modifier.size(23.dp),
        )
        Spacer(Modifier.width(12.dp))
        Text(
            text = stringResource(R.string.subscription_onboarding_no_payment),
            color = ChillColors.TextMain,
            style = ChillTypography.headlineMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun OnboardingTrialFeatureList(modifier: Modifier = Modifier) {
    val features = listOf(
        stringResource(R.string.subscription_onboarding_feature_video),
        stringResource(R.string.subscription_onboarding_feature_generate_content),
        stringResource(R.string.subscription_onboarding_feature_rewrite_translate),
    )
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(ChillRadius.Card),
                ambientColor = ChillColors.Shadow,
                spotColor = ChillColors.Shadow,
            )
            .clip(RoundedCornerShape(ChillRadius.Card))
            .background(Color.White.copy(alpha = 0.92f))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        features.forEach { feature ->
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = ChillColors.BrandTealText,
                    modifier = Modifier
                        .padding(top = 1.dp)
                        .size(17.dp),
                )
                Text(
                    text = feature,
                    color = ChillColors.TextMain,
                    style = ChillTypography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun OnboardingLegalFooter(
    onOpenUrl: (String) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(30.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OnboardingLegalLink(
            text = stringResource(R.string.subscription_terms_of_use),
            onClick = { onOpenUrl(TermsUrl) },
        )
        OnboardingLegalLink(
            text = stringResource(R.string.subscription_privacy_policy),
            onClick = { onOpenUrl(PrivacyUrl) },
        )
    }
}

@Composable
private fun OnboardingIntroLegalFooter(
    restoreEnabled: Boolean,
    onRestore: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FooterLink(
            text = stringResource(R.string.subscription_terms_of_use),
            onClick = { onOpenUrl(TermsUrl) },
        )
        FooterLink(
            text = stringResource(R.string.subscription_restore_purchases),
            enabled = restoreEnabled,
            onClick = onRestore,
        )
        FooterLink(
            text = stringResource(R.string.subscription_privacy_policy),
            onClick = { onOpenUrl(PrivacyUrl) },
        )
    }
}

@Composable
private fun OnboardingLegalLink(
    text: String,
    onClick: () -> Unit,
) {
    Text(
        text = text,
        color = ChillColors.TextMain.copy(alpha = 0.86f),
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Normal,
        textDecoration = TextDecoration.Underline,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.clickable(role = Role.Button, onClick = onClick),
    )
}

@Composable
private fun StandardUpgradeContent(
    billingState: BillingUiState,
    isPurchasing: Boolean,
    revealProgress: Float,
    onPurchase: (BillingProduct) -> Unit,
    onRestore: () -> Unit,
    onRetryProducts: () -> Unit,
    onOpenUrl: (String) -> Unit,
) {
    var isAnnual by rememberSaveable { mutableStateOf(true) }
    val yearlyProduct = remember(billingState.products) {
        billingState.products.firstOrNull { it.googlePlaySubscriptionFacts().isAnnual }
            ?: billingState.products.firstOrNull { it.id.contains("year", ignoreCase = true) }
    }
    val weeklyProduct = remember(billingState.products) {
        billingState.products.firstOrNull {
            val facts = it.googlePlaySubscriptionFacts()
            facts.isWeekly
        } ?: billingState.products.firstOrNull { it.id.contains("week", ignoreCase = true) }
    }
    val selectedProduct = if (isAnnual) {
        yearlyProduct ?: weeklyProduct
    } else {
        weeklyProduct ?: yearlyProduct
    }
    val selectedDisplayInfo = if (selectedProduct != null) {
        rememberGooglePlaySubscriptionDisplayInfo(selectedProduct)
    } else {
        null
    }
    val savingsPercent = remember(weeklyProduct, yearlyProduct) {
        yearlySavingsPercent(weeklyProduct, yearlyProduct)
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = ChillSpacing.S4),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(32.dp),
        ) {
            SubscriptionWordmark(
                modifier = Modifier
                    .padding(top = 20.dp)
                    .reveal(revealProgress, 20.dp),
            )

            SubscriptionBenefitsCard(
                modifier = Modifier.reveal(revealProgress, 30.dp),
            )

            PricingSection(
                isAnnual = isAnnual,
                savingsPercent = savingsPercent,
                selectedProduct = selectedProduct,
                selectedDisplayInfo = selectedDisplayInfo,
                billingState = billingState,
                onAnnualChange = { isAnnual = it },
                onRetryProducts = onRetryProducts,
                modifier = Modifier.reveal(revealProgress, 40.dp),
            )

            StandardSubscriptionFooter(
                billingError = billingState.error.takeIf { billingState.products.isNotEmpty() },
                restoreEnabled = !billingState.restoring,
                onRestore = onRestore,
                onOpenUrl = onOpenUrl,
                modifier = Modifier
                    .reveal(revealProgress, 50.dp)
                    .padding(bottom = 100.dp),
            )
        }

        if (selectedProduct != null && selectedDisplayInfo != null) {
            PrimarySubscriptionButton(
                text = selectedDisplayInfo.ctaText,
                enabled = !isPurchasing,
                onClick = { onPurchase(selectedProduct) },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = ChillSpacing.S4)
                    .padding(bottom = ChillSpacing.S4)
                    .navigationBarsPadding()
                    .reveal(revealProgress, 0.dp),
            )
        }
    }
}

@Composable
private fun MemberSubscriptionContent(
    subscriptionExpiresAt: String?,
    activeProductId: String?,
    billingError: String?,
    onManage: () -> Unit,
    onRestore: () -> Unit,
) {
    val locale = LocalLocale.current.platformLocale
    val renewalDate = remember(subscriptionExpiresAt, locale) {
        subscriptionExpiresAt?.let { localizedSubscriptionDate(it, locale) }
    }
    val planTitle = when {
        activeProductId?.contains("year", ignoreCase = true) == true -> stringResource(R.string.subscription_plan_annual)
        activeProductId?.contains("month", ignoreCase = true) == true -> stringResource(R.string.subscription_plan_monthly)
        else -> stringResource(R.string.subscription_plan_weekly)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(top = 20.dp)
            .padding(horizontal = ChillSpacing.S4)
            .padding(bottom = 100.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(32.dp),
    ) {
        SubscriptionWordmark(modifier = Modifier.padding(top = 20.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .cardShadow()
                .clip(RoundedCornerShape(ChillRadius.Card))
                .background(ChillColors.CardBackground)
                .padding(ChillSpacing.S4),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = planTitle,
                        color = ChillColors.TextMain,
                        fontSize = 17.sp,
                        lineHeight = 22.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(IOSGreen, CircleShape),
                        )
                        Text(
                            text = stringResource(R.string.subscription_status_active),
                            color = IOSGreen,
                            fontSize = 15.sp,
                            lineHeight = 20.sp,
                        )
                    }
                }

                Icon(
                    imageVector = Icons.Filled.Verified,
                    contentDescription = null,
                    tint = ChillColors.BrandBlue,
                    modifier = Modifier.size(22.dp),
                )
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(ChillColors.Separator),
            )

            if (renewalDate != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = stringResource(R.string.subscription_renews_on),
                        color = ChillColors.TextSub,
                        fontSize = 15.sp,
                        lineHeight = 20.sp,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = renewalDate,
                        color = ChillColors.TextMain,
                        fontSize = 15.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.End,
                    )
                }
            }
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text(
                text = stringResource(R.string.subscription_active_privileges),
                color = ChillColors.TextMain,
                fontSize = 17.sp,
                lineHeight = 22.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 4.dp),
            )
            SubscriptionBenefitsCard()
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(ChillSizes.PrimaryButtonHeight)
                    .clip(RoundedCornerShape(ChillRadius.Button))
                    .background(ChillColors.BrandBlue.copy(alpha = 0.10f))
                    .clickable(role = Role.Button, onClick = onManage),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.subscription_manage),
                    color = ChillColors.BrandBlueText,
                    style = ChillTypography.labelLarge,
                )
            }

            RestorePurchasesLink(onClick = onRestore)
            billingError?.let { InlineBillingError(it) }
        }
    }
}

@Composable
private fun SubscriptionWordmark(
    modifier: Modifier = Modifier,
    maxWidth: androidx.compose.ui.unit.Dp = 190.dp,
    height: androidx.compose.ui.unit.Dp = 56.dp,
) {
    Image(
        painter = painterResource(R.drawable.onboarding_wordmark),
        contentDescription = stringResource(R.string.app_name),
        contentScale = ContentScale.Fit,
        modifier = modifier
            .widthIn(max = maxWidth)
            .fillMaxWidth()
            .height(height),
    )
}

private data class BenefitDefinition(
    val icon: ImageVector,
    val iconColor: Color,
    val title: String,
    val subtitle: String,
)

@Composable
private fun SubscriptionBenefitsCard(modifier: Modifier = Modifier) {
    val benefits = listOf(
        BenefitDefinition(
            icon = Icons.Filled.Tune,
            iconColor = IOSTeal,
            title = stringResource(R.string.subscription_benefit_custom_skills_title),
            subtitle = stringResource(R.string.subscription_benefit_custom_skills_subtitle),
        ),
        BenefitDefinition(
            icon = Icons.Filled.AddBox,
            iconColor = IOSGreen,
            title = stringResource(R.string.subscription_benefit_flexible_capture_title),
            subtitle = stringResource(R.string.subscription_benefit_flexible_capture_subtitle),
        ),
        BenefitDefinition(
            icon = Icons.Filled.Forum,
            iconColor = IOSChatPurple,
            title = stringResource(R.string.subscription_benefit_unlimited_chat_title),
            subtitle = stringResource(R.string.subscription_benefit_unlimited_chat_subtitle),
        ),
        BenefitDefinition(
            icon = Icons.Filled.Lightbulb,
            iconColor = IOSOrange,
            title = stringResource(R.string.subscription_benefit_deep_dives_title),
            subtitle = stringResource(R.string.subscription_benefit_deep_dives_subtitle),
        ),
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .cardShadow()
            .clip(RoundedCornerShape(ChillRadius.Card))
            .background(ChillColors.CardBackground)
            .padding(ChillSpacing.S4),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        benefits.forEach { benefit ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(benefit.iconColor.copy(alpha = 0.10f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = benefit.icon,
                        contentDescription = null,
                        tint = benefit.iconColor,
                        modifier = Modifier.size(20.dp),
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = benefit.title,
                        color = ChillColors.TextMain,
                        fontSize = 16.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = benefit.subtitle,
                        color = ChillColors.TextSub,
                        fontSize = 13.sp,
                        lineHeight = 17.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun PricingSection(
    isAnnual: Boolean,
    savingsPercent: Int?,
    selectedProduct: BillingProduct?,
    selectedDisplayInfo: GooglePlaySubscriptionDisplayInfo?,
    billingState: BillingUiState,
    onAnnualChange: (Boolean) -> Unit,
    onRetryProducts: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.04f))
                .padding(4.dp),
        ) {
            PricingToggleButton(
                title = stringResource(R.string.subscription_interval_weekly),
                selected = !isAnnual,
                onClick = { onAnnualChange(false) },
                modifier = Modifier.weight(1f),
            )
            PricingToggleButton(
                title = stringResource(R.string.subscription_interval_yearly),
                selected = isAnnual,
                discountTag = savingsPercent?.let {
                    stringResource(R.string.subscription_discount_save_percent, it)
                },
                onClick = { onAnnualChange(true) },
                modifier = Modifier.weight(1f),
            )
        }

        if (selectedProduct != null && selectedDisplayInfo != null) {
            ProductHeroCard(
                displayInfo = selectedDisplayInfo,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            PaywallProductState(
                loading = billingState.loading,
                error = billingState.error,
                onRetryProducts = onRetryProducts,
                compact = true,
            )
        }
    }
}

@Composable
private fun PricingToggleButton(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    discountTag: String? = null,
) {
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier = modifier
            .then(
                if (selected) {
                    Modifier.shadow(
                        elevation = 4.dp,
                        shape = shape,
                        ambientColor = Color.Black.copy(alpha = 0.10f),
                        spotColor = Color.Black.copy(alpha = 0.10f),
                    )
                } else {
                    Modifier
                },
            )
            .clip(shape)
            .background(if (selected) Color.White else Color.Transparent)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = if (selected) ChillColors.TextMain else ChillColors.TextSub,
            fontSize = 14.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
        )
        discountTag?.let {
            Text(
                text = it,
                color = Color.White,
                fontSize = 9.sp,
                lineHeight = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                maxLines = 1,
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(ChillColors.BrandBlue)
                    .padding(horizontal = 6.dp, vertical = 3.dp),
            )
        }
    }
}

@Composable
private fun ProductHeroCard(
    displayInfo: GooglePlaySubscriptionDisplayInfo,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(ChillRadius.Card)
    val emphasized = displayInfo.hasFreeTrial || displayInfo.isAnnual
    Column(
        modifier = modifier
            .shadow(
                elevation = if (displayInfo.isAnnual) 10.dp else 5.dp,
                shape = shape,
                ambientColor = if (displayInfo.isAnnual) {
                    ChillColors.BrandBlue.copy(alpha = 0.15f)
                } else {
                    Color.Black.copy(alpha = 0.05f)
                },
                spotColor = if (displayInfo.isAnnual) {
                    ChillColors.BrandBlue.copy(alpha = 0.15f)
                } else {
                    Color.Black.copy(alpha = 0.05f)
                },
            )
            .clip(shape)
            .background(ChillColors.CardBackground)
            .border(
                BorderStroke(
                    width = if (displayInfo.isAnnual) 2.dp else 0.dp,
                    color = if (displayInfo.isAnnual) ChillColors.BrandBlue else Color.Transparent,
                ),
                shape,
            )
            .padding(vertical = ChillSpacing.S4),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = displayInfo.badgeText,
            color = if (emphasized) Color.White else ChillColors.TextSub,
            fontSize = 10.sp,
            lineHeight = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.sp,
            modifier = Modifier
                .clip(CircleShape)
                .background(
                    if (emphasized) ChillColors.BrandBlue else Color.Black.copy(alpha = 0.05f),
                )
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = displayInfo.displayPrice,
                color = ChillColors.TextMain,
                fontSize = 42.sp,
                lineHeight = 50.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                text = displayInfo.billingPeriodText,
                color = ChillColors.TextSub,
                fontSize = 17.sp,
                lineHeight = 22.sp,
                textAlign = TextAlign.Center,
            )
        }

        displayInfo.equivalentMonthlyText?.let {
            Text(
                text = it,
                color = ChillColors.BrandBlueText,
                fontSize = 16.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            )
        }

        displayInfo.renewalText?.let {
            Text(
                text = it,
                color = ChillColors.TextMain,
                fontSize = 16.sp,
                lineHeight = 21.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }
    }
}

@Composable
private fun StandardSubscriptionFooter(
    billingError: String?,
    restoreEnabled: Boolean,
    onRestore: () -> Unit,
    onOpenUrl: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        RestorePurchasesLink(
            enabled = restoreEnabled,
            onClick = onRestore,
        )

        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            FooterLink(
                text = stringResource(R.string.subscription_terms_of_use),
                color = ChillColors.TextSub.copy(alpha = 0.6f),
                fontSize = 12,
                onClick = { onOpenUrl(TermsUrl) },
            )
            FooterLink(
                text = stringResource(R.string.subscription_privacy_policy),
                color = ChillColors.TextSub.copy(alpha = 0.6f),
                fontSize = 12,
                onClick = { onOpenUrl(PrivacyUrl) },
            )
        }

        billingError?.let { InlineBillingError(it) }

        FooterDisclaimer(stringResource(R.string.subscription_footer_payment_disclaimer_google_play))
        FooterDisclaimer(stringResource(R.string.subscription_footer_renewal_disclaimer))
        FooterDisclaimer(stringResource(R.string.subscription_footer_manage_disclaimer_google_play))
    }
}

@Composable
private fun FooterDisclaimer(text: String) {
    Text(
        text = text,
        color = ChillColors.TextSub.copy(alpha = 0.4f),
        fontSize = 11.sp,
        lineHeight = 14.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun RestorePurchasesLink(
    onClick: () -> Unit,
    enabled: Boolean = true,
) {
    Text(
        text = stringResource(R.string.subscription_restore_purchases),
        color = ChillColors.TextSub.copy(alpha = if (enabled) 1f else 0.5f),
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Medium,
        textDecoration = TextDecoration.Underline,
        modifier = Modifier.clickable(
            enabled = enabled,
            role = Role.Button,
            onClick = onClick,
        ),
    )
}

@Composable
private fun FooterLink(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    color: Color = ChillColors.TextSub.copy(alpha = 0.72f),
    fontSize: Int = 13,
) {
    Text(
        text = text,
        color = color.copy(alpha = color.alpha * if (enabled) 1f else 0.5f),
        fontSize = fontSize.sp,
        lineHeight = (fontSize + 5).sp,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.clickable(
            enabled = enabled,
            role = Role.Button,
            onClick = onClick,
        ),
    )
}

@Composable
private fun PaywallProductState(
    loading: Boolean,
    error: String?,
    onRetryProducts: () -> Unit,
    modifier: Modifier = Modifier,
    compact: Boolean,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = if (compact) {
            Arrangement.spacedBy(10.dp, Alignment.CenterVertically)
        } else {
            Arrangement.spacedBy(12.dp, Alignment.CenterVertically)
        },
    ) {
        if (loading) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = if (compact) Modifier.padding(16.dp) else Modifier,
            ) {
                CircularProgressIndicator(
                    color = ChillColors.BrandBlue,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = stringResource(R.string.subscription_loading_prices),
                    color = ChillColors.TextSub,
                    style = if (compact) {
                        ChillTypography.labelMedium
                    } else {
                        ChillTypography.bodyMedium
                    },
                )
            }
        } else {
            Text(
                text = error ?: stringResource(R.string.subscription_products_unavailable),
                color = if (error != null) Color.Red else ChillColors.TextSub,
                style = if (compact) {
                    ChillTypography.labelMedium
                } else {
                    ChillTypography.bodyMedium
                },
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp),
            )
            Text(
                text = stringResource(R.string.common_retry),
                color = ChillColors.BrandBlueText,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clickable(role = Role.Button, onClick = onRetryProducts),
            )
        }
    }
}

@Composable
private fun InlineBillingError(message: String) {
    Text(
        text = message,
        color = Color.Red,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun PrimarySubscriptionButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    showChevron: Boolean = false,
) {
    val buttonShape = RoundedCornerShape(ChillRadius.Button)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(ChillSizes.PrimaryButtonHeight)
            .shadow(
                elevation = 6.dp,
                shape = buttonShape,
                ambientColor = ChillColors.BrandBlue.copy(alpha = 0.22f),
                spotColor = ChillColors.BrandBlue.copy(alpha = 0.22f),
            )
            .clip(buttonShape)
            .background(
                ChillColors.BrandBlue.copy(alpha = if (enabled) 1f else 0.5f),
            )
            .clickable(
                enabled = enabled,
                role = Role.Button,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(ChillSpacing.S1),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = text,
                color = Color.White,
                style = ChillTypography.labelLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (showChevron) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(13.dp),
                )
            }
        }
    }
}

@Composable
private fun SubscriptionLoadingOverlay() {
    val interactionSource = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = {},
            )
            .clearAndSetSemantics {},
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .background(Color.White.copy(alpha = 0.16f))
                .border(
                    width = 1.dp,
                    color = Color.White.copy(alpha = 0.16f),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(40.dp),
            contentAlignment = Alignment.Center,
        ) {
            CircularProgressIndicator(
                color = Color.White,
                strokeWidth = 3.dp,
                modifier = Modifier.size(30.dp),
            )
        }
    }
}

@Composable
private fun Modifier.reveal(progress: Float, initialOffset: androidx.compose.ui.unit.Dp): Modifier {
    val offsetPixels = with(LocalDensity.current) { initialOffset.toPx() }
    return graphicsLayer {
        alpha = progress
        translationY = offsetPixels * (1f - progress)
    }
}

private fun Modifier.cardShadow(): Modifier = shadow(
    elevation = 8.dp,
    shape = RoundedCornerShape(ChillRadius.Card),
    ambientColor = ChillColors.Shadow,
    spotColor = ChillColors.Shadow,
)

private fun localizedSubscriptionDate(value: String, locale: Locale): String {
    val date = runCatching {
        Instant.parse(value).atZone(ZoneId.systemDefault()).toLocalDate()
    }.recoverCatching {
        OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.systemDefault()).toLocalDate()
    }.recoverCatching {
        LocalDate.parse(value)
    }.getOrNull() ?: return value

    return DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)
        .withLocale(locale)
        .format(date)
}
