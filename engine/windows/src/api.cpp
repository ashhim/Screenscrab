#include "screenscrab/engine_api.h"

#include <memory>
#include <new>
#include <string>

#include "logging.h"
#include "engine_state.h"
#include "session_manager.h"

namespace {
constexpr const char kVersion[] = "0.1.0";
constexpr std::uint32_t kApiVersion = 1;
constexpr std::uint32_t kProtocolVersion = 1;
constexpr const char kCapabilities[] =
    "{\"capture\":true,\"encode\":true,\"transport\":true,\"input\":true,"
    "\"clipboard\":true,\"fileTransfer\":true,\"audio\":true,\"multiMonitor\":true,"
    "\"lockedScreen\":true,\"hostMode\":true,\"clientMode\":true}";
}

struct screenscrab::native::EngineHandle {
  EngineState state;
  SessionManager manager;
};

const char* screencrab_engine_version() {
  return kVersion;
}

std::uint32_t screencrab_engine_api_version() {
  return kApiVersion;
}

std::uint32_t screencrab_engine_protocol_version() {
  return kProtocolVersion;
}

const char* screencrab_engine_capabilities_json() {
  return kCapabilities;
}

void* screencrab_engine_create() {
  try {
    auto* handle = new screenscrab::native::EngineHandle{};
    handle->state.set_engine_loaded(true);
    handle->state.set_error(0, "initialized");
    return handle;
  } catch (...) {
    return nullptr;
  }
}

void screencrab_engine_destroy(void* engine) {
  delete static_cast<screenscrab::native::EngineHandle*>(engine);
}

int screencrab_engine_start_host(void* engine, const char* device_name) {
  if (engine == nullptr || device_name == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  handle->state.set_mode(ScreencrabEngineMode::kHost);
  handle->state.set_tailscale_reachable(false);
  const int result = handle->manager.start_host(device_name);
  handle->state.set_session_active(result == 0);
  handle->state.set_error(result, result == 0 ? "ok" : "failed to start host session");
  handle->state.set_capture_ready(result == 0);
  handle->state.set_audio_ready(result == 0);
  return result;
}

int screencrab_engine_start_client(void* engine, const char* address, std::uint16_t port) {
  if (engine == nullptr || address == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  handle->state.set_mode(ScreencrabEngineMode::kClient);
  const int result = handle->manager.start_client(address, port);
  handle->state.set_session_active(result == 0);
  handle->state.set_tailscale_reachable(result == 0);
  handle->state.set_error(result, result == 0 ? "ok" : "failed to start client session");
  handle->state.set_capture_ready(result == 0);
  handle->state.set_audio_ready(result == 0);
  return result;
}

int screencrab_engine_stop(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  const int result = handle->manager.stop();
  handle->state.set_mode(ScreencrabEngineMode::kStopped);
  handle->state.set_session_active(false);
  handle->state.set_error(result, result == 0 ? "stopped" : "failed to stop session");
  return result;
}

int screencrab_engine_last_error(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->manager.last_error();
}

const char* screencrab_engine_status_json(void* engine) {
  if (engine == nullptr) {
    return "{\"apiVersion\":1,\"mode\":\"stopped\",\"engineLoaded\":false,\"sessionActive\":false,\"tailscaleReachable\":false,\"captureReady\":false,\"audioReady\":false,\"monitorIndex\":0,\"lastError\":-1}";
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  thread_local std::string status;
  status = handle->state.snapshot_json();
  return status.c_str();
}

const char* screencrab_engine_last_error_message(void* engine) {
  if (engine == nullptr) {
    return "engine handle is null";
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->state.last_error_message().c_str();
}
