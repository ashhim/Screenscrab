#pragma once

#include <cstdint>
#include <string>

#include "../include/screenscrab/engine_api.h"

namespace screenscrab::native {

class EngineState {
 public:
  EngineState();

  void set_mode(ScreencrabEngineMode mode);
  void set_error(int code, std::string message);
  void set_engine_loaded(bool value);
  void set_session_active(bool value);
  void set_tailscale_reachable(bool value);
  void set_capture_ready(bool value);
  void set_audio_ready(bool value);
  void set_monitor_index(std::uint32_t value);
  void set_tailscale_diagnostic(bool value);

  std::string snapshot_json() const;
  const std::string& last_error_message() const noexcept;

 private:
  ScreencrabEngineMode mode_{ScreencrabEngineMode::kStopped};
  bool engine_loaded_{false};
  bool session_active_{false};
  bool tailscale_reachable_{false};
  bool capture_ready_{false};
  bool audio_ready_{false};
  std::uint32_t monitor_index_{0};
  std::int32_t last_error_{0};
  std::string last_error_message_{};
};

}  // namespace screenscrab::native
