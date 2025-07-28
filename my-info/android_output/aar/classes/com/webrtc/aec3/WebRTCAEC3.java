// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3 Android Java接口

package com.webrtc.aec3;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
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
    private final int inputChannels;
    private final int reverseChannels;
    
    /**
     * 创建AEC3处理器
     * @param sampleRate 采样率 (推荐16000Hz)
     * @param inputChannels 输入通道数 (推荐1-单声道)
     * @param reverseChannels 参考信号通道数 (推荐1-单声道)
     */
    public WebRTCAEC3(int sampleRate, int inputChannels, int reverseChannels) {
        this.sampleRate = sampleRate;
        this.inputChannels = inputChannels;
        this.reverseChannels = reverseChannels;
        
        nativeHandle = nativeCreate(sampleRate, inputChannels, reverseChannels);
        if (nativeHandle == 0) {
            throw new RuntimeException("创建WebRTC AEC3处理器失败");
        }
        
        Log.d(TAG, String.format("AEC3处理器已创建: 采样率=%d, 输入通道=%d, 参考通道=%d", 
                                sampleRate, inputChannels, reverseChannels));
    }
    
    /**
     * 处理TTS参考信号
     * 必须在播放TTS音频之前调用此方法
     * @param ttsAudio TTS PCM音频数据 (float数组)
     * @param samplesPerChannel 每个通道的采样数
     * @return true成功, false失败
     */
    public boolean processTTSReferenceStream(@NonNull float[] ttsAudio, int samplesPerChannel) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (ttsAudio.length < samplesPerChannel * reverseChannels) {
            Log.e(TAG, "TTS音频数据长度不足");
            return false;
        }
        
        int result = nativeProcessReverseStream(nativeHandle, ttsAudio, samplesPerChannel);
        return result == 0;
    }
    
    /**
     * 处理麦克风捕获信号(移除回声)
     * @param micAudio 麦克风PCM音频数据 (float数组，会被就地修改)
     * @param samplesPerChannel 每个通道的采样数  
     * @return true成功, false失败
     */
    public boolean processMicrophoneStream(@NonNull float[] micAudio, int samplesPerChannel) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (micAudio.length < samplesPerChannel * inputChannels) {
            Log.e(TAG, "麦克风音频数据长度不足");
            return false;
        }
        
        int result = nativeProcessCaptureStream(nativeHandle, micAudio, samplesPerChannel);
        return result == 0;
    }
    
    /**
     * 设置音频流延迟
     * @param delayMs 延迟毫秒数(通常20-100ms，根据设备调整)
     */
    public void setStreamDelay(int delayMs) {
        if (nativeHandle != 0) {
            nativeSetStreamDelay(nativeHandle, delayMs);
            Log.d(TAG, "设置流延迟: " + delayMs + "ms");
        }
    }
    
    /**
     * 获取回声返回损耗增强(ERLE)指标
     * @return ERLE值(dB)，-1表示无效
     */
    public float getEchoReturnLossEnhancement() {
        if (nativeHandle == 0) return -1.0f;
        return nativeGetERLE(nativeHandle);
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
    private native long nativeCreate(int sampleRate, int inputChannels, int reverseChannels);
    private native void nativeDestroy(long handle);
    private native int nativeProcessReverseStream(long handle, float[] reverseAudio, int samplesPerChannel);
    private native int nativeProcessCaptureStream(long handle, float[] captureAudio, int samplesPerChannel);
    private native void nativeSetStreamDelay(long handle, int delayMs);
    private native float nativeGetERLE(long handle);
}
