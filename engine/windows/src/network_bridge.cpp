#include "network_bridge.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <filesystem>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include <windows.h>

namespace screenscrab::native {
namespace {
using StatusPtr = std::unique_ptr<char, decltype(&::free)>;

std::string trim_copy(std::string value) {
  const auto is_space = [](unsigned char ch) { return std::isspace(ch) != 0; };
  const auto begin = std::find_if_not(value.begin(), value.end(), is_space);
  if (begin == value.end()) {
    return {};
  }
  const auto end = std::find_if_not(value.rbegin(), value.rend(), is_space).base();
  return std::string(begin, end);
}

std::string read_string(const std::string& text) {
  return trim_copy(text);
}

std::string load_runtime_path() {
  static const std::vector<std::string> candidates = {
      "screenscrab_network.dll",
      "./screenscrab_network.dll",
      "./network/.tmp-cgo/screenscrab_network.dll",
      "./engine/windows/out/screenscrab_network.dll",
  };
  for (const auto& candidate : candidates) {
    if (std::filesystem::exists(candidate)) {
      return candidate;
    }
  }
  return {};
}

using NetworkStartFn = int (*)();
using NetworkStopFn = int (*)();
using NetworkLoginFn = int (*)();
using NetworkRefreshFn = int (*)();
using NetworkGetStatusFn = char* (*)();
using NetworkGetIdentityFn = char* (*)();
using NetworkGetPeersFn = char* (*)();
using NetworkGetLastErrorFn = char* (*)();
using NetworkFreeBufferFn = void (*)(void*);

bool load_runtime_library(HMODULE& module, std::string& error) {
  const std::string path = load_runtime_path();
  if (path.empty()) {
    error = "embedded networking DLL not found";
    return false;
  }
  module = LoadLibraryA(path.c_str());
  if (module == nullptr) {
    error = "failed to load " + path;
    return false;
  }
  return true;
}

std::string extract_json_string(const std::string& json, const std::string& key) {
  const std::string needle = "\"" + key + "\":";
  const auto start = json.find(needle);
  if (start == std::string::npos) {
    return {};
  }
  const auto value_start = json.find('"', start + needle.size());
  if (value_start == std::string::npos) {
    return {};
  }
  const auto value_end = json.find('"', value_start + 1);
  if (value_end == std::string::npos) {
    return {};
  }
  return json.substr(value_start + 1, value_end - value_start - 1);
}

std::string extract_json_bool(const std::string& json, const std::string& key) {
  const std::string needle = "\"" + key + "\":";
  const auto start = json.find(needle);
  if (start == std::string::npos) {
    return {};
  }
  const auto begin = start + needle.size();
  const auto end = json.find_first_of(",}]", begin);
  if (end == std::string::npos) {
    return {};
  }
  return json.substr(begin, end - begin);
}

bool parse_status_json(const std::string& status_json, NativeStatus& out) {
  out.json = status_json;
  out.state = read_string(extract_json_string(status_json, "state"));
  out.last_error = read_string(extract_json_string(status_json, "lastError"));
  out.login_url = read_string(extract_json_string(status_json, "loginUrl"));
  const auto identity_json = status_json.find("\"identity\":{");
  if (identity_json != std::string::npos) {
    const auto identity_str = status_json.substr(identity_json + 11);
    out.identity.account_email = read_string(extract_json_string(identity_str, "accountEmail"));
    out.identity.tailnet_name = read_string(extract_json_string(identity_str, "tailnetName"));
    out.identity.device_name = read_string(extract_json_string(identity_str, "deviceName"));
    out.identity.device_id = read_string(extract_json_string(identity_str, "deviceId"));
    out.identity.tailscale_ip = read_string(extract_json_string(identity_str, "tailscaleIp"));
    out.identity.signed_in = extract_json_bool(identity_str, "signedIn") == "true";
  }
  const auto peers_start = status_json.find("\"peers\":[");
  if (peers_start != std::string::npos) {
    const auto body = status_json.substr(peers_start + 8);
    std::size_t cursor = 0;
    while (cursor < body.size()) {
      const auto object_start = body.find('{', cursor);
      if (object_start == std::string::npos) {
        break;
      }
      const auto object_end = body.find('}', object_start);
      if (object_end == std::string::npos) {
        break;
      }
      const std::string peer_json = body.substr(object_start, object_end - object_start + 1);
      TailnetPeer peer;
      peer.node_id = read_string(extract_json_string(peer_json, "nodeId"));
      peer.name = read_string(extract_json_string(peer_json, "name"));
      peer.address = read_string(extract_json_string(peer_json, "address"));
      peer.platform = read_string(extract_json_string(peer_json, "platform"));
      peer.online = extract_json_bool(peer_json, "online") == "true";
      const auto latency = extract_json_string(peer_json, "latencyMs");
      peer.latency_ms = latency.empty() ? 0u : static_cast<std::uint32_t>(std::stoul(latency));
      const auto quality = extract_json_string(peer_json, "quality");
      peer.quality = quality.empty() ? 0u : static_cast<std::uint32_t>(std::stoul(quality));
      out.peers.push_back(peer);
      cursor = object_end + 1;
    }
  }
  return true;
}

}  // namespace

bool refresh_status(NetworkBridge& bridge) {
  static HMODULE module = nullptr;
  static bool tried_load = false;
  static std::string load_error;
  if (!tried_load) {
    tried_load = true;
    if (!load_runtime_library(module, load_error)) {
      bridge.update_error(load_error);
      return false;
    }
  }
  if (module == nullptr) {
    bridge.update_error(load_error.empty() ? "embedded networking DLL not loaded" : load_error);
    return false;
  }
  auto get_status = reinterpret_cast<NetworkGetStatusFn>(GetProcAddress(module, "Network_GetStatus"));
  if (get_status == nullptr) {
    bridge.update_error("Network_GetStatus not found");
    return false;
  }
  const StatusPtr status_buffer(get_status(), &::free);
  if (status_buffer.get() == nullptr) {
    bridge.update_error("status buffer unavailable");
    return false;
  }
  NativeStatus parsed;
  if (!parse_status_json(status_buffer.get(), parsed)) {
    bridge.update_error("failed to parse runtime status");
    return false;
  }
  bridge.set_runtime_state(parsed);
  return true;
}
NetworkBridge::NetworkBridge() = default;

NetworkBridge::~NetworkBridge() {
  stop();
}

bool NetworkBridge::start() {
  std::scoped_lock lock(mutex_);
  if (!refresh_status(*this)) {
    last_error_message_ = "embedded runtime not available";
    return false;
  }
  started_ = true;
  return true;
}

void NetworkBridge::stop() {
  std::scoped_lock lock(mutex_);
  started_ = false;
  peers_.clear();
  identity_ = TailnetIdentity{};
}

bool NetworkBridge::begin_sign_in() {
  std::scoped_lock lock(mutex_);
  if (!refresh_status(*this)) {
    last_error_message_ = "sign-in flow pending embedded Go runtime";
    return false;
  }
  return true;
}

bool NetworkBridge::complete_sign_in(const std::string&) {
  std::scoped_lock lock(mutex_);
  if (!refresh_status(*this)) {
    last_error_message_ = "sign-in completion pending embedded Go runtime";
    return false;
  }
  return true;
}

TailnetIdentity NetworkBridge::identity() const {
  std::scoped_lock lock(mutex_);
  return identity_;
}

std::vector<TailnetPeer> NetworkBridge::peers() const {
  std::scoped_lock lock(mutex_);
  return peers_;
}

std::string NetworkBridge::status_json() const {
  std::scoped_lock lock(mutex_);
  std::ostringstream out;
  out << "{\"started\":" << (started_ ? "true" : "false")
      << ",\"signedIn\":" << (identity_.signed_in ? "true" : "false")
      << ",\"accountEmail\":\"" << identity_.account_email
      << "\",\"tailnetName\":\"" << identity_.tailnet_name
      << "\",\"deviceName\":\"" << identity_.device_name
      << "\",\"deviceId\":\"" << identity_.device_id
      << "\",\"tailscaleIp\":\"" << identity_.tailscale_ip
      << "\",\"peerCount\":" << peers_.size()
      << ",\"lastErrorMessage\":\"" << last_error_message_ << "\"}";
  return out.str();
}

std::string NetworkBridge::last_error_message() const {
  std::scoped_lock lock(mutex_);
  return last_error_message_;
}

void NetworkBridge::set_runtime_state(const NativeStatus& runtime_state) {
  std::scoped_lock lock(mutex_);
  identity_ = runtime_state.identity;
  peers_ = runtime_state.peers;
  started_ = runtime_state.state != "offline";
  last_error_message_ = runtime_state.last_error.empty() ? runtime_state.state : runtime_state.last_error;
}

void NetworkBridge::update_error(const std::string& error) {
  std::scoped_lock lock(mutex_);
  last_error_message_ = error;
  started_ = false;
}

}  // namespace screenscrab::native

