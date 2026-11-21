package com.nextclass.app

import androidx.annotation.Keep
import android.app.Activity
import android.app.PendingIntent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.content.Intent
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.OpenableColumns
import java.util.TimeZone
import java.io.File

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nextclass.app/app_updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getInstalledVersion" -> {
                            @Suppress("DEPRECATION")
                            val info = if (Build.VERSION.SDK_INT >= 33) {
                                packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                            } else packageManager.getPackageInfo(packageName, 0)
                            result.success(info.versionName ?: "")
                        }
                        "canRequestPackageInstalls" -> result.success(
                            Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()
                        )
                        "openInstallPermissionSettings" -> {
                            if (Build.VERSION.SDK_INT >= 26) {
                                startActivity(Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                })
                            }
                            result.success(null)
                        }
                        "startPackageInstall" -> {
                            val rawPath = call.arguments as? String
                                ?: throw IllegalArgumentException("The verified APK path is missing.")
                            startPackageInstall(rawPath)
                            result.success(null)
                        }
                        "consumeInstallStatus" -> {
                            val prefs = getSharedPreferences(ApkInstallStatusReceiver.PREFERENCES, MODE_PRIVATE)
                            val status = prefs.getString("status", null)
                            val message = prefs.getString("message", null)
                            if (status != null) prefs.edit().remove("status").remove("message").apply()
                            result.success(if (status == null) null else mapOf("status" to status, "message" to message))
                        }
                        "launchSupportEmail" -> {
                            val email = call.arguments as? String ?: ""
                            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:").buildUpon().appendQueryParameter("to", email).build())
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(Intent.createChooser(intent, "Contact NextClass support"))
                                result.success(true)
                            } else result.success(false)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    result.error("INSTALL_PERMISSION_REQUIRED", "Allow NextClass to install updates in Android settings.", null)
                } catch (e: Exception) {
                    result.error("APP_UPDATE_ERROR", e.localizedMessage ?: "The update could not be opened.", null)
                }
            }
    }

    private fun startPackageInstall(rawPath: String) {
        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
            throw SecurityException("Install permission is required.")
        }
        val cache = cacheDir.canonicalFile
        val apk = File(rawPath).canonicalFile
        if (!apk.path.startsWith(cache.path + File.separator) || !apk.isFile || apk.length() <= 0L) {
            throw IllegalArgumentException("The update APK is not in the app cache or is empty.")
        }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= 31) setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("NextClass-update.apk", 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                val callbackIntent = Intent(this, ApkInstallStatusReceiver::class.java).apply {
                    action = "com.nextclass.app.PACKAGE_INSTALL_STATUS"
                    putExtra(PackageInstaller.EXTRA_SESSION_ID, sessionId)
                }
                val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    sessionId,
                    callbackIntent,
                    pendingIntentFlags,
                )
                session.commit(pendingIntent.intentSender)
            }
        } catch (error: Exception) {
            installer.abandonSession(sessionId)
            throw error
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
