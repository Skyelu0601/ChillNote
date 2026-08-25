package com.sponteoai.chillscript.push

import com.sponteoai.chillscript.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationContentTest {
    @Test
    fun `all supported delivery kinds use semantic Android resources`() {
        assertEquals(
            NotificationResources(
                R.string.notification_import_ready_title,
                R.string.notification_import_ready_body,
            ),
            notificationResources("import_ready"),
        )
        assertEquals(
            NotificationResources(
                R.string.notification_first_creation_title,
                R.string.notification_first_creation_body,
            ),
            notificationResources("first_creation"),
        )
        assertEquals(
            NotificationResources(
                R.string.notification_weekly_topics_title,
                R.string.notification_weekly_topics_body,
            ),
            notificationResources("weekly_topics_ready"),
        )
        assertNull(notificationResources("removed_kind"))
    }

    @Test
    fun `notification identity collapses duplicates but separates notes`() {
        val first = stableNotificationId("import_ready", "note-1")
        assertEquals(first, stableNotificationId("import_ready", "note-1"))
        assertNotEquals(first, stableNotificationId("import_ready", "note-2"))
    }
}
