#pragma once

#include <cstdint>
#include <memory>
#include <vector>

namespace screenscrab::native {

enum class PixelFormat : std::uint32_t {
  kBgra32 = 0,
};

struct CaptureFrame {
  std::uint32_t width{0};
  std::uint32_t height{0};
  std::uint32_t stride_bytes{0};
  PixelFormat pixel_format{PixelFormat::kBgra32};
  std::uint64_t timestamp_utc_us{0};
  std::uint32_t monitor_index{0};
  std::vector<std::uint8_t> rgba;
};

class CaptureBackend {
 public:
  CaptureBackend();
  ~CaptureBackend();

  bool initialize(std::uint32_t monitor_index);
  bool capture(CaptureFrame& frame);
  void shutdown();
  bool initialized() const noexcept;
  std::uint32_t monitor_index() const noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_{};
  std::uint32_t monitor_index_{0};
  bool initialized_{false};
};

}  // namespace screenscrab::native
