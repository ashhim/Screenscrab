#include "screenscrab/engine_api.h"

#include <memory>
#include <new>
#include <string>

#include "logging.h"
#include "network_bridge.h"
#include "session_manager.h"

namespace {
constexpr const char kVersion[] = "0.1.0";
constexpr std::uint32_t kApiVersion = 1;
constexpr std::uint32_t kProtocolVersion = 1;
constexpr const char kCapabilities[] =
    "{\"capture\":true,\"encode\":true,\"transport\":true,\"input\":true,"
    "\"clipboard\":true,\"fileTransfer\":true,\"audio\":true,\"multiMonitor\":true,"
    "\"lockedScreen\":true,\"hostMode\":true,\"clientMode\":true}";

const char* mode_name(screenscrab::native::SessionMode mode) {
  switch (mode) {
    case screenscrab::native::SessionMode::kHost:
      return "host";
    case screenscrab::native::SessionMode::kClient:
      return "client";
    case screenscrab::native::SessionMode::kStopped:
    default:
      return "stopped";
  }
}

const char* transport_name(screenscrab::native::SessionTransportState state) {
  switch (state) {
    case screenscrab::native::SessionTransportState::kListening:
      return "listening";
    case screenscrab::native::SessionTransportState::kConnecting:
      return "connecting";
    case screenscrab::native::SessionTransportState::kConnected:
      return "connected";
    case screenscrab::native::SessionTransportState::kRetrying:
      return "retrying";
    case screenscrab::native::SessionTransportState::kOffline:
    default:
      return "offline";
  }
}

std::string status_json(const screenscrab::native::SessionSnapshot& snapshot) {
  return std::string("{\"apiVersion\":1,\"protocolVersion\":1,\"mode\":\"") + mode_name(snapshot.mode) +
         "\",\"transportState\":\"" + transport_name(snapshot.transport_state) +
         "\",\"engineLoaded\":true,\"sessionActive\":" + (snapshot.session_active ? "true" : "false") +
         ",\"tailscaleReachable\":" + (snapshot.tailscale_reachable ? "true" : "false") +
         ",\"captureActive\":" + (snapshot.capture_active ? "true" : "false") +
         ",\"inputEnabled\":" + (snapshot.input_enabled ? "true" : "false") +
         ",\"clipboardEnabled\":" + (snapshot.clipboard_enabled ? "true" : "false") +
         ",\"audioEnabled\":" + (snapshot.audio_enabled ? "true" : "false") +
         ",\"monitorIndex\":" + std::to_string(snapshot.monitor_index) +
         ",\"port\":" + std::to_string(snapshot.port) + ",\"framesSent\":" + std::to_string(snapshot.frames_sent) +
         ",\"endpoint\":\"" + snapshot.endpoint + "\",\"encoder\":\"" + snapshot.encoder_name +
         "\",\"lastError\":" + std::to_string(snapshot.last_error) + ",\"lastErrorMessage\":\"" +
         snapshot.last_error_message + "\"}";
}
}

struct screenscrab::native::EngineHandle {
  SessionManager manager;
  NetworkBridge network;
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
    return new screenscrab::native::EngineHandle{};
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
  const int result = handle->manager.start_host(device_name);
  return result;
}

int screencrab_engine_start_client(void* engine, const char* address, std::uint16_t port) {
  if (engine == nullptr || address == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  const int result = handle->manager.start_client(address, port);
  return result;
}

int screencrab_engine_stop(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  const int result = handle->manager.stop();
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
    return "{\"apiVersion\":1,\"protocolVersion\":1,\"mode\":\"stopped\",\"transportState\":\"offline\",\"engineLoaded\":false,\"sessionActive\":false,\"tailscaleReachable\":false,\"captureActive\":false,\"inputEnabled\":false,\"clipboardEnabled\":false,\"audioEnabled\":false,\"monitorIndex\":0,\"port\":4545,\"framesSent\":0,\"endpoint\":\"\",\"encoder\":\"none\",\"lastError\":-1,\"lastErrorMessage\":\"engine handle is null\"}";
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  thread_local std::string status;
  status = status_json(handle->manager.snapshot());
  return status.c_str();
}

const char* screencrab_engine_last_error_message(void* engine) {
  if (engine == nullptr) {
    return "engine handle is null";
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  thread_local std::string message;
  message = handle->manager.snapshot().last_error_message;
  return message.c_str();
}

int screencrab_engine_begin_sign_in(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->network.begin_sign_in() ? 0 : -1;
}

int screencrab_engine_refresh_runtime(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->network.refresh_runtime() ? 0 : -1;
}

int screencrab_engine_connect_peer(void* engine, const char* peer_name, std::uint16_t port) {
  if (engine == nullptr || peer_name == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->network.connect_peer(peer_name, port);
}

const char* screencrab_engine_runtime_status_json(void* engine) {
  if (engine == nullptr) {
    return "{\"mode\":\"signed_out\",\"loginUrl\":\"\",\"identity\":{},\"peers\":[],\"lastError\":\"engine handle is null\"}";
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  thread_local std::string runtime_status;
  runtime_status = handle->network.status_json();
  return runtime_status.c_str();
}
