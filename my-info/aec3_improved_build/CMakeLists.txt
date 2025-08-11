# Author: Jimmy Gan
# Date: 2025-01-28
# 改进的WebRTC AEC3 Android构建配置

cmake_minimum_required(VERSION 3.18)
project(webrtc_aec3_improved)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置包含目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules/audio_processing
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/modules/audio_processing/include
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/api
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/rtc_base
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/system_wrappers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/common_audio
    ${CMAKE_CURRENT_SOURCE_DIR}/webrtc/third_party/abseil-cpp
)

# 定义编译宏
add_definitions(
    -DWEBRTC_ANDROID
    -DWEBRTC_POSIX
    -DHAVE_PTHREAD
    -DWEBRTC_APM_DEBUG_DUMP=0
    -DWEBRTC_NS_FLOAT
    -DANDROID
)

# 收集AEC3核心源文件
file(GLOB_RECURSE AEC3_SOURCES
    "webrtc/modules/audio_processing/aec3/*.cc"
    "webrtc/modules/audio_processing/audio_buffer.cc"
    "webrtc/modules/audio_processing/splitting_filter.cc"
    "webrtc/modules/audio_processing/three_band_filter_bank.cc"
)

# 排除测试文件
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_test\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_unittest\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*test_.*\\.cc$")

# 添加我们的包装器源文件
list(APPEND AEC3_SOURCES 
    "src/webrtc_aec3_wrapper.cpp"
    "jni/webrtc_aec3_jni.cpp"
)

# 创建静态库
add_library(webrtc_aec3_static STATIC ${AEC3_SOURCES})

# 创建共享库（用于AAR）
add_library(webrtc_aec3 SHARED ${AEC3_SOURCES})

# 编译选项
target_compile_options(webrtc_aec3 PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-deprecated-declarations
    -O3
)

# 链接库
target_link_libraries(webrtc_aec3 
    log
    android
)

# 为静态库设置相同的编译选项
target_compile_options(webrtc_aec3_static PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-deprecated-declarations
    -O3
)
