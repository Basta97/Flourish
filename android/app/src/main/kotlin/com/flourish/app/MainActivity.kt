package com.flourish.app

import android.content.Intent
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
    private var pending: Map<String, Any>? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DetectionChannel.register(this, flutterEngine)
        capture(intent)
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
                        .addOnCompleteListener { recognizer.close() }
                } catch (_: Exception) { result.error("image", "Could not open image", null) }
            } else result.notImplemented()
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
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
            if (uri != null) {
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
