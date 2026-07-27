#include "input_injector.h"

namespace screenscrab::native {

bool InputInjector::initialize() {
  return true;
}

bool InputInjector::move_mouse(std::int32_t, std::int32_t) {
  return true;
}

bool InputInjector::mouse_button(bool, std::uint32_t) {
  return true;
}

bool InputInjector::scroll(std::int32_t) {
  return true;
}

bool InputInjector::key(bool, std::uint16_t) {
  return true;
}

}  // namespace screenscrab::native
