// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3 JNI包装器

#include <jni.h>
#include <android/log.h>
#include "webrtc_aec3_processor.h"

#define LOG_TAG "WebRTCAEC3"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeCreateProcessor(JNIEnv *env, 
                                                         jobject /* this */,
                                                         jint sample_rate, 
                                                         jint num_channels) {
    LOGI("创建AEC3处理器: 采样率=%d, 声道数=%d", sample_rate, num_channels);
    
    WebRTCAEC3Processor* processor = webrtc_aec3_create(sample_rate, num_channels);
    if (!processor) {
        LOGE("创建AEC3处理器失败");
        return 0;
    }
    
    LOGI("AEC3处理器创建成功");
    return reinterpret_cast<jlong>(processor);
}

JNIEXPORT void JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeDestroyProcessor(JNIEnv *env, 
                                                          jobject /* this */, 
                                                          jlong handle) {
    if (handle == 0) return;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    webrtc_aec3_destroy(processor);
    LOGI("AEC3处理器已销毁");
}

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessStream(JNIEnv *env, 
                                                       jobject /* this */,
                                                       jlong handle,
                                                       jfloatArray near_end,
                                                       jfloatArray far_end,
                                                       jfloatArray output,
                                                       jint frame_size) {
    if (handle == 0) return -1;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    
    jfloat* near_data = env->GetFloatArrayElements(near_end, nullptr);
    jfloat* far_data = env->GetFloatArrayElements(far_end, nullptr);
    jfloat* output_data = env->GetFloatArrayElements(output, nullptr);
    
    int result = webrtc_aec3_process_stream(processor, near_data, far_data, output_data, frame_size);
    
    env->ReleaseFloatArrayElements(near_end, near_data, JNI_ABORT);
    env->ReleaseFloatArrayElements(far_end, far_data, JNI_ABORT);
    env->ReleaseFloatArrayElements(output, output_data, 0);
    
    return result;
}

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessReference(JNIEnv *env,
                                                          jobject /* this */,
                                                          jlong handle,
                                                          jfloatArray reference,
                                                          jint frame_size) {
    if (handle == 0) return -1;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    
    jfloat* ref_data = env->GetFloatArrayElements(reference, nullptr);
    int result = webrtc_aec3_process_reference(processor, ref_data, frame_size);
    env->ReleaseFloatArrayElements(reference, ref_data, JNI_ABORT);
    
    return result;
}

} // extern "C"
