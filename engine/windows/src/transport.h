#pragma once

#include <cstdint>
#include <span>
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
  bool listen(std::uint16_t port);
  bool accept();
  void disconnect();
  bool connected() const noexcept;
  int last_error() const noexcept;
  bool send_all(std::span<const std::uint8_t> bytes);
  bool receive_all(std::span<std::uint8_t> bytes);
  bool poll_readable(int timeout_ms);

 private:
  bool initialize_winsock();
  SOCKET socket_{INVALID_SOCKET};
  SOCKET listen_socket_{INVALID_SOCKET};
  int last_error_{0};
};

}  // namespace screenscrab::native
