package com.sponteoai.chillscript.weekly

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

fun interface WeeklyTopicsTokenProvider {
    suspend fun accessToken(): String?
}

enum class WeeklyTopicsDestination {
    DASHBOARD,
    HISTORY,
    REPORT,
}

enum class WeeklyTopicsOperation {
    LOAD,
    SAVE_SETTINGS,
    REGENERATE,
}

enum class WeeklyTopicsFailureReason {
    AUTH_REQUIRED,
    NOT_FOUND,
    CONFLICT,
    NETWORK,
    SERVER,
    INVALID_RESPONSE,
}

data class WeeklyTopicsFailure(
    val operation: WeeklyTopicsOperation,
    val reason: WeeklyTopicsFailureReason,
)

data class WeeklyTopicsUiState(
    val dashboard: WeeklyTopicDashboard? = null,
    val reports: List<WeeklyTopicReport> = emptyList(),
    val loadedReports: Map<String, WeeklyTopicReport> = emptyMap(),
    val destination: WeeklyTopicsDestination = WeeklyTopicsDestination.DASHBOARD,
    val selectedReportId: String? = null,
    val hasLoadedHistory: Boolean = false,
    val isInitialLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isHistoryLoading: Boolean = false,
    val isDetailLoading: Boolean = false,
    val isSavingSettings: Boolean = false,
    val isRegenerating: Boolean = false,
    val failure: WeeklyTopicsFailure? = null,
) {
    val selectedReport: WeeklyTopicReport?
        get() = selectedReportId?.let(loadedReports::get)
}

class WeeklyTopicsController(
    private val dataSource: WeeklyTopicsDataSource = WeeklyTopicsApi(),
    private val tokenProvider: WeeklyTopicsTokenProvider,
    private val now: () -> Instant = Instant::now,
) {
    private val mutableState = MutableStateFlow(WeeklyTopicsUiState())
    val state: StateFlow<WeeklyTopicsUiState> = mutableState.asStateFlow()

    private val dashboardMutex = Mutex()
    private val historyMutex = Mutex()
    private val reportMutex = Mutex()
    private val settingsMutex = Mutex()
    private val regenerationMutex = Mutex()

    suspend fun loadDashboard(forceRefresh: Boolean = false): Boolean = dashboardMutex.withLock {
        val hasDashboard = mutableState.value.dashboard != null
        if (hasDashboard && !forceRefresh) return@withLock true

        mutableState.update { current ->
            current.copy(
                isInitialLoading = !hasDashboard,
                isRefreshing = hasDashboard && forceRefresh,
                failure = null,
            )
        }
        try {
            val token = accessToken(WeeklyTopicsOperation.LOAD) ?: return@withLock false
            val dashboard = dataSource.dashboard(token)
            mutableState.update { current ->
                val latest = dashboard.latestReport
                current.copy(
                    dashboard = dashboard,
                    loadedReports = if (latest == null) {
                        current.loadedReports
                    } else {
                        current.loadedReports + (latest.id to latest)
                    },
                    failure = null,
                )
            }
            true
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            recordFailure(WeeklyTopicsOperation.LOAD, error)
            false
        } finally {
            mutableState.update { it.copy(isInitialLoading = false, isRefreshing = false) }
        }
    }

    suspend fun refreshCurrent(): Boolean = when (mutableState.value.destination) {
        WeeklyTopicsDestination.DASHBOARD -> loadDashboard(forceRefresh = true)
        WeeklyTopicsDestination.HISTORY -> loadHistory(forceRefresh = true)
        WeeklyTopicsDestination.REPORT -> {
            val reportId = mutableState.value.selectedReportId
            if (reportId == null) false else loadReport(reportId, forceRefresh = true)
        }
    }

    suspend fun openHistory(): Boolean {
        mutableState.update {
            it.copy(
                destination = WeeklyTopicsDestination.HISTORY,
                selectedReportId = null,
                failure = null,
            )
        }
        return loadHistory()
    }

    suspend fun loadHistory(forceRefresh: Boolean = false): Boolean = historyMutex.withLock {
        val current = mutableState.value
        if (current.hasLoadedHistory && !forceRefresh) return@withLock true
        mutableState.update {
            it.copy(
                isHistoryLoading = true,
                isRefreshing = forceRefresh && it.hasLoadedHistory,
                failure = null,
            )
        }
        try {
            val token = accessToken(WeeklyTopicsOperation.LOAD) ?: return@withLock false
            val reports = dataSource.reports(token)
            mutableState.update { state ->
                state.copy(
                    reports = reports,
                    loadedReports = state.loadedReports + reports.associateBy(WeeklyTopicReport::id),
                    hasLoadedHistory = true,
                    failure = null,
                )
            }
            true
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            recordFailure(WeeklyTopicsOperation.LOAD, error)
            false
        } finally {
            mutableState.update { it.copy(isHistoryLoading = false, isRefreshing = false) }
        }
    }

    suspend fun openReport(reportId: String): Boolean {
        mutableState.update {
            it.copy(
                destination = WeeklyTopicsDestination.REPORT,
                selectedReportId = reportId,
                failure = null,
            )
        }
        return loadReport(reportId)
    }

    suspend fun loadReport(reportId: String, forceRefresh: Boolean = false): Boolean {
        val report = reportMutex.withLock {
            val cached = mutableState.value.loadedReports[reportId]
            if (cached != null && !forceRefresh) return@withLock cached
            mutableState.update {
                it.copy(
                    isDetailLoading = cached == null,
                    isRefreshing = cached != null && forceRefresh,
                    failure = null,
                )
            }
            try {
                val token = accessToken(WeeklyTopicsOperation.LOAD) ?: return@withLock null
                dataSource.report(token, reportId).also { loaded ->
                    mutableState.update { state -> state.withUpdatedReport(loaded).copy(failure = null) }
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                recordFailure(WeeklyTopicsOperation.LOAD, error)
                null
            } finally {
                mutableState.update { it.copy(isDetailLoading = false, isRefreshing = false) }
            }
        }
        if (report != null) markRead(report)
        return report != null
    }

    fun navigateBack(): Boolean {
        val current = mutableState.value
        return when (current.destination) {
            WeeklyTopicsDestination.DASHBOARD -> false
            WeeklyTopicsDestination.HISTORY -> {
                mutableState.update {
                    it.copy(
                        destination = WeeklyTopicsDestination.DASHBOARD,
                        selectedReportId = null,
                        failure = null,
                    )
                }
                true
            }
            WeeklyTopicsDestination.REPORT -> {
                mutableState.update {
                    it.copy(
                        destination = WeeklyTopicsDestination.HISTORY,
                        selectedReportId = null,
                        failure = null,
                    )
                }
                true
            }
        }
    }

    suspend fun saveSettings(
        enabled: Boolean,
        weekday: Int,
        hour: Int,
        minute: Int,
        timeZone: String = ZoneId.systemDefault().id,
        locale: String = Locale.getDefault().toLanguageTag(),
    ): Boolean = settingsMutex.withLock {
        mutableState.update { it.copy(isSavingSettings = true, failure = null) }
        try {
            val token = accessToken(WeeklyTopicsOperation.SAVE_SETTINGS) ?: return@withLock false
            val settings = dataSource.updateSettings(
                accessToken = token,
                payload = WeeklyTopicSettingsPayload(
                    enabled = enabled,
                    weekday = weekday.coerceIn(1, 7),
                    hour = hour.coerceIn(0, 23),
                    minute = minute.coerceIn(0, 59),
                    timeZone = timeZone,
                    locale = locale,
                ),
            )
            mutableState.update { current ->
                current.copy(
                    dashboard = current.dashboard?.copy(settings = settings),
                    failure = null,
                )
            }
            if (mutableState.value.dashboard == null) loadDashboard(forceRefresh = true)
            true
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            recordFailure(WeeklyTopicsOperation.SAVE_SETTINGS, error)
            false
        } finally {
            mutableState.update { it.copy(isSavingSettings = false) }
        }
    }

    suspend fun markLatestRead() {
        mutableState.value.dashboard?.latestReport?.let { report -> markRead(report) }
    }

    suspend fun markRead(report: WeeklyTopicReport) {
        if (!report.isUnread) return
        val token = try {
            tokenProvider.accessToken()?.trim().orEmpty()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            return
        }
        if (token.isEmpty()) return
        try {
            dataSource.markRead(token, report.id)
            val updated = report.copy(readAt = now())
            mutableState.update { state -> state.withUpdatedReport(updated) }
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // Read receipts are best effort and must not interrupt reading the report.
        }
    }

    suspend fun regenerate(report: WeeklyTopicReport): WeeklyTopicReport? = regenerationMutex.withLock {
        if (!report.canRegenerate) {
            mutableState.update {
                it.copy(
                    failure = WeeklyTopicsFailure(
                        operation = WeeklyTopicsOperation.REGENERATE,
                        reason = WeeklyTopicsFailureReason.CONFLICT,
                    ),
                )
            }
            return@withLock null
        }
        mutableState.update { it.copy(isRegenerating = true, failure = null) }
        try {
            val token = accessToken(WeeklyTopicsOperation.REGENERATE) ?: return@withLock null
            dataSource.regenerate(token, report.id).also { updated ->
                mutableState.update { state -> state.withUpdatedReport(updated).copy(failure = null) }
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            recordFailure(WeeklyTopicsOperation.REGENERATE, error)
            null
        } finally {
            mutableState.update { it.copy(isRegenerating = false) }
        }
    }

    fun clearFailure() {
        mutableState.update { it.copy(failure = null) }
    }

    private suspend fun accessToken(operation: WeeklyTopicsOperation): String? {
        val token = try {
            tokenProvider.accessToken()?.trim()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            null
        }
        if (token.isNullOrEmpty()) {
            mutableState.update {
                it.copy(
                    failure = WeeklyTopicsFailure(
                        operation = operation,
                        reason = WeeklyTopicsFailureReason.AUTH_REQUIRED,
                    ),
                )
            }
            return null
        }
        return token
    }

    private fun recordFailure(operation: WeeklyTopicsOperation, error: Exception) {
        val reason = when ((error as? WeeklyTopicsApiException)?.reason) {
            WeeklyTopicsApiError.UNAUTHORIZED -> WeeklyTopicsFailureReason.AUTH_REQUIRED
            WeeklyTopicsApiError.NOT_FOUND -> WeeklyTopicsFailureReason.NOT_FOUND
            WeeklyTopicsApiError.CONFLICT -> WeeklyTopicsFailureReason.CONFLICT
            WeeklyTopicsApiError.NETWORK -> WeeklyTopicsFailureReason.NETWORK
            WeeklyTopicsApiError.INVALID_URL,
            WeeklyTopicsApiError.INVALID_RESPONSE -> WeeklyTopicsFailureReason.INVALID_RESPONSE
            WeeklyTopicsApiError.SERVER -> WeeklyTopicsFailureReason.SERVER
            null -> WeeklyTopicsFailureReason.NETWORK
        }
        mutableState.update { it.copy(failure = WeeklyTopicsFailure(operation, reason)) }
    }
}

private fun WeeklyTopicsUiState.withUpdatedReport(report: WeeklyTopicReport): WeeklyTopicsUiState {
    val updatedDashboard = dashboard?.let { currentDashboard ->
        if (currentDashboard.latestReport?.id == report.id) {
            currentDashboard.copy(
                latestReport = report,
                hasUnreadReport = report.isUnread,
            )
        } else {
            currentDashboard
        }
    }
    val reportIndex = reports.indexOfFirst { it.id == report.id }
    val updatedReports = if (reportIndex < 0) {
        reports
    } else {
        reports.toMutableList().also { it[reportIndex] = report }
    }
    return copy(
        dashboard = updatedDashboard,
        reports = updatedReports,
        loadedReports = loadedReports + (report.id to report),
    )
}
