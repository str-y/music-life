#pragma once

#include "yin.h"

#include <memory>
#include <string>

namespace music_life {

/**
 * High-level pitch detector for the music-life app.
 *
 * Wraps the YIN algorithm and exposes a simple interface that can be called
 * from platform-specific audio callbacks on iOS (Core Audio) and Android
 * (Oboe / AAudio).
 *
 * Usage:
 *   PitchDetector detector(44100, 2048);
 *   // In the audio callback:
 *   PitchDetector::Result r = detector.process(buffer, num_samples);
 *   if (r.pitched) { use(r.frequency, r.note_name, r.cents_offset); }
 */
class PitchDetector {
public:
    struct Result {
        bool  pitched;        ///< true if a stable pitch was detected
        float frequency;      ///< Fundamental frequency in Hz
        float probability;    ///< Confidence [0, 1]
        int   midi_note;      ///< Closest MIDI note number (0–127)
        float cents_offset;   ///< Offset from the nearest semitone in cents [-50, 50]
        std::string note_name; ///< e.g. "A4", "C#3"
    };

    /**
     * @param sample_rate   Audio sample rate in Hz.
     * @param frame_size    Analysis frame size in samples (power of 2 recommended).
     * @param threshold     YIN threshold [0,1] – lower values = stricter detection.
     */
    explicit PitchDetector(int sample_rate,
                           int frame_size = 2048,
                           float threshold = 0.10f);

    ~PitchDetector() = default;

    /**
     * Process a mono audio buffer.
     *
     * If num_samples < frame_size, samples are accumulated internally until a
     * full frame is available, then detection is performed.  Subsequent calls
     * advance with 50 % hop (overlapping frames) for low-latency updates.
     *
     * @param samples     Pointer to interleaved mono float samples [-1, 1].
     * @param num_samples Number of samples in this callback block.
     * @return            Detection result (pitched = false if no full frame yet).
     */
    Result process(const float* samples, int num_samples);

    /** Reset internal state (call on stream restart). */
    void reset();

private:
    int   sample_rate_;
    int   frame_size_;
    std::unique_ptr<Yin> yin_;

    std::vector<float> ring_buffer_;
    int                write_pos_;
    int                samples_ready_;

    Result last_result_;

    static int   frequency_to_midi(float frequency);
    static float midi_to_frequency(int midi_note);
    static float cents_between(float f1, float f2);
    static std::string midi_to_note_name(int midi_note);
};

} // namespace music_life
