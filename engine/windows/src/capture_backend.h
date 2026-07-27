#pragma once

#include <cstdint>
#include <vector>

namespace screenscrab::native {

struct CaptureFrame {
  std::uint32_t width{0};
  std::uint32_t height{0};
  std::uint32_t stride_bytes{0};
  std::vector<std::uint8_t> rgba;
};

class CaptureBackend {
 public:
  bool initialize(std::uint32_t monitor_index);
  bool capture(CaptureFrame& frame);
  void shutdown();

 private:
  std::uint32_t monitor_index_{0};
  bool initialized_{false};
};

}  // namespace screenscrab::native
