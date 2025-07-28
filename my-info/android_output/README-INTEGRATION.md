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
aecHelper.processTTSBeforePlayback(ttsAudio);

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
