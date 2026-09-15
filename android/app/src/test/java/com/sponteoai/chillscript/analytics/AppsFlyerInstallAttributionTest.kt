package com.sponteoai.chillscript.analytics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppsFlyerInstallAttributionTest {
    @Test fun mapsAppsFlyerCampaignFieldsForRevenueCat() {
        val attribution = AppsFlyerInstallAttribution.from(
            mapOf(
                "media_source" to "tiktokglobal_int",
                "campaign" to "spark_launch",
                "af_adset" to "creator_a",
                "af_ad" to "video_01",
            ),
        )

        assertEquals("tiktokglobal_int", attribution.mediaSource)
        assertEquals("spark_launch", attribution.campaign)
        assertEquals("creator_a", attribution.adGroup)
        assertEquals("video_01", attribution.ad)
    }

    @Test fun ignoresMissingAndEmptyCampaignFields() {
        val attribution = AppsFlyerInstallAttribution.from(mapOf("media_source" to "  "))

        assertNull(attribution.mediaSource)
        assertNull(attribution.campaign)
        assertNull(attribution.adGroup)
        assertNull(attribution.ad)
    }
}
