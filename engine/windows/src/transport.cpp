#include "transport.h"

#include <ws2tcpip.h>

namespace screenscrab::native {

namespace {
bool g_winsock_initialized = false;
bool g_winsock_ready = false;

bool winsock_ready() {
  if (!g_winsock_initialized) {
    g_winsock_initialized = true;
    WSADATA data{};
    g_winsock_ready = WSAStartup(MAKEWORD(2, 2), &data) == 0;
  }
  return g_winsock_ready;
}

bool send_exact(SOCKET socket_handle, std::span<const std::uint8_t> bytes) {
  std::size_t offset = 0;
  while (offset < bytes.size()) {
    const int sent = send(socket_handle, reinterpret_cast<const char*>(bytes.data() + offset),
                          static_cast<int>(bytes.size() - offset), 0);
    if (sent == SOCKET_ERROR || sent == 0) {
      return false;
    }
    offset += static_cast<std::size_t>(sent);
  }
  return true;
}

bool receive_exact(SOCKET socket_handle, std::span<std::uint8_t> bytes) {
  std::size_t offset = 0;
  while (offset < bytes.size()) {
    const int received = recv(socket_handle, reinterpret_cast<char*>(bytes.data() + offset),
                              static_cast<int>(bytes.size() - offset), 0);
    if (received == SOCKET_ERROR || received == 0) {
      return false;
    }
    offset += static_cast<std::size_t>(received);
  }
  return true;
}

bool set_reuse(SOCKET socket_handle) {
  const BOOL reuse = TRUE;
  return setsockopt(socket_handle, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char*>(&reuse), sizeof(reuse)) == 0;
}
}  // namespace

Transport::~Transport() {
  disconnect();
}

bool Transport::initialize_winsock() {
  return winsock_ready();
}

bool Transport::listen(std::uint16_t port) {
  if (!initialize_winsock()) {
    last_error_ = WSAGetLastError();
    return false;
  }

  disconnect();
  listen_socket_ = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listen_socket_ == INVALID_SOCKET) {
    last_error_ = WSAGetLastError();
    return false;
  }

  if (!set_reuse(listen_socket_)) {
    last_error_ = WSAGetLastError();
    disconnect();
    return false;
  }

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(port);

  if (bind(listen_socket_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == SOCKET_ERROR) {
    last_error_ = WSAGetLastError();
    disconnect();
    return false;
  }

  if (::listen(listen_socket_, SOMAXCONN) == SOCKET_ERROR) {
    last_error_ = WSAGetLastError();
    disconnect();
    return false;
  }

  return true;
}

bool Transport::accept() {
  if (listen_socket_ == INVALID_SOCKET) {
    last_error_ = WSAEINVAL;
    return false;
  }

  if (socket_ != INVALID_SOCKET) {
    closesocket(socket_);
    socket_ = INVALID_SOCKET;
  }
  socket_ = ::accept(listen_socket_, nullptr, nullptr);
  if (socket_ == INVALID_SOCKET) {
    last_error_ = WSAGetLastError();
    return false;
  }

  return true;
}

bool Transport::connect(const std::string& address, std::uint16_t port) {
  if (!initialize_winsock()) {
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
  if (listen_socket_ != INVALID_SOCKET) {
    closesocket(listen_socket_);
    listen_socket_ = INVALID_SOCKET;
  }
}

bool Transport::connected() const noexcept {
  return socket_ != INVALID_SOCKET;
}

int Transport::last_error() const noexcept {
  return last_error_;
}

bool Transport::send_all(std::span<const std::uint8_t> bytes) {
  if (socket_ == INVALID_SOCKET) {
    last_error_ = WSAENOTCONN;
    return false;
  }
  return send_exact(socket_, bytes);
}

bool Transport::receive_all(std::span<std::uint8_t> bytes) {
  if (socket_ == INVALID_SOCKET) {
    last_error_ = WSAENOTCONN;
    return false;
  }
  return receive_exact(socket_, bytes);
}

bool Transport::poll_readable(int timeout_ms) {
  if (socket_ == INVALID_SOCKET) {
    last_error_ = WSAENOTCONN;
    return false;
  }

  fd_set read_fds;
  FD_ZERO(&read_fds);
  FD_SET(socket_, &read_fds);

  timeval timeout{};
  timeout.tv_sec = timeout_ms / 1000;
  timeout.tv_usec = (timeout_ms % 1000) * 1000;

  const int ready = select(0, &read_fds, nullptr, nullptr, &timeout);
  if (ready == SOCKET_ERROR) {
    last_error_ = WSAGetLastError();
    return false;
  }
  return ready > 0 && FD_ISSET(socket_, &read_fds);
}

}  // namespace screenscrab::native
