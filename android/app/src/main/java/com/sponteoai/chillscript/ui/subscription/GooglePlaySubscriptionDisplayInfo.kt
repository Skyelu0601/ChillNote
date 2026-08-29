package com.sponteoai.chillscript.ui.subscription

import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalLocale
import androidx.compose.ui.res.stringResource
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingProduct
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/**
 * The StoreKit `SubscriptionDisplayInfo` equivalent for Google Play.
 *
 * Prices, billing periods and trial lengths intentionally come from the offer
 * selected by [BillingProduct.offerToken]. Nothing customer-facing is inferred
 * from a hard-coded product price or trial duration.
 */
internal data class GooglePlaySubscriptionFacts(
    val isAnnual: Boolean,
    val isWeekly: Boolean,
    val paidPriceMicros: Long?,
    val paidFormattedPrice: String,
    val currencyCode: String?,
    val billingMonthCount: Int?,
    val trialPeriod: GooglePlayPeriod?,
)

internal data class GooglePlaySubscriptionDisplayInfo(
    val isAnnual: Boolean,
    val isWeekly: Boolean,
    val hasFreeTrial: Boolean,
    val displayPrice: String,
    val badgeText: String,
    val ctaText: String,
    val billingPeriodText: String,
    val equivalentMonthlyText: String?,
    val equivalentWeeklyText: String?,
    val renewalText: String?,
    val trialDurationText: String?,
    val trialDayCount: Int?,
)

internal data class GooglePlayPeriod(
    val years: Int = 0,
    val months: Int = 0,
    val weeks: Int = 0,
    val days: Int = 0,
) {
    val totalMonths: Int?
        get() = if (weeks == 0 && days == 0) years * 12 + months else null

    fun multipliedBy(multiplier: Int): GooglePlayPeriod {
        val safeMultiplier = multiplier.coerceAtLeast(1)
        return copy(
            years = years * safeMultiplier,
            months = months * safeMultiplier,
            weeks = weeks * safeMultiplier,
            days = days * safeMultiplier,
        )
    }

    fun localized(locale: Locale): String? {
        val measures = buildList {
            if (years > 0) add(Measure(years, MeasureUnit.YEAR))
            if (months > 0) add(Measure(months, MeasureUnit.MONTH))
            if (weeks > 0) add(Measure(weeks, MeasureUnit.WEEK))
            if (days > 0) add(Measure(days, MeasureUnit.DAY))
        }
        if (measures.isEmpty()) return null
        val formatter = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.WIDE)
        return formatter.formatMeasures(*measures.toTypedArray())
    }

    val exactDayCount: Int?
        get() = if (years == 0 && months == 0) {
            (weeks * 7 + days).takeIf { it > 0 }
        } else {
            null
        }
}

private val GooglePlayPeriodPattern = Regex(
    pattern = "^P(?:(\\d+)Y)?(?:(\\d+)M)?(?:(\\d+)W)?(?:(\\d+)D)?$",
    option = RegexOption.IGNORE_CASE,
)

internal fun parseGooglePlayPeriod(value: String?): GooglePlayPeriod? {
    val match = value?.let(GooglePlayPeriodPattern::matchEntire) ?: return null
    val period = GooglePlayPeriod(
        years = match.groupValues[1].toIntOrNull() ?: 0,
        months = match.groupValues[2].toIntOrNull() ?: 0,
        weeks = match.groupValues[3].toIntOrNull() ?: 0,
        days = match.groupValues[4].toIntOrNull() ?: 0,
    )
    return period.takeIf { it.years + it.months + it.weeks + it.days > 0 }
}

internal fun BillingProduct.googlePlaySubscriptionFacts(): GooglePlaySubscriptionFacts {
    val selectedOffer = details.subscriptionOfferDetails
        .orEmpty()
        .firstOrNull { it.offerToken == offerToken }
    val phases = selectedOffer?.pricingPhases?.pricingPhaseList.orEmpty()
    val paidPhase = phases.lastOrNull { it.priceAmountMicros > 0L } ?: phases.lastOrNull()
    val trialPhase = phases.firstOrNull { it.priceAmountMicros == 0L }
    val paidPeriod = parseGooglePlayPeriod(paidPhase?.billingPeriod)
    val isAnnual = paidPeriod?.totalMonths == 12 ||
        (paidPeriod == null && id.contains("year", ignoreCase = true))
    val isWeekly = paidPeriod?.let { it.weeks == 1 && it.years + it.months + it.days == 0 } == true ||
        (paidPeriod == null && id.contains("week", ignoreCase = true))

    return GooglePlaySubscriptionFacts(
        isAnnual = isAnnual,
        isWeekly = isWeekly,
        paidPriceMicros = paidPhase?.priceAmountMicros,
        paidFormattedPrice = paidPhase?.formattedPrice ?: formattedPrice,
        currencyCode = paidPhase?.priceCurrencyCode,
        billingMonthCount = paidPeriod?.totalMonths,
        trialPeriod = parseGooglePlayPeriod(trialPhase?.billingPeriod)?.multipliedBy(
            trialPhase?.billingCycleCount ?: 1,
        ),
    )
}

@Composable
internal fun rememberGooglePlaySubscriptionDisplayInfo(
    product: BillingProduct,
): GooglePlaySubscriptionDisplayInfo {
    val locale = LocalLocale.current.platformLocale
    val facts = remember(product) { product.googlePlaySubscriptionFacts() }
    val trialDurationText = remember(facts, locale) {
        facts.trialPeriod?.localized(locale)
    }
    val equivalentMonthlyPrice = remember(facts, locale) {
        facts.derivedPrice(divisor = facts.billingMonthCount, locale = locale)
            .takeIf { facts.isAnnual }
    }
    val equivalentWeeklyPrice = remember(facts, locale) {
        facts.derivedPrice(divisor = 52, locale = locale).takeIf { facts.isAnnual }
    }
    val pricePerYear = if (facts.isAnnual) {
        stringResource(R.string.subscription_price_per_year_format, facts.paidFormattedPrice)
    } else {
        null
    }

    val badgeText = when {
        trialDurationText != null -> stringResource(
            R.string.subscription_badge_free_trial_format,
            trialDurationText.uppercase(locale),
        )
        facts.isAnnual -> stringResource(R.string.subscription_badge_best_value)
        else -> stringResource(R.string.subscription_badge_flexible)
    }
    val ctaText = when {
        trialDurationText != null -> stringResource(
            R.string.subscription_cta_start_free_trial_format,
            trialDurationText,
        )
        facts.isAnnual -> stringResource(R.string.subscription_cta_start_annual)
        else -> stringResource(R.string.subscription_cta_start_weekly)
    }

    return GooglePlaySubscriptionDisplayInfo(
        isAnnual = facts.isAnnual,
        isWeekly = facts.isWeekly,
        hasFreeTrial = trialDurationText != null,
        displayPrice = facts.paidFormattedPrice,
        badgeText = badgeText,
        ctaText = ctaText,
        billingPeriodText = stringResource(
            if (facts.isAnnual) R.string.subscription_billing_period_yearly
            else R.string.subscription_billing_period_weekly,
        ),
        equivalentMonthlyText = equivalentMonthlyPrice?.let {
            stringResource(R.string.subscription_equivalent_monthly_billed_yearly_format, it)
        },
        equivalentWeeklyText = equivalentWeeklyPrice,
        renewalText = if (trialDurationText != null && pricePerYear != null) {
            stringResource(
                R.string.subscription_free_trial_then_price_format,
                trialDurationText,
                pricePerYear,
            )
        } else {
            null
        },
        trialDurationText = trialDurationText,
        trialDayCount = facts.trialPeriod?.exactDayCount,
    )
}

internal fun yearlySavingsPercent(
    weeklyProduct: BillingProduct?,
    yearlyProduct: BillingProduct?,
): Int? {
    val weeklyFacts = weeklyProduct?.googlePlaySubscriptionFacts() ?: return null
    val yearlyFacts = yearlyProduct?.googlePlaySubscriptionFacts() ?: return null
    val weeklyMicros = weeklyFacts.paidPriceMicros?.takeIf { it > 0L } ?: return null
    val yearlyMicros = yearlyFacts.paidPriceMicros?.takeIf { it > 0L } ?: return null

    val weeklyEquivalent = BigDecimal.valueOf(yearlyMicros)
        .divide(BigDecimal.valueOf(52L), 12, RoundingMode.HALF_UP)
    val ratio = BigDecimal.ONE.subtract(
        weeklyEquivalent.divide(BigDecimal.valueOf(weeklyMicros), 12, RoundingMode.HALF_UP),
    )
    val percent = ratio.multiply(BigDecimal.valueOf(100L))
        .setScale(0, RoundingMode.HALF_UP)
        .toInt()
    return percent.takeIf { it >= 1 }
}

private fun GooglePlaySubscriptionFacts.derivedPrice(
    divisor: Int?,
    locale: Locale,
): String? {
    val micros = paidPriceMicros?.takeIf { it > 0L } ?: return null
    val safeDivisor = divisor?.takeIf { it > 0 } ?: return null
    val currency = currencyCode?.let { runCatching { Currency.getInstance(it) }.getOrNull() } ?: return null
    val amount = BigDecimal.valueOf(micros, 6)
        .divide(BigDecimal.valueOf(safeDivisor.toLong()), 12, RoundingMode.HALF_UP)
    return NumberFormat.getCurrencyInstance(locale).apply {
        this.currency = currency
    }.format(amount)
}
