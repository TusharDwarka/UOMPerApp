package com.example.uom_per_app

import android.appwidget.AppWidgetManager
import android.util.Log
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
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
                        
                        // Sub Tasks
                        var subList = StringBuilder()
                        for (i in 1 until minOf(4, tasksArray.length())) {
                            val t = tasksArray.getJSONObject(i)
                            val title = t.getString("title")
                            val tType = t.getString("type")
                            val e = when (tType) {
                                "Exam" -> "🔴"
                                "Test" -> "🟠"
                                "Assignment" -> "🔵"
                                "Homework" -> "📗"
                                "Project" -> "🟣"
                                else -> "⚪"
                            }
                            subList.append("$e $title\n")
                        }
                        
                        if (subList.isEmpty()) {
                            views.setTextViewText(R.id.task_sub_list, "No other upcoming tasks")
                        } else {
                            views.setTextViewText(R.id.task_sub_list, "Up Next:\n" + subList.toString().trim())
                        }
                    }

                } catch (e: Exception) {
                    Log.e("TaskWidget", "JSON parse error", e)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("TaskWidget", "Error updating task widget", e)
        }
    }
}
