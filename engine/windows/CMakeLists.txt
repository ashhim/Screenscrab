cmake_minimum_required(VERSION 3.28)

project(screencrab_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(screencrab_engine SHARED
  src/audio_backend.cpp
  src/capture_backend.cpp
  src/clipboard_service.cpp
  src/encode_backend.cpp
  src/api.cpp
  src/logging.cpp
  src/input_injector.cpp
  src/session_manager.cpp
  src/transfer_service.cpp
  src/transport.cpp
)

target_include_directories(screencrab_engine
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../../shared/cpp/include
)

target_compile_definitions(screencrab_engine PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(screencrab_engine PRIVATE ws2_32)
