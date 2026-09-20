package com.sponteoai.chillscript.billing

import java.util.Locale

object AnnualPriceExperiment {
    const val ANNUAL_49_99 = "annual_49_99"
    const val ANNUAL_59_99 = "annual_59_99"
    const val OFFERING_49_99 = "post_login_two_page_trial_4999"
    const val OFFERING_59_99 = "post_login_two_page_trial_5999"
    const val BASE_PLAN_49_99 = "yearly49"
    const val BASE_PLAN_59_99 = "yearly"

    fun variantFor(userId: String): String {
        var hash = 0x811C9DC5L
        userId.lowercase(Locale.ROOT).toByteArray(Charsets.UTF_8).forEach { byte ->
            hash = hash xor (byte.toInt() and 0xFF).toLong()
            hash = (hash * 0x01000193L) and 0xFFFF_FFFFL
        }
        return if (hash % 100 < 50) ANNUAL_49_99 else ANNUAL_59_99
    }

    fun offeringIdentifierFor(userId: String): String = when (variantFor(userId)) {
        ANNUAL_49_99 -> OFFERING_49_99
        else -> OFFERING_59_99
    }

    fun annualBasePlanIdFor(userId: String): String = when (variantFor(userId)) {
        ANNUAL_49_99 -> BASE_PLAN_49_99
        else -> BASE_PLAN_59_99
    }
}
