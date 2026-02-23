#include "pitch_detector_ffi.h"

#include "pitch_detector.h"

#include <memory>

struct MLPitchDetectorHandle {
    std::unique_ptr<music_life::PitchDetector> detector;
};

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold) {
    try {
        auto* handle = new MLPitchDetectorHandle{
            std::make_unique<music_life::PitchDetector>(sample_rate, frame_size, threshold)
        };
        return handle;
    } catch (...) {
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

MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples) {
    MLPitchResult out{};
    if (!handle || !samples || num_samples <= 0) return out;

    const music_life::PitchDetector::Result result = handle->detector->process(samples, num_samples);
    out.pitched      = result.pitched ? 1 : 0;
    out.frequency    = result.frequency;
    out.probability  = result.probability;
    out.midi_note    = result.midi_note;
    out.cents_offset = result.cents_offset;
    return out;
}
