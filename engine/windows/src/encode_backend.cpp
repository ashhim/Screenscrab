#include "encode_backend.h"

namespace screenscrab::native {

bool EncodeBackend::initialize() {
  return true;
}

bool EncodeBackend::encode(const CaptureFrame& frame, std::vector<std::uint8_t>& output) {
  output = frame.rgba;
  return true;
}

void EncodeBackend::shutdown() {}

}  // namespace screenscrab::native
