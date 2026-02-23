/**
 * Unit tests for the music-life pitch detection module.
 *
 * Tests are written with a minimal, zero-dependency harness so they build
 * anywhere (iOS simulator, Android NDK, Linux CI).  Each test function
 * returns true on pass, false on fail.  The driver at the bottom collects
 * results and exits with a non-zero status if any test failed.
 */

#include "pitch_detector.h"
#include "pitch_detector_ffi.h"
#include "yin.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

using music_life::PitchDetector;
using music_life::Yin;

// ---------------------------------------------------------------------------
// Minimal test harness
// ---------------------------------------------------------------------------

static int g_passed = 0;
static int g_failed = 0;

#define ASSERT_TRUE(expr) \
    do { \
        if (!(expr)) { \
            std::fprintf(stderr, "  FAIL  %s:%d  %s\n", __FILE__, __LINE__, #expr); \
            return false; \
        } \
    } while (false)

#define ASSERT_NEAR(a, b, tol) \
    ASSERT_TRUE(std::abs((a) - (b)) <= (tol))

static bool run_test(const char* name, bool (*fn)()) {
    bool ok = fn();
    std::printf("[%s] %s\n", ok ? "PASS" : "FAIL", name);
    ok ? ++g_passed : ++g_failed;
    return ok;
}

// ---------------------------------------------------------------------------
// Signal generators
// ---------------------------------------------------------------------------

/** Generate a pure sine wave into buf. */
static void make_sine(std::vector<float>& buf, float freq_hz, int sample_rate) {
    int n = static_cast<int>(buf.size());
    for (int i = 0; i < n; ++i) {
        buf[i] = std::sin(2.0f * static_cast<float>(M_PI) * freq_hz
                          * static_cast<float>(i) / static_cast<float>(sample_rate));
    }
}

// ---------------------------------------------------------------------------
// Tests – YIN internals
// ---------------------------------------------------------------------------

static bool test_yin_sine_a4() {
    // A4 = 440 Hz, should be detected within ±2 Hz
    const int   SR          = 44100;
    const int   FRAME       = 2048;
    const float EXPECTED_HZ = 440.0f;

    Yin yin(SR, FRAME, 0.10f);
    std::vector<float> buf(FRAME);
    make_sine(buf, EXPECTED_HZ, SR);

    std::vector<float> workspace(FRAME / 2);
    float detected = yin.detect(buf.data(), workspace);
    ASSERT_NEAR(detected, EXPECTED_HZ, 2.0f);
    return true;
}

static bool test_yin_sine_e2() {
    // Low E guitar string ~82.4 Hz
    const int   SR          = 44100;
    const int   FRAME       = 4096;
    const float EXPECTED_HZ = 82.407f;

    Yin yin(SR, FRAME, 0.10f);
    std::vector<float> buf(FRAME);
    make_sine(buf, EXPECTED_HZ, SR);

    std::vector<float> workspace(FRAME / 2);
    float detected = yin.detect(buf.data(), workspace);
    ASSERT_NEAR(detected, EXPECTED_HZ, 2.0f);
    return true;
}

static bool test_yin_sine_c5() {
    // C5 ≈ 523.25 Hz
    const int   SR          = 44100;
    const int   FRAME       = 2048;
    const float EXPECTED_HZ = 523.25f;

    Yin yin(SR, FRAME, 0.10f);
    std::vector<float> buf(FRAME);
    make_sine(buf, EXPECTED_HZ, SR);

    std::vector<float> workspace(FRAME / 2);
    float detected = yin.detect(buf.data(), workspace);
    ASSERT_NEAR(detected, EXPECTED_HZ, 3.0f);
    return true;
}

static bool test_yin_silence_returns_no_pitch() {
    const int SR    = 44100;
    const int FRAME = 2048;

    Yin yin(SR, FRAME, 0.10f);
    std::vector<float> buf(FRAME, 0.0f);

    std::vector<float> workspace(FRAME / 2);
    float detected = yin.detect(buf.data(), workspace);
    ASSERT_TRUE(detected < 0.0f);
    return true;
}

static bool test_yin_workspace_no_reallocation() {
    // When the workspace is pre-allocated with the correct capacity,
    // Yin::detect must not trigger a heap reallocation (i.e. the
    // internal buffer pointer must remain unchanged across the call).
    const int SR    = 44100;
    const int FRAME = 2048;

    Yin yin(SR, FRAME, 0.10f);
    std::vector<float> buf(FRAME, 0.0f);

    std::vector<float> workspace(FRAME / 2);
    const float* ptr_before = workspace.data();
    yin.detect(buf.data(), workspace);
    const float* ptr_after = workspace.data();

    ASSERT_TRUE(ptr_before == ptr_after);
    return true;
}

// ---------------------------------------------------------------------------
// Tests – PitchDetector
// ---------------------------------------------------------------------------

static bool test_pd_a4_midi_and_note_name() {
    const int SR    = 44100;
    const int FRAME = 2048;

    PitchDetector pd(SR, FRAME);
    std::vector<float> buf(FRAME);
    make_sine(buf, 440.0f, SR);

    PitchDetector::Result r = pd.process(buf.data(), FRAME);
    ASSERT_TRUE(r.pitched);
    ASSERT_NEAR(r.frequency, 440.0f, 2.0f);
    ASSERT_TRUE(r.midi_note == 69);        // A4
    ASSERT_TRUE(std::strcmp(r.note_name, "A4") == 0);
    ASSERT_NEAR(r.cents_offset, 0.0f, 5.0f);
    return true;
}

static bool test_pd_c4_note() {
    // C4 (middle C) = 261.63 Hz
    const int SR    = 44100;
    const int FRAME = 2048;

    PitchDetector pd(SR, FRAME);
    std::vector<float> buf(FRAME);
    make_sine(buf, 261.63f, SR);

    PitchDetector::Result r = pd.process(buf.data(), FRAME);
    ASSERT_TRUE(r.pitched);
    ASSERT_TRUE(r.midi_note == 60);        // C4
    ASSERT_TRUE(std::strcmp(r.note_name, "C4") == 0);
    return true;
}

static bool test_pd_silence_not_pitched() {
    const int SR    = 44100;
    const int FRAME = 2048;

    PitchDetector pd(SR, FRAME);
    std::vector<float> buf(FRAME, 0.0f);

    PitchDetector::Result r = pd.process(buf.data(), FRAME);
    ASSERT_TRUE(!r.pitched);
    return true;
}

static bool test_pd_incremental_blocks() {
    // Feed samples in small chunks; result should become valid once a full
    // frame has accumulated.
    const int SR         = 44100;
    const int FRAME      = 2048;
    const int BLOCK_SIZE = 256;

    PitchDetector pd(SR, FRAME);
    std::vector<float> buf(FRAME);
    make_sine(buf, 440.0f, SR);

    PitchDetector::Result r{};
    int offset = 0;
    while (offset < FRAME) {
        int chunk = std::min(BLOCK_SIZE, FRAME - offset);
        r = pd.process(buf.data() + offset, chunk);
        offset += chunk;
    }
    // After a full frame has been fed, detection must have fired
    ASSERT_TRUE(r.pitched);
    ASSERT_NEAR(r.frequency, 440.0f, 2.0f);
    return true;
}

static bool test_pd_reset_clears_state() {
    const int SR    = 44100;
    const int FRAME = 2048;

    PitchDetector pd(SR, FRAME);
    std::vector<float> buf(FRAME);
    make_sine(buf, 440.0f, SR);
    pd.process(buf.data(), FRAME);

    pd.reset();
    // After reset, only half a frame provided → no detection yet
    PitchDetector::Result r = pd.process(buf.data(), FRAME / 2);
    ASSERT_TRUE(!r.pitched);
    return true;
}

static bool test_pd_invalid_sample_rate_throws() {
    bool threw = false;
    try {
        PitchDetector pd(0, 2048);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    ASSERT_TRUE(threw);
    return true;
}

static bool test_pd_invalid_frame_size_throws() {
    bool threw = false;
    try {
        PitchDetector pd(44100, 1);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    ASSERT_TRUE(threw);
    return true;
}

static bool test_ffi_process_a4() {
    const int SR    = 44100;
    const int FRAME = 2048;

    MLPitchDetectorHandle* handle = ml_pitch_detector_create(SR, FRAME, 0.10f);
    ASSERT_TRUE(handle != nullptr);

    std::vector<float> buf(FRAME);
    make_sine(buf, 440.0f, SR);

    MLPitchResult r = ml_pitch_detector_process(handle, buf.data(), FRAME);
    ASSERT_TRUE(r.pitched == 1);
    ASSERT_NEAR(r.frequency, 440.0f, 2.0f);
    ASSERT_TRUE(r.midi_note == 69);
    ASSERT_TRUE(std::strcmp(r.note_name, "A4") == 0);

    ml_pitch_detector_destroy(handle);
    return true;
}

static bool test_pd_reference_pitch_a4_432() {
    const int SR    = 44100;
    const int FRAME = 2048;

    PitchDetector pd(SR, FRAME, 0.10f, 432.0f);
    std::vector<float> buf(FRAME);
    make_sine(buf, 432.0f, SR);

    PitchDetector::Result r = pd.process(buf.data(), FRAME);
    ASSERT_TRUE(r.pitched);
    ASSERT_TRUE(r.midi_note == 69);       // A4 relative to A4=432
    ASSERT_NEAR(r.cents_offset, 0.0f, 0.1f);
    return true;
}

static bool test_ffi_set_reference_pitch() {
    const int SR    = 44100;
    const int FRAME = 2048;

    MLPitchDetectorHandle* handle = ml_pitch_detector_create(SR, FRAME, 0.10f);
    ASSERT_TRUE(handle != nullptr);
    ASSERT_TRUE(ml_pitch_detector_set_reference_pitch(handle, 432.0f) == 1);

    std::vector<float> buf(FRAME);
    make_sine(buf, 432.0f, SR);
    MLPitchResult r = ml_pitch_detector_process(handle, buf.data(), FRAME);
    ASSERT_TRUE(r.pitched == 1);
    ASSERT_TRUE(r.midi_note == 69);
    ASSERT_NEAR(r.cents_offset, 0.0f, 0.1f);
    ASSERT_TRUE(std::strcmp(r.note_name, "A4") == 0);

    ml_pitch_detector_destroy(handle);
    return true;
}

static bool test_ffi_process_null_handle() {
    // ml_pitch_detector_process must return a zeroed result (not crash) when
    // the handle is null.
    std::vector<float> buf(2048, 0.0f);
    MLPitchResult r = ml_pitch_detector_process(nullptr, buf.data(), static_cast<int>(buf.size()));
    ASSERT_TRUE(r.pitched == 0);
    ASSERT_TRUE(r.frequency == 0.0f);
    ASSERT_TRUE(r.midi_note == 0);
    return true;
}

static bool test_ffi_process_null_samples() {
    // ml_pitch_detector_process must return a zeroed result (not crash) when
    // the sample pointer is null.
    MLPitchDetectorHandle* handle = ml_pitch_detector_create(44100, 2048, 0.10f);
    ASSERT_TRUE(handle != nullptr);
    MLPitchResult r = ml_pitch_detector_process(handle, nullptr, 2048);
    ASSERT_TRUE(r.pitched == 0);
    ASSERT_TRUE(r.frequency == 0.0f);
    ml_pitch_detector_destroy(handle);
    return true;
}

static bool test_ffi_process_zero_num_samples() {
    // ml_pitch_detector_process must return a zeroed result (not crash) when
    // num_samples is zero.
    MLPitchDetectorHandle* handle = ml_pitch_detector_create(44100, 2048, 0.10f);
    ASSERT_TRUE(handle != nullptr);
    std::vector<float> buf(2048, 0.0f);
    MLPitchResult r = ml_pitch_detector_process(handle, buf.data(), 0);
    ASSERT_TRUE(r.pitched == 0);
    ASSERT_TRUE(r.frequency == 0.0f);
    ml_pitch_detector_destroy(handle);
    return true;
}

// ---------------------------------------------------------------------------
// Driver
// ---------------------------------------------------------------------------

int main() {
    run_test("yin: detects A4 sine",                test_yin_sine_a4);
    run_test("yin: detects low-E guitar (82 Hz)",   test_yin_sine_e2);
    run_test("yin: detects C5 (523 Hz)",            test_yin_sine_c5);
    run_test("yin: silence returns -1",             test_yin_silence_returns_no_pitch);
    run_test("yin: no realloc with pre-alloc ws",   test_yin_workspace_no_reallocation);
    run_test("pd:  A4 MIDI=69 note_name=A4",        test_pd_a4_midi_and_note_name);
    run_test("pd:  C4 (middle C)",                  test_pd_c4_note);
    run_test("pd:  silence is not pitched",         test_pd_silence_not_pitched);
    run_test("pd:  incremental block feeding",      test_pd_incremental_blocks);
    run_test("pd:  reset clears state",             test_pd_reset_clears_state);
    run_test("pd:  throws on bad sample_rate",      test_pd_invalid_sample_rate_throws);
    run_test("pd:  throws on bad frame_size",       test_pd_invalid_frame_size_throws);
    run_test("pd:  supports A4=432 reference",      test_pd_reference_pitch_a4_432);
    run_test("ffi: A4 process bridge",              test_ffi_process_a4);
    run_test("ffi: set reference pitch",            test_ffi_set_reference_pitch);
    run_test("ffi: process null handle is safe",    test_ffi_process_null_handle);
    run_test("ffi: process null samples is safe",   test_ffi_process_null_samples);
    run_test("ffi: process zero num_samples safe",  test_ffi_process_zero_num_samples);

    std::printf("\n%d passed, %d failed\n", g_passed, g_failed);
    return g_failed == 0 ? 0 : 1;
}
