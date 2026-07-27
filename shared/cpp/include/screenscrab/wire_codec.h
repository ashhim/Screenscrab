#pragma once

#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "protocol.h"

namespace screenscrab::protocol {

inline void append_u16(std::vector<std::uint8_t>& out, std::uint16_t value) {
  out.push_back(static_cast<std::uint8_t>(value & 0xFF));
  out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFF));
}

inline void append_u32(std::vector<std::uint8_t>& out, std::uint32_t value) {
  append_u16(out, static_cast<std::uint16_t>(value & 0xFFFF));
  append_u16(out, static_cast<std::uint16_t>((value >> 16) & 0xFFFF));
}

inline void append_u64(std::vector<std::uint8_t>& out, std::uint64_t value) {
  append_u32(out, static_cast<std::uint32_t>(value & 0xFFFFFFFFULL));
  append_u32(out, static_cast<std::uint32_t>((value >> 32) & 0xFFFFFFFFULL));
}

inline std::vector<std::uint8_t> make_packet(MessageType type, std::uint32_t flags, std::span<const std::uint8_t> payload,
                                             std::uint64_t timestamp_utc_us) {
  std::vector<std::uint8_t> out;
  out.reserve(24 + payload.size());
  append_u32(out, kWireMagic);
  append_u16(out, kWireVersion);
  append_u16(out, static_cast<std::uint16_t>(type));
  append_u32(out, flags);
  append_u32(out, static_cast<std::uint32_t>(payload.size()));
  append_u64(out, timestamp_utc_us);
  out.insert(out.end(), payload.begin(), payload.end());
  return out;
}

inline std::vector<std::uint8_t> make_packet(MessageType type, std::span<const std::uint8_t> payload,
                                             std::uint64_t timestamp_utc_us) {
  return make_packet(type, 0, payload, timestamp_utc_us);
}

inline void append_bytes(std::vector<std::uint8_t>& out, std::string_view text) {
  out.insert(out.end(), text.begin(), text.end());
}

inline std::vector<std::uint8_t> make_hello(std::uint32_t api_version, std::uint32_t protocol_version,
                                            std::uint32_t capability_flags) {
  std::vector<std::uint8_t> payload;
  payload.reserve(12);
  append_u32(payload, api_version);
  append_u32(payload, protocol_version);
  append_u32(payload, capability_flags);
  return payload;
}

inline std::vector<std::uint8_t> make_capabilities(std::uint32_t host_capabilities,
                                                   std::uint32_t client_capabilities) {
  std::vector<std::uint8_t> payload;
  payload.reserve(8);
  append_u32(payload, host_capabilities);
  append_u32(payload, client_capabilities);
  return payload;
}

inline std::vector<std::uint8_t> make_frame_metadata(std::uint32_t monitor_index, std::uint32_t width,
                                                     std::uint32_t height, std::uint32_t stride_bytes,
                                                     std::uint64_t frame_id) {
  std::vector<std::uint8_t> payload;
  payload.reserve(24);
  append_u32(payload, monitor_index);
  append_u32(payload, width);
  append_u32(payload, height);
  append_u32(payload, stride_bytes);
  append_u64(payload, frame_id);
  return payload;
}

struct WirePacketView {
  MessageType type{MessageType::kError};
  std::uint32_t flags{0};
  std::uint64_t timestamp_utc_us{0};
  std::span<const std::uint8_t> payload{};
};

inline std::uint16_t read_u16(std::span<const std::uint8_t> bytes, std::size_t offset) {
  return static_cast<std::uint16_t>(bytes[offset]) |
         static_cast<std::uint16_t>(static_cast<std::uint16_t>(bytes[offset + 1]) << 8);
}

inline std::uint32_t read_u32(std::span<const std::uint8_t> bytes, std::size_t offset) {
  return static_cast<std::uint32_t>(bytes[offset]) |
         (static_cast<std::uint32_t>(bytes[offset + 1]) << 8) |
         (static_cast<std::uint32_t>(bytes[offset + 2]) << 16) |
         (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
}

inline std::uint64_t read_u64(std::span<const std::uint8_t> bytes, std::size_t offset) {
  const std::uint64_t lo = read_u32(bytes, offset);
  const std::uint64_t hi = read_u32(bytes, offset + 4);
  return lo | (hi << 32);
}

inline bool parse_packet(std::span<const std::uint8_t> bytes, WirePacketView& out) {
  if (bytes.size() < 24) {
    return false;
  }
  if (read_u32(bytes, 0) != kWireMagic || read_u16(bytes, 4) != kWireVersion) {
    return false;
  }
  const std::uint16_t type_value = read_u16(bytes, 6);
  if (type_value > static_cast<std::uint16_t>(MessageType::kError)) {
    return false;
  }
  const std::uint32_t payload_size = read_u32(bytes, 12);
  if (bytes.size() < 24 + payload_size) {
    return false;
  }
  out.type = static_cast<MessageType>(type_value);
  out.flags = read_u32(bytes, 8);
  out.timestamp_utc_us = read_u64(bytes, 16);
  out.payload = bytes.subspan(24, payload_size);
  return true;
}

inline std::vector<std::uint8_t> make_pong(std::uint64_t nonce) {
  std::vector<std::uint8_t> payload;
  payload.reserve(8);
  append_u64(payload, nonce);
  return payload;
}

inline std::vector<std::uint8_t> make_input_mouse(std::int32_t x, std::int32_t y, std::int32_t wheel_delta,
                                                  std::uint32_t buttons, std::uint32_t flags) {
  std::vector<std::uint8_t> payload;
  payload.reserve(24);
  append_u32(payload, 0);
  append_u32(payload, static_cast<std::uint32_t>(x));
  append_u32(payload, static_cast<std::uint32_t>(y));
  append_u32(payload, static_cast<std::uint32_t>(wheel_delta));
  append_u32(payload, buttons);
  append_u32(payload, flags);
  return payload;
}

inline std::vector<std::uint8_t> make_input_key(std::uint32_t virtual_key, std::uint32_t scan_code,
                                                std::uint32_t flags) {
  std::vector<std::uint8_t> payload;
  payload.reserve(16);
  append_u32(payload, 1);
  append_u32(payload, virtual_key);
  append_u32(payload, scan_code);
  append_u32(payload, flags);
  return payload;
}

inline std::vector<std::uint8_t> make_ping(std::uint64_t nonce) {
  std::vector<std::uint8_t> payload;
  payload.reserve(8);
  append_u64(payload, nonce);
  return payload;
}

inline std::vector<std::uint8_t> make_clipboard(std::string_view text) {
  std::vector<std::uint8_t> payload;
  payload.reserve(4 + text.size());
  append_u32(payload, 1);
  append_bytes(payload, text);
  return payload;
}

inline std::vector<std::uint8_t> make_disconnect(std::uint32_t reason_code, std::string_view reason) {
  std::vector<std::uint8_t> payload;
  payload.reserve(8 + reason.size());
  append_u32(payload, reason_code);
  append_u32(payload, static_cast<std::uint32_t>(reason.size()));
  append_bytes(payload, reason);
  return payload;
}

}  // namespace screenscrab::protocol
