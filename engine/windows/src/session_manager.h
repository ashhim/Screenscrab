#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "transport.h"

namespace screenscrab::native {

enum class SessionMode : std::uint8_t {
  kHost = 0,
  kClient = 1,
};

class SessionManager {
 public:
  SessionManager();
  ~SessionManager();

  SessionManager(const SessionManager&) = delete;
  SessionManager& operator=(const SessionManager&) = delete;

  int start_host(const std::string& device_name);
  int start_client(const std::string& address, std::uint16_t port);
  int stop();
  int last_error() const noexcept;
  bool active() const noexcept;
  SessionMode mode() const noexcept;
  const std::string& endpoint() const noexcept;

 private:
  SessionMode mode_{SessionMode::kHost};
  Transport transport_{};
  std::string endpoint_{};
  bool active_{false};
  int last_error_{0};
};

}  // namespace screenscrab::native
