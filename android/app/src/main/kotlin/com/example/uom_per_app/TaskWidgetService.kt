package com.example.uom_per_app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskWidgetFactory(this.applicationContext)
    }
}

class TaskWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var taskItems: List<JSONObject> = listOf()

    override fun onCreate() {
    }

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val tasksJsonStr = prefs.getString("widget_tasks_json", "[]") ?: "[]"
        
        val tempItems = mutableListOf<JSONObject>()
        try {
            val tasksArray = JSONArray(tasksJsonStr)
            for (i in 0 until tasksArray.length()) {
                tempItems.add(tasksArray.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        taskItems = tempItems
    }

    override fun onDestroy() {
    }

    override fun getCount(): Int {
        return taskItems.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_task_item)
        if (position < taskItems.size) {
            val item = taskItems[position]
            val title = item.optString("title", "Unknown")
            val subject = item.optString("subject", "General")
            val type = item.optString("type", "Other")
            val dueDateStr = item.optString("dueDate", "")
            
            // Basic formatting for due date if needed (e.g. just take the date part)
            val dateDisplay = if (dueDateStr.length >= 10) dueDateStr.substring(0, 10) else dueDateStr

            var isUrgent = false
            if (type == "Exam" || type == "Test") {
                isUrgent = true
            }
            // Check if due within 3 days
            try {
                if (dueDateStr.isNotEmpty()) {
                    val format = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                    val date = format.parse(dueDateStr.substring(0, 10))
                    val diff = date.time - java.util.Date().time
                    val days = diff / (1000 * 60 * 60 * 24)
                    if (days in 0..3) isUrgent = true
                }
            } catch (e: Exception) {}

            val colorHex = when (type) {
                "Exam" -> android.graphics.Color.parseColor("#FF5252") // Red
                "Test" -> android.graphics.Color.parseColor("#FF9800") // Orange
                "Assignment" -> android.graphics.Color.parseColor("#2196F3") // Blue
                "Homework" -> android.graphics.Color.parseColor("#4CAF50") // Green
                "Project" -> android.graphics.Color.parseColor("#9C27B0") // Purple
                else -> android.graphics.Color.parseColor("#9E9E9E") // Grey
            }

            // Set the vertical color bar
            rv.setInt(R.id.item_task_color_bar, "setBackgroundColor", colorHex)
            
            // Highlight urgent titles
            if (isUrgent) {
                rv.setTextViewText(R.id.item_task_title, "⚠️ $title")
                rv.setTextColor(R.id.item_task_title, android.graphics.Color.parseColor("#FF5252")) // Red text
            } else {
                rv.setTextViewText(R.id.item_task_title, title)
                rv.setTextColor(R.id.item_task_title, android.graphics.Color.parseColor("#FFFFFF")) // White text
            }

            rv.setTextViewText(R.id.item_task_subject, "$type • $subject")
            rv.setTextViewText(R.id.item_task_due, dateDisplay)
        }
        return rv
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
