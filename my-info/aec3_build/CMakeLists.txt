# Author: Jimmy Gan
# Date: 2025-01-27
# WebRTC AEC3 Android构建配置

cmake_minimum_required(VERSION 3.18)
project(webrtc_aec3)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置包含目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/modules
    ${CMAKE_CURRENT_SOURCE_DIR}/modules/audio_processing
    ${CMAKE_CURRENT_SOURCE_DIR}/modules/audio_processing/include
    ${CMAKE_CURRENT_SOURCE_DIR}/api
    ${CMAKE_CURRENT_SOURCE_DIR}/rtc_base
    ${CMAKE_CURRENT_SOURCE_DIR}/system_wrappers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/common_audio
)

# 收集所有AEC3源文件
file(GLOB_RECURSE AEC3_SOURCES
    "modules/audio_processing/aec3/*.cc"
    "modules/audio_processing/utility/*.cc"
)

# 排除测试文件
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_test\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*_unittest\\.cc$")
list(FILTER AEC3_SOURCES EXCLUDE REGEX ".*test_.*\\.cc$")

# 添加自定义源文件
list(APPEND AEC3_SOURCES 
    "src/webrtc_aec3_processor.cpp"
    "jni/webrtc_aec3_jni.cpp"
)

# 创建共享库
add_library(webrtc_aec3 SHARED ${AEC3_SOURCES})

# 编译器定义
target_compile_definitions(webrtc_aec3 PRIVATE
    WEBRTC_ANDROID
    WEBRTC_POSIX
    HAVE_PTHREAD
)

# 链接库
target_link_libraries(webrtc_aec3 
    log
    android
)

# 编译选项
target_compile_options(webrtc_aec3 PRIVATE
    -fno-exceptions
    -fno-rtti
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-missing-field-initializers
)
