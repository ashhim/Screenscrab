#pragma once

#include <cstdint>
#include <memory>
#include <vector>

#include "capture_backend.h"

namespace screenscrab::native {

enum class EncoderKind : std::uint8_t {
  kRaw = 0,
  kH264 = 1,
  kH265 = 2,
};

struct EncodedFrame {
  EncoderKind kind{EncoderKind::kRaw};
  std::uint64_t timestamp_utc_us{0};
  std::uint32_t width{0};
  std::uint32_t height{0};
  std::uint32_t stride_bytes{0};
  std::uint32_t monitor_index{0};
  std::vector<std::uint8_t> payload;
};

class IFrameEncoder {
 public:
  virtual ~IFrameEncoder() = default;
  virtual bool initialize() = 0;
  virtual bool encode(const CaptureFrame& frame, EncodedFrame& output) = 0;
  virtual const char* name() const noexcept = 0;
};

class RawFrameEncoder final : public IFrameEncoder {
 public:
  bool initialize() override;
  bool encode(const CaptureFrame& frame, EncodedFrame& output) override;
  const char* name() const noexcept override;
};

class SoftwareFrameEncoder final : public IFrameEncoder {
 public:
  bool initialize() override;
  bool encode(const CaptureFrame& frame, EncodedFrame& output) override;
  const char* name() const noexcept override;
};

class EncodeBackend {
 public:
  bool initialize();
  bool encode(const CaptureFrame& frame, EncodedFrame& output);
  void shutdown();
  const char* active_encoder_name() const noexcept;
  EncoderKind encoder_kind() const noexcept;

 private:
  std::unique_ptr<IFrameEncoder> encoder_{};
  EncoderKind kind_{EncoderKind::kRaw};
};

}  // namespace screenscrab::native
