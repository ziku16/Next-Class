package com.nextclass.app.nextclass.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.nextclass.app.nextclass.data.local.entity.ClassEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TimetableDao {

    @Query("SELECT * FROM timetable_classes ORDER BY id ASC")
    fun getAllClasses(): Flow<List<ClassEntity>>

    @Query("SELECT * FROM timetable_classes WHERE LOWER(day) = LOWER(:day) ORDER BY id ASC")
    fun getClassesForDay(day: String): Flow<List<ClassEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertClasses(classes: List<ClassEntity>): List<Long>

    @Query("DELETE FROM timetable_classes")
    suspend fun clearAll(): Int

    @Transaction
    suspend fun replaceTimetable(classes: List<ClassEntity>) {
        clearAll()
        insertClasses(classes)
    }
}
