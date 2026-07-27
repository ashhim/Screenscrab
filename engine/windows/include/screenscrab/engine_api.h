#pragma once

#include <cstdint>

#ifdef _WIN32
#define SCRSCRAB_API extern "C" __declspec(dllexport)
#else
#define SCRSCRAB_API extern "C"
#endif

namespace screenscrab::native {
struct EngineHandle;
}

enum class ScreencrabEngineMode : std::uint8_t {
  kStopped = 0,
  kHost = 1,
  kClient = 2,
};

SCRSCRAB_API const char* screencrab_engine_version();
SCRSCRAB_API std::uint32_t screencrab_engine_api_version();
SCRSCRAB_API std::uint32_t screencrab_engine_protocol_version();
SCRSCRAB_API const char* screencrab_engine_capabilities_json();
SCRSCRAB_API void* screencrab_engine_create();
SCRSCRAB_API void screencrab_engine_destroy(void* engine);
SCRSCRAB_API int screencrab_engine_start_host(void* engine, const char* device_name);
SCRSCRAB_API int screencrab_engine_start_client(void* engine, const char* address, std::uint16_t port);
SCRSCRAB_API int screencrab_engine_stop(void* engine);
SCRSCRAB_API int screencrab_engine_last_error(void* engine);
SCRSCRAB_API const char* screencrab_engine_status_json(void* engine);
SCRSCRAB_API const char* screencrab_engine_last_error_message(void* engine);
SCRSCRAB_API int screencrab_engine_begin_sign_in(void* engine);
SCRSCRAB_API int screencrab_engine_refresh_runtime(void* engine);
SCRSCRAB_API int screencrab_engine_connect_peer(void* engine, const char* peer_name, std::uint16_t port);
SCRSCRAB_API const char* screencrab_engine_runtime_status_json(void* engine);
