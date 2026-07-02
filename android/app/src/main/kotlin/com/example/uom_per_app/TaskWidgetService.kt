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
            // Skip the first task since it's displayed as the "Main Focus"
            for (i in 1 until tasksArray.length()) {
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

            val emoji = when (type) {
                "Exam" -> "🔴"
                "Test" -> "🟠"
                "Assignment" -> "🔵"
                "Homework" -> "📗"
                "Project" -> "🟣"
                else -> "⚪"
            }

            rv.setTextViewText(R.id.item_task_emoji, emoji)
            rv.setTextViewText(R.id.item_task_title, title)
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
