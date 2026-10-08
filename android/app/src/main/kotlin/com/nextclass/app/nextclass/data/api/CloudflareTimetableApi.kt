package com.nextclass.app.nextclass.data.api

import com.nextclass.app.nextclass.data.models.TimetableResponse
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import java.util.concurrent.TimeUnit

/**
 * Retrofit API interface for NextClass Cloudflare Worker AI backend.
 * Endpoints require multipart JPEG image payload and an `X-Device-ID` header
 * for device-level rate limiting via Cloudflare KV (2 scans/week).
 */
interface CloudflareTimetableApi {

    @Multipart
    @POST("/")
    suspend fun uploadTimetable(
        @Header("X-Device-ID") deviceId: String,
        @Part image: MultipartBody.Part
    ): Response<TimetableResponse>

    companion object {
        const val BASE_URL = "https://nextclass-parser.muhammadzakriaawan237.workers.dev/"

        /**
         * Creates a configured [CloudflareTimetableApi] instance with timeout and logging.
         */
        fun create(): CloudflareTimetableApi {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }

            val okHttpClient = OkHttpClient.Builder()
                .connectTimeout(60, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(60, TimeUnit.SECONDS)
                .addInterceptor(loggingInterceptor)
                .build()

            val retrofit = Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create())
                .build()

            return retrofit.create(CloudflareTimetableApi::class.java)
        }
    }
}
