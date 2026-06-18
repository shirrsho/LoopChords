package com.practicechords.practice_chords

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 2x2 LoopChords home-screen widget.
 *
 * When 12+ hours have passed since the last practice (or you've never
 * practised), it shows a warm orange→red "Time to practice!" reminder.
 * Otherwise it shows a calm dark card with your lifetime practice total.
 * Both states display the total time you've ever practised.
 */
class PracticeWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val KEY_LAST_PRACTICE = "last_practice"
        private const val KEY_TOTAL_SECONDS = "total_practice_seconds"
        private const val REMIND_AFTER_MS = 12L * 60L * 60L * 1000L
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val now = System.currentTimeMillis()
        val last = widgetData.getString(KEY_LAST_PRACTICE, null)?.toLongOrNull()
        val totalSeconds = widgetData.getString(KEY_TOTAL_SECONDS, null)?.toLongOrNull() ?: 0L
        val overdue = last == null || (now - last) >= REMIND_AFTER_MS
        val totalLabel = formatTotal(totalSeconds)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.practice_widget)

            if (overdue) {
                views.setViewVisibility(R.id.reminder_state, View.VISIBLE)
                views.setViewVisibility(R.id.normal_state, View.GONE)
                views.setTextViewText(R.id.reminder_total, "$totalLabel total")
            } else {
                views.setViewVisibility(R.id.reminder_state, View.GONE)
                views.setViewVisibility(R.id.normal_state, View.VISIBLE)
                views.setTextViewText(R.id.total_time, totalLabel)
                views.setTextViewText(R.id.ok_subtitle, lastPractisedLabel(now - last!!))
            }

            // Tapping the widget opens the app.
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** "0m", "45m", "3h", or "12h 30m" — total time ever practised. */
    private fun formatTotal(totalSeconds: Long): String {
        val minutes = totalSeconds / 60L
        if (minutes < 60L) return "${minutes}m"
        val hours = minutes / 60L
        val rem = minutes % 60L
        return if (rem == 0L) "${hours}h" else "${hours}h ${rem}m"
    }

    private fun lastPractisedLabel(elapsedMs: Long): String {
        val minutes = elapsedMs / 60000L
        return when {
            minutes < 1L -> "just now"
            minutes < 60L -> "last: ${minutes}m ago"
            else -> "last: ${minutes / 60L}h ago"
        }
    }
}
