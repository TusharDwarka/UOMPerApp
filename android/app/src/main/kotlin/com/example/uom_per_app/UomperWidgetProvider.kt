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

class UomperWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            Log.d("UomperWidget", "Updating widgets: ${appWidgetIds.joinToString()}")

            val weekBadge = prefs.getString("weekBadge", "Week ?") ?: "Week ?"
            val classesJsonStr = prefs.getString("widget_classes_json", "[]") ?: "[]"
            
            // Current Time
            val calendar = Calendar.getInstance()
            val currentMinutes = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
            val sdf = SimpleDateFormat("EEE, d MMM, hh:mm a", Locale.getDefault())
            val statusText = sdf.format(Date())

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.uomper_widget).apply {
                    setTextViewText(R.id.widget_status, statusText)
                    setTextViewText(R.id.widget_week_badge, weekBadge)

                    try {
                        val classesArray = JSONArray(classesJsonStr)
                        var currentOrNextFound = false
                        var upcomingText = StringBuilder()
                        
                        for (i in 0 until classesArray.length()) {
                            val c = classesArray.getJSONObject(i)
                            val subject = c.getString("subject")
                            val room = c.getString("room")
                            val startStr = c.getString("startTime")
                            val endStr = c.getString("endTime")
                            
                            val startParts = startStr.split(":")
                            val startMins = startParts[0].toInt() * 60 + startParts[1].toInt()
                            val endParts = endStr.split(":")
                            val endMins = endParts[0].toInt() * 60 + endParts[1].toInt()
                            
                            if (!currentOrNextFound && currentMinutes < endMins) {
                                currentOrNextFound = true
                                
                                setTextViewText(R.id.widget_start_label, "Room $room")
                                setTextViewText(R.id.widget_start_value, startStr)
                                setTextViewText(R.id.widget_end_label, "Class")
                                setTextViewText(R.id.widget_end_value, subject)
                                
                                if (currentMinutes >= startMins) {
                                    // In Progress
                                    val totalDuration = endMins - startMins
                                    val elapsed = currentMinutes - startMins
                                    val progress = ((elapsed.toFloat() / totalDuration.toFloat()) * 1000).toInt()
                                    setProgressBar(R.id.widget_progress, 1000, progress, false)
                                } else {
                                    // Not started yet
                                    setProgressBar(R.id.widget_progress, 1000, 0, false)
                                }
                            } else if (currentOrNextFound) {
                                upcomingText.append("• $subject ($startStr - $endStr) in $room\n")
                            }
                        }
                        
                        if (!currentOrNextFound) {
                            setTextViewText(R.id.widget_start_label, "Status")
                            setTextViewText(R.id.widget_start_value, "--:--")
                            setTextViewText(R.id.widget_end_label, "Class")
                            setTextViewText(R.id.widget_end_value, "Finished")
                            setProgressBar(R.id.widget_progress, 1000, 1000, false)
                            setTextViewText(R.id.widget_upcoming_classes, "No more classes today")
                        } else {
                            if (upcomingText.isEmpty()) {
                                setTextViewText(R.id.widget_upcoming_classes, "No more classes today")
                            } else {
                                setTextViewText(R.id.widget_upcoming_classes, upcomingText.toString().trim())
                            }
                        }

                    } catch (e: Exception) {
                        Log.e("UomperWidget", "JSON parse error", e)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("UomperWidget", "Error updating widget", e)
        }
    }
}
