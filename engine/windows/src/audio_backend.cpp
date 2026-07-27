#include "audio_backend.h"

namespace screenscrab::native {

bool AudioBackend::initialize() {
  return true;
}

bool AudioBackend::capture(std::vector<std::uint8_t>& pcm16le) {
  pcm16le.clear();
  return true;
}

void AudioBackend::shutdown() {}

}  // namespace screenscrab::native
