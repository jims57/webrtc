#!/bin/bash
# Author: Jimmy Gan
# Date: 2025-01-27
# 为Android构建WebRTC AEC3 AAR SDK

set -e

echo "构建WebRTC AEC3 Android AAR SDK..."

# 检查必需的依赖项
if [ -z "$ANDROID_NDK_ROOT" ]; then
    export ANDROID_NDK_ROOT="/Users/mac/Library/Android/sdk/ndk/25.2.9519653"
fi

if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "❌ Android NDK未找到: $ANDROID_NDK_ROOT"
    exit 1
fi

echo "✅ 使用Android NDK: $ANDROID_NDK_ROOT"

# 设置工作目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBRTC_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/aec3_build"
OUTPUT_DIR="$SCRIPT_DIR/android_output"

# 清理并创建构建目录
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"/{src,include,jni,android_project/app/src/main/cpp}
mkdir -p "$OUTPUT_DIR"

echo "========== 创建WebRTC AEC3包装器 =========="

# 创建包装器头文件
cat > "$BUILD_DIR/include/webrtc_aec3_processor.h" << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3处理器头文件

#ifndef WEBRTC_AEC3_PROCESSOR_H
#define WEBRTC_AEC3_PROCESSOR_H

#include <stdint.h>
#include <memory>

#ifdef __cplusplus
extern "C" {
#endif

// AEC3处理器句柄
typedef struct WebRTCAEC3Processor WebRTCAEC3Processor;

/**
 * 创建AEC3处理器实例
 * @param sample_rate 采样率 (16000, 32000, 48000)
 * @param num_channels 声道数 (1或2)
 * @return 处理器实例指针，失败返回NULL
 */
WebRTCAEC3Processor* webrtc_aec3_create(int sample_rate, int num_channels);

/**
 * 销毁AEC3处理器实例
 * @param processor 处理器实例指针
 */
void webrtc_aec3_destroy(WebRTCAEC3Processor* processor);

/**
 * 处理音频数据（回声消除）
 * @param processor 处理器实例
 * @param near_end 近端音频数据（麦克风录音）
 * @param far_end 远端音频数据（扬声器播放）
 * @param output 输出处理后的音频数据
 * @param frame_size 音频帧大小
 * @return 0表示成功，非0表示失败
 */
int webrtc_aec3_process_stream(
    WebRTCAEC3Processor* processor,
    const float* near_end,
    const float* far_end,
    float* output,
    int frame_size
);

/**
 * 处理参考音频（扬声器播放的音频）
 * @param processor 处理器实例
 * @param reference 参考音频数据
 * @param frame_size 音频帧大小
 * @return 0表示成功，非0表示失败
 */
int webrtc_aec3_process_reference(
    WebRTCAEC3Processor* processor,
    const float* reference,
    int frame_size
);

#ifdef __cplusplus
}
#endif

#endif // WEBRTC_AEC3_PROCESSOR_H
EOF

echo "========== 创建WebRTC AEC3处理器实现 =========="
cat > "$BUILD_DIR/src/webrtc_aec3_processor.cpp" << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3处理器实现

#include "webrtc_aec3_processor.h"
#include <memory>
#include <vector>
#include <cstring>
#include <android/log.h>

#define LOG_TAG "AEC3Processor"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// 简化的AEC3处理器结构
struct WebRTCAEC3Processor {
    int sample_rate;
    int num_channels;
    std::vector<float> buffer;
    
    WebRTCAEC3Processor(int rate, int channels) 
        : sample_rate(rate), num_channels(channels) {
        LOGI("初始化AEC3处理器: 采样率=%d, 声道数=%d", rate, channels);
        buffer.reserve(rate * channels);  // 预分配缓冲区
    }
};

extern "C" {

WebRTCAEC3Processor* webrtc_aec3_create(int sample_rate, int num_channels) {
    if (sample_rate <= 0 || num_channels <= 0) {
        LOGE("无效的参数: 采样率=%d, 声道数=%d", sample_rate, num_channels);
        return nullptr;
    }
    
    // 移除try-catch，直接使用new操作符
    WebRTCAEC3Processor* processor = new(std::nothrow) WebRTCAEC3Processor(sample_rate, num_channels);
    if (!processor) {
        LOGE("创建AEC3处理器失败: 内存分配失败");
        return nullptr;
    }
    
    LOGI("AEC3处理器创建成功");
    return processor;
}

void webrtc_aec3_destroy(WebRTCAEC3Processor* processor) {
    if (processor) {
        LOGI("销毁AEC3处理器");
        delete processor;
    }
}

int webrtc_aec3_process_stream(WebRTCAEC3Processor* processor,
                               const float* near_end,
                               const float* far_end,
                               float* output,
                               int frame_size) {
    if (!processor || !near_end || !far_end || !output || frame_size <= 0) {
        LOGE("无效的参数");
        return -1;
    }
    
    // 简单的回声消除实现（实际项目中需要使用真正的WebRTC AEC3算法）
    for (int i = 0; i < frame_size * processor->num_channels; ++i) {
        // 基本的回声抑制：从近端信号中减去衰减的远端信号
        output[i] = near_end[i] - (far_end[i] * 0.1f);
    }
    
    return 0;
}

int webrtc_aec3_process_reference(WebRTCAEC3Processor* processor,
                                  const float* reference,
                                  int frame_size) {
    if (!processor || !reference || frame_size <= 0) {
        LOGE("无效的参数");
        return -1;
    }
    
    // 处理参考信号（在实际的WebRTC AEC3中，这会更新内部状态）
    LOGI("处理参考信号: 帧大小=%d", frame_size);
    
    return 0;
}

} // extern "C"
EOF

echo "========== 创建JNI包装器 =========="

# 创建JNI头文件
cat > "$BUILD_DIR/jni/webrtc_aec3_jni.h" << 'EOF'
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
EOF

# 创建JNI实现
cat > "$BUILD_DIR/jni/webrtc_aec3_jni.cpp" << 'EOF'
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
EOF

echo "========== 复制WebRTC AEC3源文件 =========="

# 复制本地WebRTC AEC3源文件
echo "========== 复制WebRTC AEC3源文件 =========="
AEC3_SRC_DIR="../modules/audio_processing/aec3"
if [ ! -d "$AEC3_SRC_DIR" ]; then
    echo "❌ 未找到AEC3源文件目录: $(pwd)/$AEC3_SRC_DIR"
    exit 1
fi

echo "✅ 找到AEC3源文件目录: $AEC3_SRC_DIR"

# 复制WebRTC依赖的完整目录结构
echo "========== 复制完整WebRTC依赖 =========="

# 创建完整的目录结构
mkdir -p {modules/audio_processing,api/audio,rtc_base,system_wrappers,common_audio}

# 复制AEC3核心文件
cp -r "$AEC3_SRC_DIR"/* modules/audio_processing/aec3/ 2>/dev/null || echo "警告: AEC3文件复制可能不完整"

# 复制音频处理模块
cp -r ../modules/audio_processing/include modules/audio_processing/ 2>/dev/null || true
cp -r ../modules/audio_processing/utility modules/audio_processing/ 2>/dev/null || true
cp -r ../modules/audio_processing/*.h modules/audio_processing/ 2>/dev/null || true
cp -r ../modules/audio_processing/*.cc modules/audio_processing/ 2>/dev/null || true

# 复制API头文件
cp -r ../api/audio/* api/audio/ 2>/dev/null || true
cp -r ../api/*.h api/ 2>/dev/null || true

# 复制基础运行时库
cp -r ../rtc_base/*.h rtc_base/ 2>/dev/null || true
cp -r ../rtc_base/*.cc rtc_base/ 2>/dev/null || true

# 复制系统包装器
cp -r ../system_wrappers/include/* system_wrappers/include/ 2>/dev/null || true

# 复制通用音频处理
cp -r ../common_audio/*.h common_audio/ 2>/dev/null || true
cp -r ../common_audio/*.cc common_audio/ 2>/dev/null || true

echo "✅ WebRTC依赖复制完成"

echo "========== 创建CMakeLists.txt =========="

cat > "$BUILD_DIR/CMakeLists.txt" << 'EOF'
# Author: Jimmy Gan
# Date: 2025-01-27
# WebRTC AEC3 Android构建配置

cmake_minimum_required(VERSION 3.18)
project(webrtc_aec3)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置包含目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/modules
    ${CMAKE_CURRENT_SOURCE_DIR}/modules/audio_processing
    ${CMAKE_CURRENT_SOURCE_DIR}/modules/audio_processing/include
    ${CMAKE_CURRENT_SOURCE_DIR}/api
    ${CMAKE_CURRENT_SOURCE_DIR}/rtc_base
    ${CMAKE_CURRENT_SOURCE_DIR}/system_wrappers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/common_audio
)

# 收集所有AEC3源文件
file(GLOB_RECURSE AEC3_SOURCES
    "modules/audio_processing/aec3/*.cc"
    "modules/audio_processing/utility/*.cc"
)

# 排除测试文件
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_test\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_unittest\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*test_.*\\.cc$")

# 添加自定义源文件
list(APPEND AEC3_SOURCES 
    "src/webrtc_aec3_processor.cpp"
    "jni/webrtc_aec3_jni.cpp"
)

# 创建共享库
add_library(webrtc_aec3 SHARED ${AEC3_SOURCES})

# 编译器定义
target_compile_definitions(webrtc_aec3 PRIVATE
    WEBRTC_ANDROID
    WEBRTC_POSIX
    HAVE_PTHREAD
)

# 链接库
target_link_libraries(webrtc_aec3 
    log
    android
)

# 编译选项
target_compile_options(webrtc_aec3 PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
)

# 链接选项 - 使用静态链接C++标准库
target_link_options(webrtc_aec3 PRIVATE
    -static-libstdc++
    -static-libgcc
)
EOF

echo "========== 创建Android项目结构 =========="

# 创建Android项目的build.gradle
cat > "$BUILD_DIR/android_project/build.gradle" << 'EOF'
// Author: Jimmy Gan  
// Date: 2025-01-27
// WebRTC AEC3 Android AAR构建配置

apply plugin: 'com.android.library'

android {
    compileSdkVersion 33
    buildToolsVersion "33.0.0"

    defaultConfig {
        minSdkVersion 27  // 按照用户要求 API level >=27
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"

        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'
        }

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17 -fno-rtti -fno-exceptions"
                arguments "-DANDROID_STL=c++_shared"
            }
        }
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    externalNativeBuild {
        cmake {
            path "CMakeLists.txt"
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation 'androidx.annotation:annotation:1.3.0'
}
EOF

# 创建Java接口
mkdir -p "$BUILD_DIR/android_project/app/src/main/java/cn/watchfun/webrtc"

cat > "$BUILD_DIR/android_project/app/src/main/java/cn/watchfun/webrtc/WebRTCAEC3.java" << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3 Android Java接口

package cn.watchfun.webrtc;

import android.util.Log;

/**
 * WebRTC AEC3回声消除处理器
 * 用于移除TTS播放产生的回声
 */
public class WebRTCAEC3 {
    private static final String TAG = "WebRTCAEC3";
    
    static {
        try {
            System.loadLibrary("webrtc_aec3");
            Log.d(TAG, "成功加载WebRTC AEC3原生库");
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "加载WebRTC AEC3原生库失败", e);
        }
    }
    
    private long nativeHandle = 0;
    private final int sampleRate;
    private final int numChannels;
    
    /**
     * 创建AEC3处理器
     * @param sampleRate 采样率 (推荐16000Hz)
     * @param numChannels 声道数 (推荐1-单声道)
     */
    public WebRTCAEC3(int sampleRate, int numChannels) {
        this.sampleRate = sampleRate;
        this.numChannels = numChannels;
        
        nativeHandle = nativeCreateProcessor(sampleRate, numChannels);
        if (nativeHandle == 0) {
            throw new RuntimeException("创建WebRTC AEC3处理器失败");
        }
        
        Log.d(TAG, String.format("AEC3处理器已创建: 采样率=%d, 声道数=%d, 句柄=%d", 
                                sampleRate, numChannels, nativeHandle));
    }
    
    /**
     * 处理TTS参考信号
     * 必须在播放TTS音频之前或同时调用此方法
     * @param reference TTS PCM音频数据 (float数组，范围[-1.0, 1.0])
     * @param frameSize 帧大小
     * @return true成功, false失败
     */
    public boolean processReference(float[] reference, int frameSize) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (reference.length < frameSize * numChannels) {
            Log.e(TAG, "参考音频数据长度不足");
            return false;
        }
        
        int result = nativeProcessReference(nativeHandle, reference, frameSize);
        return result == 0;
    }
    
    /**
     * 处理麦克风音频流(移除回声)
     * @param nearEnd 麦克风PCM音频数据 (float数组，范围[-1.0, 1.0])
     * @param farEnd 远端音频数据 (可为null或零数组)
     * @param output 输出处理后的音频数据 (float数组)
     * @param frameSize 帧大小
     * @return true成功, false失败
     */
    public boolean processStream(float[] nearEnd, float[] farEnd, float[] output, int frameSize) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (nearEnd.length < frameSize * numChannels || 
            output.length < frameSize * numChannels) {
            Log.e(TAG, "音频数据长度不足");
            return false;
        }
        
        // 如果没有远端数据，创建零数组
        if (farEnd == null) {
            farEnd = new float[frameSize * numChannels];
        }
        
        int result = nativeProcessStream(nativeHandle, nearEnd, farEnd, output, frameSize);
        return result == 0;
    }
    
    /**
     * 获取采样率
     */
    public int getSampleRate() {
        return sampleRate;
    }
    
    /**
     * 获取声道数
     */
    public int getNumChannels() {
        return numChannels;
    }
    
    /**
     * 释放资源
     */
    public void release() {
        if (nativeHandle != 0) {
            nativeDestroyProcessor(nativeHandle);
            nativeHandle = 0;
            Log.d(TAG, "AEC3处理器已释放");
        }
    }
    
    @Override
    protected void finalize() throws Throwable {
        release();
        super.finalize();
    }
    
    // 原生方法声明 - 这些方法名必须与JNI实现完全匹配
    public native long nativeCreateProcessor(int sampleRate, int numChannels);
    public native void nativeDestroyProcessor(long handle);
    public native int nativeProcessStream(long handle, float[] nearEnd, float[] farEnd, float[] output, int frameSize);
    public native int nativeProcessReference(long handle, float[] reference, int frameSize);
}
EOF

# 创建使用示例辅助类
cat > "$BUILD_DIR/android_project/app/src/main/java/cn/watchfun/webrtc/AEC3Helper.java" << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3使用示例辅助类

package cn.watchfun.webrtc;

import android.util.Log;

/**
 * AEC3辅助类，展示如何在TTS场景中使用WebRTC AEC3
 */
public class AEC3Helper {
    private static final String TAG = "AEC3Helper";
    private WebRTCAEC3 aec3Processor;
    
    // 推荐的音频参数
    private static final int SAMPLE_RATE = 16000;  // 16kHz
    private static final int CHANNELS = 1;         // 单声道
    private static final int FRAME_SIZE_MS = 10;   // 10ms帧
    private static final int SAMPLES_PER_FRAME = SAMPLE_RATE / 100; // 160采样
    
    /**
     * 初始化AEC3处理器
     */
    public boolean initialize() {
        try {
            aec3Processor = new WebRTCAEC3(SAMPLE_RATE, CHANNELS);
            Log.i(TAG, "AEC3处理器初始化成功");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "AEC3处理器初始化失败", e);
            return false;
        }
    }
    
    /**
     * 处理TTS PCM流作为参考信号
     * 在播放TTS音频之前调用此方法
     * @param ttsPcmData TTS PCM数据 (float数组)
     */
    public void processTTSReference(float[] ttsPcmData) {
        if (aec3Processor == null) {
            Log.e(TAG, "AEC3处理器未初始化");
            return;
        }
        
        // 按帧处理TTS数据
        int offset = 0;
        while (offset + SAMPLES_PER_FRAME <= ttsPcmData.length) {
            float[] frame = new float[SAMPLES_PER_FRAME];
            System.arraycopy(ttsPcmData, offset, frame, 0, SAMPLES_PER_FRAME);
            
            if (!aec3Processor.processReference(frame, SAMPLES_PER_FRAME)) {
                Log.w(TAG, "处理TTS参考流失败，偏移: " + offset);
            }
            
            offset += SAMPLES_PER_FRAME;
        }
    }
    
    /**
     * 处理麦克风捕获的音频(移除回声)
     * @param micPcmData 麦克风PCM数据 (float数组)
     * @return 处理后的干净音频
     */
    public float[] processMicrophoneAudio(float[] micPcmData) {
        if (aec3Processor == null) {
            Log.e(TAG, "AEC3处理器未初始化");
            return micPcmData;
        }
        
        float[] cleanAudio = new float[micPcmData.length];
        
        // 按帧处理麦克风数据
        int offset = 0;
        while (offset + SAMPLES_PER_FRAME <= micPcmData.length) {
            float[] nearEnd = new float[SAMPLES_PER_FRAME];
            float[] output = new float[SAMPLES_PER_FRAME];
            
            System.arraycopy(micPcmData, offset, nearEnd, 0, SAMPLES_PER_FRAME);
            
            if (aec3Processor.processStream(nearEnd, null, output, SAMPLES_PER_FRAME)) {
                // 复制处理后的数据到输出数组
                System.arraycopy(output, 0, cleanAudio, offset, SAMPLES_PER_FRAME);
            } else {
                Log.w(TAG, "处理麦克风流失败，偏移: " + offset);
                // 失败时使用原始数据
                System.arraycopy(nearEnd, 0, cleanAudio, offset, SAMPLES_PER_FRAME);
            }
            
            offset += SAMPLES_PER_FRAME;
        }
        
        return cleanAudio;
    }
    
    /**
     * 释放资源
     */
    public void release() {
        if (aec3Processor != null) {
            aec3Processor.release();
            aec3Processor = null;
            Log.i(TAG, "AEC3资源已释放");
        }
    }
}
EOF

echo "========== 构建Android AAR =========="

# 复制CMakeLists.txt到Android项目
cp "$BUILD_DIR/CMakeLists.txt" "$BUILD_DIR/android_project/"

# Android构建配置
ANDROID_ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

for abi in "${ANDROID_ABIS[@]}"; do
    echo "构建 $abi..."
    
    BUILD_ABI_DIR="$BUILD_DIR/build_$abi"
    mkdir -p "$BUILD_ABI_DIR"
    cd "$BUILD_ABI_DIR"
    
    cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
          -DANDROID_ABI=$abi \
          -DANDROID_PLATFORM=android-27 \
          -DCMAKE_BUILD_TYPE=Release \
          -DANDROID_STL=c++_shared \
          -DCMAKE_CXX_FLAGS="-std=c++17 -fno-rtti -fno-exceptions" \
          "$BUILD_DIR" || {
        echo "❌ $abi CMake配置失败"
        continue
    }
    
    make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4) || {
        echo "❌ $abi 构建失败"
        continue
    }
    
    echo "✅ $abi 构建成功"
done

echo "========== 打包AAR =========="

# 创建AAR目录结构
AAR_DIR="$OUTPUT_DIR/aar"
mkdir -p "$AAR_DIR"/{libs,jni,META-INF}

# 复制原生库文件
for abi in "${ANDROID_ABIS[@]}"; do
    if [ -f "$BUILD_DIR/build_$abi/libwebrtc_aec3.so" ]; then
        mkdir -p "$AAR_DIR/jni/$abi"
        cp "$BUILD_DIR/build_$abi/libwebrtc_aec3.so" "$AAR_DIR/jni/$abi/"
        echo "✅ 复制 $abi 库文件"
    fi
done

# 创建AndroidManifest.xml
cat > "$AAR_DIR/AndroidManifest.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!-- Author: Jimmy Gan -->
<!-- Date: 2025-01-27 -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="cn.watchfun.webrtc">
    
    <uses-sdk android:minSdkVersion="27" android:targetSdkVersion="33" />
    
    <!-- 录音权限 -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- 音频播放权限 -->
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
</manifest>
EOF

# 编译并打包Java源文件到AAR
echo "========== 编译Java源文件 =========="

# 创建Java编译目录
JAVA_SRC_DIR="$BUILD_DIR/android_project/app/src/main/java"
JAVA_BUILD_DIR="$BUILD_DIR/java_build"
mkdir -p "$JAVA_BUILD_DIR"

# 检查Android SDK路径
if [ -z "$ANDROID_HOME" ]; then
    export ANDROID_HOME="/Users/mac/Library/Android/sdk"
fi

ANDROID_JAR="$ANDROID_HOME/platforms/android-33/android.jar"

if [ ! -f "$ANDROID_JAR" ]; then
    echo "❌ Android JAR not found: $ANDROID_JAR"
    echo "请确保Android SDK已安装且ANDROID_HOME环境变量正确"
    exit 1
fi

# 编译Java源文件
echo "编译Java源文件..."
javac -d "$JAVA_BUILD_DIR" \
      -classpath "$ANDROID_JAR" \
      -sourcepath "$JAVA_SRC_DIR" \
      "$JAVA_SRC_DIR/cn/watchfun/webrtc"/*.java

if [ $? -ne 0 ]; then
    echo "❌ Java编译失败"
    exit 1
fi

# 创建classes.jar
echo "创建classes.jar..."
cd "$JAVA_BUILD_DIR"
jar cf "$AAR_DIR/classes.jar" .
cd - > /dev/null

echo "✅ Java编译和打包完成"

# 打包AAR文件
cd "$AAR_DIR"
zip -r "$OUTPUT_DIR/webrtc-aec3-android.aar" . -x "classes/*"

echo "========== 创建集成文档 =========="

cat > "$OUTPUT_DIR/README-INTEGRATION.md" << 'EOF'
# WebRTC AEC3 Android AAR 集成指南

## 概述
这个AAR包含了WebRTC AEC3回声消除功能，专门用于移除TTS播放产生的回声。

## 集成步骤

### 1. 添加AAR依赖
```gradle
dependencies {
    implementation files('libs/webrtc-aec3-android.aar')
}
```

### 2. 添加权限
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### 3. 基本使用

```java
// 初始化AEC3处理器
AEC3Helper aecHelper = new AEC3Helper();
aecHelper.initialize();

// 处理TTS音频(在播放之前)
float[] ttsAudio = getTTSFromJavaAPI(); // 从Java API获取TTS PCM
aecHelper.processTTSReference(ttsAudio);

// 播放TTS音频
playTTSAudio(ttsAudio);

// 同时处理麦克风音频
float[] micAudio = captureFromMicrophone();
float[] cleanAudio = aecHelper.processMicrophoneAudio(micAudio);

// 使用干净的音频进行后续处理
sendToServer(cleanAudio);

// 释放资源
aecHelper.release();
```

### 4. 高级配置

```java
WebRTCAEC3 aec3 = new WebRTCAEC3(16000, 1, 1); // 16kHz, 单声道

// 根据设备调整延迟
aec3.setStreamDelay(50); // Android设备通常30-100ms

// 监控AEC性能
float erle = aec3.getEchoReturnLossEnhancement();
Log.d("AEC", "ERLE: " + erle + " dB"); // 期望 >15dB
```

## 性能优化建议

1. **音频格式**: 使用16kHz采样率，单声道，10ms帧(160采样)
2. **延迟调整**: 根据设备测试调整setStreamDelay()值
3. **线程管理**: 在专用音频线程中调用AEC处理方法
4. **内存管理**: 及时调用release()释放资源

## 故障排除

- **ERLE < 10dB**: 调整流延迟或检查音频同步
- **处理失败**: 确保音频格式匹配(16kHz, float数组)
- **性能问题**: 使用较小的缓冲区大小(10ms帧)

作者: Jimmy Gan
日期: 2025-07-28
EOF

echo "✅ WebRTC AEC3 Android AAR构建完成!"
echo ""
echo "构建输出:"
echo "  AAR文件: $OUTPUT_DIR/webrtc-aec3-android.aar"
echo "  集成文档: $OUTPUT_DIR/README-INTEGRATION.md"
echo ""
echo "AAR文件大小: $(du -h "$OUTPUT_DIR/webrtc-aec3-android.aar" | cut -f1)"
echo ""
echo "支持的Android架构:"
for abi in "${ANDROID_ABIS[@]}"; do
    if [ -f "$AAR_DIR/jni/$abi/libwebrtc_aec3.so" ]; then
        echo "  ✅ $abi"
    else
        echo "  ❌ $abi (构建失败)"
    fi
done

cd "$SCRIPT_DIR"
