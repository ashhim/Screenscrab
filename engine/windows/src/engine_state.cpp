#include "engine_state.h"

#include <utility>

namespace screenscrab::native {

EngineState::EngineState() = default;

void EngineState::set_mode(ScreencrabEngineMode mode) { mode_ = mode; }
void EngineState::set_error(int code, std::string message) {
  last_error_ = code;
  last_error_message_ = std::move(message);
}
void EngineState::set_engine_loaded(bool value) { engine_loaded_ = value; }
void EngineState::set_session_active(bool value) { session_active_ = value; }
void EngineState::set_tailscale_reachable(bool value) { tailscale_reachable_ = value; }
void EngineState::set_capture_ready(bool value) { capture_ready_ = value; }
void EngineState::set_audio_ready(bool value) { audio_ready_ = value; }
void EngineState::set_monitor_index(std::uint32_t value) { monitor_index_ = value; }
void EngineState::set_tailscale_diagnostic(bool value) { tailscale_reachable_ = value; }

std::string EngineState::snapshot_json() const {
  return std::string("{\"apiVersion\":1,\"mode\":\"") +
         (mode_ == ScreencrabEngineMode::kHost ? "host" : mode_ == ScreencrabEngineMode::kClient ? "client" : "stopped") +
         "\",\"engineLoaded\":" + (engine_loaded_ ? "true" : "false") +
         ",\"sessionActive\":" + (session_active_ ? "true" : "false") +
         ",\"tailscaleReachable\":" + (tailscale_reachable_ ? "true" : "false") +
         ",\"captureReady\":" + (capture_ready_ ? "true" : "false") +
         ",\"audioReady\":" + (audio_ready_ ? "true" : "false") +
         ",\"monitorIndex\":" + std::to_string(monitor_index_) +
         ",\"lastError\":" + std::to_string(last_error_) + "}";
}

const std::string& EngineState::last_error_message() const noexcept { return last_error_message_; }

}  // namespace screenscrab::native
