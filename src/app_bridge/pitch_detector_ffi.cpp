#include "pitch_detector_ffi.h"

#include "pitch_detector.h"

#include <atomic>
#include <cstdarg>
#include <cmath>
#include <exception>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <mutex>
#include <signal.h>
#include <unistd.h>

namespace {

MLLogCallback g_log_callback = nullptr;
std::once_flag g_crash_handlers_once;
volatile sig_atomic_t g_fatal_signal_in_progress = 0;
constexpr int kMaxProcessSamplesMultiplier = 2;

void emit_log(int level, const char* fmt, ...) {
    char buffer[512];
    va_list args;
    va_start(args, fmt);
    std::vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);
    std::fprintf(stderr, "[music-life] %s\n", buffer);
    if (g_log_callback) {
        g_log_callback(level, buffer);
    }
}

void write_signal_message(const char* message, size_t length) {
    const ssize_t written = ::write(STDERR_FILENO, message, length);
    (void)written;
}

void fatal_signal_handler(int signal_number) {
    if (g_fatal_signal_in_progress != 0) {
        ::_Exit(128 + signal_number);
    }
    g_fatal_signal_in_progress = 1;
#define ML_WRITE_SIGNAL(msg) write_signal_message(msg, sizeof(msg) - 1)
    switch (signal_number) {
        case SIGABRT:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGABRT\n");
            break;
        case SIGILL:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGILL\n");
            break;
        case SIGFPE:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGFPE\n");
            break;
        case SIGSEGV:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGSEGV\n");
            break;
#ifdef SIGBUS
        case SIGBUS:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGBUS\n");
            break;
#endif
#ifdef SIGTRAP
        case SIGTRAP:
            ML_WRITE_SIGNAL("[music-life] native fatal signal: SIGTRAP\n");
            break;
#endif
        default:
            ML_WRITE_SIGNAL("[music-life] native fatal signal\n");
            break;
    }
#undef ML_WRITE_SIGNAL
    ::signal(signal_number, SIG_DFL);
    ::raise(signal_number);
    ::_Exit(128 + signal_number);
}

void terminate_handler() {
    try {
        std::exception_ptr eptr = std::current_exception();
        if (eptr) {
            std::rethrow_exception(eptr);
        }
    } catch (const std::exception& e) {
        emit_log(ML_LOG_LEVEL_ERROR, "native terminate: %s", e.what());
    } catch (...) {
        emit_log(ML_LOG_LEVEL_ERROR, "native terminate: unknown exception");
    }
    std::abort();
}

}  // namespace

struct MLPitchDetectorHandle {
    std::unique_ptr<music_life::PitchDetector> detector;
    int max_process_samples;
};

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold) {
    return ml_pitch_detector_create_with_reference_pitch(sample_rate, frame_size, threshold, 440.0f);
}

MLPitchDetectorHandle* ml_pitch_detector_create_with_reference_pitch(int sample_rate,
                                                                     int frame_size,
                                                                     float threshold,
                                                                     float reference_pitch_hz) {
    if (sample_rate <= 0 || frame_size <= 1 || frame_size > 32768 || !std::isfinite(threshold) ||
        threshold < 0.0f || threshold > 1.0f || !std::isfinite(reference_pitch_hz)) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_create: invalid arguments");
        return nullptr;
    }
    try {
        const int max_process_samples = frame_size * kMaxProcessSamplesMultiplier;
        auto* handle = new MLPitchDetectorHandle{
            std::make_unique<music_life::PitchDetector>(sample_rate, frame_size, threshold, reference_pitch_hz),
            max_process_samples
        };
        emit_log(ML_LOG_LEVEL_INFO,
                 "ml_pitch_detector_create: sample_rate=%d frame_size=%d threshold=%0.3f reference_pitch_hz=%0.2f",
                 sample_rate,
                 frame_size,
                 threshold,
                 reference_pitch_hz);
        return handle;
    } catch (const std::exception& e) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_create: exception: %s", e.what());
        return nullptr;
    } catch (...) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_create: unknown exception");
        return nullptr;
    }
}

void ml_pitch_detector_destroy(MLPitchDetectorHandle* handle) {
    if (!handle) return;
    emit_log(ML_LOG_LEVEL_DEBUG, "ml_pitch_detector_destroy");
    delete handle;
}

void ml_pitch_detector_reset(MLPitchDetectorHandle* handle) {
    if (!handle) return;
    emit_log(ML_LOG_LEVEL_TRACE, "ml_pitch_detector_reset");
    handle->detector->reset();
}

int ml_pitch_detector_set_reference_pitch(MLPitchDetectorHandle* handle, float reference_pitch_hz) {
    if (!handle) return 0;
    try {
        handle->detector->set_reference_pitch(reference_pitch_hz);
        emit_log(ML_LOG_LEVEL_INFO, "ml_pitch_detector_set_reference_pitch: %0.2f", reference_pitch_hz);
        return 1;
    } catch (const std::exception& e) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_set_reference_pitch: exception: %s", e.what());
        return 0;
    } catch (...) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_set_reference_pitch: unknown exception");
        return 0;
    }
}

MLPitchResult ml_pitch_detector_process(MLPitchDetectorHandle* handle, const float* samples, int num_samples) {
    MLPitchResult out{};
    if (!handle || !samples || num_samples <= 0) return out;
    if (num_samples > handle->max_process_samples) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_process: invalid num_samples=%d", num_samples);
        return out;
    }

    try {
        const music_life::PitchDetector::Result result = handle->detector->process(samples, num_samples);
        out.pitched      = result.pitched ? 1 : 0;
        out.frequency    = result.frequency;
        out.probability  = result.probability;
        out.midi_note    = result.midi_note;
        out.cents_offset = result.cents_offset;
        std::snprintf(out.note_name, sizeof(out.note_name), "%s", result.note_name ? result.note_name : "");
    } catch (const std::exception& e) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_process: exception: %s", e.what());
        return out;
    } catch (...) {
        emit_log(ML_LOG_LEVEL_ERROR, "ml_pitch_detector_process: unknown exception");
        return out;
    }
    return out;
}

void ml_pitch_detector_set_log_callback(MLLogCallback callback) {
    g_log_callback = callback;
}

void ml_pitch_detector_install_crash_handlers(void) {
    std::call_once(g_crash_handlers_once, []() {
        std::set_terminate(terminate_handler);
        ::signal(SIGABRT, fatal_signal_handler);
        ::signal(SIGILL, fatal_signal_handler);
        ::signal(SIGFPE, fatal_signal_handler);
        ::signal(SIGSEGV, fatal_signal_handler);
#ifdef SIGBUS
        ::signal(SIGBUS, fatal_signal_handler);
#endif
#ifdef SIGTRAP
        ::signal(SIGTRAP, fatal_signal_handler);
#endif
    });
}
