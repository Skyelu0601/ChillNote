package com.sponteoai.chillscript.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.PendingPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest

data class BillingProduct(
    val id: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val hasFreeTrial: Boolean,
    internal val details: ProductDetails,
    internal val offerToken: String,
)

data class BillingUiState(
    val connected: Boolean = false,
    val loading: Boolean = true,
    val restoring: Boolean = false,
    val products: List<BillingProduct> = emptyList(),
    val error: String? = null,
)

class PlayBillingManager(
    context: Context,
    private val onPurchased: (productId: String, purchaseToken: String) -> Unit,
) {
    private val mutableState = MutableStateFlow(BillingUiState())
    val state: StateFlow<BillingUiState> = mutableState

    private val billingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                purchases.orEmpty().filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.forEach(::processPurchase)
            } else if (result.responseCode != BillingClient.BillingResponseCode.USER_CANCELED) {
                mutableState.value = mutableState.value.copy(error = result.debugMessage)
            }
        }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    fun connect() {
        if (billingClient.isReady) { queryProducts(); queryExistingPurchases(); return }
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    mutableState.value = mutableState.value.copy(connected = true, loading = true, error = null)
                    queryProducts()
                    queryExistingPurchases()
                } else {
                    mutableState.value = BillingUiState(error = result.debugMessage, loading = false)
                }
            }
            override fun onBillingServiceDisconnected() {
                mutableState.value = mutableState.value.copy(connected = false)
            }
        })
    }

    fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) {
        val detailParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(product.details)
            .setOfferToken(product.offerToken)
            .build()
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(detailParams))
            .setObfuscatedAccountId(userId.sha256())
            .build()
        val result = billingClient.launchBillingFlow(activity, params)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            mutableState.value = mutableState.value.copy(error = result.debugMessage)
        }
    }

    fun restorePurchases() {
        if (billingClient.isReady) {
            queryExistingPurchases(isUserRestore = true)
        } else {
            mutableState.value = mutableState.value.copy(restoring = true, error = null)
            connect()
        }
    }

    fun close() = billingClient.endConnection()

    private fun queryProducts() {
        val products = PRODUCT_IDS.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        billingClient.queryProductDetailsAsync(
            QueryProductDetailsParams.newBuilder().setProductList(products).build(),
        ) { result, detailsResult ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                mutableState.value = mutableState.value.copy(loading = false, error = result.debugMessage)
                return@queryProductDetailsAsync
            }
            val mapped = detailsResult.productDetailsList.mapNotNull { details ->
                val offers = details.subscriptionOfferDetails.orEmpty()
                val offer = offers.firstOrNull { candidate ->
                    candidate.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L }
                } ?: offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull() ?: return@mapNotNull null
                val price = offer.pricingPhases.pricingPhaseList.lastOrNull()?.formattedPrice ?: return@mapNotNull null
                val hasFreeTrial = offer.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L }
                BillingProduct(details.productId, details.title, details.description, price, hasFreeTrial, details, offer.offerToken)
            }.sortedBy { PRODUCT_IDS.indexOf(it.id) }
            mutableState.value = mutableState.value.copy(loading = false, products = mapped, error = null)
        }
    }

    private fun queryExistingPurchases(isUserRestore: Boolean = false) {
        if (isUserRestore) mutableState.value = mutableState.value.copy(restoring = true, error = null)
        billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
        ) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.forEach(::processPurchase)
            }
            if (isUserRestore || mutableState.value.restoring) {
                mutableState.value = mutableState.value.copy(
                    restoring = false,
                    error = result.debugMessage.takeIf { result.responseCode != BillingClient.BillingResponseCode.OK },
                )
            }
        }
    }

    private fun processPurchase(purchase: Purchase) {
        purchase.products.firstOrNull { it in PRODUCT_IDS }?.let { onPurchased(it, purchase.purchaseToken) }
    }

    companion object {
        val PRODUCT_IDS = listOf("com.chillnote.pro.monthly", "com.chillnote.pro.yearly")
    }
}

private fun String.sha256(): String = MessageDigest.getInstance("SHA-256")
    .digest(toByteArray()).joinToString("") { "%02x".format(it) }
