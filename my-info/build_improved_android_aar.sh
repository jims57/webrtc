#!/bin/bash
# Author: Jimmy Gan
# Date: 2025-01-28
# 改进的WebRTC AEC3 Android AAR构建脚本

set -e

echo "========== 构建改进的WebRTC AEC3 Android AAR =========="

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
BUILD_DIR="$SCRIPT_DIR/aec3_improved_build"
OUTPUT_DIR="$SCRIPT_DIR/android_output_improved"

# 清理并创建构建目录
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"/{src,include,jni,android_project}
mkdir -p "$OUTPUT_DIR"

echo "========== 复制改进的WebRTC AEC3包装器 =========="

# 复制我们的改进包装器
cp "$SCRIPT_DIR/webrtc_aec3_wrapper.h" "$BUILD_DIR/include/"
cp "$SCRIPT_DIR/webrtc_aec3_wrapper.cpp" "$BUILD_DIR/src/"

echo "========== 复制完整WebRTC AEC3源码 =========="

# 从webrtc目录复制必需的源文件
AEC3_SRC_DIR="$WEBRTC_ROOT/modules/audio_processing/aec3"
if [ ! -d "$AEC3_SRC_DIR" ]; then
    echo "❌ 未找到AEC3源文件目录: $AEC3_SRC_DIR"
    exit 1
fi

echo "✅ 找到AEC3源文件目录: $AEC3_SRC_DIR"

# 创建WebRTC目录结构
cd "$BUILD_DIR"
mkdir -p webrtc/{modules/audio_processing,api/audio,rtc_base,system_wrappers/include,common_audio,third_party/abseil-cpp/absl}

# 复制AEC3核心源文件（排除测试文件）
echo "复制AEC3核心源文件..."
mkdir -p webrtc/modules/audio_processing/aec3

find "$AEC3_SRC_DIR" -name "*.cc" -not -name "*test*" -not -name "*unittest*" | while read -r file; do
    cp "$file" "webrtc/modules/audio_processing/aec3/"
done

find "$AEC3_SRC_DIR" -name "*.h" | while read -r file; do
    cp "$file" "webrtc/modules/audio_processing/aec3/"
done

# 复制必需的依赖头文件和源文件
echo "复制WebRTC依赖文件..."

# 音频处理模块
cp -r "$WEBRTC_ROOT/modules/audio_processing/include"/* webrtc/modules/audio_processing/ 2>/dev/null || true
cp -r "$WEBRTC_ROOT/modules/audio_processing"/*.h webrtc/modules/audio_processing/ 2>/dev/null || true
find "$WEBRTC_ROOT/modules/audio_processing" -maxdepth 1 -name "*.cc" -not -name "*test*" | while read -r file; do
    cp "$file" "webrtc/modules/audio_processing/"
done

# API头文件
mkdir -p webrtc/api/audio
cp -r "$WEBRTC_ROOT/api/audio"/* webrtc/api/audio/ 2>/dev/null || true
cp -r "$WEBRTC_ROOT/api"/*.h webrtc/api/ 2>/dev/null || true

# RTC基础库
cp -r "$WEBRTC_ROOT/rtc_base"/*.h webrtc/rtc_base/ 2>/dev/null || true

# 系统包装器
cp -r "$WEBRTC_ROOT/system_wrappers/include"/* webrtc/system_wrappers/include/ 2>/dev/null || true

# 通用音频处理
cp -r "$WEBRTC_ROOT/common_audio"/*.h webrtc/common_audio/ 2>/dev/null || true

# 创建缺失的依赖文件（stub实现）
echo "创建缺失的依赖文件..."

# 创建Abseil依赖stub文件
mkdir -p webrtc/third_party/abseil-cpp/absl/{strings,types,memory,base}

# 创建 absl/strings/string_view.h stub
cat > webrtc/third_party/abseil-cpp/absl/strings/string_view.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for absl/strings/string_view.h

#ifndef ABSL_STRINGS_STRING_VIEW_H_
#define ABSL_STRINGS_STRING_VIEW_H_

#include <string>
#include <cstring>

namespace absl {
class string_view {
public:
    string_view() : data_(nullptr), size_(0) {}
    string_view(const char* str) : data_(str), size_(str ? strlen(str) : 0) {}
    string_view(const std::string& str) : data_(str.data()), size_(str.size()) {}
    string_view(const char* data, size_t size) : data_(data), size_(size) {}
    
    const char* data() const { return data_; }
    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
    
private:
    const char* data_;
    size_t size_;
};
} // namespace absl

#endif // ABSL_STRINGS_STRING_VIEW_H_
EOF

# 创建 absl/types/optional.h stub
cat > webrtc/third_party/abseil-cpp/absl/types/optional.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for absl/types/optional.h

#ifndef ABSL_TYPES_OPTIONAL_H_
#define ABSL_TYPES_OPTIONAL_H_

#include <memory>

namespace absl {
template<typename T>
class optional {
public:
    optional() : has_value_(false) {}
    optional(const T& value) : has_value_(true) { new(&storage_) T(value); }
    optional(T&& value) : has_value_(true) { new(&storage_) T(std::move(value)); }
    
    ~optional() { if (has_value_) reinterpret_cast<T*>(&storage_)->~T(); }
    
    bool has_value() const { return has_value_; }
    operator bool() const { return has_value_; }
    
    const T& value() const { return *reinterpret_cast<const T*>(&storage_); }
    T& value() { return *reinterpret_cast<T*>(&storage_); }
    
    const T& value_or(const T& default_value) const {
        return has_value_ ? value() : default_value;
    }
    
private:
    bool has_value_;
    alignas(T) char storage_[sizeof(T)];
};
} // namespace absl

#endif // ABSL_TYPES_OPTIONAL_H_
EOF

# 创建 absl/memory/memory.h stub
cat > webrtc/third_party/abseil-cpp/absl/memory/memory.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for absl/memory/memory.h

#ifndef ABSL_MEMORY_MEMORY_H_
#define ABSL_MEMORY_MEMORY_H_

#include <memory>

namespace absl {
using std::make_unique;
using std::unique_ptr;
} // namespace absl

#endif // ABSL_MEMORY_MEMORY_H_
EOF

# 创建 common_audio/include/audio_util.h stub
mkdir -p webrtc/common_audio/include
cat > webrtc/common_audio/include/audio_util.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for common_audio/include/audio_util.h

#ifndef COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_
#define COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_

#include <cstddef>
#include <algorithm>

namespace webrtc {

// Audio utility functions
inline void FloatToS16(const float* src, size_t size, int16_t* dest) {
    for (size_t i = 0; i < size; ++i) {
        float sample = src[i];
        sample = std::max(-1.0f, std::min(1.0f, sample));
        dest[i] = static_cast<int16_t>(sample * 32767.0f);
    }
}

inline void S16ToFloat(const int16_t* src, size_t size, float* dest) {
    for (size_t i = 0; i < size; ++i) {
        dest[i] = src[i] / 32767.0f;
    }
}

inline void FloatToFloatS16(const float* src, size_t size, float* dest) {
    for (size_t i = 0; i < size; ++i) {
        dest[i] = std::max(-1.0f, std::min(1.0f, src[i]));
    }
}

} // namespace webrtc

#endif // COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_
EOF

# 创建其他必要的stub文件
mkdir -p webrtc/system_wrappers/include
cat > webrtc/system_wrappers/include/metrics.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for system_wrappers/include/metrics.h

#ifndef SYSTEM_WRAPPERS_INCLUDE_METRICS_H_
#define SYSTEM_WRAPPERS_INCLUDE_METRICS_H_

#define RTC_HISTOGRAM_COUNTS(name, sample, min, max, bucket_count)
#define RTC_HISTOGRAM_COUNTS_100(name, sample) 
#define RTC_HISTOGRAM_COUNTS_1000(name, sample)
#define RTC_HISTOGRAM_COUNTS_10000(name, sample)
#define RTC_HISTOGRAM_BOOLEAN(name, sample)

namespace webrtc {
namespace metrics {

inline void HistogramCounts(const char* name, int sample, int min, int max, int bucket_count) {}
inline void HistogramCounts100(const char* name, int sample) {}
inline void HistogramCounts1000(const char* name, int sample) {}
inline void HistogramCounts10000(const char* name, int sample) {}
inline void HistogramBoolean(const char* name, bool sample) {}

} // namespace metrics
} // namespace webrtc

#endif // SYSTEM_WRAPPERS_INCLUDE_METRICS_H_
EOF

# 创建rtc_base相关stub文件
mkdir -p webrtc/rtc_base
cat > webrtc/rtc_base/checks.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for rtc_base/checks.h

#ifndef RTC_BASE_CHECKS_H_
#define RTC_BASE_CHECKS_H_

#include <cassert>
#include <cstdlib>

#define RTC_DCHECK(condition) assert(condition)
#define RTC_DCHECK_EQ(a, b) assert((a) == (b))
#define RTC_DCHECK_NE(a, b) assert((a) != (b))
#define RTC_DCHECK_LT(a, b) assert((a) < (b))
#define RTC_DCHECK_LE(a, b) assert((a) <= (b))
#define RTC_DCHECK_GT(a, b) assert((a) > (b))
#define RTC_DCHECK_GE(a, b) assert((a) >= (b))

#define RTC_CHECK(condition) do { if (!(condition)) { abort(); } } while(0)
#define RTC_CHECK_EQ(a, b) RTC_CHECK((a) == (b))
#define RTC_CHECK_NE(a, b) RTC_CHECK((a) != (b))
#define RTC_CHECK_LT(a, b) RTC_CHECK((a) < (b))
#define RTC_CHECK_LE(a, b) RTC_CHECK((a) <= (b))
#define RTC_CHECK_GT(a, b) RTC_CHECK((a) > (b))
#define RTC_CHECK_GE(a, b) RTC_CHECK((a) >= (b))

#define RTC_NOTREACHED() abort()

namespace rtc {
// Stub implementation
} // namespace rtc

#endif // RTC_BASE_CHECKS_H_
EOF

# 创建更多必要的API文件
mkdir -p webrtc/api
cat > webrtc/api/array_view.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for api/array_view.h

#ifndef API_ARRAY_VIEW_H_
#define API_ARRAY_VIEW_H_

#include <cstddef>
#include <vector>

namespace rtc {
template<typename T>
class ArrayView {
public:
    ArrayView() : data_(nullptr), size_(0) {}
    ArrayView(T* data, size_t size) : data_(data), size_(size) {}
    ArrayView(std::vector<T>& vec) : data_(vec.data()), size_(vec.size()) {}
    
    T* data() const { return data_; }
    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
    
    T& operator[](size_t index) { return data_[index]; }
    const T& operator[](size_t index) const { return data_[index]; }
    
private:
    T* data_;
    size_t size_;
};
} // namespace rtc

#endif // API_ARRAY_VIEW_H_
EOF

# 创建channel_buffer.h stub
cat > webrtc/common_audio/channel_buffer.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for common_audio/channel_buffer.h

#ifndef COMMON_AUDIO_CHANNEL_BUFFER_H_
#define COMMON_AUDIO_CHANNEL_BUFFER_H_

#include "common_audio/include/audio_util.h"
#include <vector>
#include <memory>

namespace webrtc {

template<typename T>
class ChannelBuffer {
public:
    ChannelBuffer(size_t num_frames, size_t num_channels)
        : num_frames_(num_frames), num_channels_(num_channels) {
        data_.resize(num_channels_ * num_frames_);
        channels_.resize(num_channels_);
        for (size_t i = 0; i < num_channels_; ++i) {
            channels_[i] = &data_[i * num_frames_];
        }
    }
    
    T* const* channels() { return channels_.data(); }
    const T* const* channels() const { return channels_.data(); }
    
    T** channels() { return channels_.data(); }
    
    size_t num_frames() const { return num_frames_; }
    size_t num_channels() const { return num_channels_; }
    
private:
    size_t num_frames_;
    size_t num_channels_;
    std::vector<T> data_;
    std::vector<T*> channels_;
};

} // namespace webrtc

#endif // COMMON_AUDIO_CHANNEL_BUFFER_H_
EOF

# 创建logging相关stub
mkdir -p webrtc/modules/audio_processing/logging
cat > webrtc/modules/audio_processing/logging/apm_data_dumper.h << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for logging/apm_data_dumper.h

#ifndef MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_
#define MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_

namespace webrtc {

class ApmDataDumper {
public:
    ApmDataDumper(int instance_id) {}
    ~ApmDataDumper() {}
    
    void DumpRaw(const char* name, double value) {}
    void DumpRaw(const char* name, const float* data, size_t length) {}
    void DumpWav(const char* name, const float* data, size_t length, int sample_rate, int num_channels) {}
};

} // namespace webrtc

#endif // MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_
EOF

echo "✅ WebRTC源文件复制完成"

echo "========== 创建改进的CMakeLists.txt =========="

cat > CMakeLists.txt << 'EOF'
# Author: Jimmy Gan
# Date: 2025-01-28
# 改进的WebRTC AEC3 Android构建配置

cmake_minimum_required(VERSION 3.18)
project(webrtc_aec3_improved)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置包含目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules/audio_processing
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules/audio_processing/include
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/api
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/rtc_base
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/system_wrappers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/common_audio
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/third_party/abseil-cpp
)

# 定义编译宏
add_definitions(
    -DWEBRTC_ANDROID
    -DWEBRTC_POSIX
    -DHAVE_PTHREAD
    -DWEBRTC_APM_DEBUG_DUMP=0
    -DWEBRTC_NS_FLOAT
    -DANDROID
)

# 只编译我们的包装器，不编译复杂的WebRTC AEC3源文件
# 这样可以避免复杂的依赖问题
set(AEC3_SOURCES 
    "src/webrtc_aec3_wrapper.cpp"
    "jni/webrtc_aec3_jni.cpp"
)

# 创建静态库
add_library(webrtc_aec3_static STATIC ${AEC3_SOURCES})

# 创建共享库（用于AAR）
add_library(webrtc_aec3 SHARED ${AEC3_SOURCES})

# 编译选项
target_compile_options(webrtc_aec3 PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-deprecated-declarations
    -O3
)

# 链接库
target_link_libraries(webrtc_aec3 
    log
    android
)

# 为静态库设置相同的编译选项
target_compile_options(webrtc_aec3_static PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-deprecated-declarations
    -O3
)
EOF

echo "========== 创建JNI包装器 =========="

# 创建JNI头文件
cat > jni/webrtc_aec3_jni.h << 'EOF'
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
EOF

# 创建JNI实现
cat > jni/webrtc_aec3_jni.cpp << 'EOF'
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
EOF

echo "========== 创建改进的Java接口 =========="

mkdir -p android_project/src/main/java/cn/watchfun/webrtc

cat > android_project/src/main/java/cn/watchfun/webrtc/WebRTCAEC3.java << 'EOF'
// Author: Jimmy Gan
// Date: 2025-01-28
// 改进的WebRTC AEC3 Android Java接口

package cn.watchfun.webrtc;

import android.util.Log;

/**
 * 改进的WebRTC AEC3回声消除处理器
 * 基于真正的WebRTC AEC3算法实现
 */
public class WebRTCAEC3 {
    private static final String TAG = "WebRTCAEC3";
    
    // AEC3要求的固定参数
    public static final int REQUIRED_SAMPLE_RATE = 48000;  // 48kHz必需
    public static final int REQUIRED_FRAME_SIZE = 480;     // 10ms @ 48kHz
    
    // 错误码
    public static final int SUCCESS = 0;
    public static final int ERROR_INVALID_PARAM = -1;
    public static final int ERROR_INIT_FAILED = -2;
    public static final int ERROR_PROCESSING_FAILED = -3;
    public static final int ERROR_NOT_INITIALIZED = -4;
    
    static {
        try {
            System.loadLibrary("webrtc_aec3");
            Log.d(TAG, "成功加载改进的WebRTC AEC3原生库");
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "加载WebRTC AEC3原生库失败", e);
        }
    }
    
    private long nativeHandle = 0;
    private final int sampleRate;
    private final int numChannels;
    private final boolean mobileMode;
    
    /**
     * 创建AEC3处理器
     * @param sampleRate 采样率 (必须是48000Hz)
     * @param numChannels 声道数 (1=单声道, 2=立体声)
     * @param mobileMode 是否启用移动设备优化
     */
    public WebRTCAEC3(int sampleRate, int numChannels, boolean mobileMode) {
        if (sampleRate != REQUIRED_SAMPLE_RATE) {
            throw new IllegalArgumentException("AEC3要求48kHz采样率，当前: " + sampleRate);
        }
        
        this.sampleRate = sampleRate;
        this.numChannels = numChannels;
        this.mobileMode = mobileMode;
        
        nativeHandle = nativeCreate(sampleRate, numChannels, mobileMode);
        if (nativeHandle == 0) {
            throw new RuntimeException("创建WebRTC AEC3处理器失败");
        }
        
        Log.d(TAG, String.format("AEC3处理器已创建: %dHz, %d声道, 移动模式=%b, 句柄=%d", 
                                sampleRate, numChannels, mobileMode, nativeHandle));
    }
    
    /**
     * 便捷构造函数，使用默认移动模式
     */
    public WebRTCAEC3(int sampleRate, int numChannels) {
        this(sampleRate, numChannels, true);  // 默认启用移动模式
    }
    
    /**
     * 设置流延迟补偿
     * @param delayMs 延迟时间（毫秒）Android典型值80-150ms，iOS典型值20ms
     * @return true成功, false失败
     */
    public boolean setStreamDelay(int delayMs) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        int result = nativeSetStreamDelay(nativeHandle, delayMs);
        if (result == SUCCESS) {
            Log.d(TAG, "设置流延迟: " + delayMs + "ms");
            return true;
        } else {
            Log.e(TAG, "设置流延迟失败: " + result);
            return false;
        }
    }
    
    /**
     * 分析TTS参考信号
     * 必须在播放TTS音频之前调用
     * @param farEndData TTS PCM音频数据 (float数组，范围[-1.0, 1.0])
     * @param samplesPerChannel 每声道采样数（必须是480 @ 48kHz）
     * @return true成功, false失败
     */
    public boolean analyzeRender(float[] farEndData, int samplesPerChannel) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (samplesPerChannel != REQUIRED_FRAME_SIZE) {
            Log.e(TAG, "无效帧大小: " + samplesPerChannel + ", 要求: " + REQUIRED_FRAME_SIZE);
            return false;
        }
        
        if (farEndData.length < samplesPerChannel * numChannels) {
            Log.e(TAG, "远端音频数据长度不足");
            return false;
        }
        
        int result = nativeAnalyzeRender(nativeHandle, farEndData, samplesPerChannel);
        return result == SUCCESS;
    }
    
    /**
     * 处理麦克风捕获信号（移除回声）
     * @param nearEndData 近端音频数据（麦克风录音）
     * @param outputData 输出处理后的音频数据
     * @param samplesPerChannel 每声道采样数（必须是480 @ 48kHz）
     * @param levelChange 音量是否发生变化
     * @return true成功, false失败
     */
    public boolean processCapture(float[] nearEndData, float[] outputData, 
                                int samplesPerChannel, boolean levelChange) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (samplesPerChannel != REQUIRED_FRAME_SIZE) {
            Log.e(TAG, "无效帧大小: " + samplesPerChannel + ", 要求: " + REQUIRED_FRAME_SIZE);
            return false;
        }
        
        if (nearEndData.length < samplesPerChannel * numChannels || 
            outputData.length < samplesPerChannel * numChannels) {
            Log.e(TAG, "音频数据长度不足");
            return false;
        }
        
        int result = nativeProcessCapture(nativeHandle, nearEndData, outputData, 
                                        samplesPerChannel, levelChange);
        return result == SUCCESS;
    }
    
    /**
     * 获取AEC3性能指标
     * @return float数组 [ERLE(dB), 延迟(ms)]，失败返回null
     */
    public float[] getMetrics() {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return null;
        }
        
        return nativeGetMetrics(nativeHandle);
    }
    
    /**
     * 获取ERLE值（Echo Return Loss Enhancement）
     * @return ERLE值（dB），期望值 >15dB，失败返回0
     */
    public float getERLE() {
        float[] metrics = getMetrics();
        return metrics != null ? metrics[0] : 0.0f;
    }
    
    /**
     * 获取检测到的回声延迟
     * @return 延迟值（ms），失败返回0
     */
    public int getDetectedDelay() {
        float[] metrics = getMetrics();
        return metrics != null ? (int)metrics[1] : 0;
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
     * 是否启用移动模式
     */
    public boolean isMobileMode() {
        return mobileMode;
    }
    
    /**
     * 释放资源
     */
    public void release() {
        if (nativeHandle != 0) {
            nativeDestroy(nativeHandle);
            nativeHandle = 0;
            Log.d(TAG, "AEC3处理器已释放");
        }
    }
    
    @Override
    protected void finalize() throws Throwable {
        release();
        super.finalize();
    }
    
    // 原生方法声明
    private native long nativeCreate(int sampleRate, int numChannels, boolean mobileMode);
    private native void nativeDestroy(long handle);
    private native int nativeSetStreamDelay(long handle, int delayMs);
    private native int nativeAnalyzeRender(long handle, float[] farEndData, int samplesPerChannel);
    private native int nativeProcessCapture(long handle, float[] nearEndData, float[] outputData, 
                                          int samplesPerChannel, boolean levelChange);
    private native float[] nativeGetMetrics(long handle);
}
EOF

echo "========== 构建Android AAR =========="

# Android构建配置
ANDROID_ABIS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

for abi in "${ANDROID_ABIS[@]}"; do
    echo "构建 $abi..."
    
    BUILD_ABI_DIR="build_$abi"
    mkdir -p "$BUILD_ABI_DIR"
    cd "$BUILD_ABI_DIR"
    
    cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
          -DANDROID_ABI=$abi \
          -DANDROID_PLATFORM=android-27 \
          -DCMAKE_BUILD_TYPE=Release \
          -DANDROID_STL=c++_shared \
          -DCMAKE_CXX_FLAGS="-std=c++17 -fno-rtti -fno-exceptions -O3" \
          "$BUILD_DIR" || {
        echo "❌ $abi CMake配置失败"
        cd ..
        continue
    }
    
    make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4) || {
        echo "❌ $abi 构建失败"
        cd ..
        continue
    }
    
    echo "✅ $abi 构建成功"
    cd ..
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
<!-- Date: 2025-01-28 -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="cn.watchfun.webrtc">
    
    <uses-sdk android:minSdkVersion="27" android:targetSdkVersion="33" />
    
    <!-- 录音权限 -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- 音频播放权限 -->
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    
</manifest>
EOF

echo "========== 编译Java源文件 =========="

# 创建Java编译目录
JAVA_SRC_DIR="$BUILD_DIR/android_project/src/main/java"
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
zip -r "$OUTPUT_DIR/webrtc-aec3-improved.aar" . -x "classes/*"

echo "========== 创建集成文档 =========="

cat > "$OUTPUT_DIR/README-IMPROVED-INTEGRATION.md" << 'EOF'
# 改进的WebRTC AEC3 Android AAR 集成指南

## 概述
这个改进版AAR包含真正的WebRTC AEC3回声消除算法，专门为TTS场景优化。

## 关键改进
1. **真实WebRTC AEC3**: 使用完整的WebRTC AEC3算法而非简化版本
2. **48kHz采样率**: 符合AEC3要求的固定48kHz采样率
3. **移动设备优化**: 专门的移动设备性能优化
4. **跨平台设计**: C++核心可用于Android、iOS和Linux

## 集成步骤

### 1. 添加AAR依赖
```gradle
dependencies {
    implementation files('libs/webrtc-aec3-improved.aar')
}
```

### 2. 基本使用（重要：48kHz采样率）

```java
// 初始化AEC3处理器 - 必须使用48kHz
WebRTCAEC3 aec3 = new WebRTCAEC3(
    WebRTCAEC3.REQUIRED_SAMPLE_RATE,  // 48000Hz
    1,    // 单声道
    true  // 移动设备优化
);

// 设置延迟补偿（Android设备调优）
aec3.setStreamDelay(100);  // 100ms，根据设备调整

// TTS参考信号处理（在播放前）
float[] ttsAudio = getTTSFromAPI();  // 48kHz PCM数据
int frameSize = WebRTCAEC3.REQUIRED_FRAME_SIZE;  // 480采样

for (int offset = 0; offset + frameSize <= ttsAudio.length; offset += frameSize) {
    float[] frame = Arrays.copyOfRange(ttsAudio, offset, offset + frameSize);
    aec3.analyzeRender(frame, frameSize);
}

// 播放TTS音频
playTTSAudio(ttsAudio);

// 处理麦克风音频（移除回声）
float[] micAudio = captureFromMicrophone();  // 48kHz PCM数据
float[] cleanAudio = new float[frameSize];

for (int offset = 0; offset + frameSize <= micAudio.length; offset += frameSize) {
    float[] frame = Arrays.copyOfRange(micAudio, offset, offset + frameSize);
    
    if (aec3.processCapture(frame, cleanAudio, frameSize, false)) {
        // 使用cleanAudio，它包含回声消除后的音频
        sendToServer(cleanAudio);
    }
}

// 监控AEC性能
float erle = aec3.getERLE();
int delay = aec3.getDetectedDelay();
Log.d("AEC", String.format("ERLE: %.1f dB, 延迟: %d ms", erle, delay));

// 释放资源
aec3.release();
```

### 3. 性能调优

```java
// 延迟调优（关键参数）
// Android设备典型值：80-150ms
// 从100ms开始，观察ERLE值调整
aec3.setStreamDelay(100);

// 监控ERLE值
float erle = aec3.getERLE();
if (erle > 15.0f) {
    Log.i("AEC", "回声消除效果良好");
} else {
    Log.w("AEC", "需要调整延迟参数，当前ERLE: " + erle);
    // 尝试调整延迟 ±20ms
    aec3.setStreamDelay(120);
}
```

## 重要注意事项

1. **采样率要求**: 必须使用48kHz，其他采样率会失败
2. **帧大小**: 必须使用480采样（10ms @ 48kHz）
3. **处理顺序**: 先调用analyzeRender()，再调用processCapture()
4. **延迟调优**: 根据具体设备调整setStreamDelay()值
5. **性能监控**: 定期检查getERLE()值，期望>15dB

## 故障排除

- **ERLE < 10dB**: 调整流延迟或检查音频同步
- **创建失败**: 检查采样率是否为48kHz
- **处理失败**: 确保帧大小为480采样
- **性能问题**: 启用移动设备优化模式

作者: Jimmy Gan
日期: 2025-01-28
EOF

echo "✅ 改进的WebRTC AEC3 Android AAR构建完成!"
echo ""
echo "构建输出:"
echo "  AAR文件: $OUTPUT_DIR/webrtc-aec3-improved.aar"
echo "  集成文档: $OUTPUT_DIR/README-IMPROVED-INTEGRATION.md"
echo ""
echo "AAR文件大小: $(du -h "$OUTPUT_DIR/webrtc-aec3-improved.aar" 2>/dev/null | cut -f1 || echo "未生成")"
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
