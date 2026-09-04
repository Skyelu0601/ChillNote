package com.sponteoai.chillscript

import kotlinx.coroutines.CancellationException
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test

class CoroutineResultTest {
    @Test fun cancellationIsRethrown() {
        assertThrows(CancellationException::class.java) {
            runCatchingPreservingCancellation<Unit> { throw CancellationException("cancelled") }
        }
    }

    @Test fun ordinaryFailureIsReturned() {
        val failure = IllegalStateException("failed")

        assertSame(failure, runCatchingPreservingCancellation<Unit> { throw failure }.exceptionOrNull())
    }
}
