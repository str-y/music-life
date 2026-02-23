#include "pitch_detector_ffi.h"

#include "pitch_detector.h"

#include <cstdio>
#include <cstring>
#include <memory>

struct MLPitchDetectorHandle {
    std::unique_ptr<music_life::PitchDetector> detector;
};

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold) {
    return ml_pitch_detector_create_with_reference_pitch(sample_rate, frame_size, threshold, 440.0f);
}

MLPitchDetectorHandle* ml_pitch_detector_create_with_reference_pitch(int sample_rate,
                                                                     int frame_size,
                                                                     float threshold,
                                                                     float reference_pitch_hz) {
    try {
        auto* handle = new MLPitchDetectorHandle{
            std::make_unique<music_life::PitchDetector>(sample_rate, frame_size, threshold, reference_pitch_hz)
        };
        return handle;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_create: exception: %s\n", e.what());
        return nullptr;
    } catch (...) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_create: unknown exception\n");
        return nullptr;
    }
}

void ml_pitch_detector_destroy(MLPitchDetectorHandle* handle) {
    if (!handle) return;
    delete handle;
}

void ml_pitch_detector_reset(MLPitchDetectorHandle* handle) {
    if (!handle) return;
    handle->detector->reset();
}

int ml_pitch_detector_set_reference_pitch(MLPitchDetectorHandle* handle, float reference_pitch_hz) {
    if (!handle) return 0;
    try {
        handle->detector->set_reference_pitch(reference_pitch_hz);
        return 1;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_set_reference_pitch: exception: %s\n", e.what());
        return 0;
    } catch (...) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_set_reference_pitch: unknown exception\n");
        return 0;
    }
}

MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples) {
    MLPitchResult out{};
    if (!handle || !samples || num_samples <= 0) return out;

    try {
        const music_life::PitchDetector::Result result = handle->detector->process(samples, num_samples);
        out.pitched      = result.pitched ? 1 : 0;
        out.frequency    = result.frequency;
        out.probability  = result.probability;
        out.midi_note    = result.midi_note;
        out.cents_offset = result.cents_offset;
        std::strncpy(out.note_name, result.note_name, sizeof(out.note_name) - 1);
        out.note_name[sizeof(out.note_name) - 1] = '\0';
    } catch (const std::exception& e) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_process: exception: %s\n", e.what());
        return out;
    } catch (...) {
        std::fprintf(stderr, "[music-life] ml_pitch_detector_process: unknown exception\n");
        return out;
    }
    return out;
}
