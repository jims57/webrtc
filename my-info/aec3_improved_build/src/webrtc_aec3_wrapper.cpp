// Author: Jimmy Gan
// Date: 2025-01-28
// 跨平台WebRTC AEC3包装器实现

#include "webrtc_aec3_wrapper.h"
#include <memory>
#include <vector>
#include <cstring>

// WebRTC AEC3核心头文件
#include "modules/audio_processing/aec3/echo_canceller3.h"
#include "modules/audio_processing/audio_buffer.h"
#include "api/audio/echo_canceller3_config.h"
#include "rtc_base/checks.h"

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

// 内部AEC3处理器结构
struct WebRTCAEC3Processor {
    std::unique_ptr<webrtc::EchoCanceller3> echo_canceller;
    std::unique_ptr<webrtc::AudioBuffer> render_buffer;
    std::unique_ptr<webrtc::AudioBuffer> capture_buffer;
    
    WebRTCAEC3Config config;
    bool initialized;
    
    // 性能监控
    float last_erle_db;
    int last_delay_ms;
    
    WebRTCAEC3Processor() : initialized(false), last_erle_db(0.0f), last_delay_ms(0) {}
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
    
    try {
        auto processor = std::make_unique<WebRTCAEC3Processor>();
        processor->config = *config;
        
        // 创建WebRTC AEC3配置
        webrtc::EchoCanceller3Config aec3_config;
        
        // 移动设备优化配置
        if (config->use_mobile_mode) {
            aec3_config.delay.num_filters = 6;      // 移动设备减少滤波器数量
            aec3_config.delay.api_call_jitter_blocks = 1;
            aec3_config.echo_audibility.use_stationarity_properties = true;
            aec3_config.echo_removal_control.has_clock_drift = false;
            LOGI("启用移动设备优化模式");
        }
        
        // 设置延迟容忍度
        aec3_config.delay.delay_headroom_blocks = 
            std::max(1, config->stream_delay_ms / 10);  // 转换ms到块数
        
        // 创建EchoCanceller3实例
        processor->echo_canceller = std::make_unique<webrtc::EchoCanceller3>(
            aec3_config, 
            config->sample_rate_hz, 
            true  // 使用高通滤波器
        );
        
        // 创建AudioBuffer用于渲染流
        processor->render_buffer = std::make_unique<webrtc::AudioBuffer>(
            config->sample_rate_hz,
            config->num_channels,
            config->sample_rate_hz,
            config->num_channels,
            config->sample_rate_hz,
            config->num_channels
        );
        
        // 创建AudioBuffer用于捕获流
        processor->capture_buffer = std::make_unique<webrtc::AudioBuffer>(
            config->sample_rate_hz,
            config->num_channels,
            config->sample_rate_hz,
            config->num_channels,
            config->sample_rate_hz,
            config->num_channels
        );
        
        // 设置初始延迟
        processor->echo_canceller->SetAudioBufferDelay(config->stream_delay_ms);
        
        processor->initialized = true;
        
        LOGI("AEC3处理器创建成功: %dHz, %d声道, 延迟%dms", 
             config->sample_rate_hz, config->num_channels, config->stream_delay_ms);
        
        return processor.release();
        
    } catch (const std::exception& e) {
        LOGE("创建AEC3处理器异常: %s", e.what());
        return nullptr;
    } catch (...) {
        LOGE("创建AEC3处理器未知异常");
        return nullptr;
    }
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
    
    try {
        processor->echo_canceller->SetAudioBufferDelay(delay_ms);
        processor->config.stream_delay_ms = delay_ms;
        LOGD("设置流延迟: %d ms", delay_ms);
        return WEBRTC_AEC3_SUCCESS;
    } catch (...) {
        LOGE("设置流延迟失败");
        return WEBRTC_AEC3_ERROR_PROCESSING_FAILED;
    }
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
    
    try {
        // 将float数据复制到AudioBuffer
        float** channels = processor->render_buffer->channels_f();
        for (int ch = 0; ch < processor->config.num_channels; ++ch) {
            for (int i = 0; i < samples_per_channel; ++i) {
                if (processor->config.num_channels == 1) {
                    channels[ch][i] = farend_data[i];
                } else {
                    // 交错格式转换为分离格式
                    channels[ch][i] = farend_data[i * processor->config.num_channels + ch];
                }
            }
        }
        
        // 分析远端信号
        processor->echo_canceller->AnalyzeRender(processor->render_buffer.get());
        
        return WEBRTC_AEC3_SUCCESS;
        
    } catch (...) {
        LOGE("分析远端信号失败");
        return WEBRTC_AEC3_ERROR_PROCESSING_FAILED;
    }
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
    
    try {
        // 将float数据复制到AudioBuffer
        float** channels = processor->capture_buffer->channels_f();
        for (int ch = 0; ch < processor->config.num_channels; ++ch) {
            for (int i = 0; i < samples_per_channel; ++i) {
                if (processor->config.num_channels == 1) {
                    channels[ch][i] = nearend_data[i];
                } else {
                    // 交错格式转换为分离格式
                    channels[ch][i] = nearend_data[i * processor->config.num_channels + ch];
                }
            }
        }
        
        // 分析捕获信号（用于饱和检测）
        processor->echo_canceller->AnalyzeCapture(processor->capture_buffer.get());
        
        // 处理捕获信号（移除回声）
        processor->echo_canceller->ProcessCapture(processor->capture_buffer.get(), level_change);
        
        // 将处理后的数据复制到输出
        for (int ch = 0; ch < processor->config.num_channels; ++ch) {
            for (int i = 0; i < samples_per_channel; ++i) {
                if (processor->config.num_channels == 1) {
                    output_data[i] = channels[ch][i];
                } else {
                    // 分离格式转换为交错格式
                    output_data[i * processor->config.num_channels + ch] = channels[ch][i];
                }
            }
        }
        
        return WEBRTC_AEC3_SUCCESS;
        
    } catch (...) {
        LOGE("处理捕获信号失败");
        return WEBRTC_AEC3_ERROR_PROCESSING_FAILED;
    }
}

WebRTCAEC3ErrorCode webrtc_aec3_get_metrics(
    WebRTCAEC3Processor* processor,
    float* erle_db,
    int* delay_ms) {
    
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    try {
        auto metrics = processor->echo_canceller->GetMetrics();
        
        if (erle_db) {
            *erle_db = metrics.echo_return_loss_enhancement.value_or(0.0f);
            processor->last_erle_db = *erle_db;
        }
        
        if (delay_ms) {
            *delay_ms = metrics.delay_ms.value_or(0);
            processor->last_delay_ms = *delay_ms;
        }
        
        return WEBRTC_AEC3_SUCCESS;
        
    } catch (...) {
        LOGE("获取性能指标失败");
        return WEBRTC_AEC3_ERROR_PROCESSING_FAILED;
    }
}

WebRTCAEC3ErrorCode webrtc_aec3_reset(WebRTCAEC3Processor* processor) {
    if (!processor || !processor->initialized) {
        return WEBRTC_AEC3_ERROR_NOT_INITIALIZED;
    }
    
    try {
        // WebRTC EchoCanceller3没有公开的reset方法
        // 需要重新创建实例
        WebRTCAEC3Config config = processor->config;
        webrtc_aec3_destroy(processor);
        
        auto* new_processor = webrtc_aec3_create(&config);
        if (new_processor) {
            // 复制新实例的内容到当前实例
            *processor = *new_processor;
            delete new_processor;  // 只删除外壳，内容已转移
            return WEBRTC_AEC3_SUCCESS;
        }
        
        return WEBRTC_AEC3_ERROR_INIT_FAILED;
        
    } catch (...) {
        LOGE("重置AEC3处理器失败");
        return WEBRTC_AEC3_ERROR_PROCESSING_FAILED;
    }
}

} // extern "C"