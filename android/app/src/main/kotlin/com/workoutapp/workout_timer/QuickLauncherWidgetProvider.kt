package com.workoutapp.workout_timer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class QuickLauncherWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_launcher).apply {
                val workout1Id = widgetData.getInt("workout_1_id", -1)
                val workout1Name = widgetData.getString("workout_1_name", "ВИТ") ?: "ВИТ"
                val workout1Info = widgetData.getString("workout_1_info", "▶ СТАРТ") ?: "▶ СТАРТ"

                val workout2Id = widgetData.getInt("workout_2_id", -1)
                val workout2Name = widgetData.getString("workout_2_name", "ТАБАТА") ?: "ТАБАТА"
                val workout2Info = widgetData.getString("workout_2_info", "▶ СТАРТ") ?: "▶ СТАРТ"

                setTextViewText(R.id.tv_workout_1_name, workout1Name)
                setTextViewText(R.id.tv_workout_1_info, workout1Info)

                setTextViewText(R.id.tv_workout_2_name, workout2Name)
                setTextViewText(R.id.tv_workout_2_info, workout2Info)

                // Intent for General App open
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("workout://open_home")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val appPendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId * 10,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_launcher_app, appPendingIntent)

                // Intent for Workout 1
                val w1Intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("workout://launch?id=$workout1Id")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val w1PendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId * 10 + 1,
                    w1Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_workout_slot_1, w1PendingIntent)

                // Intent for Workout 2
                val w2Intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("workout://launch?id=$workout2Id")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val w2PendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId * 10 + 2,
                    w2Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_workout_slot_2, w2PendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
