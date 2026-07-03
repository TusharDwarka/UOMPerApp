package com.example.uom_per_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

class BusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_NEXT_ROUTE = "com.example.uom_per_app.ACTION_NEXT_BUS_ROUTE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEXT_ROUTE) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonStr = prefs.getString("flutter.bus_locations_json", null)
            
            if (jsonStr != null) {
                try {
                    val array = JSONArray(jsonStr)
                    val len = array.length()
                    if (len > 0) {
                        var currentIndex = prefs.getInt("widget_bus_route_index", 0)
                        currentIndex = (currentIndex + 1) % len
                        prefs.edit().putInt("widget_bus_route_index", currentIndex).apply()
                        
                        val appWidgetManager = AppWidgetManager.getInstance(context)
                        val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                        if (appWidgetIds != null) {
                            for (id in appWidgetIds) {
                                updateAppWidget(context, appWidgetManager, id)
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("flutter.bus_locations_json", null)
        
        val views = RemoteViews(context.packageName, R.layout.widget_bus)
        
        // Default Tap action to open app
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_bus_root, pendingIntent)
        
        // Next Button Tap action
        val nextIntent = Intent(context, BusWidgetProvider::class.java).apply {
            action = ACTION_NEXT_ROUTE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val nextPendingIntent = PendingIntent.getBroadcast(
            context,
            appWidgetId, // Unique request code per widget
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.bus_next_button, nextPendingIntent)

        if (jsonStr == null) {
            views.setTextViewText(R.id.bus_route_text, "--")
            views.setTextViewText(R.id.bus_location_text, "No routes saved")
            views.setTextViewText(R.id.bus_next_time_text, "--")
            views.setTextViewText(R.id.bus_subsequent_times_text, "--")
        } else {
            try {
                val array = JSONArray(jsonStr)
                val len = array.length()
                if (len > 0) {
                    var routeIndex = prefs.getInt("widget_bus_route_index", 0)
                    if (routeIndex >= len) routeIndex = 0
                    
                    val selectedRoute = array.getJSONObject(routeIndex)
                    val locationName = selectedRoute.optString("location_name", "Unknown")
                    val busRouteStr = selectedRoute.optString("bus_route", "")
                    
                    views.setTextViewText(R.id.bus_location_text, locationName)
                    views.setTextViewText(R.id.bus_route_text, if (busRouteStr.isNotEmpty()) busRouteStr else "--")
                    
                    val schedules = selectedRoute.optJSONObject("schedules")
                    val cal = Calendar.getInstance()
                    val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
                    val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                    
                    val tripsArray = when (dayOfWeek) {
                        Calendar.SUNDAY -> schedules?.optJSONArray("sundays_public_holidays")
                        Calendar.SATURDAY -> schedules?.optJSONArray("saturdays")
                        else -> schedules?.optJSONArray("weekdays")
                    }
                    
                    val upcomingBuses = mutableListOf<Int>()
                    var nextBusName = ""
                    
                    if (tripsArray != null) {
                        for (i in 0 until tripsArray.length()) {
                            val trip = tripsArray.getJSONObject(i)
                            val depStr = trip.optString("departure", "")
                            if (depStr.contains(":")) {
                                val parts = depStr.replace("~", "").split(":")
                                if (parts.size == 2) {
                                    val depMin = parts[0].toInt() * 60 + parts[1].toInt()
                                    if (depMin > currentMinutes) {
                                        if (upcomingBuses.isEmpty()) {
                                            nextBusName = trip.optString("bus_name", "")
                                        }
                                        val diff = depMin - currentMinutes
                                        upcomingBuses.add(diff)
                                    }
                                }
                            }
                        }
                    }
                    
                    if (upcomingBuses.isEmpty()) {
                        views.setTextViewText(R.id.bus_next_time_text, "--")
                        views.setTextViewText(R.id.bus_subsequent_times_text, "--")
                        views.setTextViewText(R.id.bus_name_text, "")
                    } else {
                        views.setTextViewText(R.id.bus_next_time_text, upcomingBuses[0].toString())
                        views.setTextViewText(R.id.bus_name_text, nextBusName)
                        
                        var subsequent = ""
                        if (upcomingBuses.size > 1) subsequent += upcomingBuses[1].toString()
                        if (upcomingBuses.size > 2) subsequent += ", " + upcomingBuses[2].toString()
                        
                        if (subsequent.isEmpty()) subsequent = "--"
                        views.setTextViewText(R.id.bus_subsequent_times_text, subsequent)
                    }
                    
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
