#include "session_manager.h"

#include <utility>

namespace screenscrab::native {

SessionManager::SessionManager() = default;
SessionManager::~SessionManager() = default;

int SessionManager::start_host(const std::string&) {
  mode_ = SessionMode::kHost;
  last_error_ = 0;
  return 0;
}

int SessionManager::start_client(const std::string& address, std::uint16_t port) {
  mode_ = SessionMode::kClient;
  if (!transport_.connect(address, port)) {
    last_error_ = transport_.last_error();
    return last_error_;
  }
  last_error_ = 0;
  return 0;
}

int SessionManager::stop() {
  transport_.disconnect();
  last_error_ = 0;
  return 0;
}

int SessionManager::last_error() const noexcept {
  return last_error_;
}

}  // namespace screenscrab::native
