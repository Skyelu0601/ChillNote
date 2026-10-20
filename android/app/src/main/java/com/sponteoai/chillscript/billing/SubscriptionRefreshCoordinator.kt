package com.sponteoai.chillscript.billing

import com.sponteoai.chillscript.data.remote.SubscriptionStatusResponse
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

enum class SubscriptionCheck { Checking, Confirmed, Failed }

fun allowsSubscriptionPurchase(tier: String, check: SubscriptionCheck): Boolean =
    tier == "free" && check == SubscriptionCheck.Confirmed

/** Serializes refreshes; a purchase/restore arriving mid-request invalidates that response. */
internal class SubscriptionRefreshCoordinator(
    private val scope: CoroutineScope,
    private val fetch: suspend (String) -> SubscriptionStatusResponse,
    private val onChecking: () -> Unit,
    private val onConfirmed: (String, SubscriptionStatusResponse) -> Unit,
    private val onFailed: (String, Throwable) -> Unit,
) {
    private var job: Job? = null
    private var accountId: String? = null
    private var revision = 0L
    private var expectPro = false

    fun reset() {
        revision++
        job?.cancel()
        job = null
        accountId = null
        expectPro = false
    }

    fun request(userId: String, purchaseCompleted: Boolean = false) {
        if (accountId != userId) reset()
        accountId = userId
        expectPro = expectPro || purchaseCompleted
        revision++
        onChecking()
        if (job?.isActive == true) return
        job = scope.launch {
            do {
                val requestedRevision = revision
                var response: SubscriptionStatusResponse? = null
                var failure: Throwable? = null
                for (attempt in 0..2) {
                    try {
                        val result = fetch(userId)
                        currentCoroutineContext().ensureActive()
                        check(result.success && result.tier in setOf("free", "pro"))
                        // A delayed store notification must never reopen purchasing after checkout.
                        check(!expectPro || result.tier == "pro") { "Purchased entitlement is not active yet" }
                        response = result
                        break
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (error: Throwable) {
                        failure = error
                        if (requestedRevision != revision) break
                        if (attempt < 2) delay(1_000L * (attempt + 1))
                    }
                }
                if (accountId != userId) return@launch
                if (requestedRevision == revision) {
                    if (response != null) {
                        if (response.tier == "pro") expectPro = false
                        onConfirmed(userId, response)
                    } else {
                        onFailed(userId, checkNotNull(failure))
                    }
                }
            } while (requestedRevision != revision)
        }
    }
}
