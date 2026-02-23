#include "yin.h"

#include <cmath>
#include <limits>

namespace music_life {

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

Yin::Yin(int sample_rate, int buffer_size, float threshold)
    : sample_rate_(sample_rate)
    , buffer_size_(buffer_size)
    , threshold_(threshold)
    , half_buffer_(buffer_size / 2)
    , probability_(0.0f)
{}

// ---------------------------------------------------------------------------
// Public interface
// ---------------------------------------------------------------------------

float Yin::detect(const float* samples) const {
    std::vector<float> df(half_buffer_, 0.0f);

    difference(samples, df);
    cmndf(df);

    int tau = absolute_threshold(df);
    if (tau == -1) {
        probability_ = 0.0f;
        return -1.0f;
    }

    float refined_tau = parabolic_interpolation(df, tau);
    probability_ = 1.0f - df[tau];
    return static_cast<float>(sample_rate_) / refined_tau;
}

// ---------------------------------------------------------------------------
// Step 2: Difference function
//
//   d(tau) = sum_{j=1}^{W} ( x_j - x_{j+tau} )^2
// ---------------------------------------------------------------------------

void Yin::difference(const float* samples, std::vector<float>& df) const {
    for (int tau = 0; tau < half_buffer_; ++tau) {
        float sum = 0.0f;
        for (int j = 0; j < half_buffer_; ++j) {
            float delta = samples[j] - samples[j + tau];
            sum += delta * delta;
        }
        df[tau] = sum;
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
