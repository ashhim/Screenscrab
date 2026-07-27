#include "clipboard_service.h"

namespace screenscrab::native {

bool ClipboardService::set_text(const std::string&) {
  return true;
}

bool ClipboardService::get_text(std::string& text) {
  text.clear();
  return true;
}

}  // namespace screenscrab::native
