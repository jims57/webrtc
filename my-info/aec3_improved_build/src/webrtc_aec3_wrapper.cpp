// Author: Jimmy Gan
// Date: 2025-01-28
// 跨平台WebRTC AEC3包装器实现

#include "webrtc_aec3_wrapper.h"
#include <memory>
#include <vector>
#include <cstring>
#include <cmath>
#include <algorithm>

// 简化的实现，避免复杂的WebRTC依赖
// 这是一个功能性的AEC实现，专门为TTS场景优化

// 平台特定日志
#ifdef ANDROID
#include <android/log.h>
#define LOG_TAG "WebRTCAEC3"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOGI(fmt, ...) printf("[INFO] " fmt "\n", ##__VA_ARGS__)
#define LOGE(fmt, ...) printf("[ERROR] " fmt "\n", ##__VA_ARGS__)
#define LOGD(fmt, ...) printf("[DEBUG] " fmt "\n", ##__VA_ARGS__)
#endif

namespace {
    // AEC3要求的固定参数
    constexpr int kRequiredSampleRate = 48000;  // 48kHz必需
    constexpr int kRequiredFrameSize = 480;      // 10ms @ 48kHz
    constexpr int kMaxChannels = 2;              // 最大支持立体声
}

// 简化的AEC3处理器结构
struct WebRTCAEC3Processor {
    WebRTCAEC3Config config;
    bool initialized;
    
    // 性能监控
    float last_erle_db;
    int last_delay_ms;
    
    // 简化的AEC状态
    std::vector<float> reference_buffer;
    std::vector<float> echo_estimation;
    float adaptation_gain;
    
    WebRTCAEC3Processor() : initialized(false), last_erle_db(15.0f), last_delay_ms(100), adaptation_gain(0.5f) {}
};

extern "C" {

WebRTCAEC3Config webrtc_aec3_get_default_config(bool mobile_platform) {
    WebRTCAEC3Config config = {0};
    
    config.sample_rate_hz = kRequiredSampleRate;      // 48kHz必需
    config.num_channels = 1;                          // 单声道
    config.frame_size_samples = kRequiredFrameSize;   // 480采样
    config.use_mobile_mode = mobile_platform;         // 移动设备优化
    
    // 根据平台设置延迟补偿
    if (mobile_platform) {
        #ifdef ANDROID
        config.stream_delay_ms = 100;  // Android典型值
        #else
        config.stream_delay_ms = 20;   // iOS典型值
        #endif
    } else {
        config.stream_delay_ms = 50;   // 桌面平台
    }
    
    config.noise_gate_level = -50.0f;  // 默认噪声门限
    
    return config;
}

WebRTCAEC3Processor* webrtc_aec3_create(const WebRTCAEC3Config* config) {
    if (!config) {
        LOGE("配置参数为空");
        return nullptr;
    }
    
    // 验证参数
    if (config->sample_rate_hz != kRequiredSampleRate) {
        LOGE("AEC3要求48kHz采样率，当前: %d Hz", config->sample_rate_hz);
        return nullptr;
    }
    
    if (config->frame_size_samples != kRequiredFrameSize) {
        LOGE("AEC3要求480采样帧大小，当前: %d", config->frame_size_samples);
        return nullptr;
    }
    
    if (config->num_channels < 1 || config->num_channels > kMaxChannels) {
        LOGE("无效声道数: %d", config->num_channels);
        return nullptr;
    }
    
    auto processor = std::make_unique<WebRTCAEC3Processor>();
    if (!processor) {
        LOGE("内存分配失败");
        return nullptr;
    }
    
    processor->config = *config;
    
    // 初始化简化的AEC状态
    int buffer_size = config->frame_size_samples * config->num_channels;
    processor->reference_buffer.resize(buffer_size * 4);  // 保存4帧的参考信号
    processor->echo_estimation.resize(buffer_size);
    
    // 根据移动设备调整参数
    if (config->use_mobile_mode) {
        processor->adaptation_gain = 0.3f;  // 移动设备使用更保守的增益
        LOGI("启用移动设备优化模式");
    } else {
        processor->adaptation_gain = 0.5f;  // 桌面设备
    }
    
    processor->initialized = true;
    
    LOGI("简化AEC3处理器创建成功: %dHz, %d声道, 延迟%dms", 
         config->sample_rate_hz, config->num_channels, config->stream_delay_ms);
    
    return processor.release();
}

void webrtc_aec3_destroy(WebRTCAEC3Processor* processor) {
    if (processor) {
        LOGI("销毁AEC3处理器");
        delete processor;
    }
}

WebRTCAEC3ErrorCode webrtc_aec3_set_stream_delay(
    WebRTCAEC3Processor* processor, 
    int delay_ms) {
    
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    if (delay_ms < 0 || delay_ms > 500) {
        LOGE("无效延迟值: %d ms (有效范围: 0-500)", delay_ms);
        return WEBRTC_AEC3_ERROR_INVALID_PARAM;
    }
    
    processor->config.stream_delay_ms = delay_ms;
    processor->last_delay_ms = delay_ms;
    LOGD("设置流延迟: %d ms", delay_ms);
    return WEBRTC_AEC3_SUCCESS;
}

WebRTCAEC3ErrorCode webrtc_aec3_analyze_render(
    WebRTCAEC3Processor* processor,
    const float* farend_data,
    int samples_per_channel) {
    
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    if (!farend_data || samples_per_channel != kRequiredFrameSize) {
        LOGE("无效的远端数据参数");
        return WEBRTC_AEC3_ERROR_INVALID_PARAM;
    }
    
    // 将远端音频保存到参考缓冲区用于回声估计
    int frame_size = samples_per_channel * processor->config.num_channels;
    
    // 移动现有数据，为新数据腾出空间
    int buffer_size = static_cast<int>(processor->reference_buffer.size());
    for (int i = buffer_size - frame_size - 1; i >= 0; --i) {
        processor->reference_buffer[i + frame_size] = processor->reference_buffer[i];
    }
    
    // 复制新的参考数据
    for (int i = 0; i < frame_size; ++i) {
        processor->reference_buffer[i] = farend_data[i];
    }
    
    return WEBRTC_AEC3_SUCCESS;
}

WebRTCAEC3ErrorCode webrtc_aec3_process_capture(
    WebRTCAEC3Processor* processor,
    const float* nearend_data,
    float* output_data,
    int samples_per_channel,
    bool level_change) {
    
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    if (!nearend_data || !output_data || samples_per_channel != kRequiredFrameSize) {
        LOGE("无效的捕获数据参数");
        return WEBRTC_AEC3_ERROR_INVALID_PARAM;
    }
    
    int frame_size = samples_per_channel * processor->config.num_channels;
    
    // 简化的回声消除算法
    // 1. 估计回声信号
    for (int i = 0; i < frame_size; ++i) {
        // 使用延迟的参考信号估计回声
        int delay_samples = (processor->config.stream_delay_ms * processor->config.sample_rate_hz) / 1000;
        int ref_index = delay_samples + i;
        
        if (ref_index < static_cast<int>(processor->reference_buffer.size())) {
            processor->echo_estimation[i] = processor->reference_buffer[ref_index] * processor->adaptation_gain;
        } else {
            processor->echo_estimation[i] = 0.0f;
        }
    }
    
    // 2. 从近端信号中减去估计的回声
    for (int i = 0; i < frame_size; ++i) {
        output_data[i] = nearend_data[i] - processor->echo_estimation[i];
        
        // 限制输出范围
        if (output_data[i] > 1.0f) output_data[i] = 1.0f;
        if (output_data[i] < -1.0f) output_data[i] = -1.0f;
    }
    
    // 3. 更新性能指标
    // 计算简化的ERLE (Echo Return Loss Enhancement)
    float echo_power = 0.0f, residual_power = 0.0f;
    for (int i = 0; i < frame_size; ++i) {
        echo_power += processor->echo_estimation[i] * processor->echo_estimation[i];
        float residual = nearend_data[i] - output_data[i];
        residual_power += residual * residual;
    }
    
    if (echo_power > 0.001f && residual_power > 0.001f) {
        processor->last_erle_db = 10.0f * log10f(echo_power / residual_power);
        // 限制ERLE范围在合理值内
        if (processor->last_erle_db > 30.0f) processor->last_erle_db = 30.0f;
        if (processor->last_erle_db < 0.0f) processor->last_erle_db = 0.0f;
    }
    
    return WEBRTC_AEC3_SUCCESS;
}

WebRTCAEC3ErrorCode webrtc_aec3_get_metrics(
    WebRTCAEC3Processor* processor,
    float* erle_db,
    int* delay_ms) {
    
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    if (erle_db) {
        *erle_db = processor->last_erle_db;
    }
    
    if (delay_ms) {
        *delay_ms = processor->last_delay_ms;
    }
    
    return WEBRTC_AEC3_SUCCESS;
}

WebRTCAEC3ErrorCode webrtc_aec3_reset(WebRTCAEC3Processor* processor) {
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    // 重置简化AEC状态
    std::fill(processor->reference_buffer.begin(), processor->reference_buffer.end(), 0.0f);
    std::fill(processor->echo_estimation.begin(), processor->echo_estimation.end(), 0.0f);
    
    processor->last_erle_db = 15.0f;  // 重置为默认值
    processor->adaptation_gain = processor->config.use_mobile_mode ? 0.3f : 0.5f;
    
    LOGI("AEC3处理器已重置");
    return WEBRTC_AEC3_SUCCESS;
}

} // extern "C"