package com.sponteoai.chillscript.weekly

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class WeeklyTopicsControllerTest {
    private val readTime = Instant.parse("2026-08-24T03:00:00Z")

    @Test
    fun `initial load stores dashboard and latest report`() = runTest {
        val dataSource = FakeWeeklyTopicsDataSource()
        val controller = controller(dataSource)

        assertTrue(controller.loadDashboard())

        val state = controller.state.value
        assertEquals(dataSource.dashboardResponse, state.dashboard)
        assertEquals(dataSource.dashboardResponse.latestReport, state.loadedReports["report-1"])
        assertFalse(state.isInitialLoading)
        assertFalse(state.isRefreshing)
        assertNull(state.failure)
        assertEquals(1, dataSource.dashboardCalls)
    }

    @Test
    fun `parallel initial loads are deduplicated`() = runTest {
        val dataSource = FakeWeeklyTopicsDataSource(dashboardDelayMillis = 100)
        val controller = controller(dataSource)

        val first = async { controller.loadDashboard() }
        val second = async { controller.loadDashboard() }

        assertTrue(first.await())
        assertTrue(second.await())
        assertEquals(1, dataSource.dashboardCalls)
    }

    @Test
    fun `missing session becomes semantic auth failure and clears loading`() = runTest {
        val controller = WeeklyTopicsController(
            dataSource = FakeWeeklyTopicsDataSource(),
            tokenProvider = WeeklyTopicsTokenProvider { null },
        )

        assertFalse(controller.loadDashboard())

        assertEquals(
            WeeklyTopicsFailure(WeeklyTopicsOperation.LOAD, WeeklyTopicsFailureReason.AUTH_REQUIRED),
            controller.state.value.failure,
        )
        assertFalse(controller.state.value.isInitialLoading)
    }

    @Test
    fun `failed refresh keeps previously loaded dashboard`() = runTest {
        val dataSource = FakeWeeklyTopicsDataSource()
        val controller = controller(dataSource)
        controller.loadDashboard()
        val original = controller.state.value.dashboard
        dataSource.dashboardFailure = WeeklyTopicsApiException(WeeklyTopicsApiError.NETWORK)

        assertFalse(controller.loadDashboard(forceRefresh = true))

        assertEquals(original, controller.state.value.dashboard)
        assertEquals(WeeklyTopicsFailureReason.NETWORK, controller.state.value.failure?.reason)
        assertEquals(WeeklyTopicsOperation.LOAD, controller.state.value.failure?.operation)
        assertFalse(controller.state.value.isRefreshing)
    }

    @Test
    fun `history report opens from cache and read receipt updates every copy`() = runTest {
        val unread = sampleReport()
        val dataSource = FakeWeeklyTopicsDataSource(
            dashboardResponse = sampleDashboard(unread),
            reportsResponse = listOf(unread),
        )
        val controller = controller(dataSource)
        controller.loadDashboard()

        assertTrue(controller.openHistory())
        assertEquals(WeeklyTopicsDestination.HISTORY, controller.state.value.destination)
        assertTrue(controller.openReport(unread.id))

        val state = controller.state.value
        assertEquals(WeeklyTopicsDestination.REPORT, state.destination)
        assertEquals(readTime, state.selectedReport?.readAt)
        assertEquals(readTime, state.dashboard?.latestReport?.readAt)
        assertFalse(state.dashboard?.hasUnreadReport ?: true)
        assertEquals(readTime, state.reports.single().readAt)
        assertEquals(listOf(unread.id), dataSource.markReadIds)
        assertEquals(0, dataSource.reportCalls)
    }

    @Test
    fun `detail missing from cache is loaded then marked read`() = runTest {
        val requested = sampleReport(id = "report-2")
        val dataSource = FakeWeeklyTopicsDataSource(reportResponse = requested)
        val controller = controller(dataSource)

        assertTrue(controller.openReport(requested.id))

        assertEquals(1, dataSource.reportCalls)
        assertEquals(requested.id, dataSource.lastReportId)
        assertEquals(readTime, controller.state.value.selectedReport?.readAt)
    }

    @Test
    fun `regeneration replaces dashboard cache and history`() = runTest {
        val original = sampleReport()
        val regenerated = original.copy(
            topics = listOf(original.topics.single().copy(title = "A reorganized topic")),
            regenerationCount = 1,
            readAt = null,
        )
        val dataSource = FakeWeeklyTopicsDataSource(
            dashboardResponse = sampleDashboard(original),
            reportsResponse = listOf(original),
            regenerateResponse = regenerated,
        )
        val controller = controller(dataSource)
        controller.loadDashboard()
        controller.openHistory()

        assertEquals(regenerated, controller.regenerate(original))

        val state = controller.state.value
        assertEquals(regenerated, state.dashboard?.latestReport)
        assertEquals(regenerated, state.loadedReports[original.id])
        assertEquals(regenerated, state.reports.single())
        assertTrue(state.dashboard?.hasUnreadReport == true)
        assertFalse(state.isRegenerating)
    }

    @Test
    fun `second regeneration is rejected without network request`() = runTest {
        val report = sampleReport(regenerationCount = 1)
        val dataSource = FakeWeeklyTopicsDataSource()
        val controller = controller(dataSource)

        assertNull(controller.regenerate(report))

        assertEquals(0, dataSource.regenerateCalls)
        assertEquals(WeeklyTopicsOperation.REGENERATE, controller.state.value.failure?.operation)
        assertEquals(WeeklyTopicsFailureReason.CONFLICT, controller.state.value.failure?.reason)
    }

    @Test
    fun `settings values are bounded and returned settings update dashboard`() = runTest {
        val dataSource = FakeWeeklyTopicsDataSource()
        val controller = controller(dataSource)
        controller.loadDashboard()

        assertTrue(
            controller.saveSettings(
                enabled = true,
                weekday = 99,
                hour = -4,
                minute = 72,
                timeZone = "Asia/Shanghai",
                locale = "zh-Hans",
            ),
        )

        val payload = requireNotNull(dataSource.lastSettingsPayload)
        assertEquals(7, payload.weekday)
        assertEquals(0, payload.hour)
        assertEquals(59, payload.minute)
        assertEquals(dataSource.settingsResponse, controller.state.value.dashboard?.settings)
        assertFalse(controller.state.value.isSavingSettings)
    }

    @Test
    fun `navigation back stays inside weekly topics before closing route`() = runTest {
        val controller = controller(FakeWeeklyTopicsDataSource())
        controller.openHistory()
        controller.openReport("report-1")

        assertTrue(controller.navigateBack())
        assertEquals(WeeklyTopicsDestination.HISTORY, controller.state.value.destination)
        assertTrue(controller.navigateBack())
        assertEquals(WeeklyTopicsDestination.DASHBOARD, controller.state.value.destination)
        assertFalse(controller.navigateBack())
    }

    private fun controller(dataSource: FakeWeeklyTopicsDataSource): WeeklyTopicsController =
        WeeklyTopicsController(
            dataSource = dataSource,
            tokenProvider = WeeklyTopicsTokenProvider { "access-token" },
            now = { readTime },
        )
}

private class FakeWeeklyTopicsDataSource(
    var dashboardResponse: WeeklyTopicDashboard = sampleDashboard(),
    var reportsResponse: List<WeeklyTopicReport> = emptyList(),
    var reportResponse: WeeklyTopicReport = sampleReport(),
    var regenerateResponse: WeeklyTopicReport = sampleReport(regenerationCount = 1),
    val settingsResponse: WeeklyTopicSettings = WeeklyTopicSettings(
        enabled = true,
        weekday = 7,
        hour = 0,
        minute = 59,
        timeZone = "Asia/Shanghai",
        locale = "zh-Hans",
    ),
    private val dashboardDelayMillis: Long = 0,
) : WeeklyTopicsDataSource {
    var dashboardCalls = 0
    var reportCalls = 0
    var regenerateCalls = 0
    var dashboardFailure: Exception? = null
    var lastReportId: String? = null
    var lastSettingsPayload: WeeklyTopicSettingsPayload? = null
    val markReadIds = mutableListOf<String>()

    override suspend fun dashboard(accessToken: String): WeeklyTopicDashboard {
        dashboardCalls += 1
        if (dashboardDelayMillis > 0) delay(dashboardDelayMillis)
        dashboardFailure?.let { throw it }
        return dashboardResponse
    }

    override suspend fun updateSettings(
        accessToken: String,
        payload: WeeklyTopicSettingsPayload,
    ): WeeklyTopicSettings {
        lastSettingsPayload = payload
        return settingsResponse
    }

    override suspend fun reports(accessToken: String, limit: Int): List<WeeklyTopicReport> = reportsResponse

    override suspend fun report(accessToken: String, reportId: String): WeeklyTopicReport {
        reportCalls += 1
        lastReportId = reportId
        return reportResponse
    }

    override suspend fun markRead(accessToken: String, reportId: String) {
        markReadIds += reportId
    }

    override suspend fun regenerate(accessToken: String, reportId: String): WeeklyTopicReport {
        regenerateCalls += 1
        return regenerateResponse
    }
}
