#pragma once

#include <cstdint>
#include <string>
#include <string_view>

namespace screenscrab::protocol {

enum class MessageType : std::uint8_t {
  kHello = 0,
  kSessionStart = 1,
  kSessionStop = 2,
  kVideoFrame = 3,
  kAudioFrame = 4,
  kInputEvent = 5,
  kClipboardSync = 6,
  kFileOffer = 7,
  kFileChunk = 8,
  kDeviceList = 9,
  kPing = 10,
  kPong = 11,
  kError = 12,
};

struct SessionEndpoint {
  std::string device_id;
  std::string name;
  std::string address;
};

struct MessageHeader {
  MessageType type;
  std::uint32_t payload_size;
  std::uint64_t timestamp_utc_ms;
};

inline constexpr std::string_view kProtocolName = "screenscrab/1";

}  // namespace screenscrab::protocol
