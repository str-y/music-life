#include "pitch_detector.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
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

/** Buffer size (bytes, including null terminator) for each entry in the
 *  pre-built note-name lookup table.  Sized to hold the longest possible
 *  name ("C#-1" = 4 chars) plus a null terminator, with comfortable
 *  headroom. */
static constexpr int   kNoteNameBufSize   = 6;

static const char* const kNoteTable[128] = {
    "C-1","C#-1","D-1","D#-1","E-1","F-1","F#-1","G-1","G#-1","A-1","A#-1","B-1",
    "C0", "C#0", "D0", "D#0", "E0", "F0", "F#0", "G0", "G#0", "A0", "A#0", "B0",
    "C1", "C#1", "D1", "D#1", "E1", "F1", "F#1", "G1", "G#1", "A1", "A#1", "B1",
    "C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2",
    "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3",
    "C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
    "C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
    "C6", "C#6", "D6", "D#6", "E6", "F6", "F#6", "G6", "G#6", "A6", "A#6", "B6",
    "C7", "C#7", "D7", "D#7", "E7", "F7", "F#7", "G7", "G#7", "A7", "A#7", "B7",
    "C8", "C#8", "D8", "D#8", "E8", "F8", "F#8", "G8", "G#8", "A8", "A#8", "B8",
    "C9", "C#9", "D9", "D#9", "E9", "F9", "F#9", "G9"
};

// Pre-built lookup table for all 128 MIDI note names.
// Populated once at static-initialization time so the audio thread never
// allocates.  Longest entry is "C#-1" (4 chars) + null = 5 bytes; 6 chars
// gives comfortable headroom.
static char s_note_name_buf[128][kNoteNameBufSize];

static const char* const kNoteNames[12] = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
};

static bool init_note_name_table() {
    for (int i = 0; i < 128; ++i) {
        int octave = (i / 12) - 1;
        int note   = i % 12;
        std::snprintf(s_note_name_buf[i], sizeof(s_note_name_buf[i]),
                      "%s%d", kNoteNames[note], octave);
    }
    return true;
}

[[maybe_unused]] static const bool s_note_name_table_initialized = init_note_name_table();

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

PitchDetector::PitchDetector(int sample_rate, int frame_size, float threshold, float reference_pitch_hz)
    : sample_rate_(sample_rate)
    , frame_size_(frame_size)
    , reference_pitch_hz_(reference_pitch_hz)
    , yin_(std::make_unique<Yin>(sample_rate, frame_size, threshold))
    , reset_pending_(false)
    , ring_buffer_(frame_size * 2, 0.0f)
    , frame_buffer_(frame_size, 0.0f)
    , yin_workspace_(frame_size / 2, 0.0f)
    , write_pos_(0)
    , samples_ready_(0)
    , samples_since_last_process_(0)
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
    reset_pending_.store(true, std::memory_order_release);
}

void PitchDetector::set_reference_pitch(float reference_pitch_hz) {
    if (reference_pitch_hz < kMinReferencePitch || reference_pitch_hz > kMaxReferencePitch) {
        throw std::invalid_argument("reference_pitch_hz must be in [432, 445]");
    }
    reference_pitch_hz_.store(reference_pitch_hz, std::memory_order_relaxed);
}

PitchDetector::Result PitchDetector::process(const float* samples, int num_samples) {
    if (reset_pending_.exchange(false, std::memory_order_acq_rel)) {
        std::fill(ring_buffer_.begin(), ring_buffer_.end(), 0.0f);
        write_pos_     = 0;
        samples_ready_ = 0;
        last_result_   = {};
    }

    // Feed incoming samples into the ring buffer
    for (int i = 0; i < num_samples; ++i) {
        ring_buffer_[write_pos_] = samples[i];
        write_pos_ = (write_pos_ + 1) % (frame_size_ * 2);
        if (samples_ready_ < frame_size_) {
            ++samples_ready_;
        }
    }
    samples_since_last_process_ += num_samples;

    // Not enough samples yet
    if (samples_ready_ < frame_size_) {
        return last_result_;
    }

    // Hop hasn't elapsed (50% overlap): only run YIN every frame_size/2 new samples
    if (samples_since_last_process_ < frame_size_ / 2) {
        return last_result_;
    }
    samples_since_last_process_ = 0;

    // Assemble a contiguous frame from the ring buffer
    int start = (write_pos_ - frame_size_ + frame_size_ * 2) % (frame_size_ * 2);
    for (int i = 0; i < frame_size_; ++i) {
        frame_buffer_[i] = ring_buffer_[(start + i) % (frame_size_ * 2)];
    }

    // Run YIN detection
    float freq = yin_->detect(frame_buffer_.data(), yin_workspace_);
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
    float ref = reference_pitch_hz_.load(std::memory_order_relaxed);
    float midi = 12.0f * std::log2(frequency / ref) + static_cast<float>(kA4_Midi);
    return std::clamp(static_cast<int>(std::round(midi)), 0, 127);
}

float PitchDetector::midi_to_frequency(int midi_note) const {
    float ref = reference_pitch_hz_.load(std::memory_order_relaxed);
    return ref * std::pow(2.0f, (static_cast<float>(midi_note - kA4_Midi)) / 12.0f);
}

float PitchDetector::cents_between(float reference_hz, float actual_hz) {
    if (reference_hz <= 0.0f || actual_hz <= 0.0f) return 0.0f;
    return 1200.0f * std::log2(actual_hz / reference_hz);
}

const char* PitchDetector::midi_to_note_name(int midi_note) {
    return s_note_name_buf[midi_note];
}

} // namespace music_life
