#include "clipboard_service.h"

#include <windows.h>
#include <utility>

namespace screenscrab::native {

bool ClipboardService::set_text(const std::string& text) {
  if (!OpenClipboard(nullptr)) {
    return false;
  }
  EmptyClipboard();

  const int wide_len = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  if (wide_len <= 0) {
    CloseClipboard();
    return false;
  }

  const SIZE_T size_bytes = static_cast<SIZE_T>(wide_len) * sizeof(wchar_t);
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, size_bytes);
  if (memory == nullptr) {
    CloseClipboard();
    return false;
  }

  void* lock = GlobalLock(memory);
  if (lock == nullptr) {
    GlobalFree(memory);
    CloseClipboard();
    return false;
  }

  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, static_cast<wchar_t*>(lock), wide_len);
  GlobalUnlock(memory);
  SetClipboardData(CF_UNICODETEXT, memory);
  CloseClipboard();
  return true;
}

bool ClipboardService::get_text(std::string& text) {
  if (!OpenClipboard(nullptr)) {
    return false;
  }

  HANDLE data = GetClipboardData(CF_UNICODETEXT);
  if (data == nullptr) {
    CloseClipboard();
    return false;
  }

  const wchar_t* buffer = static_cast<const wchar_t*>(GlobalLock(data));
  if (buffer == nullptr) {
    CloseClipboard();
    return false;
  }

  const int utf8_len = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, nullptr, 0, nullptr, nullptr);
  if (utf8_len <= 0) {
    GlobalUnlock(data);
    CloseClipboard();
    return false;
  }

  std::string converted(static_cast<std::size_t>(utf8_len - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, buffer, -1, converted.data(), utf8_len, nullptr, nullptr);
  text = std::move(converted);
  GlobalUnlock(data);
  CloseClipboard();
  return true;
}

}  // namespace screenscrab::native
