package com.sponteoai.chillscript

import kotlinx.coroutines.CancellationException

/** Keeps structured-concurrency cancellation from being converted into an ordinary failure. */
internal inline fun <T> runCatchingPreservingCancellation(block: () -> T): Result<T> = try {
    Result.success(block())
} catch (cancelled: CancellationException) {
    throw cancelled
} catch (error: Throwable) {
    Result.failure(error)
}
