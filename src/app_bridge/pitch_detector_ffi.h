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
void ml_pitch_detector_destroy(MLPitchDetectorHandle* handle);
void ml_pitch_detector_reset(MLPitchDetectorHandle* handle);
MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples);

#ifdef __cplusplus
}
#endif
