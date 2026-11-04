package com.flourish.app

import android.content.Intent
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.time.Instant
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.flourish.app.detect.DetectionChannel

class MainActivity : FlutterFragmentActivity() {
    private var widgetAction: String? = null
    private var widgetChannel: MethodChannel? = null
    private var pending: Map<String, Any>? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DetectionChannel.register(this, flutterEngine)
        capture(intent)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flourish/widgets").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "publish" -> { com.flourish.app.widgets.WidgetStore.publish(this, call.arguments as String); result.success(null) }
                    "consumeAction" -> { result.success(widgetAction); widgetAction = null }
                    else -> result.notImplemented()
                }
            }
        }
        // While the app lock is on, keep finances out of screenshots, screen
        // recordings and the recent-apps thumbnail.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flourish/privacy").setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                val secure = call.arguments as? Boolean ?: false
                if (secure) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) setRecentsScreenshotEnabled(!secure)
                result.success(null)
            } else result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flourish/imports").setMethodCallHandler { call, result ->
            if (call.method == "consumePendingImport") {
                result.success(pending)
                pending = null
            } else if (call.method == "recognizeImage") {
                val path = call.arguments as? String
                if (path == null) result.error("image", "Missing image path", null)
                else try {
                    val image = InputImage.fromFilePath(this, android.net.Uri.fromFile(File(path)))
                    val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    recognizer.process(image).addOnSuccessListener { result.success(it.text) }
                        .addOnFailureListener { result.error("ocr", "Text recognition failed", null) }
                        .addOnCompleteListener {
                            recognizer.close()
                            // The copy made from a share is only needed for OCR.
                            val file = File(path)
                            if (file.parentFile == cacheDir && file.name.startsWith("shared-")) file.delete()
                        }
                } catch (_: Exception) { result.error("image", "Could not open image", null) }
            } else result.notImplemented()
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
        widgetChannel?.invokeMethod("actionAvailable", null)
    }

    override fun onResume() {
        super.onResume()
        DetectionChannel.foreground = true
    }

    override fun onPause() {
        DetectionChannel.foreground = false
        super.onPause()
    }
    @Suppress("DEPRECATION")
    private fun capture(intent: Intent?) {
        intent?.getStringExtra(com.flourish.app.widgets.WidgetStore.ACTION_EXTRA)?.let {
            widgetAction = it
            intent.removeExtra(com.flourish.app.widgets.WidgetStore.ACTION_EXTRA)
            // Dart consumes this on resume; do not deliver twice via two paths.
        }
        // Tapping a detected-payment notification opens the inbox.
        intent?.getStringExtra(DetectionChannel.ROUTE_EXTRA)?.let {
            DetectionChannel.pendingRoute = it
            intent.removeExtra(DetectionChannel.ROUTE_EXTRA)
        }
        if (intent?.action != Intent.ACTION_SEND) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
        var imagePath = ""
        if (intent.type?.startsWith("image/") == true) {
            val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
            // Only content:// shares: a file:// path could make the app copy
            // its own private files on another app's behalf.
            if (uri != null && uri.scheme == "content") {
                try {
                    val file = File(cacheDir, "shared-${System.currentTimeMillis()}.jpg")
                    contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } }
                    if (file.exists()) imagePath = file.absolutePath
                } catch (_: Exception) { }
            }
        }
        if (text.isNotBlank() || imagePath.isNotBlank()) pending = mapOf(
            "source" to "android-share", "rawText" to text,
            "imagePath" to imagePath, "createdAt" to Instant.now().toString())
        intent.action = null
    }
}
