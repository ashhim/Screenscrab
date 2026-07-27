#include "input_injector.h"

#include <windows.h>

namespace screenscrab::native {

bool InputInjector::initialize() {
  return true;
}

bool InputInjector::move_mouse(std::int32_t x, std::int32_t y) {
  const int virtual_width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int virtual_height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  const int virtual_left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int virtual_top = GetSystemMetrics(SM_YVIRTUALSCREEN);

  const int clamped_x = x < virtual_left ? virtual_left : (x > virtual_left + virtual_width ? virtual_left + virtual_width : x);
  const int clamped_y = y < virtual_top ? virtual_top : (y > virtual_top + virtual_height ? virtual_top + virtual_height : y);

  const std::int32_t normalized_x = virtual_width <= 1 ? 0 :
      static_cast<std::int32_t>(((clamped_x - virtual_left) * 65535LL) / (virtual_width - 1));
  const std::int32_t normalized_y = virtual_height <= 1 ? 0 :
      static_cast<std::int32_t>(((clamped_y - virtual_top) * 65535LL) / (virtual_height - 1));

  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.dx = normalized_x;
  input.mi.dy = normalized_y;
  input.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;
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
