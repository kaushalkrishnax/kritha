cmake_minimum_required(VERSION 3.10.2)
project(wakeword_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(EI_ARCHIVE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../edge-impulse-exports/kritha-cpp-android-v5-impulse-#1.zip")
if(NOT EXISTS "${EI_ARCHIVE}")
    message(FATAL_ERROR "Missing Edge Impulse export archive: ${EI_ARCHIVE}")
endif()

# Keep the generated Edge Impulse SDK/model archive as the reviewed source
# artifact in Git; unpack it only under CMake's generated build directory.
set(EI_EXPORT_DIR "${CMAKE_CURRENT_BINARY_DIR}/edge-impulse-export")
file(ARCHIVE_EXTRACT INPUT "${EI_ARCHIVE}" DESTINATION "${EI_EXPORT_DIR}")

set(EI_ROOT "${EI_EXPORT_DIR}/edge-impulse-sdk")
set(EI_MODEL "${EI_EXPORT_DIR}/tflite-model")

include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}"
    # EI_EXPORT_DIR is the unzip destination: it contains edge-impulse-sdk/, tflite-model/,
    # and model-parameters/ as top-level siblings.
    # WakeWordBridge.cpp uses #include "edge-impulse-sdk/..." so EI_EXPORT_DIR must be on the
    # include path so that the "edge-impulse-sdk" prefix resolves to EI_ROOT.
    "${EI_EXPORT_DIR}"
    # model-parameters/ and tflite-model/ are top-level siblings of edge-impulse-sdk/.
    "${EI_EXPORT_DIR}/model-parameters"
    # All sub-trees inside edge-impulse-sdk/ that are referenced by short #include paths.
    "${EI_ROOT}"
    "${EI_ROOT}/classifier"
    "${EI_ROOT}/dsp"
    "${EI_ROOT}/dsp/kissfft"
    "${EI_ROOT}/porting"
    "${EI_ROOT}/third_party"
    "${EI_ROOT}/third_party/flatbuffers/include"
    "${EI_ROOT}/third_party/ruy"
    "${EI_MODEL}"
)

file(GLOB_RECURSE EI_SDK_SOURCES CONFIGURE_DEPENDS
    "${EI_ROOT}/dsp/kissfft/*.cpp"
    "${EI_ROOT}/dsp/dct/*.cpp"
    "${EI_ROOT}/classifier/*.cpp"
    "${EI_ROOT}/porting/android/*.cpp"
)

file(GLOB_RECURSE EI_TFLITE_SOURCES CONFIGURE_DEPENDS
    "${EI_ROOT}/tensorflow/*.cpp"
    "${EI_ROOT}/tensorflow/*.cc"
    "${EI_ROOT}/tensorflow/*.c"
)

file(GLOB_RECURSE EI_MODEL_SOURCES CONFIGURE_DEPENDS
    "${EI_MODEL}/*.cpp"
)

list(APPEND EI_SDK_SOURCES "${EI_ROOT}/porting/posix/debug_log.cpp")

add_library(wakeword_bridge SHARED
    WakeWordBridge.cpp
    ${EI_SDK_SOURCES}
    ${EI_TFLITE_SOURCES}
    ${EI_MODEL_SOURCES}
)

find_library(log-lib log)
target_link_libraries(wakeword_bridge ${log-lib})
