package com.nextclass.app.nextclass

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nextclass.app/device_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getTimeZone") {
                    val zoneId = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        java.time.ZoneId.systemDefault().id
                    } else {
                        TimeZone.getDefault().id
                    }
                    result.success(zoneId)
                } else {
                    result.notImplemented()
                }
            }
    }
}
