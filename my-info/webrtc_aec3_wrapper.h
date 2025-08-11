// Author: Jimmy Gan
// Date: 2025-01-28
// 跨平台WebRTC AEC3包装器头文件
// 支持Android、iOS和Linux平台

#ifndef WEBRTC_AEC3_WRAPPER_H
#define WEBRTC_AEC3_WRAPPER_H

#include <stdint.h>
#include <memory>

#ifdef __cplusplus
extern "C" {
#endif

// AEC3处理器句柄
typedef struct WebRTCAEC3Processor WebRTCAEC3Processor;

// 错误码定义
typedef enum {
    WEBRTC_AEC3_SUCCESS = 0,
    WEBRTC_AEC3_ERROR_INVALID_PARAM = -1,
    WEBRTC_AEC3_ERROR_INIT_FAILED = -2,
    WEBRTC_AEC3_ERROR_PROCESSING_FAILED = -3,
    WEBRTC_AEC3_ERROR_NOT_INITIALIZED = -4
} WebRTCAEC3ErrorCode;

// AEC3配置参数
typedef struct {
    int sample_rate_hz;        // 采样率，必须是48000 (AEC3要求)
    int num_channels;          // 声道数 (1=单声道, 2=立体声)
    int frame_size_samples;    // 帧大小（480采样 = 10ms @ 48kHz）
    bool use_mobile_mode;      // 移动设备优化模式
    int stream_delay_ms;       // 流延迟补偿（Android: 80-150ms, iOS: 20ms）
    float noise_gate_level;    // 噪声门限 (-60.0f到0.0f dB)
} WebRTCAEC3Config;

/**
 * 获取默认AEC3配置
 * @param mobile_platform true为移动平台优化，false为桌面平台
 * @return 默认配置结构体
 */
WebRTCAEC3Config webrtc_aec3_get_default_config(bool mobile_platform);

/**
 * 创建AEC3处理器实例
 * @param config AEC3配置参数
 * @return 处理器实例指针，失败返回NULL
 */
WebRTCAEC3Processor* webrtc_aec3_create(const WebRTCAEC3Config* config);

/**
 * 销毁AEC3处理器实例
 * @param processor 处理器实例指针
 */
void webrtc_aec3_destroy(WebRTCAEC3Processor* processor);

/**
 * 设置流延迟（用于优化AEC性能）
 * @param processor 处理器实例
 * @param delay_ms 延迟时间（毫秒）
 * @return 错误码
 */
WebRTCAEC3ErrorCode webrtc_aec3_set_stream_delay(
    WebRTCAEC3Processor* processor, 
    int delay_ms
);

/**
 * 分析远端信号（TTS音频参考信号）
 * 必须在播放TTS音频之前调用，用于建立回声消除的参考
 * @param processor 处理器实例
 * @param farend_data 远端音频数据 (float格式，范围[-1.0, 1.0])
 * @param samples_per_channel 每声道采样数（必须是480 @ 48kHz）
 * @return 错误码
 */
WebRTCAEC3ErrorCode webrtc_aec3_analyze_render(
    WebRTCAEC3Processor* processor,
    const float* farend_data,
    int samples_per_channel
);

/**
 * 处理捕获信号（麦克风音频，移除回声）
 * @param processor 处理器实例
 * @param nearend_data 近端音频数据（麦克风录音）
 * @param output_data 输出处理后的音频数据
 * @param samples_per_channel 每声道采样数（必须是480 @ 48kHz）
 * @param level_change 音量是否发生变化
 * @return 错误码
 */
WebRTCAEC3ErrorCode webrtc_aec3_process_capture(
    WebRTCAEC3Processor* processor,
    const float* nearend_data,
    float* output_data,
    int samples_per_channel,
    bool level_change
);

/**
 * 获取AEC3性能指标
 * @param processor 处理器实例
 * @param erle_db Echo Return Loss Enhancement (期望值 >15dB)
 * @param delay_ms 检测到的回声延迟
 * @return 错误码
 */
WebRTCAEC3ErrorCode webrtc_aec3_get_metrics(
    WebRTCAEC3Processor* processor,
    float* erle_db,
    int* delay_ms
);

/**
 * 重置AEC3处理器状态
 * @param processor 处理器实例
 * @return 错误码
 */
WebRTCAEC3ErrorCode webrtc_aec3_reset(WebRTCAEC3Processor* processor);

#ifdef __cplusplus
}
#endif

#endif // WEBRTC_AEC3_WRAPPER_H