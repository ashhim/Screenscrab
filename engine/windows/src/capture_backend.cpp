#include "capture_backend.h"

#include <chrono>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdint>

namespace screenscrab::native {

namespace {
using Microsoft::WRL::ComPtr;

struct DxgiCaptureContext {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  ComPtr<IDXGIOutputDuplication> duplication;
  DXGI_OUTDUPL_DESC desc{};
};

bool create_capture_context(std::uint32_t monitor_index, DxgiCaptureContext& context) {
  D3D_FEATURE_LEVEL feature_level = D3D_FEATURE_LEVEL_11_0;
  UINT device_flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> device_context;
  if (FAILED(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, device_flags, &feature_level, 1,
                               D3D11_SDK_VERSION, &device, nullptr, &device_context))) {
    return false;
  }

  ComPtr<IDXGIDevice> dxgi_device;
  if (FAILED(device.As(&dxgi_device))) {
    return false;
  }

  ComPtr<IDXGIAdapter> adapter;
  if (FAILED(dxgi_device->GetAdapter(&adapter))) {
    return false;
  }

  ComPtr<IDXGIOutput> output;
  if (FAILED(adapter->EnumOutputs(monitor_index, &output))) {
    return false;
  }

  ComPtr<IDXGIOutput1> output1;
  if (FAILED(output.As(&output1))) {
    return false;
  }

  ComPtr<IDXGIOutputDuplication> duplication;
  if (FAILED(output1->DuplicateOutput(device.Get(), &duplication))) {
    return false;
  }

  duplication->GetDesc(&context.desc);
  context.device = std::move(device);
  context.context = std::move(device_context);
  context.duplication = std::move(duplication);
  return true;
}
}  // namespace

struct CaptureBackend::Impl {
  DxgiCaptureContext context;
  std::uint32_t monitor_index{0};
  bool ready{false};
};

CaptureBackend::CaptureBackend() = default;

CaptureBackend::~CaptureBackend() = default;

bool CaptureBackend::initialize(std::uint32_t monitor_index) {
  monitor_index_ = monitor_index;
  impl_ = std::make_unique<Impl>();
  impl_->monitor_index = monitor_index;
  impl_->ready = create_capture_context(monitor_index, impl_->context);
  initialized_ = impl_->ready;
  return initialized_;
}

bool CaptureBackend::capture(CaptureFrame& frame) {
  if (!initialized_ || impl_ == nullptr || !impl_->ready) {
    return false;
  }

  DXGI_OUTDUPL_FRAME_INFO frame_info{};
  ComPtr<IDXGIResource> resource;
  HRESULT hr = impl_->context.duplication->AcquireNextFrame(16, &frame_info, &resource);
  if (FAILED(hr)) {
    return false;
  }

  struct FrameGuard {
    IDXGIOutputDuplication* duplication{nullptr};
    ~FrameGuard() {
      if (duplication != nullptr) {
        duplication->ReleaseFrame();
      }
    }
  } guard{impl_->context.duplication.Get()};

  ComPtr<ID3D11Texture2D> texture;
  if (FAILED(resource.As(&texture))) {
    return false;
  }

  D3D11_TEXTURE2D_DESC desc{};
  texture->GetDesc(&desc);
  desc.Usage = D3D11_USAGE_STAGING;
  desc.BindFlags = 0;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  desc.MiscFlags = 0;

  ComPtr<ID3D11Texture2D> staging;
  if (FAILED(impl_->context.device->CreateTexture2D(&desc, nullptr, &staging))) {
    return false;
  }

  impl_->context.context->CopyResource(staging.Get(), texture.Get());

  D3D11_MAPPED_SUBRESOURCE mapped{};
  if (FAILED(impl_->context.context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped))) {
    return false;
  }

  frame.width = desc.Width;
  frame.height = desc.Height;
  frame.stride_bytes = mapped.RowPitch;
  frame.pixel_format = PixelFormat::kBgra32;
  frame.timestamp_utc_us = static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::system_clock::now().time_since_epoch())
          .count());
  frame.monitor_index = monitor_index_;
  frame.rgba.resize(static_cast<std::size_t>(mapped.RowPitch) * desc.Height);
  const auto* source = static_cast<const std::uint8_t*>(mapped.pData);
  for (UINT row = 0; row < desc.Height; ++row) {
    std::copy_n(source + (mapped.RowPitch * row), mapped.RowPitch,
                frame.rgba.data() + (mapped.RowPitch * row));
  }
  impl_->context.context->Unmap(staging.Get(), 0);
  return true;
}

void CaptureBackend::shutdown() {
  impl_.reset();
  initialized_ = false;
}

bool CaptureBackend::initialized() const noexcept {
  return initialized_;
}

std::uint32_t CaptureBackend::monitor_index() const noexcept {
  return monitor_index_;
}

}  // namespace screenscrab::native
