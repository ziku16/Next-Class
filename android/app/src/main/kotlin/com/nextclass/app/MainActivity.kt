package com.nextclass.app

import androidx.annotation.Keep
import android.app.Activity
import android.content.Intent
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.OpenableColumns
import java.util.TimeZone

/**
 * Main application entry point for NextClass on Android.
 *
 * Annotated with @Keep to prevent R8 from stripping or renaming class and lifecycle
 * methods in release builds.
 */
@Keep
class MainActivity : FlutterActivity() {
    private var pendingDocumentPickerResult: MethodChannel.Result? = null
    private val documentPickerRequestCode = 7301

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
                        when (call.method) {
                            "getTimeZone" -> result.success(TimeZone.getDefault().id ?: "UTC")
                            "pickExamDocument" -> {
                                if (pendingDocumentPickerResult != null) {
                                    result.error("PICKER_BUSY", "A document picker is already open.", null)
                                    return@setMethodCallHandler
                                }
                                pendingDocumentPickerResult = result
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                        "application/pdf",
                                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                        "application/vnd.ms-excel",
                                        "image/jpeg",
                                        "image/png",
                                    ))
                                }
                                startActivityForResult(intent, documentPickerRequestCode)
                            }
                            else -> result.notImplemented()
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

    @Keep
    @Deprecated("Deprecated in Android, retained for the document-picker activity result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != documentPickerRequestCode) return

        val result = pendingDocumentPickerResult
        pendingDocumentPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }

        try {
            val uri = data.data!!
            val fileName = contentResolver.query(uri, null, null, null, null).use { cursor: Cursor? ->
                val column = cursor?.getColumnIndex(OpenableColumns.DISPLAY_NAME) ?: -1
                if (cursor != null && column >= 0 && cursor.moveToFirst()) cursor.getString(column)
                else "exam_document"
            }
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("Could not read the selected file.")
            result?.success(mapOf(
                "name" to fileName,
                "mimeType" to contentResolver.getType(uri),
                "bytes" to bytes,
            ))
        } catch (error: Exception) {
            result?.error("DOCUMENT_READ_FAILED", error.localizedMessage, null)
        }
    }
}
