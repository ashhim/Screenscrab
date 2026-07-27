#pragma once

#include <cstdint>
#include <string>

namespace screenscrab::native {

class Transport {
 public:
  Transport() = default;
  ~Transport() = default;

  Transport(const Transport&) = delete;
  Transport& operator=(const Transport&) = delete;

  bool connect(const std::string& address, std::uint16_t port);
  void disconnect();
  bool connected() const noexcept;
  int last_error() const noexcept;

 private:
  bool connected_{false};
  int last_error_{0};
};

}  // namespace screenscrab::native
