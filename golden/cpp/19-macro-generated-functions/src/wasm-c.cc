struct Config {};
#define WASM_DEFINE_OWN(name, Name) \
  inline auto hide_##name(Name* x) -> Name* { \
    return x; \
  }
#define WASM_DEFINE_VEC_BASE(name, Name, ptr_or_none) \
  inline auto hide_##name##_vec(Name ptr_or_none* v) -> Name* { \
    return nullptr; \
  }
#define WASM_DEFINE_VEC_OWN(name, Name) \
  WASM_DEFINE_VEC_BASE(name, Name, *)
#define WASM_DEFINE_TYPE(name, Name) \
  WASM_DEFINE_OWN(name, Name) \
  WASM_DEFINE_VEC_OWN(name, Name)
#define WASM_DEFINE_LATER(expr) \
  WASM_DEFINE_OWN(expr, Config)

WASM_DEFINE_OWN(config, Config)
WASM_DEFINE_TYPE(valtype, Config)
WASM_DEFINE_LATER(a + b)

void use(Config* c) {
  hide_config(c);
  hide_valtype(c);
  hide_valtype_vec(nullptr);
  hide_later(c);
}
