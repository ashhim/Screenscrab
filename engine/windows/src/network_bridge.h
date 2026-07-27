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

class NetworkBridge {
 public:
  NetworkBridge();
  ~NetworkBridge();

  NetworkBridge(const NetworkBridge&) = delete;
  NetworkBridge& operator=(const NetworkBridge&) = delete;

  bool start();
  void stop();
  bool begin_sign_in();
  bool complete_sign_in(const std::string& code);
  TailnetIdentity identity() const;
  std::vector<TailnetPeer> peers() const;
  std::string status_json() const;
  std::string last_error_message() const;

 private:
  mutable std::mutex mutex_{};
  TailnetIdentity identity_{};
  std::vector<TailnetPeer> peers_{};
  std::string last_error_message_{"embedded networking not yet linked"};
  bool started_{false};
};

}  // namespace screenscrab::native

