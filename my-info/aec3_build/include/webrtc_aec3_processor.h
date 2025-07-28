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
