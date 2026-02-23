#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MLPitchDetectorHandle MLPitchDetectorHandle;

typedef struct {
    int   pitched;
    float frequency;
    float probability;
    int   midi_note;
    float cents_offset;
} MLPitchResult;

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold);
MLPitchDetectorHandle* ml_pitch_detector_create_with_reference_pitch(int sample_rate, int frame_size, float threshold, float reference_pitch_hz);
void ml_pitch_detector_destroy(MLPitchDetectorHandle* handle);
void ml_pitch_detector_reset(MLPitchDetectorHandle* handle);
int ml_pitch_detector_set_reference_pitch(MLPitchDetectorHandle* handle, float reference_pitch_hz);
MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples);

#ifdef __cplusplus
}
#endif
