#include <jni.h>
#include <vector>
#include "edge-impulse-sdk/classifier/ei_run_classifier.h"

extern "C"
JNIEXPORT jfloatArray JNICALL
Java_expo_modules_wakeword_WakeWordNative_runInference(JNIEnv *env, jobject thiz, jshortArray samples) {
    jsize length = env->GetArrayLength(samples);
    jshort *body = env->GetShortArrayElements(samples, 0);

    std::vector<float> float_buffer(length);
    for (int i = 0; i < length; i++) {
        // BUG FIX: Do NOT normalize the audio! Edge Impulse MFE blocks
        // require raw PCM integer ranges to calculate energy correctly.
        float_buffer[i] = (float)body[i]; 
    }
    
    env->ReleaseShortArrayElements(samples, body, JNI_ABORT);

    signal_t signal;
    signal.total_length = length;
    signal.get_data = [&float_buffer](size_t offset, size_t length, float *out_ptr) -> int {
        memcpy(out_ptr, float_buffer.data() + offset, length * sizeof(float));
        return 0;
    };

    ei_impulse_result_t result = { 0 };
    EI_IMPULSE_ERROR ei_errors = run_classifier(&signal, &result, false);

    if (ei_errors != EI_IMPULSE_OK) {
        return nullptr;
    }

    size_t label_count = EI_CLASSIFIER_LABEL_COUNT;
    jfloatArray out_array = env->NewFloatArray(label_count);
    
    float scores[label_count];
    for (size_t i = 0; i < label_count; i++) {
        scores[i] = result.classification[i].value;
    }

    env->SetFloatArrayRegion(out_array, 0, label_count, scores);
    return out_array;
}
