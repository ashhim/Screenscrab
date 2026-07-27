#pragma once

#include <cstdint>

namespace screenscrab::native {

class InputInjector {
 public:
  bool initialize();
  bool move_mouse(std::int32_t x, std::int32_t y);
  bool mouse_button(bool down, std::uint32_t button);
  bool scroll(std::int32_t delta);
  bool key(bool down, std::uint16_t virtual_key);
};

}  // namespace screenscrab::native
