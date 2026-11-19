#pragma once

namespace Microsoft {
namespace WRL {
template <typename T>
class ComPtr {
 public:
  ComPtr() : ptr_(nullptr) {}
  T* Get() const { return ptr_; }
  void Reset() { ptr_ = nullptr; }

 private:
  T* ptr_;
};
}  // namespace WRL
}  // namespace Microsoft
