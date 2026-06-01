cmake_minimum_required(VERSION 3.10.2)

project(wakeword_bridge)

include_directories(
    .
    ./edge-impulse-sdk
    ./edge-impulse-sdk/third_party
    ./edge-impulse-sdk/third_party/flatbuffers/include
    ./edge-impulse-sdk/third_party/ruy
    ./edge-impulse-sdk/anomaly
    ./edge-impulse-sdk/classifier
    ./edge-impulse-sdk/dsp
    ./edge-impulse-sdk/dsp/kissfft
    ./edge-impulse-sdk/porting
    ./model-parameters
    ./tflite-model
)

file(GLOB_RECURSE EI_SDK_SOURCES 
    "edge-impulse-sdk/dsp/kissfft/*.cpp"
    "edge-impulse-sdk/dsp/dct/*.cpp"
    "edge-impulse-sdk/classifier/*.cpp"
    "edge-impulse-sdk/porting/android/*.cpp"
)

# We need debug log from posix but must exclude the duplicated ei classifier porting
list(APPEND EI_SDK_SOURCES "edge-impulse-sdk/porting/posix/debug_log.cpp")

# Grab all TensorFlow Lite Micro source files
file(GLOB_RECURSE EI_TFLITE_SOURCES
    "edge-impulse-sdk/tensorflow/*.cpp"
    "edge-impulse-sdk/tensorflow/*.cc"
    "edge-impulse-sdk/tensorflow/*.c"
)

add_library(
    wakeword_bridge
    SHARED
    WakeWordBridge.cpp
    ${EI_SDK_SOURCES}
    ${EI_TFLITE_SOURCES}
)

find_library(log-lib log)

target_link_libraries(
    wakeword_bridge
    ${log-lib}
)