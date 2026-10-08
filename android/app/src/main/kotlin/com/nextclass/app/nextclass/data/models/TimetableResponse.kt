package com.nextclass.app.nextclass.data.models

import com.google.gson.annotations.SerializedName

/**
 * Root response object returned by the Cloudflare Worker running Meta Llama 3.2 Vision.
 */
data class TimetableResponse(
    @SerializedName("schedule")
    val schedule: List<DailySchedule>
)

/**
 * Represents a single day's class schedule.
 */
data class DailySchedule(
    @SerializedName("day")
    val day: String,
    @SerializedName("classes")
    val classes: List<Lecture>
)

/**
 * Individual class lecture item.
 */
data class Lecture(
    @SerializedName("subject")
    val subject: String,
    @SerializedName("time")
    val time: String,
    @SerializedName("room")
    val room: String
)
