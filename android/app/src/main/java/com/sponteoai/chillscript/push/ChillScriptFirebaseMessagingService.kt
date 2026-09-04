package com.sponteoai.chillscript.push

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import androidx.annotation.StringRes
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.sponteoai.chillscript.MainActivity
import com.sponteoai.chillscript.R

class ChillScriptFirebaseMessagingService : FirebaseMessagingService() {
    @Suppress("OVERRIDE_DEPRECATION")
    override fun onNewToken(token: String) {
        PushNotificationManager.get(this).recordRegistration(token)
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onRegistered(installationId: String) {
        PushNotificationManager.get(this).recordRegistration(installationId)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val kind = message.data[PushContract.DATA_KIND] ?: return
        val resources = notificationResources(kind) ?: return
        showNotification(
            kind = kind,
            route = message.data[PushContract.DATA_ROUTE],
            noteId = message.data[PushContract.DATA_NOTE_ID],
            resources = resources,
        )
    }

    @SuppressLint("MissingPermission")
    private fun showNotification(
        kind: String,
        route: String?,
        noteId: String?,
        resources: NotificationResources,
    ) {
        if (!PushNotificationManager.hasNotificationPermission(this)) return
        PushNotificationManager.createNotificationChannel(this)
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            route?.let { putExtra(PushContract.DATA_ROUTE, it) }
            noteId?.let { putExtra(PushContract.DATA_NOTE_ID, it) }
            putExtra(PushContract.DATA_KIND, kind)
        }
        val notificationId = stableNotificationId(kind, noteId)
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val body = getString(resources.body)
        val notification = NotificationCompat.Builder(this, PushContract.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(getString(resources.title))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        NotificationManagerCompat.from(this).notify(notificationId, notification)
    }
}

internal data class NotificationResources(
    @StringRes val title: Int,
    @StringRes val body: Int,
)

internal fun notificationResources(kind: String): NotificationResources? = when (kind) {
    "import_ready" -> NotificationResources(
        R.string.notification_import_ready_title,
        R.string.notification_import_ready_body,
    )
    "first_creation" -> NotificationResources(
        R.string.notification_first_creation_title,
        R.string.notification_first_creation_body,
    )
    "weekly_topics_ready" -> NotificationResources(
        R.string.notification_weekly_topics_title,
        R.string.notification_weekly_topics_body,
    )
    else -> null
}

internal fun stableNotificationId(kind: String, noteId: String?): Int =
    "$kind:${noteId.orEmpty()}".hashCode() and Int.MAX_VALUE
