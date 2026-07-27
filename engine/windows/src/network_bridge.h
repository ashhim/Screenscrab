#pragma once

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace screenscrab::native {

struct TailnetPeer {
  std::string node_id;
  std::string name;
  std::string address;
  std::string platform;
  bool online{false};
  std::uint32_t latency_ms{0};
  std::uint32_t quality{0};
};

struct TailnetIdentity {
  std::string account_email;
  std::string tailnet_name;
  std::string device_name;
  std::string device_id;
  std::string tailscale_ip;
  bool signed_in{false};
};

struct NativeStatus {
  std::string state;
  std::string last_error;
  std::string login_url;
  std::string json;
  TailnetIdentity identity;
  std::vector<TailnetPeer> peers;
};

class NetworkBridge {
 public:
  NetworkBridge();
  ~NetworkBridge();

  NetworkBridge(const NetworkBridge&) = delete;
  NetworkBridge& operator=(const NetworkBridge&) = delete;

  bool start();
  void stop();
  bool begin_sign_in();
  bool refresh_runtime();
  int connect_peer(const std::string& peer_name, std::uint16_t port);
  bool complete_sign_in(const std::string& code);
  TailnetIdentity identity() const;
  std::vector<TailnetPeer> peers() const;
  std::string status_json() const;
  std::string last_error_message() const;

 private:
  friend bool refresh_status(NetworkBridge& bridge);
  void set_runtime_state(const NativeStatus& runtime_state);
  void update_error(const std::string& error);

  mutable std::mutex mutex_{};
  TailnetIdentity identity_{};
  std::vector<TailnetPeer> peers_{};
  std::string login_url_{};
  std::string runtime_state_{"offline"};
  std::string last_error_message_{"embedded networking not yet linked"};
  bool started_{false};
};

bool refresh_status(NetworkBridge& bridge);

}  // namespace screenscrab::native

