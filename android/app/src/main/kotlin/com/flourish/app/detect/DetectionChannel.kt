package com.flourish.app.detect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.flourish.app.MainActivity
import com.flourish.app.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** `flourish/detection`: the Flutter side of payment detection. */
object DetectionChannel {
    const val ROUTE_EXTRA = "flourish_route"
    private const val NOTIFICATION_CHANNEL = "detected_payments"
    private const val NOTIFICATION_ID = 4100

    @Volatile var foreground = false
    @Volatile private var sink: EventChannel.EventSink? = null
    @Volatile var pendingRoute: String? = null
    private val main = Handler(Looper.getMainLooper())

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "flourish/detection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "peek" -> result.success(DetectionQueue.peek(app))
                    "ack" -> {
                        @Suppress("UNCHECKED_CAST")
                        DetectionQueue.ack(app, (call.arguments as? List<String>) ?: emptyList())
                        cancelSummary(app)
                        result.success(null)
                    }
                    "isAccessGranted" -> result.success(
                        NotificationManagerCompat.getEnabledListenerPackages(app)
                            .contains(app.packageName),
                    )
                    "openAccessSettings" -> {
                        openAccessSettings(app)
                        result.success(null)
                    }
                    "configure" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        DetectionConfig.save(
                            app,
                            enabled = args["enabled"] == true,
                            packages = (args["packages"] as? List<*>)?.map { it.toString() }
                                ?: emptyList(),
                            notify = args["notify"] != false,
                        )
                        result.success(null)
                    }
                    "candidates" -> result.success(DetectionConfig.candidates(app))
                    "consumePendingRoute" -> {
                        result.success(pendingRoute)
                        pendingRoute = null
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(engine.dartExecutor.binaryMessenger, "flourish/detection/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            })
    }

    /** A message was queued: tell the running app, or post a summary. */
    fun onQueued(context: Context) {
        val events = sink
        if (foreground && events != null) {
            main.post { events.success(null) }
            return
        }
        if (DetectionConfig.notify(context)) postSummary(context)
    }

    private fun openAccessSettings(context: Context) {
        val component = ComponentName(context, PaymentNotificationListener::class.java)
        val intent: Intent = if (Build.VERSION.SDK_INT >= 30) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun postSummary(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL,
                    "Detected payments",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "Payments found in bank and wallet alerts" },
            )
        }
        val waiting = DetectionQueue.peek(context).size
        val open = Intent(context, MainActivity::class.java)
            .putExtra(ROUTE_EXTRA, "/inbox")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (waiting == 1) "1 payment to review" else "$waiting payments to review")
            .setContentText("Tap to add them to Flourish")
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(tap)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notifications not permitted; the inbox still fills on next launch.
        }
    }

    private fun cancelSummary(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }
}
