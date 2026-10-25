package com.workoutapp.workout_timer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_streak_tracker).apply {
                val streakCount = widgetData.getInt("streak_count", 0)
                val statusText = widgetData.getString("streak_status", "Время для тренировки!") ?: "Время для тренировки!"
                val statsText = widgetData.getString("streak_stats", "0 тренировок на этой неделе") ?: "0 тренировок на этой неделе"
                
                setTextViewText(R.id.tv_streak_count, "$streakCount ДНЕЙ")
                setTextViewText(R.id.tv_streak_status, statusText)
                setTextViewText(R.id.tv_streak_stats, statsText)

                // Days of week highlights (format: "1,3,5" -> Mon, Wed, Fri active)
                val activeDays = widgetData.getString("week_active_days", "") ?: ""
                val daysSet = activeDays.split(",").filter { it.isNotEmpty() }.toSet()

                val dayViewIds = listOf(
                    R.id.dot_mon to "1",
                    R.id.dot_tue to "2",
                    R.id.dot_wed to "3",
                    R.id.dot_thu to "4",
                    R.id.dot_fri to "5",
                    R.id.dot_sat to "6",
                    R.id.dot_sun to "7"
                )

                dayViewIds.forEach { (viewId, dayNumber) ->
                    val isCompleted = daysSet.contains(dayNumber)
                    if (isCompleted) {
                        setTextColor(viewId, android.graphics.Color.parseColor("#10B981"))
                    } else {
                        setTextColor(viewId, android.graphics.Color.parseColor("#64748B"))
                    }
                }

                // Intent to open app
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("workout://open_history")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_streak_container, pendingIntent)
                setOnClickPendingIntent(R.id.btn_streak_open, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
