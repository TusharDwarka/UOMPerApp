package com.example.uom_per_app

import android.appwidget.AppWidgetManager
import android.util.Log
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Calendar

import es.antonborri.home_widget.HomeWidgetPlugin

class TaskWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            Log.d("TaskWidget", "Updating task widgets: ${appWidgetIds.joinToString()}")

            val tasksJsonStr = prefs.getString("widget_tasks_json", "[]") ?: "[]"
            
            // Current Time logic for days left
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val todayMs = calendar.timeInMillis
            
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.widget_tasks)

                val listIntent = Intent(context, TaskWidgetService::class.java)
                views.setRemoteAdapter(R.id.widget_list, listIntent)

                val calIntent = Intent(context, CalendarWidgetService::class.java)
                views.setRemoteAdapter(R.id.widget_calendar_grid, calIntent)
                
                val calendar = java.util.Calendar.getInstance()
                val monthName = calendar.getDisplayName(java.util.Calendar.MONTH, java.util.Calendar.LONG, java.util.Locale.getDefault())?.uppercase() ?: "MONTH"
                views.setTextViewText(R.id.calendar_month_title, monthName)

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("uomper://tasks")
                }
                val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 1, intent, flags)
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                try {
                    val tasksArray = JSONArray(tasksJsonStr)
                    
                    if (tasksArray.length() == 0) {
                        views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)
                    }

                } catch (e: Exception) {
                    Log.e("TaskWidget", "JSON parse error", e)
                }

                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_calendar_grid)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("TaskWidget", "Error updating task widget", e)
        }
    }
}
