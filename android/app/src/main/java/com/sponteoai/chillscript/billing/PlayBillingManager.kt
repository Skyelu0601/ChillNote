package com.sponteoai.chillscript.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.ProductType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.getProductsWith
import com.revenuecat.purchases.logInWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith
import com.revenuecat.purchases.syncPurchasesWith
import com.revenuecat.purchases.models.StoreProduct
import com.sponteoai.chillscript.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest

data class BillingPricingPhase(
    val formattedPrice: String,
    val priceAmountMicros: Long,
    val priceCurrencyCode: String,
    val billingPeriod: String,
    val billingCycleCount: Int,
)

sealed interface BillingPurchaseTarget {
    data class GooglePlay(
        val details: ProductDetails,
        val offerToken: String,
    ) : BillingPurchaseTarget

    data class RevenueCatPackage(val value: Package) : BillingPurchaseTarget
    data class RevenueCatProduct(val value: StoreProduct) : BillingPurchaseTarget
}

data class BillingProduct(
    val id: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val hasFreeTrial: Boolean,
    val pricingPhases: List<BillingPricingPhase>,
    internal val purchaseTarget: BillingPurchaseTarget,
)

data class BillingUiState(
    val connected: Boolean = false,
    val loading: Boolean = true,
    val restoring: Boolean = false,
    val products: List<BillingProduct> = emptyList(),
    val error: String? = null,
)

/**
 * RevenueCat is the production purchase path once a `goog_` SDK key is configured.
 * The legacy BillingClient path remains as a temporary no-key fallback so a missing
 * dashboard configuration cannot disable purchases in an already published build.
 */
class PlayBillingManager(
    context: Context,
    onPurchased: (productId: String, purchaseToken: String) -> Unit,
    onRestoreComplete: () -> Unit = {},
) {
    private val delegate: BillingManagerDelegate = if (RevenueCatService.isConfigured) {
        RevenueCatBillingManager(context, onPurchased, onRestoreComplete)
    } else {
        LegacyPlayBillingManager(context, onPurchased)
    }

    val state: StateFlow<BillingUiState> = delegate.state

    fun connect() = delegate.connect()
    fun identify(userId: String?, migrateLegacyPurchase: Boolean) =
        delegate.identify(userId, migrateLegacyPurchase)
    fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) =
        delegate.launchPurchase(activity, product, userId)
    fun restorePurchases() = delegate.restorePurchases()
    fun close() = delegate.close()

    companion object {
        private const val ANNUAL_PRODUCT_ID = "com.chillnote.pro.yearly"
        val PRODUCT_IDS = listOf("com.chillnote.pro.weekly", ANNUAL_PRODUCT_ID)
        val RECOGNIZED_PRODUCT_IDS = PRODUCT_IDS.toSet() + "com.chillnote.pro.monthly"
    }
}

private interface BillingManagerDelegate {
    val state: StateFlow<BillingUiState>
    fun connect()
    fun identify(userId: String?, migrateLegacyPurchase: Boolean)
    fun launchPurchase(activity: Activity, product: BillingProduct, userId: String)
    fun restorePurchases()
    fun close()
}

private class RevenueCatBillingManager(
    context: Context,
    private val onPurchased: (productId: String, purchaseToken: String) -> Unit,
    private val onRestoreComplete: () -> Unit,
) : BillingManagerDelegate {
    private val appContext = context.applicationContext
    private val migrationPreferences = appContext.getSharedPreferences(MIGRATION_PREFERENCES, Context.MODE_PRIVATE)
    private val mutableState = MutableStateFlow(BillingUiState())
    override val state: StateFlow<BillingUiState> = mutableState

    override fun connect() {
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener {
            onRestoreComplete()
        }
        mutableState.value = mutableState.value.copy(connected = true, loading = true, error = null)
        queryProducts()
    }

    override fun identify(userId: String?, migrateLegacyPurchase: Boolean) {
        if (userId.isNullOrBlank()) return
        ensureIdentity(userId) {
            if (migrateLegacyPurchase) syncLegacyPurchasesOnce(userId)
            queryProducts()
        }
    }

    override fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) {
        ensureIdentity(userId) {
            val params = when (val target = product.purchaseTarget) {
                is BillingPurchaseTarget.RevenueCatPackage -> PurchaseParams.Builder(activity, target.value).build()
                is BillingPurchaseTarget.RevenueCatProduct -> PurchaseParams.Builder(activity, target.value).build()
                is BillingPurchaseTarget.GooglePlay -> {
                    reportError("Unexpected legacy product passed to RevenueCat")
                    return@ensureIdentity
                }
            }
            Purchases.sharedInstance.purchaseWith(
                purchaseParams = params,
                onError = { error, userCancelled ->
                    if (!userCancelled) reportError("RevenueCat purchase failed: ${error.code}")
                },
                onSuccess = { transaction, _ ->
                    val purchaseToken = transaction?.purchaseToken
                    val purchasedProductId = transaction?.productIds
                        ?.map(String::baseProductId)
                        ?.firstOrNull { it in PlayBillingManager.RECOGNIZED_PRODUCT_IDS }
                        ?: product.id
                    if (purchaseToken.isNullOrBlank()) {
                        reportError("RevenueCat purchase completed without a Google purchase token")
                    } else {
                        mutableState.value = mutableState.value.copy(error = null)
                        onPurchased(purchasedProductId, purchaseToken)
                        onRestoreComplete()
                    }
                },
            )
        }
    }

    override fun restorePurchases() {
        mutableState.value = mutableState.value.copy(restoring = true, error = null)
        Purchases.sharedInstance.restorePurchasesWith(
            onError = { error ->
                Log.w(TAG, "RevenueCat restore failed: ${error.code}")
                mutableState.value = mutableState.value.copy(restoring = false, error = userFacingError())
            },
            onSuccess = {
                mutableState.value = mutableState.value.copy(restoring = false, error = null)
                onRestoreComplete()
            },
        )
    }

    override fun close() {
        Purchases.sharedInstance.removeUpdatedCustomerInfoListener()
    }

    private fun ensureIdentity(userId: String, onReady: () -> Unit) {
        val purchases = Purchases.sharedInstance
        if (purchases.appUserID == userId) {
            onReady()
            return
        }
        purchases.logInWith(
            appUserID = userId,
            onError = { error -> reportError("RevenueCat user identification failed: ${error.code}") },
            onSuccess = { _, _ -> onReady() },
        )
    }

    private fun syncLegacyPurchasesOnce(userId: String) {
        val migrationKey = "synced_${userId.sha256()}"
        if (migrationPreferences.getBoolean(migrationKey, false)) return
        Purchases.sharedInstance.getCustomerInfoWith(
            onError = { error -> Log.w(TAG, "RevenueCat customer lookup failed before migration: ${error.code}") },
            onSuccess = { customerInfo ->
                if (customerInfo.entitlements[ENTITLEMENT_ID]?.isActive == true) {
                    migrationPreferences.edit().putBoolean(migrationKey, true).apply()
                    onRestoreComplete()
                    return@getCustomerInfoWith
                }
                Purchases.sharedInstance.syncPurchasesWith(
                    onError = { error -> Log.w(TAG, "RevenueCat legacy purchase sync failed: ${error.code}") },
                    onSuccess = {
                        migrationPreferences.edit().putBoolean(migrationKey, true).apply()
                        onRestoreComplete()
                    },
                )
            },
        )
    }

    private fun queryProducts() {
        Purchases.sharedInstance.getOfferingsWith(
            onError = {
                Log.w(TAG, "RevenueCat offerings unavailable: ${it.code}")
                queryStoreProducts()
            },
            onSuccess = { offerings ->
                val products = offerings.current?.availablePackages
                    .orEmpty()
                    .mapNotNull(::billingProduct)
                    .distinctBy(BillingProduct::id)
                    .sortedByProductOrder()
                if (products.isEmpty()) queryStoreProducts() else publishProducts(products)
            },
        )
    }

    private fun queryStoreProducts() {
        Purchases.sharedInstance.getProductsWith(
            productIds = PlayBillingManager.PRODUCT_IDS,
            type = ProductType.SUBS,
            onError = { reportError("RevenueCat product query failed: ${it.code}") },
            onGetStoreProducts = { storeProducts ->
                publishProducts(storeProducts.mapNotNull(::billingProduct).sortedByProductOrder())
            },
        )
    }

    private fun billingProduct(packageToPurchase: Package): BillingProduct? =
        billingProduct(
            storeProduct = packageToPurchase.product,
            target = BillingPurchaseTarget.RevenueCatPackage(packageToPurchase),
        )

    private fun billingProduct(storeProduct: StoreProduct): BillingProduct? =
        billingProduct(
            storeProduct = storeProduct,
            target = BillingPurchaseTarget.RevenueCatProduct(storeProduct),
        )

    private fun billingProduct(
        storeProduct: StoreProduct,
        target: BillingPurchaseTarget,
    ): BillingProduct? {
        val productId = storeProduct.id.baseProductId()
        if (productId !in PlayBillingManager.PRODUCT_IDS) return null
        val phases = storeProduct.defaultOption?.pricingPhases.orEmpty().map { phase ->
            BillingPricingPhase(
                formattedPrice = phase.price.formatted,
                priceAmountMicros = phase.price.amountMicros,
                priceCurrencyCode = phase.price.currencyCode,
                billingPeriod = phase.billingPeriod.iso8601,
                billingCycleCount = phase.billingCycleCount ?: 1,
            )
        }
        val paidPhase = phases.lastOrNull { it.priceAmountMicros > 0L }
        return BillingProduct(
            id = productId,
            title = storeProduct.title,
            description = storeProduct.description,
            formattedPrice = paidPhase?.formattedPrice ?: storeProduct.price.formatted,
            hasFreeTrial = phases.any { it.priceAmountMicros == 0L },
            pricingPhases = phases,
            purchaseTarget = target,
        )
    }

    private fun publishProducts(products: List<BillingProduct>) {
        mutableState.value = mutableState.value.copy(
            connected = true,
            loading = false,
            products = products,
            error = userFacingError().takeIf { products.isEmpty() },
        )
    }

    private fun reportError(detail: String) {
        Log.w(TAG, detail)
        mutableState.value = mutableState.value.copy(loading = false, error = userFacingError())
    }

    private fun userFacingError(): String = appContext.getString(R.string.subscription_billing_error)

    private companion object {
        const val TAG = "RevenueCatBilling"
        const val ENTITLEMENT_ID = "pro"
        const val MIGRATION_PREFERENCES = "revenuecat_purchase_migration"
    }
}

private class LegacyPlayBillingManager(
    context: Context,
    private val onPurchased: (productId: String, purchaseToken: String) -> Unit,
) : BillingManagerDelegate {
    private val appContext = context.applicationContext
    private val mutableState = MutableStateFlow(BillingUiState())
    override val state: StateFlow<BillingUiState> = mutableState

    private val billingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                purchases.orEmpty().filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .forEach(::processPurchase)
            } else if (result.responseCode != BillingClient.BillingResponseCode.USER_CANCELED) {
                reportBillingError("Purchase update failed", result)
            }
        }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    override fun connect() {
        if (billingClient.isReady) {
            queryProducts()
            queryExistingPurchases()
            return
        }
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    mutableState.value = mutableState.value.copy(connected = true, loading = true, error = null)
                    queryProducts()
                    queryExistingPurchases()
                } else {
                    logBillingResult("Billing setup failed", result)
                    mutableState.value = BillingUiState(error = userFacingError(), loading = false)
                }
            }

            override fun onBillingServiceDisconnected() {
                mutableState.value = mutableState.value.copy(connected = false)
            }
        })
    }

    override fun identify(userId: String?, migrateLegacyPurchase: Boolean) = Unit

    override fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) {
        val target = product.purchaseTarget as? BillingPurchaseTarget.GooglePlay ?: return
        val detailParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(target.details)
            .setOfferToken(target.offerToken)
            .build()
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(detailParams))
            .setObfuscatedAccountId(userId.sha256())
            .build()
        val result = billingClient.launchBillingFlow(activity, params)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            reportBillingError("Billing flow failed to launch", result)
        }
    }

    override fun restorePurchases() {
        if (billingClient.isReady) {
            queryExistingPurchases(isUserRestore = true)
        } else {
            mutableState.value = mutableState.value.copy(restoring = true, error = null)
            connect()
        }
    }

    override fun close() = billingClient.endConnection()

    private fun queryProducts() {
        val products = PlayBillingManager.PRODUCT_IDS.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        billingClient.queryProductDetailsAsync(
            QueryProductDetailsParams.newBuilder().setProductList(products).build(),
        ) { result, detailsResult ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                logBillingResult("Product query failed", result)
                mutableState.value = mutableState.value.copy(loading = false, error = userFacingError())
                return@queryProductDetailsAsync
            }
            val mapped = detailsResult.productDetailsList.mapNotNull { details ->
                val offers = details.subscriptionOfferDetails.orEmpty()
                val isAnnualProduct = details.productId == ANNUAL_PRODUCT_ID ||
                    details.productId.contains("year", ignoreCase = true)
                val offer = if (isAnnualProduct) {
                    offers.firstOrNull { candidate ->
                        candidate.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L }
                    } ?: offers.firstOrNull { it.offerId == null }
                } else {
                    offers.firstOrNull { candidate ->
                        candidate.offerId == null &&
                            candidate.pricingPhases.pricingPhaseList.none { it.priceAmountMicros == 0L }
                    } ?: offers.firstOrNull { candidate ->
                        candidate.pricingPhases.pricingPhaseList.none { it.priceAmountMicros == 0L }
                    }
                } ?: offers.firstOrNull() ?: return@mapNotNull null
                val phases = offer.pricingPhases.pricingPhaseList.map { phase ->
                    BillingPricingPhase(
                        formattedPrice = phase.formattedPrice,
                        priceAmountMicros = phase.priceAmountMicros,
                        priceCurrencyCode = phase.priceCurrencyCode,
                        billingPeriod = phase.billingPeriod,
                        billingCycleCount = phase.billingCycleCount,
                    )
                }
                val price = phases.lastOrNull()?.formattedPrice ?: return@mapNotNull null
                BillingProduct(
                    id = details.productId,
                    title = details.title,
                    description = details.description,
                    formattedPrice = price,
                    hasFreeTrial = phases.any { it.priceAmountMicros == 0L },
                    pricingPhases = phases,
                    purchaseTarget = BillingPurchaseTarget.GooglePlay(details, offer.offerToken),
                )
            }.sortedByProductOrder()
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
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    logBillingResult("Purchase restore failed", result)
                }
                mutableState.value = mutableState.value.copy(
                    restoring = false,
                    error = userFacingError().takeIf { result.responseCode != BillingClient.BillingResponseCode.OK },
                )
            }
        }
    }

    private fun processPurchase(purchase: Purchase) {
        purchase.products.firstOrNull { it in PlayBillingManager.RECOGNIZED_PRODUCT_IDS }
            ?.let { onPurchased(it, purchase.purchaseToken) }
    }

    private fun reportBillingError(operation: String, result: BillingResult) {
        logBillingResult(operation, result)
        mutableState.value = mutableState.value.copy(error = userFacingError())
    }

    private fun logBillingResult(operation: String, result: BillingResult) {
        Log.w(TAG, "$operation: code=${result.responseCode}, detail=${result.debugMessage}")
    }

    private fun userFacingError(): String = appContext.getString(R.string.subscription_billing_error)

    private companion object {
        const val TAG = "LegacyPlayBilling"
        const val ANNUAL_PRODUCT_ID = "com.chillnote.pro.yearly"
    }
}

private fun List<BillingProduct>.sortedByProductOrder(): List<BillingProduct> =
    sortedBy { PlayBillingManager.PRODUCT_IDS.indexOf(it.id).takeIf { index -> index >= 0 } ?: Int.MAX_VALUE }

private fun String.baseProductId(): String = substringBefore(':')

private fun String.sha256(): String = MessageDigest.getInstance("SHA-256")
    .digest(toByteArray()).joinToString("") { "%02x".format(it) }
