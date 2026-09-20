package com.sponteoai.chillscript.billing

import org.junit.Assert.assertEquals
import org.junit.Test

class AnnualPriceExperimentTest {
    @Test
    fun assignmentIsStableAndCaseInsensitive() {
        val userId = "A3B9CB58-0B4C-43DA-9BE2-2F18AA6743EA"

        assertEquals(
            AnnualPriceExperiment.variantFor(userId),
            AnnualPriceExperiment.variantFor(userId.lowercase()),
        )
    }

    @Test
    fun knownAssignmentsMatchIos() {
        assertEquals(AnnualPriceExperiment.ANNUAL_49_99, AnnualPriceExperiment.variantFor("user-0"))
        assertEquals(AnnualPriceExperiment.ANNUAL_59_99, AnnualPriceExperiment.variantFor("user-2"))
    }

    @Test
    fun eachVariantUsesItsOwnOfferingAndBasePlan() {
        assertEquals(AnnualPriceExperiment.OFFERING_49_99, AnnualPriceExperiment.offeringIdentifierFor("user-0"))
        assertEquals(AnnualPriceExperiment.BASE_PLAN_49_99, AnnualPriceExperiment.annualBasePlanIdFor("user-0"))
        assertEquals(AnnualPriceExperiment.OFFERING_59_99, AnnualPriceExperiment.offeringIdentifierFor("user-2"))
        assertEquals(AnnualPriceExperiment.BASE_PLAN_59_99, AnnualPriceExperiment.annualBasePlanIdFor("user-2"))
    }
}
