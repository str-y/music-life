#include "yin.h"

#include <algorithm>
#include <cmath>
#include <complex>
#include <limits>

namespace music_life {

// ---------------------------------------------------------------------------
// Internal FFT utilities (anonymous namespace)
// ---------------------------------------------------------------------------

namespace {

// In-place Cooley-Tukey radix-2 DIT FFT.  n must be a power of two.
void fft_inplace(std::vector<std::complex<float>>& x) {
    const int n = static_cast<int>(x.size());

    // Bit-reversal permutation
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(x[i], x[j]);
    }

    // Butterfly passes
    for (int len = 2; len <= n; len <<= 1) {
        const float ang = -2.0f * static_cast<float>(M_PI) / static_cast<float>(len);
        const std::complex<float> wlen(std::cos(ang), std::sin(ang));
        for (int i = 0; i < n; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (int j = 0; j < len / 2; ++j) {
                const std::complex<float> u = x[i + j];
                const std::complex<float> v = x[i + j + len / 2] * w;
                x[i + j]           = u + v;
                x[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

// In-place IFFT via conjugate trick.
void ifft_inplace(std::vector<std::complex<float>>& x) {
    for (auto& c : x) c = std::conj(c);
    fft_inplace(x);
    const float inv_n = 1.0f / static_cast<float>(x.size());
    for (auto& c : x) c = std::conj(c) * inv_n;
}

} // anonymous namespace

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

Yin::Yin(int sample_rate, int buffer_size, float threshold)
    : sample_rate_(sample_rate)
    , buffer_size_(buffer_size)
    , threshold_(threshold)
    , half_buffer_(buffer_size / 2)
    , probability_(0.0f)
    , df_buffer_(half_buffer_, 0.0f)
{}

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

float Yin::detect(const float* samples) const {
    std::fill(df_buffer_.begin(), df_buffer_.end(), 0.0f);
    difference(samples, df_buffer_);
    cmndf(df_buffer_);

    int tau = absolute_threshold(df_buffer_);
    if (tau == -1) {
        probability_ = 0.0f;
        return -1.0f;
    }

    float refined_tau = parabolic_interpolation(df_buffer_, tau);
    probability_ = 1.0f - df_buffer_[tau];
    return static_cast<float>(sample_rate_) / refined_tau;
}

// ---------------------------------------------------------------------------
// Step 2: Difference function (O(N log N) via FFT-based autocorrelation)
//
//   d(tau) = sum_{j=0}^{W-1} ( x_j - x_{j+tau} )^2
//          = A + B(tau) - 2 * r(tau)
//
//   where:
//     A      = sum_{j=0}^{W-1} x_j^2                (constant, prefix sum)
//     B(tau) = sum_{j=tau}^{tau+W-1} x_j^2           (sliding window, prefix sum)
//     r(tau) = sum_{j=0}^{W-1} x_j * x_{j+tau}       (cross-correlation via FFT)
// ---------------------------------------------------------------------------

void Yin::difference(const float* samples, std::vector<float>& df) const {
    const int W = half_buffer_;

    // FFT size: next power of two that is >= 2 * buffer_size to prevent
    // circular aliasing in the cross-correlation.
    int fft_size = 1;
    while (fft_size < 2 * buffer_size_) fft_size <<= 1;

    // f = x[0..W-1], zero-padded to fft_size
    std::vector<std::complex<float>> F(fft_size, {0.0f, 0.0f});
    for (int j = 0; j < W; ++j) F[j] = {samples[j], 0.0f};

    // g = x[0..buffer_size-1], zero-padded to fft_size
    std::vector<std::complex<float>> G(fft_size, {0.0f, 0.0f});
    for (int j = 0; j < buffer_size_; ++j) G[j] = {samples[j], 0.0f};

    fft_inplace(F);
    fft_inplace(G);

    // Cross-correlation in frequency domain: conj(F) * G
    for (int i = 0; i < fft_size; ++i) F[i] = std::conj(F[i]) * G[i];
    ifft_inplace(F);  // F[tau].real() == r(tau)

    // Prefix sums of squares for A and B(tau)
    std::vector<float> sq_prefix(buffer_size_ + 1, 0.0f);
    for (int j = 0; j < buffer_size_; ++j)
        sq_prefix[j + 1] = sq_prefix[j] + samples[j] * samples[j];

    const float A = sq_prefix[W];
    for (int tau = 0; tau < W; ++tau) {
        const float B_tau = sq_prefix[tau + W] - sq_prefix[tau];
        const float r_tau = F[tau].real();
        df[tau] = A + B_tau - 2.0f * r_tau;
    }
}

// ---------------------------------------------------------------------------
// Step 3: Cumulative mean normalized difference function
//
//   d'(0)   = 1
//   d'(tau) = d(tau) / [ (1/tau) * sum_{j=1}^{tau} d(j) ]
// ---------------------------------------------------------------------------

void Yin::cmndf(std::vector<float>& df) const {
    df[0] = 1.0f;
    float running_sum = 0.0f;
    for (int tau = 1; tau < half_buffer_; ++tau) {
        running_sum += df[tau];
        if (running_sum == 0.0f) {
            df[tau] = 1.0f;
        } else {
            df[tau] *= static_cast<float>(tau) / running_sum;
        }
    }
}

// ---------------------------------------------------------------------------
// Step 4: Absolute threshold
// ---------------------------------------------------------------------------

int Yin::absolute_threshold(const std::vector<float>& df) const {
    // Start from tau = 2 (tau = 1 is always very low for periodic signals)
    for (int tau = 2; tau < half_buffer_; ++tau) {
        if (df[tau] < threshold_) {
            // Find the local minimum in this dip
            while (tau + 1 < half_buffer_ && df[tau + 1] < df[tau]) {
                ++tau;
            }
            return tau;
        }
    }
    // No pitch found below threshold – return the global minimum instead
    int min_tau = 2;
    for (int tau = 3; tau < half_buffer_; ++tau) {
        if (df[tau] < df[min_tau]) {
            min_tau = tau;
        }
    }
    return (df[min_tau] < 0.5f) ? min_tau : -1;
}

// ---------------------------------------------------------------------------
// Step 5: Parabolic interpolation for sub-sample accuracy
// ---------------------------------------------------------------------------

float Yin::parabolic_interpolation(const std::vector<float>& df, int tau) const {
    if (tau <= 0 || tau >= half_buffer_ - 1) {
        return static_cast<float>(tau);
    }
    float s0 = df[tau - 1];
    float s1 = df[tau];
    float s2 = df[tau + 1];
    float denom = 2.0f * (2.0f * s1 - s2 - s0);
    if (std::abs(denom) < std::numeric_limits<float>::epsilon()) {
        return static_cast<float>(tau);
    }
    return static_cast<float>(tau) + (s2 - s0) / denom;
}

} // namespace music_life
