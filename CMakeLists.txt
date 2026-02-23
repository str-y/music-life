cmake_minimum_required(VERSION 3.16)
project(music_life VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -----------------------------------------------------------------------
# Pitch Detection Library
# -----------------------------------------------------------------------
add_library(pitch_detection STATIC
    src/pitch_detection/yin.cpp
    src/pitch_detection/pitch_detector.cpp
    src/app_bridge/pitch_detector_ffi.cpp
)

target_include_directories(pitch_detection
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/src/pitch_detection
        ${CMAKE_CURRENT_SOURCE_DIR}/src/app_bridge
)

target_compile_options(pitch_detection PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra -O2>
    $<$<CXX_COMPILER_ID:MSVC>:/W4 /O2>
)

# -----------------------------------------------------------------------
# Tests (enabled by default; pass -DBUILD_TESTING=OFF to skip)
# -----------------------------------------------------------------------
include(CTest)
if(BUILD_TESTING)
    add_executable(test_pitch_detection
        tests/test_pitch_detector.cpp
    )
    target_link_libraries(test_pitch_detection PRIVATE pitch_detection)
    add_test(NAME pitch_detection_tests COMMAND test_pitch_detection)
endif()
