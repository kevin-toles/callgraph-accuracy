#pragma once

namespace DirectX {
struct XMVECTOR {
  float x;
  float y;
};

inline XMVECTOR XMVectorAdd(XMVECTOR a, XMVECTOR b) {
  a.x += b.x;
  a.y += b.y;
  return a;
}

inline XMVECTOR XMVectorScale(XMVECTOR v, float s) {
  v.x *= s;
  return DirectX::XMVectorAdd(v, v);
}
}  // namespace DirectX
