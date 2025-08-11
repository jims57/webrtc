// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for common_audio/channel_buffer.h

#ifndef COMMON_AUDIO_CHANNEL_BUFFER_H_
#define COMMON_AUDIO_CHANNEL_BUFFER_H_

#include "common_audio/include/audio_util.h"
#include <vector>
#include <memory>

namespace webrtc {

template<typename T>
class ChannelBuffer {
public:
    ChannelBuffer(size_t num_frames, size_t num_channels)
        : num_frames_(num_frames), num_channels_(num_channels) {
        data_.resize(num_channels_ * num_frames_);
        channels_.resize(num_channels_);
        for (size_t i = 0; i < num_channels_; ++i) {
            channels_[i] = &data_[i * num_frames_];
        }
    }
    
    T* const* channels() { return channels_.data(); }
    const T* const* channels() const { return channels_.data(); }
    
    T** channels() { return channels_.data(); }
    
    size_t num_frames() const { return num_frames_; }
    size_t num_channels() const { return num_channels_; }
    
private:
    size_t num_frames_;
    size_t num_channels_;
    std::vector<T> data_;
    std::vector<T*> channels_;
};

} // namespace webrtc

#endif // COMMON_AUDIO_CHANNEL_BUFFER_H_
