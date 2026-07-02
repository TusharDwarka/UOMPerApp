package com.example.uom_per_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar

class CalendarWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CalendarWidgetFactory(this.applicationContext)
    }
}

class CalendarWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val days = mutableListOf<String>()
    private var currentDayIndex = -1

    override fun onCreate() {}

    override fun onDataSetChanged() {
        days.clear()
        val cal = Calendar.getInstance()
        val today = cal.get(Calendar.DAY_OF_MONTH)
        
        cal.set(Calendar.DAY_OF_MONTH, 1)
        val firstDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon
        
        // Adjust for Monday start
        var offset = firstDayOfWeek - 2
        if (offset < 0) offset += 7
        
        for (i in 0 until offset) {
            days.add("")
        }
        
        val maxDays = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        for (i in 1..maxDays) {
            if (i == today) {
                currentDayIndex = days.size
            }
            days.add(i.toString())
        }
        
        // Pad to ensure full rows
        while (days.size % 7 != 0) {
            days.add("")
        }
    }

    override fun onDestroy() {}
    override fun getCount(): Int = days.size

    override fun getViewAt(position: Int): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_calendar_item)
        val dayStr = days[position]
        rv.setTextViewText(R.id.calendar_day_text, dayStr)
        
        if (dayStr.isNotEmpty()) {
            if (position == currentDayIndex) {
                // Highlight current day
                rv.setTextColor(R.id.calendar_day_text, Color.WHITE)
                rv.setInt(R.id.calendar_day_text, "setBackgroundColor", Color.parseColor("#2962FF")) // Deep Blue
            } else {
                rv.setTextColor(R.id.calendar_day_text, Color.parseColor("#B0BEC5"))
                rv.setInt(R.id.calendar_day_text, "setBackgroundColor", Color.TRANSPARENT)
            }
        } else {
            rv.setInt(R.id.calendar_day_text, "setBackgroundColor", Color.TRANSPARENT)
        }
        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
