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

                    val listIntent = Intent(context, UomperWidgetService::class.java)
                    setRemoteAdapter(R.id.widget_list, listIntent)

                    val intent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("uomper://schedule")
                    }
                    val flags = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(context, 0, intent, flags)
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)

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
                            val nextLabel = prefs.getString("nextLabel", "Status") ?: "Status"
                            val className = prefs.getString("className", "Finished") ?: "Finished"
                            val classDetail = prefs.getString("classDetail", "No more classes today") ?: "No more classes today"
                            
                            if (className != "Finished" && className != "No upcoming classes" && className != "Online Week") {
                                // We have a class tomorrow or later
                                setViewVisibility(R.id.tracker_container, android.view.View.VISIBLE)
                                setViewVisibility(R.id.empty_state_container, android.view.View.GONE)
                                
                                setTextViewText(R.id.widget_start_label, "Status")
                                setTextViewText(R.id.widget_start_value, nextLabel)
                                setTextViewText(R.id.widget_end_label, "Class")
                                setTextViewText(R.id.widget_end_value, className)
                                setProgressBar(R.id.widget_progress, 1000, 1000, false)
                            } else {
                                // Truly no classes
                                setViewVisibility(R.id.tracker_container, android.view.View.GONE)
                                setViewVisibility(R.id.empty_state_container, android.view.View.VISIBLE)
                                
                                val emptyTitle = if (classDetail.contains("No campus classes")) "Online Week" else "No classes right now"
                                setTextViewText(R.id.widget_empty_text, emptyTitle)
                                setTextViewText(R.id.widget_empty_subtext, classDetail)
                            }
                        } else {
                            // Show tracker, hide empty state
                            setViewVisibility(R.id.tracker_container, android.view.View.VISIBLE)
                            setViewVisibility(R.id.empty_state_container, android.view.View.GONE)
                        }

                    } catch (e: Exception) {
                        Log.e("UomperWidget", "JSON parse error", e)
                    }
                }

                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        } catch (e: Exception) {
            Log.e("UomperWidget", "Error updating widget", e)
        }
    }
}
