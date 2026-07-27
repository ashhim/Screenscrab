#pragma once

#include <cstdint>
#include <string>

namespace screenscrab {

enum class ConnectionState : std::uint8_t {
  kDisconnected = 0,
  kConnecting = 1,
  kConnected = 2,
  kReconnecting = 3,
  kError = 4,
};

struct SessionStatus {
  ConnectionState connection_state{ConnectionState::kDisconnected};
  std::string remote_name;
  std::uint32_t latency_ms{0};
  std::uint32_t monitor_index{0};
  bool audio_enabled{false};
  bool clipboard_enabled{false};
};

}  // namespace screenscrab
