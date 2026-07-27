#pragma once

#include <string>

namespace screenscrab::native {

class ClipboardService {
 public:
  bool set_text(const std::string& text);
  bool get_text(std::string& text);
};

}  // namespace screenscrab::native
