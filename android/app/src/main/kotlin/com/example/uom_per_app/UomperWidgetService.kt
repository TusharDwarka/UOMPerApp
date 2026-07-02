package com.example.uom_per_app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class UomperWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return UomperWidgetFactory(this.applicationContext)
    }
}

class UomperWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var classItems: List<JSONObject> = listOf()

    override fun onCreate() {
        // Init
    }

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val classesJsonStr = prefs.getString("widget_classes_json", "[]") ?: "[]"
        
        val tempItems = mutableListOf<JSONObject>()
        try {
            val classesArray = JSONArray(classesJsonStr)
            // Filter only upcoming classes for today
            // Actually, we could just display all classes. The WidgetProvider handles the "Current/Next".
            // We can just list all of them.
            for (i in 0 until classesArray.length()) {
                tempItems.add(classesArray.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        classItems = tempItems
    }

    override fun onDestroy() {
        // Clean up
    }

    override fun getCount(): Int {
        return classItems.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_class_item)
        if (position < classItems.size) {
            val item = classItems[position]
            rv.setTextViewText(R.id.item_class_subject, item.optString("subject", "Unknown"))
            rv.setTextViewText(R.id.item_class_room, item.optString("room", "TBD"))
            val startTime = item.optString("startTime", "")
            val endTime = item.optString("endTime", "")
            rv.setTextViewText(R.id.item_class_time, "$startTime - $endTime")
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
