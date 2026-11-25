package com.hasani.payroll

import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import android.os.Bundle
import android.os.Build
import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenSecurityChannel = "com.hasani.payroll/screen_security"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Protect the first Flutter frame as well. The identity-card widget
        // keeps this flag enabled while it is mounted and clears it after the
        // last protected card leaves the screen.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hasani.payroll/play_updates",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedVersionCode" -> {
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(packageName, 0)
                    @Suppress("DEPRECATION")
                    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        info.longVersionCode
                    } else {
                        info.versionCode.toLong()
                    }
                    result.success(code)
                }
                "openPlayStore" -> {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
                        intent.setPackage("com.android.vending")
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://play.google.com/store/apps/details?id=$packageName")))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hasani.payroll/downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePdf") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.success(false) // Dart opens the system save picker.
            } else {
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || bytes.isEmpty() || filename.isNullOrBlank() ||
                    filename.contains('/') || filename.contains('\\')) {
                    result.error("INVALID_PDF", "Invalid payslip file", null)
                } else {
                    var uri: Uri? = null
                    try {
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                            put(MediaStore.MediaColumns.IS_PENDING, 1)
                        }
                        val destination = contentResolver.insert(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values,
                        ) ?: error("Unable to create download")
                        uri = destination
                        val stream = contentResolver.openOutputStream(destination)
                            ?: error("Unable to open download")
                        stream.use { it.write(bytes) }
                        values.clear()
                        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        check(contentResolver.update(destination, values, null, null) == 1)
                        result.success(true)
                    } catch (error: Exception) {
                        uri?.let {
                            try { contentResolver.delete(it, null, null) } catch (_: Exception) {}
                        }
                        result.error("DOWNLOAD_FAILED", "Unable to save payslip to Downloads", null)
                    }
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenSecurityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureScreen" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecureScreen" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
