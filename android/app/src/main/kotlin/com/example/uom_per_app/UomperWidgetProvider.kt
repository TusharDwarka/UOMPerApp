package com.example.uom_per_app

import android.appwidget.AppWidgetManager
import android.util.Log
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

import es.antonborri.home_widget.HomeWidgetPlugin

class UomperWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            Log.d("UomperWidget", "Updating widgets: ${appWidgetIds.joinToString()}")

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.uomper_widget).apply {
                    val className = prefs.getString("className", "No upcoming classes") ?: "No upcoming classes"
                    val classDetail = prefs.getString("classDetail", "") ?: ""
                    val nextLabel = prefs.getString("nextLabel", "NEXT CLASS") ?: "NEXT CLASS"
                    val taskName = prefs.getString("taskName", "No pending tasks") ?: "No pending tasks"
                    val taskDetail = prefs.getString("taskDetail", "") ?: ""
                    val weekBadge = prefs.getString("weekBadge", "Week ?") ?: "Week ?"

                    Log.d("UomperWidget", "Setting text for widget $widgetId: $className")

                    setTextViewText(R.id.widget_class_name, className)
                    setTextViewText(R.id.widget_class_detail, classDetail)
                    setTextViewText(R.id.widget_next_label, nextLabel)
                    setTextViewText(R.id.widget_task_name, taskName)
                    setTextViewText(R.id.widget_task_detail, taskDetail)
                    setTextViewText(R.id.widget_week_badge, weekBadge)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("UomperWidget", "Error updating widget", e)
        }
    }
}
