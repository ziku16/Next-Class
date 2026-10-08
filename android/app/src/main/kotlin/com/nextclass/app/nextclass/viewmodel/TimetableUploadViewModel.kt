package com.nextclass.app.nextclass.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nextclass.app.nextclass.data.local.NextClassDatabase
import com.nextclass.app.nextclass.data.local.entity.ClassEntity
import com.nextclass.app.nextclass.data.mapper.toClassEntities
import com.nextclass.app.nextclass.data.models.TimetableResponse
import com.nextclass.app.nextclass.data.repository.TimetableUploadException
import com.nextclass.app.nextclass.data.repository.TimetableUploadRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * UI State for timetable image upload and parsing.
 */
sealed class TimetableUploadUiState {
    object Idle : TimetableUploadUiState()
    object Loading : TimetableUploadUiState()
    data class Success(
        val response: TimetableResponse,
        val entities: List<ClassEntity> = emptyList()
    ) : TimetableUploadUiState()
    data class RateLimitExceeded(val message: String) : TimetableUploadUiState()
    data class Error(val message: String) : TimetableUploadUiState()
}

/**
 * ViewModel managing timetable upload UI state, triggering the repository call,
 * saving parsed classes to the local Room database, and propagating states.
 */
class TimetableUploadViewModel(
    private val repository: TimetableUploadRepository,
    private val database: NextClassDatabase
) : ViewModel() {

    constructor(context: Context, repository: TimetableUploadRepository) : this(
        repository = repository,
        database = NextClassDatabase.getDatabase(context)
    )

    private val _uiState = MutableStateFlow<TimetableUploadUiState>(TimetableUploadUiState.Idle)
    val uiState: StateFlow<TimetableUploadUiState> = _uiState.asStateFlow()

    /**
     * Uploads the image file, and upon success immediately persists the parsed
     * classes into the local Room database via [replaceTimetable].
     */
    fun uploadTimetable(imageFile: File) {
        viewModelScope.launch {
            _uiState.value = TimetableUploadUiState.Loading

            val result = repository.processTimetableImage(imageFile)
            result.fold(
                onSuccess = { response ->
                    val entities = response.toClassEntities()
                    database.timetableDao().replaceTimetable(entities)
                    _uiState.value = TimetableUploadUiState.Success(response, entities)
                },
                onFailure = { error ->
                    _uiState.value = when (error) {
                        is TimetableUploadException.RateLimitExceeded -> {
                            TimetableUploadUiState.RateLimitExceeded(
                                error.message ?: "Weekly scan limit reached. Please try again next week or enter manually."
                            )
                        }
                        else -> {
                            TimetableUploadUiState.Error(
                                error.localizedMessage ?: "Failed to upload timetable."
                            )
                        }
                    }
                }
            )
        }
    }

    /**
     * Resets state back to [TimetableUploadUiState.Idle].
     */
    fun resetState() {
        _uiState.value = TimetableUploadUiState.Idle
    }
}
