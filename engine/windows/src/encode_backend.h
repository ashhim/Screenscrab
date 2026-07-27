#pragma once

#include <cstdint>
#include <vector>

#include "capture_backend.h"

namespace screenscrab::native {

class EncodeBackend {
 public:
  bool initialize();
  bool encode(const CaptureFrame& frame, std::vector<std::uint8_t>& output);
  void shutdown();
};

}  // namespace screenscrab::native
