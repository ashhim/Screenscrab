#pragma once

#include <cstdint>
#include <string>
#include <winsock2.h>

namespace screenscrab::native {

class Transport {
 public:
  Transport() = default;
  ~Transport();

  Transport(const Transport&) = delete;
  Transport& operator=(const Transport&) = delete;

  bool connect(const std::string& address, std::uint16_t port);
  void disconnect();
  bool connected() const noexcept;
  int last_error() const noexcept;

 private:
  SOCKET socket_{INVALID_SOCKET};
  int last_error_{0};
};

}  // namespace screenscrab::native
