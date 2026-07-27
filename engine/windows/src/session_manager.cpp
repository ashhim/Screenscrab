#include "session_manager.h"

#include <array>
#include <chrono>
#include <cstring>
#include <string_view>
#include <thread>
#include <vector>

#include "screenscrab/wire_codec.h"

namespace screenscrab::native {

using namespace screenscrab::protocol;

namespace {
using namespace std::chrono_literals;

std::uint32_t capability_mask() {
  return (1u << 0) | (1u << 1) | (1u << 2) | (1u << 3) | (1u << 4) | (1u << 5) | (1u << 6);
}

std::uint64_t now_micros() {
  return static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::system_clock::now().time_since_epoch())
          .count());
}
}  // namespace

SessionManager::SessionManager() = default;

SessionManager::~SessionManager() {
  stop();
}

int SessionManager::start_host(const std::string& device_name, std::uint16_t port) {
  stop();
  std::scoped_lock lock(mutex_);
  device_name_ = device_name;
  port_ = port;
  mode_ = SessionMode::kHost;
  endpoint_.clear();
  session_active_ = false;
  transport_state_ = SessionTransportState::kListening;
  capture_active_ = false;
  last_error_ = 0;
  last_error_message_ = "starting host";
  stop_requested_ = false;
  if (!encoder_.initialize()) {
    apply_error(-1, "encoder initialization failed");
    return last_error_;
  }
  encoder_name_ = encoder_.active_encoder_name();
  worker_ = std::thread([this, device_name, port]() { run_host_loop(device_name, port); });
  return 0;
}

int SessionManager::start_client(const std::string& address, std::uint16_t port) {
  stop();
  std::scoped_lock lock(mutex_);
  mode_ = SessionMode::kClient;
  endpoint_ = address + ":" + std::to_string(port);
  port_ = port;
  transport_state_ = SessionTransportState::kConnecting;
  session_active_ = false;
  capture_active_ = false;
  stop_requested_ = false;
  last_error_ = 0;
  last_error_message_ = "connecting client";
  worker_ = std::thread([this, address, port]() { run_client_loop(address, port); });
  return 0;
}

int SessionManager::stop() {
  stop_requested_ = true;
  transport_.disconnect();
  if (worker_.joinable()) {
    worker_.join();
  }
  capture_.shutdown();
  encoder_.shutdown();
  std::scoped_lock lock(mutex_);
  mode_ = SessionMode::kStopped;
  transport_state_ = SessionTransportState::kOffline;
  session_active_ = false;
  capture_active_ = false;
  encoder_name_ = "none";
  return 0;
}

int SessionManager::last_error() const noexcept {
  return last_error_;
}

SessionSnapshot SessionManager::snapshot() const {
  std::scoped_lock lock(mutex_);
  SessionSnapshot snapshot{};
  snapshot.mode = mode_;
  snapshot.transport_state = transport_state_;
  snapshot.capture_active = capture_active_;
  snapshot.session_active = session_active_;
  snapshot.tailscale_reachable = tailscale_reachable_;
  snapshot.input_enabled = input_enabled_;
  snapshot.clipboard_enabled = clipboard_enabled_;
  snapshot.audio_enabled = audio_enabled_;
  snapshot.monitor_index = monitor_index_;
  snapshot.port = port_;
  snapshot.frames_sent = frames_sent_.load();
  snapshot.endpoint = endpoint_;
  snapshot.encoder_name = encoder_name_;
  snapshot.last_error_message = last_error_message_;
  snapshot.last_error = last_error_;
  return snapshot;
}

void SessionManager::set_monitor_index(std::uint32_t monitor_index) {
  std::scoped_lock lock(mutex_);
  monitor_index_ = monitor_index;
}

void SessionManager::set_input_enabled(bool enabled) {
  std::scoped_lock lock(mutex_);
  input_enabled_ = enabled;
}

void SessionManager::set_clipboard_enabled(bool enabled) {
  std::scoped_lock lock(mutex_);
  clipboard_enabled_ = enabled;
}

void SessionManager::set_audio_enabled(bool enabled) {
  std::scoped_lock lock(mutex_);
  audio_enabled_ = enabled;
}

void SessionManager::run_host_loop([[maybe_unused]] std::string device_name, std::uint16_t port) {
  if (!transport_.listen(port)) {
    apply_error(transport_.last_error(), "host listen failed");
    return;
  }

  if (!input_.initialize()) {
    apply_error(-5, "input initialization failed");
    return;
  }

  if (!capture_.initialize(monitor_index_)) {
    apply_error(-2, "capture initialization failed");
    return;
  }
  {
    std::scoped_lock lock(mutex_);
    capture_active_ = true;
    session_active_ = false;
    transport_state_ = SessionTransportState::kListening;
  }

  while (!stop_requested_) {
    if (!transport_.accept()) {
      if (stop_requested_) {
        break;
      }
      apply_error(transport_.last_error(), "accept failed");
      std::this_thread::sleep_for(250ms);
      continue;
    }

    {
      std::scoped_lock lock(mutex_);
      transport_state_ = SessionTransportState::kConnected;
      session_active_ = true;
      tailscale_reachable_ = true;
      endpoint_ = "peer";
      last_error_message_ = "client connected";
    }

    send_host_hello();

    std::uint64_t last_ping = now_micros();

    while (!stop_requested_ && transport_.connected()) {
      CaptureFrame frame{};
      if (!capture_.capture(frame)) {
        apply_error(-3, "capture failed");
        std::this_thread::sleep_for(16ms);
        continue;
      }

      EncodedFrame encoded{};
      if (!encoder_.encode(frame, encoded)) {
        apply_error(-4, "encode failed");
        std::this_thread::sleep_for(16ms);
        continue;
      }

      if (!send_frame(encoded)) {
        apply_error(transport_.last_error(), "frame send failed");
        transport_.disconnect();
        break;
      }

      frames_sent_.fetch_add(1);
      process_incoming_packets();

      const std::uint64_t now = now_micros();
      if (now - last_ping > 1000000ULL) {
        const auto ping = make_packet(protocol::MessageType::kPing, make_ping(now), now);
        transport_.send_all(ping);
        last_ping = now;
      }
      std::this_thread::sleep_for(16ms);
    }

    transport_.disconnect();
    {
      std::scoped_lock lock(mutex_);
      session_active_ = false;
      transport_state_ = SessionTransportState::kListening;
      endpoint_.clear();
    }
  }
}

void SessionManager::run_client_loop(std::string address, std::uint16_t port) {
  if (!transport_.connect(address, port)) {
    apply_error(transport_.last_error(), "client connect failed");
    return;
  }
  {
    std::scoped_lock lock(mutex_);
    session_active_ = true;
    transport_state_ = SessionTransportState::kConnected;
    tailscale_reachable_ = true;
    last_error_message_ = "client connected";
  }

  while (!stop_requested_ && transport_.connected()) {
    std::this_thread::sleep_for(250ms);
  }
  transport_.disconnect();
  std::scoped_lock lock(mutex_);
  session_active_ = false;
  transport_state_ = SessionTransportState::kOffline;
}

void SessionManager::process_incoming_packets() {
  while (!stop_requested_ && transport_.connected() && transport_.poll_readable(0)) {
    std::array<std::uint8_t, 24> header{};
    if (!transport_.receive_all(header)) {
      apply_error(transport_.last_error(), "packet header receive failed");
      transport_.disconnect();
      return;
    }

    if (protocol::read_u32(header, 0) != protocol::kWireMagic || protocol::read_u16(header, 4) != protocol::kWireVersion) {
      apply_error(-6, "wire header mismatch");
      transport_.disconnect();
      return;
    }

    const std::uint32_t payload_size = protocol::read_u32(header, 12);
    if (payload_size > 1024u * 1024u) {
      apply_error(-7, "packet payload too large");
      transport_.disconnect();
      return;
    }

    std::vector<std::uint8_t> packet_bytes(24 + payload_size);
    std::memcpy(packet_bytes.data(), header.data(), header.size());
    if (payload_size > 0) {
      if (!transport_.receive_all(std::span<std::uint8_t>(packet_bytes).subspan(24, payload_size))) {
        apply_error(transport_.last_error(), "packet payload receive failed");
        transport_.disconnect();
        return;
      }
    }

    if (!handle_packet(packet_bytes)) {
      transport_.disconnect();
      return;
    }
  }
}

bool SessionManager::handle_packet(std::span<const std::uint8_t> packet) {
  protocol::WirePacketView view{};
  if (!protocol::parse_packet(packet, view)) {
    apply_error(-8, "invalid packet");
    return false;
  }

  switch (view.type) {
    case MessageType::kHello:
    case MessageType::kCapabilities:
    case MessageType::kSessionStart:
    case MessageType::kSessionStop:
    case MessageType::kDeviceList:
      return true;
    case MessageType::kInputEvent:
      return handle_input_packet(view.payload);
    case MessageType::kClipboardSync:
      return handle_clipboard_packet(view.payload);
    case MessageType::kPing:
      return handle_ping_packet(view.payload);
    case MessageType::kDisconnect:
      transport_.disconnect();
      return false;
    case MessageType::kPong:
    case MessageType::kError:
    default:
      return true;
  }
}

bool SessionManager::handle_input_packet(std::span<const std::uint8_t> payload) {
  if (!input_enabled_) {
    return true;
  }
  if (payload.size() < 4) {
    return false;
  }

  const std::uint32_t kind = protocol::read_u32(payload, 0);
  if (kind == 0) {
    if (payload.size() < 24) {
      return false;
    }
    const std::int32_t x = static_cast<std::int32_t>(protocol::read_u32(payload, 4));
    const std::int32_t y = static_cast<std::int32_t>(protocol::read_u32(payload, 8));
    const std::int32_t wheel_delta = static_cast<std::int32_t>(protocol::read_u32(payload, 12));
    const std::uint32_t buttons = protocol::read_u32(payload, 16);
    const std::uint32_t flags = protocol::read_u32(payload, 20);
    if ((flags & 0x4u) != 0u || wheel_delta != 0) {
      return input_.scroll(wheel_delta);
    }
    if ((flags & 0x2u) != 0u) {
      const bool down = (flags & 0x1u) != 0u;
      return input_.mouse_button(down, buttons);
    }
    return input_.move_mouse(x, y);
  }
  if (kind == 1) {
    if (payload.size() < 16) {
      return false;
    }
    const std::uint32_t virtual_key = protocol::read_u32(payload, 4);
    const std::uint32_t flags = protocol::read_u32(payload, 12);
    const bool down = (flags & 0x1u) != 0u;
    return input_.key(down, static_cast<std::uint16_t>(virtual_key));
  }

  return false;
}

bool SessionManager::handle_clipboard_packet(std::span<const std::uint8_t> payload) {
  if (!clipboard_enabled_ || payload.size() < 4) {
    return true;
  }

  const std::uint32_t format = protocol::read_u32(payload, 0);
  if (format != 1u) {
    return true;
  }

  std::string text(reinterpret_cast<const char*>(payload.data() + 4), payload.size() - 4);
  return clipboard_.set_text(text);
}

bool SessionManager::handle_ping_packet(std::span<const std::uint8_t> payload) {
  if (payload.size() < 8) {
    return false;
  }
  const std::uint64_t nonce = protocol::read_u64(payload, 0);
  const auto pong = make_packet(protocol::MessageType::kPong, make_pong(nonce), now_micros());
  return transport_.send_all(pong);
}

void SessionManager::apply_error(int error_code, const std::string& message) {
  std::scoped_lock lock(mutex_);
  last_error_ = error_code;
  last_error_message_ = message;
}

void SessionManager::send_host_hello() {
  const auto hello_payload = make_hello(1, 1, capability_mask());
  const auto hello_packet = make_packet(protocol::MessageType::kHello, hello_payload, now_micros());
  transport_.send_all(hello_packet);

  const auto capabilities_payload = make_capabilities(capability_mask(), capability_mask());
  const auto capabilities_packet =
      make_packet(protocol::MessageType::kCapabilities, capabilities_payload, now_micros());
  transport_.send_all(capabilities_packet);

  const auto session_start = make_packet(protocol::MessageType::kSessionStart, std::span<const std::uint8_t>(),
                                         now_micros());
  transport_.send_all(session_start);
}

bool SessionManager::send_frame(const EncodedFrame& encoded) {
  const auto metadata_payload = make_frame_metadata(encoded.monitor_index, encoded.width, encoded.height,
                                                    encoded.stride_bytes, encoded.timestamp_utc_us);
  const auto metadata_packet =
      make_packet(protocol::MessageType::kFrameMetadata, metadata_payload, encoded.timestamp_utc_us);
  const auto frame_packet =
      make_packet(protocol::MessageType::kVideoFrame, std::span<const std::uint8_t>(encoded.payload.data(),
                                                                                     encoded.payload.size()),
                  encoded.timestamp_utc_us);
  return transport_.send_all(metadata_packet) && transport_.send_all(frame_packet);
}

}  // namespace screenscrab::native
