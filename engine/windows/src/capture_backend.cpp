#include "capture_backend.h"

namespace screenscrab::native {

bool CaptureBackend::initialize(std::uint32_t monitor_index) {
  monitor_index_ = monitor_index;
  initialized_ = true;
  return true;
}

bool CaptureBackend::capture(CaptureFrame& frame) {
  if (!initialized_) {
    return false;
  }
  frame.width = 1;
  frame.height = 1;
  frame.rgba.assign({0, 0, 0, 255});
  return true;
}

void CaptureBackend::shutdown() {
  initialized_ = false;
}

}  // namespace screenscrab::native
