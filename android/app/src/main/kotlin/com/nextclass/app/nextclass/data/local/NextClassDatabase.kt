package com.nextclass.app.nextclass.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.nextclass.app.nextclass.data.local.dao.TimetableDao
import com.nextclass.app.nextclass.data.local.entity.ClassEntity

@Database(entities = [ClassEntity::class], version = 1, exportSchema = false)
abstract class NextClassDatabase : RoomDatabase() {
    abstract fun timetableDao(): TimetableDao

    companion object {
        @Volatile
        private var INSTANCE: NextClassDatabase? = null

        fun getDatabase(context: Context): NextClassDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    NextClassDatabase::class.java,
                    "nextclass_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}
