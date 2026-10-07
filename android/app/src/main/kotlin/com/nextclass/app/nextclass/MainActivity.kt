package com.nextclass.app.nextclass

import androidx.annotation.Keep
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * Main application entry point for NextClass on Android.
 *
 * Annotated with @Keep to prevent R8 from stripping or renaming class and lifecycle
 * methods in release builds.
 */
@Keep
class MainActivity : FlutterActivity() {

    /**
     * Registers the platform method channel for device configuration query.
     * Provides Olson-compliant timezone identification without requiring API 26+ desugaring.
     */
    @Keep
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nextclass.app/device_info")
                .setMethodCallHandler { call, result ->
                    try {
                        if (call.method == "getTimeZone") {
                            val zoneId = TimeZone.getDefault().id
                            result.success(zoneId ?: "UTC")
                        } else {
                            result.notImplemented()
                        }
                    } catch (e: Exception) {
                        result.error("TZ_ERROR", e.localizedMessage, null)
                    }
                }
        } catch (e: Exception) {
            // Defensively catch unexpected engine attachment issues to prevent startup crashes.
            e.printStackTrace()
        }
    }
}
