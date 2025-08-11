// Author: Jimmy Gan
// Date: 2025-01-28
// 改进的WebRTC AEC3 JNI接口

#ifndef WEBRTC_AEC3_JNI_H
#define WEBRTC_AEC3_JNI_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

// 创建和销毁
JNIEXPORT jlong JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeCreate(JNIEnv *env, 
                                                jobject /* this */,
                                                jint sample_rate, 
                                                jint num_channels,
                                                jboolean mobile_mode);

JNIEXPORT void JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeDestroy(JNIEnv *env, 
                                                 jobject /* this */, 
                                                 jlong handle);

// 配置和控制
JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeSetStreamDelay(JNIEnv *env,
                                                        jobject /* this */,
                                                        jlong handle,
                                                        jint delay_ms);

// 音频处理
JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeAnalyzeRender(JNIEnv *env, 
                                                       jobject /* this */,
                                                       jlong handle,
                                                       jfloatArray farend_data,
                                                       jint samples_per_channel);

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessCapture(JNIEnv *env,
                                                        jobject /* this */,
                                                        jlong handle,
                                                        jfloatArray nearend_data,
                                                        jfloatArray output_data,
                                                        jint samples_per_channel,
                                                        jboolean level_change);

// 性能监控
JNIEXPORT jfloatArray JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeGetMetrics(JNIEnv *env,
                                                    jobject /* this */,
                                                    jlong handle);

#ifdef __cplusplus
}
#endif

#endif // WEBRTC_AEC3_JNI_H
