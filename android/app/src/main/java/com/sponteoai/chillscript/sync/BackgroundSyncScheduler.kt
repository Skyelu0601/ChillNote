package com.sponteoai.chillscript.sync

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

internal enum class BackgroundSyncSchedule {
    PERIODIC,
    FOREGROUND,
    LINK_IMPORT,
}

internal enum class BackgroundSyncUniquePolicy {
    KEEP,
    APPEND_OR_REPLACE,
}

internal data class BackgroundSyncScheduleSpec(
    val uniqueName: String,
    val schedule: BackgroundSyncSchedule,
    val uniquePolicy: BackgroundSyncUniquePolicy,
    val requiresConnectedNetwork: Boolean = true,
    val backoffPolicy: BackoffPolicy = BackoffPolicy.EXPONENTIAL,
    val backoffDelaySeconds: Long = 30L,
    val repeatIntervalMinutes: Long? = null,
)

internal fun backgroundSyncScheduleSpec(schedule: BackgroundSyncSchedule): BackgroundSyncScheduleSpec = when (schedule) {
    BackgroundSyncSchedule.PERIODIC -> BackgroundSyncScheduleSpec(
        uniqueName = "chillscript.periodic-sync",
        schedule = schedule,
        uniquePolicy = BackgroundSyncUniquePolicy.KEEP,
        repeatIntervalMinutes = 15L,
    )
    BackgroundSyncSchedule.FOREGROUND -> BackgroundSyncScheduleSpec(
        uniqueName = "chillscript.foreground-sync",
        schedule = schedule,
        uniquePolicy = BackgroundSyncUniquePolicy.KEEP,
    )
    BackgroundSyncSchedule.LINK_IMPORT -> BackgroundSyncScheduleSpec(
        uniqueName = "chillscript.link-import-recovery",
        schedule = schedule,
        uniquePolicy = BackgroundSyncUniquePolicy.APPEND_OR_REPLACE,
    )
}

object BackgroundSyncScheduler {
    fun ensurePeriodic(context: Context) {
        val spec = backgroundSyncScheduleSpec(BackgroundSyncSchedule.PERIODIC)
        val request = PeriodicWorkRequestBuilder<BackgroundSyncWorker>(
            requireNotNull(spec.repeatIntervalMinutes),
            TimeUnit.MINUTES,
        )
            .setConstraints(spec.constraints())
            .setBackoffCriteria(spec.backoffPolicy, spec.backoffDelaySeconds, TimeUnit.SECONDS)
            .addTag(WORK_TAG)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
            spec.uniqueName,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    fun enqueueForegroundSync(context: Context) {
        enqueueOneTime(context, backgroundSyncScheduleSpec(BackgroundSyncSchedule.FOREGROUND))
    }

    fun enqueueLinkImportRecovery(context: Context) {
        enqueueOneTime(context, backgroundSyncScheduleSpec(BackgroundSyncSchedule.LINK_IMPORT))
    }

    private fun enqueueOneTime(context: Context, spec: BackgroundSyncScheduleSpec) {
        val request = OneTimeWorkRequestBuilder<BackgroundSyncWorker>()
            .setConstraints(spec.constraints())
            .setBackoffCriteria(spec.backoffPolicy, spec.backoffDelaySeconds, TimeUnit.SECONDS)
            .addTag(WORK_TAG)
            .build()
        val policy = when (spec.uniquePolicy) {
            BackgroundSyncUniquePolicy.KEEP -> ExistingWorkPolicy.KEEP
            BackgroundSyncUniquePolicy.APPEND_OR_REPLACE -> ExistingWorkPolicy.APPEND_OR_REPLACE
        }
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(spec.uniqueName, policy, request)
    }

    private fun BackgroundSyncScheduleSpec.constraints(): Constraints = Constraints.Builder()
        .setRequiredNetworkType(if (requiresConnectedNetwork) NetworkType.CONNECTED else NetworkType.NOT_REQUIRED)
        .build()

    private const val WORK_TAG = "chillscript.background-sync"
}
