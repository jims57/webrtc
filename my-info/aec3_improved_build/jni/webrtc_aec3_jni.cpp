// Author: Jimmy Gan
// Date: 2025-01-28
// 改进的WebRTC AEC3 JNI包装器

#include <jni.h>
#include <android/log.h>
#include "webrtc_aec3_wrapper.h"

#define LOG_TAG "WebRTCAEC3JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeCreate(JNIEnv *env, 
                                                jobject /* this */,
                                                jint sample_rate, 
                                                jint num_channels,
                                                jboolean mobile_mode) {
    LOGI("创建AEC3处理器: %dHz, %d声道, 移动模式=%d", sample_rate, num_channels, mobile_mode);
    
    WebRTCAEC3Config config = webrtc_aec3_get_default_config(mobile_mode);
    config.sample_rate_hz = sample_rate;
    config.num_channels = num_channels;
    
    WebRTCAEC3Processor* processor = webrtc_aec3_create(&config);
    if (!processor) {
        LOGE("创建AEC3处理器失败");
        return 0;
    }
    
    LOGI("AEC3处理器创建成功");
    return reinterpret_cast<jlong>(processor);
}

JNIEXPORT void JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeDestroy(JNIEnv *env, 
                                                 jobject /* this */, 
                                                 jlong handle) {
    if (handle == 0) return;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    webrtc_aec3_destroy(processor);
    LOGI("AEC3处理器已销毁");
}

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeSetStreamDelay(JNIEnv *env,
                                                        jobject /* this */,
                                                        jlong handle,
                                                        jint delay_ms) {
    if (handle == 0) return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    return webrtc_aec3_set_stream_delay(processor, delay_ms);
}

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeAnalyzeRender(JNIEnv *env, 
                                                       jobject /* this */,
                                                       jlong handle,
                                                       jfloatArray farend_data,
                                                       jint samples_per_channel) {
    if (handle == 0) return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    
    jfloat* farend_ptr = env->GetFloatArrayElements(farend_data, nullptr);
    if (!farend_ptr) {
        LOGE("获取远端数据失败");
        return WEBRTC_AEC3_ERROR_INVALID_PARAM;
    }
    
    WebRTCAEC3ErrorCode result = webrtc_aec3_analyze_render(
        processor, farend_ptr, samples_per_channel);
    
    env->ReleaseFloatArrayElements(farend_data, farend_ptr, JNI_ABORT);
    
    return result;
}

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessCapture(JNIEnv *env,
                                                        jobject /* this */,
                                                        jlong handle,
                                                        jfloatArray nearend_data,
                                                        jfloatArray output_data,
                                                        jint samples_per_channel,
                                                        jboolean level_change) {
    if (handle == 0) return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    
    jfloat* nearend_ptr = env->GetFloatArrayElements(nearend_data, nullptr);
    jfloat* output_ptr = env->GetFloatArrayElements(output_data, nullptr);
    
    if (!nearend_ptr || !output_ptr) {
        LOGE("获取音频数据失败");
        if (nearend_ptr) env->ReleaseFloatArrayElements(nearend_data, nearend_ptr, JNI_ABORT);
        if (output_ptr) env->ReleaseFloatArrayElements(output_data, output_ptr, JNI_ABORT);
        return WEBRTC_AEC3_ERROR_INVALID_PARAM;
    }
    
    WebRTCAEC3ErrorCode result = webrtc_aec3_process_capture(
        processor, nearend_ptr, output_ptr, samples_per_channel, level_change);
    
    env->ReleaseFloatArrayElements(nearend_data, nearend_ptr, JNI_ABORT);
    env->ReleaseFloatArrayElements(output_data, output_ptr, 0);  // 提交更改
    
    return result;
}

JNIEXPORT jfloatArray JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeGetMetrics(JNIEnv *env,
                                                    jobject /* this */,
                                                    jlong handle) {
    if (handle == 0) return nullptr;
    
    WebRTCAEC3Processor* processor = reinterpret_cast<WebRTCAEC3Processor*>(handle);
    
    float erle_db = 0.0f;
    int delay_ms = 0;
    WebRTCAEC3ErrorCode result = webrtc_aec3_get_metrics(processor, &erle_db, &delay_ms);
    
    if (result == WEBRTC_AEC3_SUCCESS) {
        jfloatArray metrics = env->NewFloatArray(2);
        jfloat values[2] = {erle_db, static_cast<float>(delay_ms)};
        env->SetFloatArrayRegion(metrics, 0, 2, values);
        return metrics;
    }
    
    return nullptr;
}

} // extern "C"
