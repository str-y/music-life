#pragma once

#include <complex>
#include <vector>

namespace music_life {

enum class FftBackend {
    Auto,
    Radix2,
    Accelerate,
    Fftw
};

/**
 * YIN pitch detection algorithm.
 *
 * Based on: "YIN, a fundamental frequency estimator for speech and music"
 * de Cheveigné & Kawahara, JASA 2002.
 *
 * Provides high-precision fundamental frequency (F0) estimation from a
 * mono audio buffer using the Cumulative Mean Normalized Difference Function
 * with parabolic interpolation for sub-sample accuracy.
 */
class Yin {
public:
    /**
     * @param sample_rate   Audio sample rate in Hz (e.g. 44100).
     * @param buffer_size   Number of samples in one analysis frame.
     * @param threshold     CMNDF threshold for peak detection (default 0.10).
     */
    Yin(int sample_rate, int buffer_size, float threshold = 0.10f);
    ~Yin();

    /**
     * Estimate the fundamental frequency of the given audio samples.
     *
     * @param samples    Mono audio buffer (buffer_size samples, range [-1, 1]).
     * @param workspace  Caller-supplied scratch buffer (size >= buffer_size / 2).
     *                   Providing this per-call buffer makes detect() safe for
     *                   concurrent use from multiple real-time threads as long as
     *                   each thread passes its own workspace. detect() does not
     *                   resize this buffer in the real-time path.
     * @return Fundamental frequency in Hz, or -1 if no pitch is detected.
     */
    float detect(const float* samples, std::vector<float>& workspace);
    const char* fft_backend_name() const;

    /** Probability of the last detected pitch (0–1). */
    float probability() const { return probability_; }

private:
    int   sample_rate_;
    int   buffer_size_;
    float threshold_;
    int   half_buffer_;
    int   fft_size_;

    float probability_;

    // Pre-allocated scratch buffers for difference() – avoids per-call
    // heap allocations in the real-time audio path.
    mutable std::vector<std::complex<float>> fft_F_;
    mutable std::vector<std::complex<float>> fft_G_;
    mutable std::vector<float>               sq_prefix_;

    // Pre-computed twiddle factors: twiddle_[k] = exp(-2pi*i*k / fft_size_)
    // for k = 0 ... fft_size_/2 - 1.  Computed once in the constructor so the
    // hot audio path never calls std::cos / std::sin.
    std::vector<std::complex<float>> twiddle_;
    FftBackend fft_backend_;

    void* accelerate_forward_setup_;
    void* accelerate_inverse_setup_;
    void* fftw_forward_plan_;
    void* fftw_inverse_plan_;
    std::vector<std::complex<float>> fftw_plan_buffer_;
    mutable std::vector<float> accelerate_in_real_;
    mutable std::vector<float> accelerate_in_imag_;
    mutable std::vector<float> accelerate_out_real_;
    mutable std::vector<float> accelerate_out_imag_;


    /** Step 2: Difference function. */
    void  difference(const float* samples, std::vector<float>& df) const;

    /** Step 3: Cumulative mean normalized difference function. */
    void  cmndf(std::vector<float>& df) const;

    /** Steps 4–5: Absolute threshold + parabolic interpolation. */
    float parabolic_interpolation(const std::vector<float>& df, int tau) const;

    /** Return the best lag index using the absolute threshold. */
    int   absolute_threshold(const std::vector<float>& df) const;
};

} // namespace music_life
