#include <jni.h>
#include <cstring>
#include <vector>

#include "edge-impulse-sdk/classifier/ei_run_classifier.h"

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_kritha_app_wakeword_WakeWordNative_runInference(
    JNIEnv *env,
    jobject /* thiz */,
    jshortArray samples
) {
    if (samples == nullptr) return nullptr;

    const jsize length = env->GetArrayLength(samples);
    jshort *pcm = env->GetShortArrayElements(samples, nullptr);
    if (pcm == nullptr) return nullptr;

    std::vector<float> signalSamples(static_cast<size_t>(length));
    for (jsize index = 0; index < length; ++index) {
        // Edge Impulse's microphone model expects the original PCM amplitude.
        signalSamples[static_cast<size_t>(index)] = static_cast<float>(pcm[index]);
    }
    env->ReleaseShortArrayElements(samples, pcm, JNI_ABORT);

    signal_t signal;
    signal.total_length = static_cast<size_t>(length);
    signal.get_data = [&signalSamples](size_t offset, size_t count, float *output) {
        if (offset + count > signalSamples.size()) return -1;
        std::memcpy(output, signalSamples.data() + offset, count * sizeof(float));
        return 0;
    };

    ei_impulse_result_t result = {};
    if (run_classifier(&signal, &result, false) != EI_IMPULSE_OK) return nullptr;

    const jsize labelCount = static_cast<jsize>(EI_CLASSIFIER_LABEL_COUNT);
    jfloatArray output = env->NewFloatArray(labelCount);
    if (output == nullptr) return nullptr;

    std::vector<jfloat> scores(static_cast<size_t>(labelCount));
    for (jsize index = 0; index < labelCount; ++index) {
        scores[static_cast<size_t>(index)] =
            result.classification[static_cast<size_t>(index)].value;
    }
    env->SetFloatArrayRegion(output, 0, labelCount, scores.data());
    return output;
}
