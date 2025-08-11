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
