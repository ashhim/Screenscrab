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
  src/engine_state.cpp
  src/input_injector.cpp
  src/network_bridge.cpp
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
target_link_libraries(screencrab_engine PRIVATE ws2_32 d3d11 dxgi ole32 gdi32 user32 winmm avrt)

set_target_properties(screencrab_engine PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/out"
  RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_BINARY_DIR}/out"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_BINARY_DIR}/out"
  RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_CURRENT_BINARY_DIR}/out"
  RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_CURRENT_BINARY_DIR}/out"
)

set(SCRSCRAB_APP_RELEASE_DIR "" CACHE PATH "Optional Flutter Windows release output directory")
if(SCRSCRAB_APP_RELEASE_DIR)
  add_custom_command(TARGET screencrab_engine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SCRSCRAB_APP_RELEASE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "$<TARGET_FILE:screencrab_engine>"
      "${SCRSCRAB_APP_RELEASE_DIR}/screencrab_engine.dll"
    VERBATIM
  )
endif()
