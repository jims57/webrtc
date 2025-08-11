# WebRTC AEC3 Android AAR 完整集成指南

**Author: Jimmy Gan**  
**Date: 2025-01-28**

## 概述

这是一个完整的WebRTC AEC3解决方案，专为TTS回声消除场景优化。包含真正的WebRTC AEC3算法实现，支持Android、iOS和Linux跨平台使用。

## 🚀 关键特性

1. **真实WebRTC AEC3**: 基于完整的WebRTC AEC3算法，非简化版本
2. **48kHz采样率**: 符合AEC3要求的固定48kHz采样率
3. **移动设备优化**: 专门的Android移动设备性能优化于Android、iOS和Linu
4. **跨平台设计**: C++核心可用x
5. **实时性能监控**: ERLE值和延迟监控
6. **动态延迟调整**: 支持运行时调整流延迟补偿

## 📁 项目结构

```
webrtc/my-info/
├── webrtc_aec3_wrapper.h           # 跨平台C++头文件
├── webrtc_aec3_wrapper.cpp         # 跨平台C++实现
├── build_improved_android_aar.sh   # 改进的Android AAR构建脚本
└── WEBRTC_AEC3_INTEGRATION_GUIDE.md # 本指南

android_use_cpp/
├── app/src/main/java/.../MainActivity.java  # 更新的测试应用
└── app/src/main/res/layout/activity_main.xml # 改进的UI界面
```

## 🔧 构建步骤

### 1. 构建Android AAR

```bash
# 进入WebRTC目录
cd webrtc/my-info

# 给脚本执行权限
chmod +x build_improved_android_aar.sh

# 构建AAR
./build_improved_android_aar.sh
```

构建完成后将生成：
- `android_output_improved/webrtc-aec3-improved.aar`
- `android_output_improved/README-IMPROVED-INTEGRATION.md`

### 2. 集成到Android项目

#### 添加AAR依赖

```gradle
// app/build.gradle
dependencies {
    implementation files('libs/webrtc-aec3-improved.aar')
}
```

#### 添加权限

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## 💻 使用示例

### 基本使用

```java
// 1. 创建AEC3处理器（必须使用48kHz）
WebRTCAEC3 aec3 = new WebRTCAEC3(
    WebRTCAEC3.REQUIRED_SAMPLE_RATE,  // 48000Hz
    1,    // 单声道
    true  // 移动设备优化
);

// 2. 设置延迟补偿（关键参数）
aec3.setStreamDelay(100);  // Android典型值80-150ms

// 3. 处理TTS参考信号（在播放前）
float[] ttsAudio = getTTSFromAPI();  // 48kHz PCM数据
int frameSize = WebRTCAEC3.REQUIRED_FRAME_SIZE;  // 480采样

for (int offset = 0; offset + frameSize <= ttsAudio.length; offset += frameSize) {
    float[] frame = Arrays.copyOfRange(ttsAudio, offset, offset + frameSize);
    aec3.analyzeRender(frame, frameSize);
}

// 4. 播放TTS音频
playTTSAudio(ttsAudio);

// 5. 处理麦克风音频（移除回声）
float[] micAudio = captureFromMicrophone();  // 48kHz PCM数据
float[] cleanAudio = new float[frameSize];

for (int offset = 0; offset + frameSize <= micAudio.length; offset += frameSize) {
    float[] frame = Arrays.copyOfRange(micAudio, offset, offset + frameSize);
    
    if (aec3.processCapture(frame, cleanAudio, frameSize, false)) {
        // cleanAudio包含回声消除后的音频
        sendToServer(cleanAudio);
    }
}

// 6. 监控性能
float erle = aec3.getERLE();
int delay = aec3.getDetectedDelay();
Log.d("AEC", String.format("ERLE: %.1f dB, 延迟: %d ms", erle, delay));

// 7. 释放资源
aec3.release();
```

### 实时处理示例

```java
public class RealtimeAECProcessor {
    private WebRTCAEC3 aec3;
    private static final int FRAME_SIZE = 480;
    
    public void initialize() {
        aec3 = new WebRTCAEC3(48000, 1, true);
        aec3.setStreamDelay(100);
    }
    
    // TTS播放回调
    public void onTTSAudioReady(float[] ttsFrame) {
        if (ttsFrame.length == FRAME_SIZE) {
            aec3.analyzeRender(ttsFrame, FRAME_SIZE);
        }
    }
    
    // 麦克风录音回调
    public float[] onMicrophoneAudio(float[] micFrame) {
        if (micFrame.length == FRAME_SIZE) {
            float[] output = new float[FRAME_SIZE];
            if (aec3.processCapture(micFrame, output, FRAME_SIZE, false)) {
                return output;  // 返回处理后的音频
            }
        }
        return micFrame;  // 失败时返回原始音频
    }
    
    public void cleanup() {
        if (aec3 != null) {
            aec3.release();
        }
    }
}
```

## 🎛️ 测试应用使用

更新后的测试应用提供了完整的AEC3测试界面：

### UI功能

1. **原始录音（无AEC）**: 测试无回声消除的录音效果
2. **AEC3录音（回声消除）**: 测试WebRTC AEC3回声消除效果
3. **延迟补偿控制**: 动态调整流延迟（20-200ms）
4. **实时性能监控**: 显示ERLE值和检测延迟
5. **状态指示**: 实时显示处理状态

### 测试步骤

1. **权限确认**: 确保已授予录音权限
2. **原始测试**: 先点击"原始录音"测试基础功能
3. **AEC3测试**: 点击"AEC3录音"测试回声消除
4. **延迟调优**: 根据ERLE值调整延迟补偿
5. **性能监控**: 观察ERLE值（期望>15dB）

## ⚙️ 性能调优

### 延迟调优

```java
// 延迟调优策略
int baseDelay = 100;  // 起始值
aec3.setStreamDelay(baseDelay);

// 监控ERLE值并调整
float erle = aec3.getERLE();
if (erle < 10.0f) {
    // ERLE过低，尝试调整延迟
    aec3.setStreamDelay(baseDelay + 20);
} else if (erle > 20.0f) {
    // ERLE很高，可以尝试减少延迟
    aec3.setStreamDelay(baseDelay - 10);
}
```

### 设备特定参数

```java
// Android设备优化参数
public class AEC3DeviceConfig {
    public static int getOptimalDelay(String deviceModel) {
        switch (deviceModel.toLowerCase()) {
            case "samsung":
                return 120;  // Samsung设备典型值
            case "xiaomi":
                return 100;  // 小米设备典型值
            case "huawei":
                return 110;  // 华为设备典型值
            default:
                return 100;  // 默认值
        }
    }
}
```

## 🔍 故障排除

### 常见问题

1. **ERLE < 10dB**
   - 检查：延迟补偿设置
   - 解决：调整setStreamDelay()值（±20ms）

2. **创建失败**
   - 检查：采样率是否为48kHz
   - 解决：确保使用REQUIRED_SAMPLE_RATE

3. **处理失败**
   - 检查：帧大小是否为480采样
   - 解决：确保使用REQUIRED_FRAME_SIZE

4. **性能问题**
   - 检查：是否启用移动设备优化
   - 解决：构造函数传入true启用移动模式

### 调试日志

```java
// 启用详细日志
adb shell setprop log.tag.WebRTCAEC3 VERBOSE
adb shell setprop log.tag.MainActivity VERBOSE

// 查看AEC3相关日志
adb logcat | grep -E "(WebRTCAEC3|AEC3|ERLE)"
```

## 📊 性能指标

### ERLE值解读

- **> 20dB**: 优秀，回声消除效果很好
- **15-20dB**: 良好，可接受的回声消除
- **10-15dB**: 一般，需要优化延迟设置
- **< 10dB**: 较差，需要调整参数或检查音频同步

### 延迟范围

- **Android手机**: 80-150ms（典型值100ms）
- **Android平板**: 60-120ms（典型值80ms）
- **高端设备**: 50-100ms（典型值70ms）

## 🌐 跨平台扩展

### iOS集成

C++核心代码可直接用于iOS：

```cpp
// iOS特定配置
WebRTCAEC3Config config = webrtc_aec3_get_default_config(true);
config.stream_delay_ms = 20;  // iOS典型延迟
```

### Linux服务器

```cpp
// Linux服务器配置
WebRTCAEC3Config config = webrtc_aec3_get_default_config(false);
config.stream_delay_ms = 50;  // 服务器典型延迟
```

## 📝 最佳实践

1. **音频格式**: 始终使用48kHz采样率，480采样帧
2. **处理顺序**: 先调用analyzeRender()，再调用processCapture()
3. **延迟设置**: 根据设备类型设置初始延迟，然后根据ERLE值微调
4. **性能监控**: 定期检查ERLE值，及时调整参数
5. **资源管理**: 及时调用release()释放资源
6. **线程安全**: 在专用音频线程中调用AEC处理方法

## 🔗 相关文档

- [WebRTC AEC3 官方文档](https://webrtc.org/architecture/)
- [Android Audio 最佳实践](https://developer.android.com/guide/topics/media/audio-app-best-practices)
- [WebRTC Native API](https://webrtc.googlesource.com/src/+/refs/heads/main/docs/native-code/)

---

**注意**: 本方案基于WebRTC最新版本，确保AEC3算法的最佳性能和兼容性。如遇问题，请参考故障排除部分或查看详细日志。
