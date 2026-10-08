package com.nextclass.app.nextclass.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "timetable_classes")
data class ClassEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val day: String,          // e.g., "Monday", "Tuesday"
    val subject: String,      // e.g., "Operating Systems"
    val timeRange: String,    // e.g., "08:30 AM - 10:00 AM"
    val room: String,         // e.g., "Lab 2" or "Room 104"
    val accentColorHex: String = DEFAULT_ACCENT_COLOR // Default Brutalist Neon
) {
    companion object {
        const val DEFAULT_ACCENT_COLOR = "#CCFF00"

        val BRUTALIST_PALETTE = listOf(
            "#CCFF00", // Neon Lime
            "#00F0FF", // Cyan
            "#FF2A85", // Acid Pink
            "#FF6B00", // High-lighter Orange
            "#E0FE00"  // Electric Volt
        )

        /**
         * Returns a deterministic brutalist color based on subject or index.
         */
        fun getColorForIndex(index: Int): String {
            return BRUTALIST_PALETTE[index % BRUTALIST_PALETTE.size]
        }
    }
}
