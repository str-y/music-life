#include "pitch_detector.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace music_life {

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

static constexpr float kA4_Hz        = 440.0f;
static constexpr int   kA4_Midi      = 69;
static constexpr float kMinFrequency = 20.0f;   // Hz
static constexpr float kMaxFrequency = 4200.0f; // Hz
static constexpr float kMinReferencePitch = 430.0f;
static constexpr float kMaxReferencePitch = 450.0f;

static const char* kNoteNames[] = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
};

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

PitchDetector::PitchDetector(int sample_rate, int frame_size, float threshold, float reference_pitch_hz)
    : sample_rate_(sample_rate)
    , frame_size_(frame_size)
    , reference_pitch_hz_(reference_pitch_hz)
    , yin_(std::make_unique<Yin>(sample_rate, frame_size, threshold))
    , ring_buffer_(frame_size * 2, 0.0f)
    , frame_buffer_(frame_size, 0.0f)
    , write_pos_(0)
    , samples_ready_(0)
    , last_result_{}
{
    if (sample_rate <= 0) throw std::invalid_argument("sample_rate must be > 0");
    if (frame_size  <= 1) throw std::invalid_argument("frame_size must be > 1");
    if (reference_pitch_hz < kMinReferencePitch || reference_pitch_hz > kMaxReferencePitch) {
        throw std::invalid_argument("reference_pitch_hz must be in [432, 445]");
    }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void PitchDetector::reset() {
    std::fill(ring_buffer_.begin(), ring_buffer_.end(), 0.0f);
    write_pos_    = 0;
    samples_ready_ = 0;
    last_result_  = {};
}

void PitchDetector::set_reference_pitch(float reference_pitch_hz) {
    if (reference_pitch_hz < kMinReferencePitch || reference_pitch_hz > kMaxReferencePitch) {
        throw std::invalid_argument("reference_pitch_hz must be in [432, 445]");
    }
    reference_pitch_hz_ = reference_pitch_hz;
}

PitchDetector::Result PitchDetector::process(const float* samples, int num_samples) {
    // Feed incoming samples into the ring buffer
    for (int i = 0; i < num_samples; ++i) {
        ring_buffer_[write_pos_] = samples[i];
        write_pos_ = (write_pos_ + 1) % (frame_size_ * 2);
        if (samples_ready_ < frame_size_) {
            ++samples_ready_;
        }
    }

    // Not enough samples yet
    if (samples_ready_ < frame_size_) {
        return last_result_;
    }

    // Assemble a contiguous frame from the ring buffer
    int start = (write_pos_ - frame_size_ + frame_size_ * 2) % (frame_size_ * 2);
    for (int i = 0; i < frame_size_; ++i) {
        frame_buffer_[i] = ring_buffer_[(start + i) % (frame_size_ * 2)];
    }

    // Run YIN detection
    float freq = yin_->detect(frame_buffer_.data());
    float prob = yin_->probability();

    Result result{};
    if (freq > kMinFrequency && freq < kMaxFrequency) {
        result.pitched     = true;
        result.frequency   = freq;
        result.probability = prob;
        result.midi_note   = frequency_to_midi(freq);
        float nearest_freq = midi_to_frequency(result.midi_note);
        result.cents_offset = cents_between(nearest_freq, freq);
        result.note_name   = midi_to_note_name(result.midi_note);
    } else {
        result.pitched     = false;
        result.frequency   = 0.0f;
        result.probability = 0.0f;
    }

    last_result_ = result;
    return result;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

int PitchDetector::frequency_to_midi(float frequency) const {
    if (frequency <= 0.0f) return 0;
    float midi = 12.0f * std::log2(frequency / reference_pitch_hz_) + static_cast<float>(kA4_Midi);
    return std::clamp(static_cast<int>(std::round(midi)), 0, 127);
}

float PitchDetector::midi_to_frequency(int midi_note) const {
    return reference_pitch_hz_ * std::pow(2.0f, (static_cast<float>(midi_note - kA4_Midi)) / 12.0f);
}

float PitchDetector::cents_between(float reference_hz, float actual_hz) {
    if (reference_hz <= 0.0f || actual_hz <= 0.0f) return 0.0f;
    return 1200.0f * std::log2(actual_hz / reference_hz);
}

std::string PitchDetector::midi_to_note_name(int midi_note) {
    int octave     = (midi_note / 12) - 1;
    int note_index = midi_note % 12;
    return std::string(kNoteNames[note_index]) + std::to_string(octave);
}

} // namespace music_life
