#include "transport.h"

namespace screenscrab::native {

bool Transport::connect(const std::string&, std::uint16_t) {
  connected_ = true;
  last_error_ = 0;
  return true;
}

void Transport::disconnect() {
  connected_ = false;
}

bool Transport::connected() const noexcept {
  return connected_;
}

int Transport::last_error() const noexcept {
  return last_error_;
}

}  // namespace screenscrab::native
