#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Maximum number of bytes (including null terminator) reserved for a note name
 *  in MLPitchResult.  Sized to hold the longest possible name (e.g. "C#-1")
 *  with comfortable headroom for future extensions. */
#define ML_PITCH_NOTE_NAME_SIZE 8

typedef struct MLPitchDetectorHandle MLPitchDetectorHandle;

typedef enum {
    ML_LOG_LEVEL_TRACE = 0,
    ML_LOG_LEVEL_DEBUG = 1,
    ML_LOG_LEVEL_INFO  = 2,
    ML_LOG_LEVEL_ERROR = 3,
} MLLogLevel;

typedef void (*MLLogCallback)(int level, const char* message);

typedef struct {
    int   pitched;
    float frequency;
    float probability;
    int   midi_note;
    float cents_offset;
    char  note_name[ML_PITCH_NOTE_NAME_SIZE];
} MLPitchResult;

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold);
MLPitchDetectorHandle* ml_pitch_detector_create_with_reference_pitch(int sample_rate, int frame_size, float threshold, float reference_pitch_hz);
void ml_pitch_detector_destroy(MLPitchDetectorHandle* handle);
void ml_pitch_detector_reset(MLPitchDetectorHandle* handle);
int ml_pitch_detector_set_reference_pitch(MLPitchDetectorHandle* handle, float reference_pitch_hz);
MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples);
void ml_pitch_detector_set_log_callback(MLLogCallback callback);
void ml_pitch_detector_install_crash_handlers(void);

#ifdef __cplusplus
}
#endif
