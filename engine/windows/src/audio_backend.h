#pragma once

#include <cstdint>
#include <vector>

namespace screenscrab::native {

class AudioBackend {
 public:
  bool initialize();
  bool capture(std::vector<std::uint8_t>& pcm16le);
  void shutdown();
};

}  // namespace screenscrab::native
