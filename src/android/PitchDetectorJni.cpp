#include "../pitch_detection/pitch_detector.h"

#include <jni.h>
#include <mutex>

namespace {

jclass gResultClass = nullptr;
jmethodID gResultCtor = nullptr;
std::once_flag gResultClassInitFlag;
std::once_flag gResultCtorInitFlag;

music_life::PitchDetector* fromHandle(jlong handle) {
    if (handle == 0) return nullptr;
    return reinterpret_cast<music_life::PitchDetector*>(handle);
}

void throwRuntimeException(JNIEnv* env, const char* message) {
    jclass exceptionClass = env->FindClass("java/lang/RuntimeException");
    if (!exceptionClass) return;
    env->ThrowNew(exceptionClass, message);
    env->DeleteLocalRef(exceptionClass);
}

jclass getResultClass(JNIEnv* env) {
    std::call_once(gResultClassInitFlag, [&]() {
        jclass localClass = env->FindClass("com/musiclife/PitchDetector$Result");
        if (!localClass) return;
        gResultClass = reinterpret_cast<jclass>(env->NewGlobalRef(localClass));
        env->DeleteLocalRef(localClass);
    });
    return gResultClass;
}

jmethodID getResultCtor(JNIEnv* env) {
    std::call_once(gResultCtorInitFlag, [&]() {
        jclass resultClass = getResultClass(env);
        if (!resultClass) return;
        gResultCtor = env->GetMethodID(resultClass, "<init>", "(ZFFIF)V");
    });
    return gResultCtor;
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
        throwRuntimeException(env, "Failed to create native PitchDetector");
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

    struct FloatArrayGuard {
        JNIEnv* env;
        jfloatArray array;
        jfloat* data;
        ~FloatArrayGuard() {
            if (data) env->ReleaseFloatArrayElements(array, data, JNI_ABORT);
        }
    };

    FloatArrayGuard sampleGuard{env, samples, env->GetFloatArrayElements(samples, nullptr)};
    if (!sampleGuard.data) return nullptr;

    music_life::PitchDetector::Result result{};
    try {
        result = detector->process(sampleGuard.data, static_cast<int>(numSamples));
    } catch (...) {
        return nullptr;
    }

    jclass resultClass = getResultClass(env);
    jmethodID ctor = getResultCtor(env);
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

extern "C" JNIEXPORT void JNICALL
JNI_OnUnload(JavaVM* vm, void* /* reserved */) {
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK || !env) {
        return;
    }
    if (gResultClass) {
        env->DeleteGlobalRef(gResultClass);
        gResultClass = nullptr;
    }
    gResultCtor = nullptr;
}
