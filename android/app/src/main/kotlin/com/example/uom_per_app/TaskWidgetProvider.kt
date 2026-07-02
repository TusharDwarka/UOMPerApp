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
                        views.setTextViewText(R.id.task_main_title, "No pending tasks")
                        views.setTextViewText(R.id.task_main_subject, "Enjoy your free time!")
                        views.setTextViewText(R.id.task_main_due, "")
                        views.setTextViewText(R.id.task_sub_list, "")
                    } else {
                        // Main Task
                        val mainTask = tasksArray.getJSONObject(0)
                        val mainTitle = mainTask.getString("title")
                        val mainSubject = mainTask.getString("subject")
                        val mainType = mainTask.getString("type")
                        val mainDueStr = mainTask.getString("dueDate")
                        
                        var mainDaysLeftStr = "Due date unknown"
                        var colorHex = "#FF5252" // default red
                        try {
                            val date = isoFormat.parse(mainDueStr)
                            if (date != null) {
                                val dueCal = Calendar.getInstance()
                                dueCal.time = date
                                dueCal.set(Calendar.HOUR_OF_DAY, 0)
                                dueCal.set(Calendar.MINUTE, 0)
                                dueCal.set(Calendar.SECOND, 0)
                                dueCal.set(Calendar.MILLISECOND, 0)
                                val dueMs = dueCal.timeInMillis
                                
                                val diffDays = ((dueMs - todayMs) / (1000 * 60 * 60 * 24)).toInt()
                                
                                if (diffDays < 0) {
                                    mainDaysLeftStr = "OVERDUE"
                                } else if (diffDays == 0) {
                                    mainDaysLeftStr = "DUE TODAY"
                                } else if (diffDays == 1) {
                                    mainDaysLeftStr = "DUE TOMORROW"
                                    colorHex = "#FF9800" // orange
                                } else {
                                    mainDaysLeftStr = "$diffDays Days Left"
                                    colorHex = "#4CAF50" // green
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("TaskWidget", "Date parse error", e)
                        }

                        val emoji = when (mainType) {
                            "Exam" -> "🔴"
                            "Test" -> "🟠"
                            "Assignment" -> "🔵"
                            "Homework" -> "📗"
                            "Project" -> "🟣"
                            else -> "⚪"
                        }
                        
                        views.setTextViewText(R.id.task_main_title, "$emoji $mainTitle")
                        views.setTextViewText(R.id.task_main_subject, "$mainType • $mainSubject")
                        views.setTextViewText(R.id.task_main_due, mainDaysLeftStr)
                        // Android RemoteViews doesn't support setTextColor with hex string directly, so we just use the default XML color
                        
                        // Sub Tasks are now handled by the TaskWidgetService (ListView)
                    }

                } catch (e: Exception) {
                    Log.e("TaskWidget", "JSON parse error", e)
                }

                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("TaskWidget", "Error updating task widget", e)
        }
    }
}
