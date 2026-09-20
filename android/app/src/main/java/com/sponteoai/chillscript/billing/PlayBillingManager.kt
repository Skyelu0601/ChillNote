package com.sponteoai.chillscript.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.InAppMessageParams
import com.android.billingclient.api.InAppMessageResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.getOfferingsWith
import com.revenuecat.purchases.getCustomerInfoWith
import com.revenuecat.purchases.logInWith
import com.revenuecat.purchases.purchaseWith
import com.revenuecat.purchases.restorePurchasesWith
import com.revenuecat.purchases.syncAttributesAndOfferingsIfNeededWith
import com.revenuecat.purchases.syncPurchasesWith
import com.revenuecat.purchases.models.StoreProduct
import com.revenuecat.purchases.models.InAppMessageType
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.analytics.AppsFlyerService
import com.sponteoai.chillscript.analytics.ProductAnalytics
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.lang.ref.WeakReference
import java.security.MessageDigest
import java.util.Locale

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
    fun identify(userId: String?, migrateLegacyPurchase: Boolean) {
        delegate.identify(userId, migrateLegacyPurchase)
    }
    fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) =
        delegate.launchPurchase(activity, product, userId)
    fun restorePurchases() = delegate.restorePurchases()
    fun showInAppMessages(activity: Activity) = delegate.showInAppMessages(activity)
    fun close() = delegate.close()

    companion object {
        const val ANNUAL_PRODUCT_ID = "com.chillnote.pro.yearly"
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
    fun showInAppMessages(activity: Activity)
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
    private var assignedOfferingIdentifier: String? = null
    private var assignedAnnualBasePlanId: String? = null

    override fun connect() {
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener {
            onRestoreComplete()
        }
        mutableState.value = mutableState.value.copy(
            connected = true,
            loading = true,
            products = emptyList(),
            error = null,
        )
        val offeringIdentifier = assignedOfferingIdentifier
        val annualBasePlanId = assignedAnnualBasePlanId
        if (offeringIdentifier != null && annualBasePlanId != null) {
            queryProducts(offeringIdentifier, annualBasePlanId)
        }
    }

    override fun identify(userId: String?, migrateLegacyPurchase: Boolean) {
        if (userId.isNullOrBlank()) {
            assignedOfferingIdentifier = null
            assignedAnnualBasePlanId = null
            mutableState.value = mutableState.value.copy(
                loading = false,
                products = emptyList(),
                error = null,
            )
            return
        }
        AppsFlyerService.identify(appContext, userId)
        val offeringIdentifier = AnnualPriceExperiment.offeringIdentifierFor(userId)
        val annualBasePlanId = AnnualPriceExperiment.annualBasePlanIdFor(userId)
        assignedOfferingIdentifier = offeringIdentifier
        assignedAnnualBasePlanId = annualBasePlanId
        mutableState.value = mutableState.value.copy(
            loading = true,
            products = emptyList(),
            error = null,
        )
        ensureIdentity(userId) {
            Purchases.sharedInstance.setAttributes(
                mapOf("annual_price_variant" to AnnualPriceExperiment.variantFor(userId)),
            )
            if (migrateLegacyPurchase) syncLegacyPurchasesOnce(userId)
            Purchases.sharedInstance.syncAttributesAndOfferingsIfNeededWith(
                onError = { error ->
                    Log.w(TAG, "RevenueCat price variant sync failed: ${error.code}")
                    queryProducts(offeringIdentifier, annualBasePlanId)
                },
                onSuccess = { queryProducts(offeringIdentifier, annualBasePlanId) },
            )
        }
    }

    override fun launchPurchase(activity: Activity, product: BillingProduct, userId: String) {
        ensureIdentity(userId) {
            Purchases.sharedInstance.setAttributes(ProductAnalytics.currentRevenueCatPurchaseAttributes())
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
                    if (userCancelled) {
                        ProductAnalytics.completePurchase("purchase_cancelled")
                    } else {
                        ProductAnalytics.completePurchase(
                            "purchase_failed", "store_error",
                            billingProvider = "revenuecat",
                            billingErrorCode = error.code.name,
                            billingStage = "purchase",
                        )
                        reportError("RevenueCat purchase failed: ${error.code}")
                    }
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
                        ProductAnalytics.clearPurchaseAttribution()
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

    override fun showInAppMessages(activity: Activity) {
        Purchases.sharedInstance.showInAppMessagesIfNeeded(
            activity,
            listOf(InAppMessageType.BILLING_ISSUES),
        )
    }

    override fun close() {
        Purchases.sharedInstance.removeUpdatedCustomerInfoListener()
    }

    private fun ensureIdentity(userId: String, onReady: () -> Unit) {
        val purchases = Purchases.sharedInstance
        if (purchases.appUserID == userId) {
            purchases.setPostHogUserId(userId.lowercase(Locale.ROOT))
            onReady()
            return
        }
        purchases.logInWith(
            appUserID = userId,
            onError = { error -> reportError("RevenueCat user identification failed: ${error.code}") },
            onSuccess = { _, _ ->
                purchases.setPostHogUserId(userId.lowercase(Locale.ROOT))
                onReady()
            },
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

    private fun queryProducts(offeringIdentifier: String, annualBasePlanId: String) {
        Purchases.sharedInstance.getOfferingsWith(
            onError = {
                if (assignedOfferingIdentifier == offeringIdentifier) {
                    reportError("RevenueCat assigned offering unavailable: ${it.code}")
                }
            },
            onSuccess = { offerings ->
                if (assignedOfferingIdentifier != offeringIdentifier ||
                    assignedAnnualBasePlanId != annualBasePlanId
                ) return@getOfferingsWith
                val products = offerings.getOffering(offeringIdentifier)?.availablePackages
                    .orEmpty()
                    .mapNotNull { billingProduct(it, annualBasePlanId) }
                    .distinctBy(BillingProduct::id)
                    .sortedByProductOrder()
                publishProducts(products)
            },
        )
    }

    private fun billingProduct(
        packageToPurchase: Package,
        annualBasePlanId: String,
    ): BillingProduct? {
        val storeProduct = packageToPurchase.product
        val productId = storeProduct.id.baseProductId()
        if (productId == PlayBillingManager.ANNUAL_PRODUCT_ID &&
            storeProduct.defaultOption?.id?.substringBefore(':') != annualBasePlanId
        ) {
            Log.w(TAG, "Ignoring annual product from mismatched base plan")
            return null
        }
        return billingProduct(
            storeProduct = packageToPurchase.product,
            target = BillingPurchaseTarget.RevenueCatPackage(packageToPurchase),
        )
    }

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
        mutableState.value = mutableState.value.copy(
            loading = false,
            products = emptyList(),
            error = userFacingError(),
        )
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
    private var pendingInAppMessageActivity: WeakReference<Activity>? = null
    private var connectionInProgress = false
    private var assignedAnnualBasePlanId: String? = null

    private val billingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                purchases.orEmpty().filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .forEach(::processPurchase)
            } else if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
                ProductAnalytics.completePurchase("purchase_cancelled")
            } else {
                ProductAnalytics.completePurchase(
                    "purchase_failed", "store_error",
                    billingProvider = "google_play",
                    billingErrorCode = result.responseCode.toString(),
                    billingStage = "purchase_update",
                )
                reportBillingError("Purchase update failed", result)
            }
        }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    override fun connect() {
        if (billingClient.isReady) {
            assignedAnnualBasePlanId?.let { queryProducts() }
            queryExistingPurchases()
            showPendingInAppMessages()
            return
        }
        if (connectionInProgress) return
        connectionInProgress = true
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                connectionInProgress = false
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    mutableState.value = mutableState.value.copy(connected = true, loading = true, error = null)
                    assignedAnnualBasePlanId?.let { queryProducts() }
                    queryExistingPurchases()
                    showPendingInAppMessages()
                } else {
                    logBillingResult("Billing setup failed", result)
                    mutableState.value = BillingUiState(error = userFacingError(), loading = false)
                }
            }

            override fun onBillingServiceDisconnected() {
                connectionInProgress = false
                mutableState.value = mutableState.value.copy(connected = false)
            }
        })
    }

    override fun identify(userId: String?, migrateLegacyPurchase: Boolean) {
        if (userId.isNullOrBlank()) {
            assignedAnnualBasePlanId = null
            mutableState.value = mutableState.value.copy(
                loading = false,
                products = emptyList(),
                error = null,
            )
            return
        }
        assignedAnnualBasePlanId = AnnualPriceExperiment.annualBasePlanIdFor(userId)
        mutableState.value = mutableState.value.copy(
            loading = true,
            products = emptyList(),
            error = null,
        )
        if (billingClient.isReady) queryProducts() else connect()
    }

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
            ProductAnalytics.completePurchase(
                "purchase_failed", "flow_launch_failed",
                billingProvider = "google_play",
                billingErrorCode = result.responseCode.toString(),
                billingStage = "flow_launch",
            )
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

    override fun showInAppMessages(activity: Activity) {
        pendingInAppMessageActivity = WeakReference(activity)
        if (billingClient.isReady) showPendingInAppMessages() else connect()
    }

    override fun close() {
        pendingInAppMessageActivity = null
        billingClient.endConnection()
    }

    private fun showPendingInAppMessages() {
        val activity = pendingInAppMessageActivity?.get() ?: return
        pendingInAppMessageActivity = null
        if (activity.isFinishing || activity.isDestroyed) return
        val supported = billingClient.isFeatureSupported(BillingClient.FeatureType.IN_APP_MESSAGING)
        if (supported.responseCode != BillingClient.BillingResponseCode.OK) {
            logBillingResult("Google Play in-app messaging is unavailable", supported)
            return
        }
        val params = InAppMessageParams.newBuilder()
            .addInAppMessageCategoryToShow(InAppMessageParams.InAppMessageCategoryId.TRANSACTIONAL)
            .build()
        val result = billingClient.showInAppMessages(activity, params) { messageResult ->
            if (messageResult.responseCode ==
                InAppMessageResult.InAppMessageResponseCode.SUBSCRIPTION_STATUS_UPDATED
            ) {
                queryExistingPurchases()
            }
        }
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            logBillingResult("Google Play in-app messaging failed to launch", result)
        }
    }

    private fun queryProducts() {
        val annualBasePlanId = assignedAnnualBasePlanId ?: return
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
                        candidate.basePlanId == annualBasePlanId &&
                            candidate.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L }
                    } ?: offers.firstOrNull { candidate ->
                        candidate.basePlanId == annualBasePlanId && candidate.offerId == null
                    } ?: offers.firstOrNull { candidate ->
                        candidate.basePlanId == annualBasePlanId
                    }
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
            ?.let {
                onPurchased(it, purchase.purchaseToken)
                ProductAnalytics.clearPurchaseAttribution()
            }
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
