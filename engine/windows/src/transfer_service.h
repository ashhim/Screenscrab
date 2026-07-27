#pragma once

#include <cstdint>
#include <string>

namespace screenscrab::native {

class TransferService {
 public:
  bool begin_send(const std::string& path);
  bool begin_receive(const std::string& path, std::uint64_t size_bytes);
};

}  // namespace screenscrab::native
