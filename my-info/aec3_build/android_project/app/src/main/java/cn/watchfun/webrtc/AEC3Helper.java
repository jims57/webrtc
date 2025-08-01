// Author: Jimmy Gan
// Date: 2025-01-27
// WebRTC AEC3使用示例辅助类

package cn.watchfun.webrtc;

import android.util.Log;

/**
 * AEC3辅助类，展示如何在TTS场景中使用WebRTC AEC3
 */
public class AEC3Helper {
    private static final String TAG = "AEC3Helper";
    private WebRTCAEC3 aec3Processor;
    
    // 推荐的音频参数
    private static final int SAMPLE_RATE = 16000;  // 16kHz
    private static final int CHANNELS = 1;         // 单声道
    private static final int FRAME_SIZE_MS = 10;   // 10ms帧
    private static final int SAMPLES_PER_FRAME = SAMPLE_RATE / 100; // 160采样
    
    /**
     * 初始化AEC3处理器
     */
    public boolean initialize() {
        try {
            aec3Processor = new WebRTCAEC3(SAMPLE_RATE, CHANNELS);
            Log.i(TAG, "AEC3处理器初始化成功");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "AEC3处理器初始化失败", e);
            return false;
        }
    }
    
    /**
     * 处理TTS PCM流作为参考信号
     * 在播放TTS音频之前调用此方法
     * @param ttsPcmData TTS PCM数据 (float数组)
     */
    public void processTTSReference(float[] ttsPcmData) {
        if (aec3Processor == null) {
            Log.e(TAG, "AEC3处理器未初始化");
            return;
        }
        
        // 按帧处理TTS数据
        int offset = 0;
        while (offset + SAMPLES_PER_FRAME <= ttsPcmData.length) {
            float[] frame = new float[SAMPLES_PER_FRAME];
            System.arraycopy(ttsPcmData, offset, frame, 0, SAMPLES_PER_FRAME);
            
            if (!aec3Processor.processReference(frame, SAMPLES_PER_FRAME)) {
                Log.w(TAG, "处理TTS参考流失败，偏移: " + offset);
            }
            
            offset += SAMPLES_PER_FRAME;
        }
    }
    
    /**
     * 处理麦克风捕获的音频(移除回声)
     * @param micPcmData 麦克风PCM数据 (float数组)
     * @return 处理后的干净音频
     */
    public float[] processMicrophoneAudio(float[] micPcmData) {
        if (aec3Processor == null) {
            Log.e(TAG, "AEC3处理器未初始化");
            return micPcmData;
        }
        
        float[] cleanAudio = new float[micPcmData.length];
        
        // 按帧处理麦克风数据
        int offset = 0;
        while (offset + SAMPLES_PER_FRAME <= micPcmData.length) {
            float[] nearEnd = new float[SAMPLES_PER_FRAME];
            float[] output = new float[SAMPLES_PER_FRAME];
            
            System.arraycopy(micPcmData, offset, nearEnd, 0, SAMPLES_PER_FRAME);
            
            if (aec3Processor.processStream(nearEnd, null, output, SAMPLES_PER_FRAME)) {
                // 复制处理后的数据到输出数组
                System.arraycopy(output, 0, cleanAudio, offset, SAMPLES_PER_FRAME);
            } else {
                Log.w(TAG, "处理麦克风流失败，偏移: " + offset);
                // 失败时使用原始数据
                System.arraycopy(nearEnd, 0, cleanAudio, offset, SAMPLES_PER_FRAME);
            }
            
            offset += SAMPLES_PER_FRAME;
        }
        
        return cleanAudio;
    }
    
    /**
     * 释放资源
     */
    public void release() {
        if (aec3Processor != null) {
            aec3Processor.release();
            aec3Processor = null;
            Log.i(TAG, "AEC3资源已释放");
        }
    }
}
