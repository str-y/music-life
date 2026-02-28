#include "pitch_detector_ffi.h"

#include "pitch_detector.h"

#include <cstdarg>
#include <exception>
#include <cstdio>
#include <memory>
#include <signal.h>

namespace {

MLLogCallback g_log_callback = nullptr;

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

const char* signal_name(int signal_number) {
    switch (signal_number) {
        case SIGABRT: return "SIGABRT";
        case SIGILL: return "SIGILL";
        case SIGFPE: return "SIGFPE";
        case SIGSEGV: return "SIGSEGV";
#ifdef SIGBUS
        case SIGBUS: return "SIGBUS";
#endif
#ifdef SIGTRAP
        case SIGTRAP: return "SIGTRAP";
#endif
        default: return "UNKNOWN_SIGNAL";
    }
}

void fatal_signal_handler(int signal_number) {
    emit_log(ML_LOG_LEVEL_ERROR, "native fatal signal: %s (%d)", signal_name(signal_number), signal_number);
    ::signal(signal_number, SIG_DFL);
    raise(signal_number);
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
};

MLPitchDetectorHandle* ml_pitch_detector_create(int sample_rate, int frame_size, float threshold) {
    return ml_pitch_detector_create_with_reference_pitch(sample_rate, frame_size, threshold, 440.0f);
}

MLPitchDetectorHandle* ml_pitch_detector_create_with_reference_pitch(int sample_rate,
                                                                     int frame_size,
                                                                     float threshold,
                                                                     float reference_pitch_hz) {
    try {
        auto* handle = new MLPitchDetectorHandle{
            std::make_unique<music_life::PitchDetector>(sample_rate, frame_size, threshold, reference_pitch_hz)
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
    static bool installed = false;
    if (installed) return;
    installed = true;
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
}
