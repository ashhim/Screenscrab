#include "network_bridge.h"

#include <sstream>

namespace screenscrab::native {

NetworkBridge::NetworkBridge() = default;

NetworkBridge::~NetworkBridge() {
  stop();
}

bool NetworkBridge::start() {
  std::scoped_lock lock(mutex_);
  started_ = true;
  identity_.signed_in = false;
  identity_.tailnet_name = "";
  identity_.account_email = "";
  identity_.device_name = "Screenscrab";
  identity_.device_id = "pending";
  identity_.tailscale_ip = "";
  peers_.clear();
  last_error_message_ = "embedded network runtime not linked";
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
  last_error_message_ = "sign-in flow pending embedded Go runtime";
  return false;
}

bool NetworkBridge::complete_sign_in(const std::string&) {
  std::scoped_lock lock(mutex_);
  last_error_message_ = "sign-in completion pending embedded Go runtime";
  return false;
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

}  // namespace screenscrab::native

