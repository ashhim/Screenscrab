#include "transfer_service.h"

namespace screenscrab::native {

bool TransferService::begin_send(const std::string&) {
  return true;
}

bool TransferService::begin_receive(const std::string&, std::uint64_t) {
  return true;
}

}  // namespace screenscrab::native
