package com.sponteoai.chillscript.weekly

import kotlinx.serialization.SerializationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class WeeklyTopicsModelsTest {
    private val json = defaultWeeklyTopicsJson()

    @Test
    fun `dashboard decodes server payload including fractional dates`() {
        val dashboard = json.decodeFromString(
            WeeklyTopicDashboard.serializer(),
            dashboardJson(),
        )

        assertTrue(dashboard.settings.enabled)
        assertEquals(Instant.parse("2026-08-24T01:00:00.123Z"), dashboard.settings.nextRunAt)
        assertNull(dashboard.settings.lastPeriodEnd)
        assertTrue(dashboard.hasUnreadReport)
        assertEquals(3, dashboard.currentSourceCount)
        assertEquals(2, dashboard.minimumSourceCount)

        val report = requireNotNull(dashboard.latestReport)
        assertEquals(Instant.parse("2026-08-17T00:00:00Z"), report.periodStart)
        assertTrue(report.isUnread)
        assertTrue(report.canRegenerate)
        assertEquals(WeeklyTopicSourceAvailability.TRASHED, report.topics[0].sources[0].resolvedAvailability)
        assertEquals(WeeklyTopicSourceAvailability.ACTIVE, report.topics[0].sources[1].resolvedAvailability)
    }

    @Test
    fun `report derived state follows read and regeneration fields`() {
        val report = sampleReport(
            readAt = Instant.parse("2026-08-24T02:00:00Z"),
            regenerationCount = 1,
        )

        assertFalse(report.isUnread)
        assertFalse(report.canRegenerate)
    }

    @Test
    fun `settings payload uses server field names and values`() {
        val payload = WeeklyTopicSettingsPayload(
            enabled = true,
            weekday = 5,
            hour = 18,
            minute = 30,
            timeZone = "Asia/Shanghai",
            locale = "zh-Hans",
        )

        val encoded = json.encodeToString(WeeklyTopicSettingsPayload.serializer(), payload)

        assertTrue(encoded.contains("\"enabled\":true"))
        assertTrue(encoded.contains("\"weekday\":5"))
        assertTrue(encoded.contains("\"timeZone\":\"Asia/Shanghai\""))
        assertTrue(encoded.contains("\"locale\":\"zh-Hans\""))
    }

    @Test(expected = SerializationException::class)
    fun `invalid server timestamp fails decoding`() {
        json.decodeFromString(
            WeeklyTopicReport.serializer(),
            reportJson().replace("2026-08-17T00:00:00Z", "not-a-date"),
        )
    }
}

internal fun dashboardJson(): String = """
    {
      "settings": {
        "enabled": true,
        "weekday": 1,
        "hour": 9,
        "minute": 0,
        "timeZone": "Asia/Shanghai",
        "locale": "zh-Hans",
        "lastPeriodEnd": null,
        "nextRunAt": "2026-08-24T01:00:00.123Z"
      },
      "latestReport": ${reportJson()},
      "hasUnreadReport": true,
      "currentSourceCount": 3,
      "minimumSourceCount": 2,
      "futureServerField": "ignored"
    }
""".trimIndent()

internal fun reportJson(id: String = "report-1"): String = """
    {
      "id": "$id",
      "periodStart": "2026-08-17T00:00:00Z",
      "periodEnd": "2026-08-24T00:00:00.456Z",
      "sourceNoteCount": 2,
      "language": "en",
      "topics": [
        {
          "id": "topic-1",
          "title": "Turn saved examples into a stronger opening",
          "sources": [
            {
              "noteId": "note-1",
              "noteTitle": "Hook reference",
              "platformName": "TikTok",
              "excerpt": "The first three seconds set the promise.",
              "availability": "trashed"
            },
            {
              "noteId": "note-2",
              "noteTitle": "Second reference",
              "platformName": null,
              "excerpt": "A supporting example without availability."
            }
          ]
        }
      ],
      "readAt": null,
      "regenerationCount": 0,
      "createdAt": "2026-08-24T00:01:00Z"
    }
""".trimIndent()

internal fun sampleReport(
    id: String = "report-1",
    readAt: Instant? = null,
    regenerationCount: Int = 0,
): WeeklyTopicReport = WeeklyTopicReport(
    id = id,
    periodStart = Instant.parse("2026-08-17T00:00:00Z"),
    periodEnd = Instant.parse("2026-08-24T00:00:00Z"),
    sourceNoteCount = 2,
    language = "en",
    topics = listOf(
        WeeklyTopicItem(
            id = "topic-1",
            title = "A weekly topic",
            sources = listOf(
                WeeklyTopicSource(
                    noteId = "note-1",
                    noteTitle = "A source note",
                    platformName = "YouTube",
                    excerpt = "A source excerpt",
                ),
            ),
        ),
    ),
    readAt = readAt,
    regenerationCount = regenerationCount,
    createdAt = Instant.parse("2026-08-24T00:01:00Z"),
)

internal fun sampleDashboard(
    report: WeeklyTopicReport? = sampleReport(),
    enabled: Boolean = true,
): WeeklyTopicDashboard = WeeklyTopicDashboard(
    settings = WeeklyTopicSettings(
        enabled = enabled,
        weekday = 1,
        hour = 9,
        minute = 0,
        timeZone = "UTC",
        locale = "en",
    ),
    latestReport = report,
    hasUnreadReport = report?.isUnread == true,
    currentSourceCount = 2,
    minimumSourceCount = 2,
)
