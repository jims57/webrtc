// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3 Android Java接口

package cn.watchfun.webrtc;

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
    private final int numChannels;
    
    /**
     * 创建AEC3处理器
     * @param sampleRate 采样率 (推荐16000Hz)
     * @param numChannels 声道数 (推荐1-单声道)
     */
    public WebRTCAEC3(int sampleRate, int numChannels) {
        this.sampleRate = sampleRate;
        this.numChannels = numChannels;
        
        nativeHandle = nativeCreateProcessor(sampleRate, numChannels);
        if (nativeHandle == 0) {
            throw new RuntimeException("创建WebRTC AEC3处理器失败");
        }
        
        Log.d(TAG, String.format("AEC3处理器已创建: 采样率=%d, 声道数=%d, 句柄=%d", 
                                sampleRate, numChannels, nativeHandle));
    }
    
    /**
     * 处理TTS参考信号
     * 必须在播放TTS音频之前或同时调用此方法
     * @param reference TTS PCM音频数据 (float数组，范围[-1.0, 1.0])
     * @param frameSize 帧大小
     * @return true成功, false失败
     */
    public boolean processReference(float[] reference, int frameSize) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (reference.length < frameSize * numChannels) {
            Log.e(TAG, "参考音频数据长度不足");
            return false;
        }
        
        int result = nativeProcessReference(nativeHandle, reference, frameSize);
        return result == 0;
    }
    
    /**
     * 处理麦克风音频流(移除回声)
     * @param nearEnd 麦克风PCM音频数据 (float数组，范围[-1.0, 1.0])
     * @param farEnd 远端音频数据 (可为null或零数组)
     * @param output 输出处理后的音频数据 (float数组)
     * @param frameSize 帧大小
     * @return true成功, false失败
     */
    public boolean processStream(float[] nearEnd, float[] farEnd, float[] output, int frameSize) {
        if (nativeHandle == 0) {
            Log.e(TAG, "AEC3处理器未初始化");
            return false;
        }
        
        if (nearEnd.length < frameSize * numChannels || 
            output.length < frameSize * numChannels) {
            Log.e(TAG, "音频数据长度不足");
            return false;
        }
        
        // 如果没有远端数据，创建零数组
        if (farEnd == null) {
            farEnd = new float[frameSize * numChannels];
        }
        
        int result = nativeProcessStream(nativeHandle, nearEnd, farEnd, output, frameSize);
        return result == 0;
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
     * 释放资源
     */
    public void release() {
        if (nativeHandle != 0) {
            nativeDestroyProcessor(nativeHandle);
            nativeHandle = 0;
            Log.d(TAG, "AEC3处理器已释放");
        }
    }
    
    @Override
    protected void finalize() throws Throwable {
        release();
        super.finalize();
    }
    
    // 原生方法声明 - 这些方法名必须与JNI实现完全匹配
    public native long nativeCreateProcessor(int sampleRate, int numChannels);
    public native void nativeDestroyProcessor(long handle);
    public native int nativeProcessStream(long handle, float[] nearEnd, float[] farEnd, float[] output, int frameSize);
    public native int nativeProcessReference(long handle, float[] reference, int frameSize);
}
