#include "../pitch_detection/pitch_detector.h"

#include <jni.h>

namespace {

music_life::PitchDetector* fromHandle(jlong handle) {
    return reinterpret_cast<music_life::PitchDetector*>(handle);
}

} // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_musiclife_PitchDetector_nativeCreate(
    JNIEnv* env,
    jobject /* thiz */,
    jint sampleRate,
    jint frameSize,
    jfloat threshold,
    jfloat referencePitchHz) {
    try {
        auto* detector = new music_life::PitchDetector(
            static_cast<int>(sampleRate),
            static_cast<int>(frameSize),
            static_cast<float>(threshold),
            static_cast<float>(referencePitchHz)
        );
        return reinterpret_cast<jlong>(detector);
    } catch (...) {
        return 0;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_musiclife_PitchDetector_nativeDestroy(
    JNIEnv* env,
    jobject /* thiz */,
    jlong handle) {
    (void)env;
    delete fromHandle(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_musiclife_PitchDetector_nativeReset(
    JNIEnv* env,
    jobject /* thiz */,
    jlong handle) {
    (void)env;
    auto* detector = fromHandle(handle);
    if (detector) {
        detector->reset();
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_musiclife_PitchDetector_nativeSetReferencePitch(
    JNIEnv* env,
    jobject /* thiz */,
    jlong handle,
    jfloat referencePitchHz) {
    (void)env;
    auto* detector = fromHandle(handle);
    if (!detector) return JNI_FALSE;
    try {
        detector->set_reference_pitch(static_cast<float>(referencePitchHz));
        return JNI_TRUE;
    } catch (...) {
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_musiclife_PitchDetector_nativeProcess(
    JNIEnv* env,
    jobject /* thiz */,
    jlong handle,
    jfloatArray samples,
    jint numSamples) {
    auto* detector = fromHandle(handle);
    if (!detector || !samples || numSamples <= 0) return nullptr;

    jfloat* sampleBuffer = env->GetFloatArrayElements(samples, nullptr);
    if (!sampleBuffer) return nullptr;

    const music_life::PitchDetector::Result result = detector->process(sampleBuffer, static_cast<int>(numSamples));
    env->ReleaseFloatArrayElements(samples, sampleBuffer, JNI_ABORT);

    jclass resultClass = env->FindClass("com/musiclife/PitchDetector$Result");
    if (!resultClass) return nullptr;
    jmethodID ctor = env->GetMethodID(resultClass, "<init>", "(ZFFIF)V");
    if (!ctor) return nullptr;

    return env->NewObject(
        resultClass,
        ctor,
        result.pitched ? JNI_TRUE : JNI_FALSE,
        result.frequency,
        result.probability,
        static_cast<jint>(result.midi_note),
        result.cents_offset
    );
}
