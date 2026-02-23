package com.musiclife

import java.io.Closeable

class PitchDetector(
    sampleRate: Int,
    frameSize: Int = 2048,
    threshold: Float = 0.10f,
    referencePitchHz: Float = 440.0f,
) : Closeable {
    data class Result(
        val pitched: Boolean,
        val frequency: Float,
        val probability: Float,
        val midiNote: Int,
        val centsOffset: Float,
    )

    private var nativeHandle: Long = nativeCreate(sampleRate, frameSize, threshold, referencePitchHz)

    init {
        require(nativeHandle != 0L) { "Failed to create native PitchDetector" }
    }

    fun process(samples: FloatArray): Result {
        if (samples.isEmpty()) {
            return Result(false, 0.0f, 0.0f, 0, 0.0f)
        }
        return nativeProcess(nativeHandle, samples, samples.size)
            ?: Result(false, 0.0f, 0.0f, 0, 0.0f)
    }

    fun reset() {
        nativeReset(nativeHandle)
    }

    fun setReferencePitch(referencePitchHz: Float): Boolean {
        return nativeSetReferencePitch(nativeHandle, referencePitchHz)
    }

    override fun close() {
        if (nativeHandle != 0L) {
            nativeDestroy(nativeHandle)
            nativeHandle = 0L
        }
    }

    private external fun nativeCreate(
        sampleRate: Int,
        frameSize: Int,
        threshold: Float,
        referencePitchHz: Float,
    ): Long

    private external fun nativeDestroy(handle: Long)
    private external fun nativeReset(handle: Long)
    private external fun nativeSetReferencePitch(handle: Long, referencePitchHz: Float): Boolean
    private external fun nativeProcess(handle: Long, samples: FloatArray, numSamples: Int): Result?

    companion object {
        init {
            System.loadLibrary("music_life_jni")
        }
    }
}
