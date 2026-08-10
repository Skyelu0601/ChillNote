package com.sponteoai.chillscript.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.sponteoai.chillscript.MainActivity
import com.sponteoai.chillscript.R

class BrainDumpWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { widgetId ->
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("chillscript://record?source=home_widget"), context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val views = RemoteViews(context.packageName, R.layout.widget_brain_dump).apply {
                setOnClickPendingIntent(R.id.brain_dump_widget_root, pendingIntent)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
