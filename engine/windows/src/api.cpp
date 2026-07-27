#include "screenscrab/engine_api.h"

#include <memory>
#include <new>
#include <string>

#include "logging.h"
#include "session_manager.h"

namespace {
constexpr const char kVersion[] = "0.1.0";
}

struct screenscrab::native::EngineHandle {
  SessionManager manager;
  int last_error{0};
};

const char* screencrab_engine_version() {
  return kVersion;
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
  handle->last_error = handle->manager.start_host(device_name);
  return handle->last_error;
}

int screencrab_engine_start_client(void* engine, const char* address, std::uint16_t port) {
  if (engine == nullptr || address == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  handle->last_error = handle->manager.start_client(address, port);
  return handle->last_error;
}

int screencrab_engine_stop(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  handle->last_error = handle->manager.stop();
  return handle->last_error;
}

int screencrab_engine_last_error(void* engine) {
  if (engine == nullptr) {
    return -1;
  }
  auto* handle = static_cast<screenscrab::native::EngineHandle*>(engine);
  return handle->manager.last_error();
}
