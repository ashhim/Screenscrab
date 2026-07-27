#include "encode_backend.h"

namespace screenscrab::native {

bool RawFrameEncoder::initialize() {
  return true;
}

bool RawFrameEncoder::encode(const CaptureFrame& frame, EncodedFrame& output) {
  output.kind = EncoderKind::kRaw;
  output.timestamp_utc_us = frame.timestamp_utc_us;
  output.width = frame.width;
  output.height = frame.height;
  output.stride_bytes = frame.stride_bytes;
  output.monitor_index = frame.monitor_index;
  output.payload = frame.rgba;
  return true;
}

const char* RawFrameEncoder::name() const noexcept {
  return "raw";
}

bool SoftwareFrameEncoder::initialize() {
  return true;
}

bool SoftwareFrameEncoder::encode(const CaptureFrame& frame, EncodedFrame& output) {
  return RawFrameEncoder{}.encode(frame, output);
}

const char* SoftwareFrameEncoder::name() const noexcept {
  return "software";
}

bool EncodeBackend::initialize() {
  encoder_ = std::make_unique<RawFrameEncoder>();
  if (!encoder_->initialize()) {
    encoder_.reset();
    kind_ = EncoderKind::kRaw;
    return false;
  }
  kind_ = EncoderKind::kRaw;
  return true;
}

bool EncodeBackend::encode(const CaptureFrame& frame, EncodedFrame& output) {
  if (encoder_ == nullptr) {
    return false;
  }
  return encoder_->encode(frame, output);
}

void EncodeBackend::shutdown() {
  encoder_.reset();
}

const char* EncodeBackend::active_encoder_name() const noexcept {
  return encoder_ == nullptr ? "none" : encoder_->name();
}

EncoderKind EncodeBackend::encoder_kind() const noexcept {
  return kind_;
}

}  // namespace screenscrab::native
