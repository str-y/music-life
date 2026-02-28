#include "yin.h"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstring>
#include <limits>
#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif
#if defined(__SSE3__)
#include <pmmintrin.h>
#endif

namespace music_life {

// ---------------------------------------------------------------------------
// Internal FFT utilities (anonymous namespace)
// ---------------------------------------------------------------------------

namespace {

inline void multiply_conj_fft_bins(std::complex<float>* lhs,
                                   const std::complex<float>* rhs,
                                   int n) {
    int i = 0;
#if defined(__ARM_NEON)
    const float32x4_t conj_sign = {1.0f, -1.0f, 1.0f, -1.0f};
    for (; i + 1 < n; i += 2) {
        const float32x4_t a = vld1q_f32(reinterpret_cast<const float*>(lhs + i));
        const float32x4_t b = vld1q_f32(reinterpret_cast<const float*>(rhs + i));
        const float32x4_t a_conj = vmulq_f32(a, conj_sign);

        const float32x4x2_t a_parts = vuzpq_f32(a_conj, a_conj);
        const float32x4x2_t b_parts = vuzpq_f32(b, b);

        const float32x4_t re = vsubq_f32(vmulq_f32(a_parts.val[0], b_parts.val[0]),
                                         vmulq_f32(a_parts.val[1], b_parts.val[1]));
        const float32x4_t im = vaddq_f32(vmulq_f32(a_parts.val[0], b_parts.val[1]),
                                         vmulq_f32(a_parts.val[1], b_parts.val[0]));
        const float32x4x2_t out = vzipq_f32(re, im);
        vst1q_f32(reinterpret_cast<float*>(lhs + i), out.val[0]);
    }
#elif defined(__SSE3__)
    const __m128 conj_sign = _mm_castsi128_ps(_mm_set_epi32(0x80000000, 0, 0x80000000, 0));
    for (; i + 1 < n; i += 2) {
        const __m128 a = _mm_loadu_ps(reinterpret_cast<const float*>(lhs + i));
        const __m128 b = _mm_loadu_ps(reinterpret_cast<const float*>(rhs + i));
        const __m128 a_conj = _mm_xor_ps(a, conj_sign);
        const __m128 ar = _mm_moveldup_ps(a_conj);
        const __m128 ai = _mm_movehdup_ps(a_conj);
        const __m128 b_swapped = _mm_shuffle_ps(b, b, _MM_SHUFFLE(2, 3, 0, 1));
        const __m128 out = _mm_addsub_ps(_mm_mul_ps(ar, b), _mm_mul_ps(ai, b_swapped));
        _mm_storeu_ps(reinterpret_cast<float*>(lhs + i), out);
    }
#endif
    for (; i < n; ++i) lhs[i] = std::conj(lhs[i]) * rhs[i];
}

inline void compute_sq_prefix(const float* samples, int n, std::vector<float>& sq_prefix) {
    sq_prefix[0] = 0.0f;
    int i = 0;
    float running = 0.0f;
#if defined(__ARM_NEON)
    for (; i + 3 < n; i += 4) {
        const float32x4_t x = vld1q_f32(samples + i);
        const float32x4_t xx = vmulq_f32(x, x);
        alignas(16) float sq[4];
        vst1q_f32(sq, xx);
        running += sq[0]; sq_prefix[i + 1] = running;
        running += sq[1]; sq_prefix[i + 2] = running;
        running += sq[2]; sq_prefix[i + 3] = running;
        running += sq[3]; sq_prefix[i + 4] = running;
    }
#elif defined(__SSE3__)
    for (; i + 3 < n; i += 4) {
        const __m128 x = _mm_loadu_ps(samples + i);
        const __m128 xx = _mm_mul_ps(x, x);
        alignas(16) float sq[4];
        _mm_store_ps(sq, xx);
        running += sq[0]; sq_prefix[i + 1] = running;
        running += sq[1]; sq_prefix[i + 2] = running;
        running += sq[2]; sq_prefix[i + 3] = running;
        running += sq[3]; sq_prefix[i + 4] = running;
    }
#endif
    for (; i < n; ++i) {
        running += samples[i] * samples[i];
        sq_prefix[i + 1] = running;
    }
}

inline void compute_difference_from_corr(const std::vector<float>& sq_prefix,
                                         const std::vector<std::complex<float>>& corr,
                                         int W,
                                         std::vector<float>& df) {
    const float A = sq_prefix[W];
    int tau = 0;
#if defined(__ARM_NEON)
    const float32x4_t a_vec = vdupq_n_f32(A);
    for (; tau + 3 < W; tau += 4) {
        const float32x4_t b_lo = vld1q_f32(sq_prefix.data() + tau);
        const float32x4_t b_hi = vld1q_f32(sq_prefix.data() + tau + W);
        const float32x4_t b = vsubq_f32(b_hi, b_lo);
        float32x4_t r = vmovq_n_f32(0.0f);
        r = vsetq_lane_f32(corr[tau].real(), r, 0);
        r = vsetq_lane_f32(corr[tau + 1].real(), r, 1);
        r = vsetq_lane_f32(corr[tau + 2].real(), r, 2);
        r = vsetq_lane_f32(corr[tau + 3].real(), r, 3);
        const float32x4_t out = vsubq_f32(vaddq_f32(a_vec, b), vmulq_n_f32(r, 2.0f));
        vst1q_f32(df.data() + tau, out);
    }
#elif defined(__SSE3__)
    const __m128 a_vec = _mm_set1_ps(A);
    const __m128 two = _mm_set1_ps(2.0f);
    for (; tau + 3 < W; tau += 4) {
        const __m128 b_lo = _mm_loadu_ps(sq_prefix.data() + tau);
        const __m128 b_hi = _mm_loadu_ps(sq_prefix.data() + tau + W);
        const __m128 b = _mm_sub_ps(b_hi, b_lo);
        const __m128 r = _mm_set_ps(corr[tau + 3].real(), corr[tau + 2].real(),
                                    corr[tau + 1].real(), corr[tau].real());
        const __m128 out = _mm_sub_ps(_mm_add_ps(a_vec, b), _mm_mul_ps(two, r));
        _mm_storeu_ps(df.data() + tau, out);
    }
#endif
    for (; tau < W; ++tau) {
        const float B_tau = sq_prefix[tau + W] - sq_prefix[tau];
        const float r_tau = corr[tau].real();
        df[tau] = A + B_tau - 2.0f * r_tau;
    }
}

// In-place Cooley-Tukey radix-2 DIT FFT.  n must be a power of two.
void fft_inplace(std::vector<std::complex<float>>& x,
                 const std::vector<std::complex<float>>& twiddle) {
    const int n = static_cast<int>(x.size());

    // Bit-reversal permutation
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) std::swap(x[i], x[j]);
    }

    // Butterfly passes – twiddle factor for butterfly j in stage len is
    // W_len^j = W_n^(j*n/len) = twiddle[j * (n/len)].
    // No transcendental calls in the hot path.
    for (int len = 2; len <= n; len <<= 1) {
        const int step = n / len;
        for (int i = 0; i < n; i += len) {
            for (int j = 0; j < len / 2; ++j) {
                const std::complex<float> w = twiddle[j * step];
                const std::complex<float> u = x[i + j];
                const std::complex<float> v = x[i + j + len / 2] * w;
                x[i + j]           = u + v;
                x[i + j + len / 2] = u - v;
            }
        }
    }
}

// In-place IFFT via conjugate trick.
void ifft_inplace(std::vector<std::complex<float>>& x,
                  const std::vector<std::complex<float>>& twiddle) {
    for (auto& c : x) c = std::conj(c);
    fft_inplace(x, twiddle);
    const float inv_n = 1.0f / static_cast<float>(x.size());
    for (auto& c : x) c = std::conj(c) * inv_n;
}

} // anonymous namespace

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static int compute_fft_size(int buffer_size) {
    int s = 1;
    while (s < 2 * buffer_size) s <<= 1;
    return s;
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

Yin::Yin(int sample_rate, int buffer_size, float threshold)
    : sample_rate_(sample_rate)
    , buffer_size_(buffer_size)
    , threshold_(threshold)
    , half_buffer_(buffer_size / 2)
    , fft_size_(compute_fft_size(buffer_size))
    , probability_(0.0f)
    , fft_F_(fft_size_, {0.0f, 0.0f})
    , fft_G_(fft_size_, {0.0f, 0.0f})
    , sq_prefix_(buffer_size + 1, 0.0f)
    , twiddle_(fft_size_ / 2)
{
    // Pre-compute twiddle factors: twiddle_[k] = exp(-2pi*i*k / fft_size_).
    // These are computed once here so the real-time audio path is free of
    // any std::cos / std::sin calls during FFT butterfly passes.
    const float two_pi_over_n =
        -2.0f * static_cast<float>(M_PI) / static_cast<float>(fft_size_);
    for (int k = 0; k < fft_size_ / 2; ++k) {
        const float ang = two_pi_over_n * static_cast<float>(k);
        twiddle_[k] = {std::cos(ang), std::sin(ang)};
    }
}

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

float Yin::detect(const float* samples, std::vector<float>& workspace) {
    if (static_cast<int>(workspace.size()) < half_buffer_) {
        probability_ = 0.0f;
        return -1.0f;
    }
    std::memset(workspace.data(), 0, static_cast<size_t>(half_buffer_) * sizeof(float));

    difference(samples, workspace);
    cmndf(workspace);

    int tau = absolute_threshold(workspace);
    if (tau == -1) {
        probability_ = 0.0f;
        return -1.0f;
    }

    float refined_tau = parabolic_interpolation(workspace, tau);
    probability_ = 1.0f - workspace[tau];
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

    // f = x[0..W-1], zero-padded to fft_size_
    for (int j = 0; j < W; ++j) fft_F_[j] = {samples[j], 0.0f};
    std::fill(fft_F_.begin() + W, fft_F_.end(), std::complex<float>{0.0f, 0.0f});

    // g = x[0..buffer_size_-1], zero-padded to fft_size_
    for (int j = 0; j < buffer_size_; ++j) fft_G_[j] = {samples[j], 0.0f};
    std::fill(fft_G_.begin() + buffer_size_, fft_G_.end(), std::complex<float>{0.0f, 0.0f});

    fft_inplace(fft_F_, twiddle_);
    fft_inplace(fft_G_, twiddle_);

    // Cross-correlation in frequency domain: conj(F) * G
    multiply_conj_fft_bins(fft_F_.data(), fft_G_.data(), fft_size_);
    ifft_inplace(fft_F_, twiddle_);  // fft_F_[tau].real() == r(tau)

    // Prefix sums of squares for A and B(tau)
    compute_sq_prefix(samples, buffer_size_, sq_prefix_);
    compute_difference_from_corr(sq_prefix_, fft_F_, W, df);
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
