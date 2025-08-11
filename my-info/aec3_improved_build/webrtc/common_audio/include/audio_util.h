// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for common_audio/include/audio_util.h

#ifndef COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_
#define COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_

#include <cstddef>
#include <algorithm>

namespace webrtc {

// Audio utility functions
inline void FloatToS16(const float* src, size_t size, int16_t* dest) {
    for (size_t i = 0; i < size; ++i) {
        float sample = src[i];
        sample = std::max(-1.0f, std::min(1.0f, sample));
        dest[i] = static_cast<int16_t>(sample * 32767.0f);
    }
}

inline void S16ToFloat(const int16_t* src, size_t size, float* dest) {
    for (size_t i = 0; i < size; ++i) {
        dest[i] = src[i] / 32767.0f;
    }
}

inline void FloatToFloatS16(const float* src, size_t size, float* dest) {
    for (size_t i = 0; i < size; ++i) {
        dest[i] = std::max(-1.0f, std::min(1.0f, src[i]));
    }
}

} // namespace webrtc

#endif // COMMON_AUDIO_INCLUDE_AUDIO_UTIL_H_
