package com.nextclass.app.nextclass.data.mapper

import com.nextclass.app.nextclass.data.local.entity.ClassEntity
import com.nextclass.app.nextclass.data.models.TimetableResponse

val BRUTALIST_NEON_PALETTE = listOf(
    "#CCFF00", // Neon Lime
    "#00F0FF", // Cyan
    "#FF2A85", // Acid Pink
    "#FF6B00", // High-lighter Orange
    "#E0FE00"  // Electric Volt
)

/**
 * Maps a [TimetableResponse] from the Cloudflare parser into a flat list of [ClassEntity]
 * objects for Room storage.
 *
 * Cycles through the brutalist neon palette to assign a consistent, distinct accent color
 * to each unique subject.
 */
fun TimetableResponse.toClassEntities(): List<ClassEntity> {
    val subjectColorMap = mutableMapOf<String, String>()
    val result = mutableListOf<ClassEntity>()

    for (dailySchedule in schedule) {
        for (lecture in dailySchedule.classes) {
            val normalizedSubject = lecture.subject.trim()
            val color = subjectColorMap.getOrPut(normalizedSubject) {
                BRUTALIST_NEON_PALETTE[subjectColorMap.size % BRUTALIST_NEON_PALETTE.size]
            }

            result.add(
                ClassEntity(
                    day = dailySchedule.day.trim(),
                    subject = lecture.subject.trim(),
                    timeRange = lecture.time.trim(),
                    room = lecture.room.trim(),
                    accentColorHex = color
                )
            )
        }
    }

    return result
}
