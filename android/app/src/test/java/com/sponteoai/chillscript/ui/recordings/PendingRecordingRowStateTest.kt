package com.sponteoai.chillscript.ui.recordings

import com.sponteoai.chillscript.voice.PendingRecordingSaveOutcome
import org.junit.Assert.assertEquals
import org.junit.Test

class PendingRecordingRowStateTest {
    @Test
    fun successfulSaveShowsSavedConfirmation() {
        assertEquals(
            PendingRecordingRowSaveState.Saved,
            rowStateAfter(PendingRecordingSaveOutcome.Saved),
        )
    }

    @Test
    fun declinedConsentReturnsRowToIdleWithoutClaimingFailure() {
        assertEquals(
            PendingRecordingRowSaveState.Idle,
            rowStateAfter(PendingRecordingSaveOutcome.ConsentDeclined),
        )
    }

    @Test
    fun failedSaveReturnsRowToIdleSoItCanBeRetried() {
        assertEquals(
            PendingRecordingRowSaveState.Idle,
            rowStateAfter(PendingRecordingSaveOutcome.Error),
        )
    }
}
