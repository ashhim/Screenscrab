#pragma once

#include <cstdint>

#ifdef _WIN32
#define SCRSCRAB_NET_API extern "C" __declspec(dllexport)
#else
#define SCRSCRAB_NET_API extern "C"
#endif

namespace screenscrab::native {
struct TailnetHandle;
}

enum class ScreencrabNetworkState : std::uint32_t {
  kOffline = 0,
  kSignedOut = 1,
  kSigningIn = 2,
  kSignedIn = 3,
  kConnecting = 4,
  kConnected = 5,
  kError = 6,
};

SCRSCRAB_NET_API std::uint32_t screencrab_network_api_version();
SCRSCRAB_NET_API const char* screencrab_network_version();
SCRSCRAB_NET_API void* screencrab_network_create();
SCRSCRAB_NET_API void screencrab_network_destroy(void* network);
SCRSCRAB_NET_API int screencrab_network_start(void* network);
SCRSCRAB_NET_API int screencrab_network_stop(void* network);
SCRSCRAB_NET_API int screencrab_network_begin_sign_in(void* network);
SCRSCRAB_NET_API int screencrab_network_complete_sign_in(void* network, const char* code);
SCRSCRAB_NET_API const char* screencrab_network_status_json(void* network);
SCRSCRAB_NET_API const char* screencrab_network_last_error_message(void* network);

