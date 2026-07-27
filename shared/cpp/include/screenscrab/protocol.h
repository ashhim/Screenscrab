#pragma once

#include <cstdint>
#include <string>
#include <string_view>

namespace screenscrab::protocol {

enum class MessageType : std::uint8_t {
  kHello = 0,
  kCapabilities = 1,
  kFrameMetadata = 2,
  kSessionStart = 3,
  kSessionStop = 4,
  kVideoFrame = 5,
  kAudioFrame = 6,
  kInputEvent = 7,
  kClipboardSync = 8,
  kFileOffer = 9,
  kFileChunk = 10,
  kDeviceList = 11,
  kPing = 12,
  kPong = 13,
  kDisconnect = 14,
  kError = 15,
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

struct HelloPayload {
  std::uint32_t api_version{1};
  std::uint32_t protocol_version{1};
  std::uint32_t capability_flags{0};
};

struct CapabilityPayload {
  std::uint32_t host_capabilities{0};
  std::uint32_t client_capabilities{0};
};

struct FrameMetadata {
  std::uint32_t monitor_index{0};
  std::uint32_t width{0};
  std::uint32_t height{0};
  std::uint32_t stride_bytes{0};
  std::uint64_t frame_id{0};
};

struct InputMousePayload {
  std::int32_t x{0};
  std::int32_t y{0};
  std::int32_t wheel_delta{0};
  std::uint32_t buttons{0};
  std::uint32_t flags{0};
};

struct InputKeyPayload {
  std::uint32_t virtual_key{0};
  std::uint32_t scan_code{0};
  std::uint32_t flags{0};
};

struct ClipboardPayload {
  std::uint32_t format{0};
  std::uint32_t bytes{0};
};

struct FileOfferPayload {
  std::uint64_t size_bytes{0};
  std::uint64_t offset_bytes{0};
  std::uint32_t name_bytes{0};
  std::uint32_t transfer_id{0};
};

struct AudioFramePayload {
  std::uint32_t sample_rate{48000};
  std::uint32_t channels{2};
  std::uint32_t bytes_per_sample{2};
  std::uint32_t frame_bytes{0};
};

struct PingPayload {
  std::uint64_t nonce{0};
};

inline constexpr std::string_view kProtocolName = "screenscrab/1";
inline constexpr std::uint32_t kWireMagic = 0x53435242;  // SCRB
inline constexpr std::uint16_t kWireVersion = 1;

struct WireHeader {
  std::uint32_t magic{kWireMagic};
  std::uint16_t version{kWireVersion};
  std::uint16_t type{0};
  std::uint32_t flags{0};
  std::uint32_t payload_size{0};
  std::uint64_t timestamp_utc_us{0};
};

}  // namespace screenscrab::protocol
