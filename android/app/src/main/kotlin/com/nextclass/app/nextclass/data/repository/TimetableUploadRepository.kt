package com.nextclass.app.nextclass.data.repository

import android.content.Context
import com.nextclass.app.nextclass.data.api.CloudflareTimetableApi
import com.nextclass.app.nextclass.data.local.NextClassDatabase
import com.nextclass.app.nextclass.data.local.entity.ClassEntity
import com.nextclass.app.nextclass.data.mapper.toClassEntities
import com.nextclass.app.nextclass.data.models.TimetableResponse
import kotlinx.coroutines.flow.Flow
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException
import java.util.UUID

/**
 * Custom exceptions representing specific Cloudflare timetable parsing states.
 */
sealed class TimetableUploadException(message: String) : Exception(message) {
    class RateLimitExceeded(
        message: String = "Weekly scan limit reached. Please try again next week or enter manually."
    ) : TimetableUploadException(message)

    class ServerError(
        val statusCode: Int,
        message: String = "Server returned error: $statusCode"
    ) : TimetableUploadException(message)

    class NetworkError(
        cause: Throwable,
        message: String = "Network error: Unable to reach Cloudflare AI parser."
    ) : TimetableUploadException(message)
}

/**
 * Repository responsible for managing the persistent Device ID, dispatching
 * timetable image multipart uploads to the Cloudflare Worker, and syncing
 * results with the local Room Database.
 */
class TimetableUploadRepository(
    private val context: Context,
    private val api: CloudflareTimetableApi = CloudflareTimetableApi.create(),
    private val database: NextClassDatabase = NextClassDatabase.getDatabase(context)
) {
    companion object {
        private const val PREFS_NAME = "NextClassPrefs"
        private const val KEY_DEVICE_ID = "DEVICE_ID"
    }

    /**
     * Checks SharedPreferences for `DEVICE_ID`. If null or empty, generates a `UUID.randomUUID().toString()`,
     * saves it persistently, and returns it. This acts as the secure key for Cloudflare KV rate limiting.
     */
    fun getOrCreateDeviceId(): String {
        val sharedPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        var deviceId = sharedPrefs.getString(KEY_DEVICE_ID, null)

        if (deviceId.isNullOrEmpty()) {
            deviceId = UUID.randomUUID().toString()
            sharedPrefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        }

        return deviceId
    }

    /**
     * Converts the provided image [File] into a `MultipartBody.Part` of type `image/jpeg`,
     * executes the network call via [CloudflareTimetableApi], and maps the HTTP response.
     */
    suspend fun processTimetableImage(imageFile: File): Result<TimetableResponse> {
        return try {
            // 1. Get or generate persistent Device ID
            val deviceId = getOrCreateDeviceId()

            // 2. Prepare the Multipart file
            val requestFile = imageFile.asRequestBody("image/jpeg".toMediaTypeOrNull())
            val imagePart = MultipartBody.Part.createFormData("image", imageFile.name, requestFile)

            // 3. Execute network request
            val response = api.uploadTimetable(deviceId, imagePart)

            // 4. Handle HTTP responses
            when {
                response.isSuccessful && response.body() != null -> {
                    Result.success(response.body()!!)
                }
                response.code() == 429 -> {
                    Result.failure(TimetableUploadException.RateLimitExceeded())
                }
                else -> {
                    Result.failure(TimetableUploadException.ServerError(response.code()))
                }
            }
        } catch (e: IOException) {
            Result.failure(TimetableUploadException.NetworkError(e))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Syncs a parsed [TimetableResponse] into Room database by mapping it to [ClassEntity]
     * items with brutalist neon colors and atomically replacing the existing timetable.
     */
    suspend fun syncTimetable(response: TimetableResponse): List<ClassEntity> {
        val entities = response.toClassEntities()
        database.timetableDao().replaceTimetable(entities)
        return entities
    }

    /**
     * Reactive Flow of all timetable classes.
     */
    fun getAllClasses(): Flow<List<ClassEntity>> {
        return database.timetableDao().getAllClasses()
    }

    /**
     * Reactive Flow of timetable classes for a specified day.
     */
    fun getClassesForDay(day: String): Flow<List<ClassEntity>> {
        return database.timetableDao().getClassesForDay(day)
    }

    /**
     * Clears all cached timetable classes from Room.
     */
    suspend fun clearTimetable() {
        database.timetableDao().clearAll()
    }
}

/**
 * Standalone top-level function matching the Step 4 reference specification.
 * Delegates to [TimetableUploadRepository] for consistent device ID management
 * and error handling.
 */
suspend fun processTimetableImage(
    context: Context,
    imageFile: File,
    api: CloudflareTimetableApi = CloudflareTimetableApi.create()
): Result<TimetableResponse> {
    return TimetableUploadRepository(context, api).processTimetableImage(imageFile)
}
