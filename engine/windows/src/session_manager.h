#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <span>
#include <string>
#include <thread>

#include "capture_backend.h"
#include "clipboard_service.h"
#include "encode_backend.h"
#include "input_injector.h"
#include "transport.h"

namespace screenscrab::native {

enum class SessionMode : std::uint8_t {
  kStopped = 0,
  kHost = 1,
  kClient = 2,
};

enum class SessionTransportState : std::uint8_t {
  kOffline = 0,
  kListening = 1,
  kConnecting = 2,
  kConnected = 3,
  kRetrying = 4,
};

struct SessionSnapshot {
  SessionMode mode{SessionMode::kStopped};
  SessionTransportState transport_state{SessionTransportState::kOffline};
  bool capture_active{false};
  bool session_active{false};
  bool tailscale_reachable{false};
  bool input_enabled{false};
  bool clipboard_enabled{false};
  bool audio_enabled{false};
  std::uint32_t monitor_index{0};
  std::uint16_t port{4545};
  std::uint64_t frames_sent{0};
  std::string endpoint;
  std::string encoder_name;
  std::string last_error_message;
  int last_error{0};
};

class SessionManager {
 public:
  SessionManager();
  ~SessionManager();

  SessionManager(const SessionManager&) = delete;
  SessionManager& operator=(const SessionManager&) = delete;

  int start_host(const std::string& device_name, std::uint16_t port = 4545);
  int start_client(const std::string& address, std::uint16_t port);
  int stop();
  int last_error() const noexcept;
  SessionSnapshot snapshot() const;
  void set_monitor_index(std::uint32_t monitor_index);
  void set_input_enabled(bool enabled);
  void set_clipboard_enabled(bool enabled);
  void set_audio_enabled(bool enabled);

 private:
  void run_host_loop(std::string device_name, std::uint16_t port);
  void run_client_loop(std::string address, std::uint16_t port);
  void apply_error(int error_code, const std::string& message);
  void send_host_hello();
  bool send_frame(const EncodedFrame& encoded);
  void process_incoming_packets();
  bool handle_packet(std::span<const std::uint8_t> packet);
  bool handle_input_packet(std::span<const std::uint8_t> payload);
  bool handle_clipboard_packet(std::span<const std::uint8_t> payload);
  bool handle_ping_packet(std::span<const std::uint8_t> payload);

  mutable std::mutex mutex_{};
  std::thread worker_{};
  std::atomic_bool running_{false};
  std::atomic_bool stop_requested_{false};
  std::atomic_uint64_t frames_sent_{0};
  std::string device_name_{};
  std::string endpoint_{};
  std::string last_error_message_{};
  SessionMode mode_{SessionMode::kStopped};
  SessionTransportState transport_state_{SessionTransportState::kOffline};
  bool capture_active_{false};
  bool session_active_{false};
  bool tailscale_reachable_{false};
  bool input_enabled_{true};
  bool clipboard_enabled_{true};
  bool audio_enabled_{true};
  std::uint32_t monitor_index_{0};
  std::uint16_t port_{4545};
  int last_error_{0};
  std::string encoder_name_{"none"};
  Transport transport_{};
  CaptureBackend capture_{};
  EncodeBackend encoder_{};
  InputInjector input_{};
  ClipboardService clipboard_{};
};

}  // namespace screenscrab::native
