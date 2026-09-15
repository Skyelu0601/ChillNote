package com.sponteoai.chillscript.share

import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Test

class ShareImportAnalyticsTest {
    @Test fun separatesCreditLimitsFromTechnicalFailures() {
        assertEquals("insufficient_credits", ShareLinkInsufficientCreditsException().analyticsCode())
        assertEquals("invalid_share_content", ShareLinkImportException().analyticsCode())
        assertEquals("io_error", IOException("private file path").analyticsCode())
        assertEquals("not_authorized", SecurityException("private url").analyticsCode())
        assertEquals("unknown", RuntimeException("private note").analyticsCode())
    }
}
