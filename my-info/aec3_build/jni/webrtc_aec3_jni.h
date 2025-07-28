// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3 JNI接口

#ifndef WEBRTC_AEC3_JNI_H
#define WEBRTC_AEC3_JNI_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT jlong JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeCreateProcessor(JNIEnv *env, 
                                                         jobject /* this */,
                                                         jint sample_rate, 
                                                         jint num_channels);

JNIEXPORT void JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeDestroyProcessor(JNIEnv *env, 
                                                          jobject /* this */, 
                                                          jlong handle);

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessStream(JNIEnv *env, 
                                                       jobject /* this */,
                                                       jlong handle,
                                                       jfloatArray near_end,
                                                       jfloatArray far_end,
                                                       jfloatArray output,
                                                       jint frame_size);

JNIEXPORT jint JNICALL
Java_cn_watchfun_webrtc_WebRTCAEC3_nativeProcessReference(JNIEnv *env,
                                                          jobject /* this */,
                                                          jlong handle,
                                                          jfloatArray reference,
                                                          jint frame_size);

#ifdef __cplusplus
}
#endif

#endif // WEBRTC_AEC3_JNI_H
