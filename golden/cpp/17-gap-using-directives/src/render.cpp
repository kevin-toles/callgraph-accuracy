#include "common.h"

void gfx::Device::Present() {}

void render(ComPtr<Device>& device, Device& screen) {
  device.Reset();
  screen.Present();
  if (device.Get() == nullptr) screen.Present();
}
