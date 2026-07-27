#include "session_manager.h"

#include <utility>

namespace screenscrab::native {

SessionManager::SessionManager() = default;
SessionManager::~SessionManager() = default;

int SessionManager::start_host(const std::string&) {
  mode_ = SessionMode::kHost;
  endpoint_.clear();
  active_ = true;
  last_error_ = 0;
  return 0;
}

int SessionManager::start_client(const std::string& address, std::uint16_t port) {
  mode_ = SessionMode::kClient;
  endpoint_ = address + ":" + std::to_string(port);
  if (!transport_.connect(address, port)) {
    last_error_ = transport_.last_error();
    return last_error_;
  }
  active_ = true;
  last_error_ = 0;
  return 0;
}

int SessionManager::stop() {
  transport_.disconnect();
  active_ = false;
  last_error_ = 0;
  return 0;
}

int SessionManager::last_error() const noexcept {
  return last_error_;
}

bool SessionManager::active() const noexcept {
  return active_;
}

SessionMode SessionManager::mode() const noexcept {
  return mode_;
}

const std::string& SessionManager::endpoint() const noexcept {
  return endpoint_;
}

}  // namespace screenscrab::native
