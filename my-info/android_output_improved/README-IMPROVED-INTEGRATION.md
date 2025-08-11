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
