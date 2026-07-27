#include "logging.h"

#include <iostream>

namespace screenscrab::native {

void log_info(const std::string& message) {
  std::clog << "[screenscrab] " << message << '\n';
}

void log_error(const std::string& message) {
  std::cerr << "[screenscrab] " << message << '\n';
}

}  // namespace screenscrab::native
