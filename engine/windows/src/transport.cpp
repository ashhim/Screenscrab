#include "transport.h"

#include <winsock2.h>
#include <ws2tcpip.h>

namespace screenscrab::native {

namespace {
bool winsock_ready() {
  static bool initialized = false;
  static bool ready = false;
  if (!initialized) {
    initialized = true;
    WSADATA data{};
    ready = WSAStartup(MAKEWORD(2, 2), &data) == 0;
  }
  return ready;
}
}  // namespace

Transport::~Transport() {
  disconnect();
}

bool Transport::connect(const std::string& address, std::uint16_t port) {
  if (!winsock_ready()) {
    last_error_ = WSAGetLastError();
    return false;
  }

  disconnect();
  last_error_ = 0;

  const std::string port_text = std::to_string(port);
  addrinfo hints{};
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;

  addrinfo* result = nullptr;
  if (getaddrinfo(address.c_str(), port_text.c_str(), &hints, &result) != 0) {
    last_error_ = WSAGetLastError();
    return false;
  }

  for (addrinfo* ptr = result; ptr != nullptr; ptr = ptr->ai_next) {
    SOCKET socket_handle = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);
    if (socket_handle == INVALID_SOCKET) {
      continue;
    }

    if (::connect(socket_handle, ptr->ai_addr, static_cast<int>(ptr->ai_addrlen)) == 0) {
      socket_ = socket_handle;
      last_error_ = 0;
      break;
    }

    last_error_ = WSAGetLastError();
    closesocket(socket_handle);
  }

  freeaddrinfo(result);
  return socket_ != INVALID_SOCKET;
}

void Transport::disconnect() {
  if (socket_ != INVALID_SOCKET) {
    closesocket(socket_);
    socket_ = INVALID_SOCKET;
  }
}

bool Transport::connected() const noexcept {
  return socket_ != INVALID_SOCKET;
}

int Transport::last_error() const noexcept {
  return last_error_;
}

}  // namespace screenscrab::native
