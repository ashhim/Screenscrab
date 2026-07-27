#include "input_injector.h"

#include <windows.h>

namespace screenscrab::native {

bool InputInjector::initialize() {
  return true;
}

bool InputInjector::move_mouse(std::int32_t x, std::int32_t y) {
  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.dx = x;
  input.mi.dy = y;
  input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
  return SendInput(1, &input, sizeof(INPUT)) == 1;
}

bool InputInjector::mouse_button(bool down, std::uint32_t button) {
  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = 0;
  if (button == 1) {
    input.mi.dwFlags = down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
  } else if (button == 2) {
    input.mi.dwFlags = down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP;
  } else {
    input.mi.dwFlags = down ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP;
  }
  return SendInput(1, &input, sizeof(INPUT)) == 1;
}

bool InputInjector::scroll(std::int32_t delta) {
  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.mouseData = static_cast<DWORD>(delta);
  input.mi.dwFlags = MOUSEEVENTF_WHEEL;
  return SendInput(1, &input, sizeof(INPUT)) == 1;
}

bool InputInjector::key(bool down, std::uint16_t virtual_key) {
  INPUT input{};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = virtual_key;
  input.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
  return SendInput(1, &input, sizeof(INPUT)) == 1;
}

}  // namespace screenscrab::native
