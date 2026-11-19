# Blind call-graph review: s-quinn (rust), round 14

precision 49/50; census ≈98.4% (152 wrong of 9419 in-scope); recall: 0 missed of 44 real calls; 0 non-calls

## Scope
Tool output `<scans>/final18-A/s-quinn.v2.json` has 13,632 edges, all from `.rs` files. 9,419 are in scope across 83 files. The other 4,213 sit under a `tests/`, `examples/` or `docs/` directory segment (`quinn-proto/src/tests/`, `quinn/examples/`, `quinn-udp/tests/`, `quinn/tests/`, `docs/book/`). Per Decisions 2026-11-09, `bench/`, `perf/`, `fuzz/`, `benches/` and `build.rs` stay in scope, and so do the `tests.rs` files, which are files, not directories.

Confidence split: medium 4,011, high 2,890, low 2,502, unknown 16. call_type split: method 7,583, macro 1,157, direct 663, callback 16. By tier and type: medium/method 2,679; low/method 2,476; high/method 2,428; medium/macro 1,130; high/direct 435; medium/direct 202; high/macro 27; low/direct 26; unknown/callback 16.

Sample: seed 14, stratified as medium 19, high 14, low 12, unknown 5, over 27 files. Results: 49 are not wrong, 1 is wrong (#16), and 2 of the 49 are spec gaps (#40, #44). `measured_accuracy` was ignored.

Recall functions:
- `Pacer#delay` (quinn-proto/src/connection/pacing.rs:62–130): 18 calls.
- `SendStream#finish` (quinn/src/send_stream.rs:184–196): 5 calls.
- `send_via_sendmsg_x` (quinn-udp/src/unix.rs:478–519): 21 calls.

All 44 calls have edges and there are no extra edges. Struct literals (`Transmit { .. }`, `cmsg::Aligned(..)`) and `Some`/`Ok`/`Err` correctly get no edge. `conn.wake()` in `SendStream#finish` has an edge but with a wrong ID (P2).

Helper scripts are in the fanout folder with the `s-quinn_r14_` prefix. `s-quinn_r14_census.py` gives the union, and `s-quinn_r14_gaps.py` gives the spec-gap counts.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| quinn-proto/src/connection/mod.rs:2593 (sample #16) | `TransportError::new(` | Connection#process_decrypted_packet → TransportError#new, medium, method | `Error#new`, high (`pub use crate::transport_error::{Code as TransportErrorCode, Error as TransportError}`; `Error::new` is defined at transport_error.rs:30) | wrong callee + wrong confidence | `use … as` alias of a scanned type not expanded (C1) |
| quinn-proto/src/connection/mod.rs:2594 | `TransportErrorCode::crypto(0x6d),` | → TransportErrorCode#crypto, medium | `Code#crypto`, high | wrong callee | same alias pattern |
| quinn/src/send_stream.rs:188 | `conn.wake();` (with `let mut conn = self.conn.state.lock("finish");`) | SendStream#finish → T#wake, medium, method | `conn.wake`, low (`impl<T> Deref for MutexGuard<'_, T> { type Target = T; }`: unknown pointee) | wrong callee | type parameter `T` leaked into the ID (C2 invented ID) |
| quinn-proto/src/endpoint.rs:865 | `crypto.packet.local.tag_len();` | Endpoint#initial_close → T#tag_len, medium | not `T#…`. `KeyPair<T>{ local: T }` with `packet: KeyPair<Box<dyn PacketKey>>`: either `PacketKey#tag_len` or a low guess, never `T#` | wrong callee | generic struct field's type parameter named as a type |
| perf/src/lib.rs:130 | `qlog.writer(Box::new(writer)).title(Some(name.into()));` | CommonOpt#build_transport_config → Self#title, medium | `QlogConfig#title`, high (`writer` returns `&mut Self` on QlogConfig) | wrong callee + wrong confidence | declared return type `Self` not substituted |
| quinn-proto/src/connection/paths.rs:125 | `prev.current_mtu(),` (`prev: &Self`) | PathData#from_previous → Self#current_mtu, medium | `PathData#current_mtu`, high | wrong callee + wrong confidence | `&Self` parameter not substituted |
| quinn/src/connection.rs:1116 | `self.inner.handle_event(event);` (`pub(crate) inner: proto::Connection`) | State#process_conn_events → inner.handle_event, low | `Connection#handle_event`, high | wrong callee + wrong confidence | declared field type (workspace-crate path) not used (decision A) |
| quinn/src/runtime/tokio.rs:63 | `self.io.try_io(Interest::WRITABLE, \|\| {` (`io: Arc<tokio::net::UdpSocket>`) | UdpSocket#try_send → io.try_io, low | `tokio::net::UdpSocket#try_io`, medium (Arc pointee; name collides with the scanned `UdpSocket`) | wrong callee + wrong confidence | field type not used |
| perf/src/client.rs:72 | `let mut host_parts = opt.host.split(':');` (`opt: Opt`, `host: String`) | run → host.split, low | `String#split`, medium | wrong callee + wrong confidence | field chain on a typed parameter not typed |
| quinn-proto/src/connection/mod.rs:2881 | `Frame::StreamDataBlocked { id, offset } => {` … `id.initiator()` | → id.initiator, low | `StreamId#initiator`, high | wrong callee + wrong confidence | open defect rust/15 (pattern bindings untyped) |
| quinn-proto/src/packet.rs:491 | `crypto.encrypt(number, buf, header_len);` after `if let Some((number, crypto)) = crypto {` | PartialEncode#finish → Option#encrypt, medium | `PacketKey#encrypt`, high (the shadowing binding is `&dyn crypto::PacketKey`) or the rust/15 low guess; never `Option#` | wrong callee | shadowed pattern binding given the outer parameter's type |
| quinn/src/send_stream.rs:330 | `Poll::Ready(self.get_mut().finish().map_err(Into::into))` (`self: Pin<&mut Self>`) | SendStream#poll_close → SendStream#get_mut, medium | `Pin#get_mut`, medium (the wrapper defines `get_mut`) | wrong callee | Pin receiver dereferenced although Pin defines the method |
| quinn-proto/src/packet.rs:592 | `dst_cid: cid_parser.parse(buf)?,` (`cid_parser: &(impl ConnectionIdParser + ?Sized)`) | ProtectedHeader#decode → cid_parser.parse, low | `ConnectionIdParser#parse`, high (type variable resolves to its bound) | wrong callee + wrong confidence | parenthesized `impl Trait` parameter not typed |
| bench/src/bin/bulk.rs:36 | `runtime.block_on(server(endpoint, opt))` (`rt() -> Runtime`, `use tokio::runtime::{Builder, Runtime}`) | main → Runtime#block_on, medium | `tokio::runtime::Runtime#block_on`, medium (the scan defines `trait Runtime`) | wrong callee | external type collides with a scanned name (C1/C2) |
| quinn/src/runtime/smol.rs:35 | `self.set_at(t)` in `impl AsyncTimer for Timer` (`use async_io::Timer`) | Timer#reset → Timer#set_at, medium | `async_io::Timer#set_at`, medium (the scan defines `enum Timer`) | wrong callee | same collision |
| perf/src/server.rs:83 | `.context("creating endpoint")?;` on `quinn::Endpoint::new(...)` (`-> io::Result<Self>`) | run → Endpoint#context, medium | `Result#context`, medium (typed call result) or the fallible-constructor low guess; not `Endpoint#` | wrong callee | fallible constructor's result typed as T |
| perf/src/lib.rs:139 | `.context("create socket")?;` on `Socket::new(...)` | → Socket#context, medium | low guess (Decisions 2026-10-29, fallible constructor) | wrong callee | same |
| fuzz/fuzz_targets/streamid.rs:17 | `assert_eq!(s.initiator(), data.side);` (`let s = StreamId::new(...)` inside `fuzz_target!`) | crate::streamid → s.initiator, low | `StreamId#initiator`, high | wrong callee + wrong confidence | constructor-typed `let` inside a macro body not typed |
| quinn-proto/src/connection/streams/state.rs:925 | `if self.local_max_data > VarInt::MAX.into_inner() {` | → .into_inner, low | `VarInt#into_inner`, high (`pub const MAX: Self`) | wrong callee + wrong confidence | associated-const receiver untyped |
| quinn-proto/src/transport_parameters.rs:852 | `builder(&mut params);` (`for mut builder in illegal_params_builders`) | → builder, low, direct | `builder`, unknown, callback | wrong confidence + call_type | call through a loop variable holding a closure |
| quinn-udp/src/unix.rs:980 | `match libc::c_int::from(name.ss_family) {` | → libc::c_int::from, medium, direct | `c_int#from` (`Type::assoc → Type#assoc`), method | wrong callee + call_type | type path treated as a module function |
| quinn-udp/src/unix.rs:742 (sample #40) | `encoder.push(...)` with `let mut encoder = unsafe { cmsg::Encoder::new(hdr) };` | prepare_msg → encoder.push, low | spec gap G4 | spec gap | — |
| quinn-proto/src/bloom_token_log.rs:271 (sample #44) | `builder.hash_one(n)` with `let builder = IdentityBuildHasher;` | → builder.hash_one, low | spec gap G5 | spec gap | — |

The other 48 sample edges check out on caller, callee, tier, call_type and line. Some of them are worth noting:
- #1 `Builder#new_current_thread`, then `.enable_all`/`.build`/`.unwrap` as low guesses (external builder).
- #7 `std::io::Error#last_os_error`: the path is kept because the scan defines `Error`.
- #27 `BufMutExt#write`, high (scanned extension trait).
- #36 `.finish` and #43 `conn.wake`, low: both go through `MutexGuard<'_, T>`, whose pointee is unknown.
- #38 `all` inside `cfg_aliases!`: an honest low DSL name.
- #46–50 are correct callbacks.

## Systematic patterns (scripted counts, union 152)
1. **P2, type parameter or `Self` emitted as the callee type: 50** (`T#` 28, `Self#` 22; script `s-quinn_r14_generic.py`).
   - `T#wake`/`T#check_0rtt` come through `MutexGuard<'_, T>`.
   - `T#tag_len`/`T#decrypt` come through `KeyPair<T>.local`, and `T#as_mut_ptr` through `Aligned<T>.0`.
   - `Self#…` comes from receivers typed `&Self`, from `T::new()` declared `-> Self`, and from builder methods returning `&mut Self`.
   - Hand-checked at connection.rs:671, endpoint.rs:865, unix.rs:727, perf/src/lib.rs:130, paths.rs:125, recv.rs:476 and tests.rs:61.
2. **P1, field chains on a typed root left as `field.m` low: 39** (`s-quinn_r14_chain.py`).
   - The root is `self`, a typed parameter or a constructor-typed `let`, and every field on the chain has a declared type.
   - Counts: 17× `self.inner.*` on `proto::Connection`, 2× on `proto::Endpoint`, 6× `self.io.*` (tokio/smol sockets), 2× `std::sync::Mutex`, 2× `std::sync::MutexGuard`, 2× `self.bytes.len()` (`Bytes`), 4× `prev.<field>.*` with `prev: &Self`, 2× `peer_params.min_ack_delay` (`Option<VarInt>`), and `opt.host.split`, `self.streams.push`.
   - Plus `self.socket.max_transmit_segments()` (generic `Socket` bound `UdpSenderHelperSocket`) and `prev.congestion.clone_box()` (`Box<dyn congestion::Controller>`).
   - Hand-checked at connection.rs:1116, tokio.rs:63, client.rs:72, ack_frequency.rs:45 and runtime/mod.rs:199.
3. **P3, pattern-bound receivers untyped (open defect rust/15): 31, a scripted lower bound** (`s-quinn_r14_patbind2.py` plus the 5 fuzz tuple bindings).
   - 21 bindings come from scanned enum-variant patterns (`Frame::StreamDataBlocked { id, .. }`, `Self::Set(hset)`, `ChunksState::Readable(mut rs)`, `Phase::Searching(state)`, …).
   - 5 come from `if let Some(x) = self.<field>` with a declared `Option<T>` field.
   - 5 come from `let (params, operations) = input;` with `input: (StreamParams, Vec<Operation>)` in fuzz/fuzz_targets/streams.rs.
   - Of the 158 low `x.m` edges bound by a pattern, only these determinable forms were counted. The rest (bindings from call results such as `ty.stream()` and library types such as `io::Error`) were not.
4. **P4, `self.get_mut()` on `self: Pin<&mut Self>` named `Self#get_mut`: 8** (`s-quinn_r14_pin.py`). The cases are in recv_stream.rs:493/504/638/658/711 and send_stream.rs:292/330/348.
5. **P5, `use … as` alias of a scanned type not expanded: 8.** These are `TransportError#new` ×3, `TransportErrorCode#crypto` ×3, `TransportError#into`, `TransportErrorCode#fmt`. By contrast, `type StreamMetaVec = TinyVec<…>` is expanded correctly to `TinyVec#…`.
6. **P6, parenthesized `&(impl Trait + ?Sized)` parameters untyped: 4** (`s-quinn_r14_bound.py`): spaces.rs:844/882, packet.rs:592, shared.rs:95.
7. **P7, an external type sharing a scanned name loses its path: 3** (`Runtime#block_on` ×2, `Timer#set_at`). Elsewhere `tokio::runtime::Runtime#…` is kept correctly (20 edges).
8. **P9, typed bindings inside a `fuzz_target!` closure body untyped: 3** (streamid.rs:17/18, packet.rs:12 `data.buf.len` with `|data: PacketParams|`).
9. **P8, fallible constructor result named as T: 2** (`Endpoint#context`, `Socket#context`). Scripted checks found no other non-`Result`/`Option` type given a `Result`/`Option`-only method, and no external `T::new(..).unwrap()` promoted to `Result#unwrap`.
10. **P10–P13: 1 each.** They are `Option#encrypt` (shadowing binding), `VarInt::MAX.into_inner` (assoc const), `builder(&mut params)` (loop closure variable as low direct) and `libc::c_int::from` (type path as direct function).

The high tier is clean. Every high `T#m` and every high bare callee maps to an `fn` defined in a scanned impl or trait (`s-quinn_r14_highdef.py`; its two hits are header-parsing artifacts of that script). The medium edges on scanned types are derived `Default`/`Clone`, `Into`/`Iterator` methods inherited from std, or macro-generated impls; only P7 and P8 among them are wrong.

## Missed-call patterns (recall)
- No misses in the three recall functions (0 of 44).
- Calls through a fn-pointer or closure field, `(x.field)(..)` (open defect rust/05, which is a recall gap): 2 sites get no edge. They are quinn-proto/src/endpoint.rs:335 `let remote_id = (config.initial_dst_cid_provider)();` and quinn/src/runtime/mod.rs:170 `(this.make_writable_fut_fn)(this.socket)`.
- Invoking a call's result, `f(..)(..)`: 2 sites have an edge for the inner call only. They are streams/mod.rs:141 and streams/recv.rs:267, `get_or_insert_recv(…)(entry.get_mut())`. The construct's callee ID is also open; see G10.

## Spec gaps (counted separately, not wrong; union ≈287 edges)
- **G2, receivers whose declared type is a slice, array or `str` (≈112 edges).** Examples: `contents: &'a [u8]` → `contents.len`, `const MSG: &[u8]` → `MSG.len`, `[bool; 2]` → `max_stream_id.into_iter`, `Box<[u8]>` → `recv_buf.len`. Decision A says the declared type gives `T#m`. SPEC does not say what ID names a slice, array or `str` type, or whether such receivers stay low.
- **G1, suffixed numeric literal receivers (103 edges)**, e.g. `0u32.into()`, `2u64.saturating_pow(exponent)`, emitted as `.into`/`.pow` low. "Typed call results" types a literal "when its static type can be determined from declarations". SPEC does not say whether a literal's suffix counts as such a determination, or what the primitive ID is (`u32#into`?).
- **G3, user `Deref` to a slice (23 edges).** `ConnectionId#len` ×14, `#is_empty` ×6, `#split_at`, `#iter`, `ResetToken#iter`, all medium. `impl Deref for ConnectionId { type Target = [u8]; }` and `len` is not defined on ConnectionId. SPEC does not say whether the ID names the wrapper type or the pointee, nor how to name a primitive pointee.
- **G4, constructor inside an `unsafe` block (17 edges)**: `let mut encoder = unsafe { cmsg::Encoder::new(hdr) };` → `encoder.push`/`encoder.finish`, low. The constructor-typing ruling names `let x = T::new(..)`. SPEC does not say whether a block-wrapped initializer types the binding.
- **G8, Rust prelude function `drop(x)` (17 edges)**, low direct `drop`. SPEC does not give Rust's prelude functions an ID or tier, unlike Python `builtins.len` and Ruby `Kernel#puts`.
- **G7, blanket-impl callers (7 edges).** In `impl<T: Buf> BufExt for T { fn get_var … }` the callers are `T#get`, `T#get_var`, `T#write`, `T#write_var`, while calls resolve to `BufExt#get_var`/`BufMutExt#write`. SPEC does not say what the caller ID of a method in an impl for a bare type parameter is.
- **G6, local bound to an index (5 edges)**: `let space = &mut self.spaces[SpaceId::Initial];` → `space.take` low. The same index in place, `self.spaces[..].m()`, gives `PacketSpace#m` high (7 edges). The let-bound ruling covers call results. SPEC does not say whether a `let` bound to an index expression takes its element type.
- **G9, qualified path on a primitive array type (2 edges)**: `<[u8; 4]>::try_from(x)` → `::try_from`, medium, direct. SPEC does not say what ID `<[T; N]>::f` takes.
- **G5, unit-struct value (1 edge)**: `let builder = IdentityBuildHasher;` → `builder.hash_one`, low. The ruling lists `T { .. }`, `T::new(..)`, `T::default()` and `T::with_capacity(..)`. SPEC does not say whether a unit-struct expression `T` types the binding.
- **G11, macro-generated associated consts (1 edge)**: `FrameType::IMMEDIATE_ACK.encode(&mut buf)`, where `IMMEDIATE_ACK` is declared inside a `frame_types!` invocation (`IMMEDIATE_ACK = 0x1f,`). SPEC does not say whether a const that a `macro_rules!` expansion declares types its receiver.
- **G10, invoking a call result (2 sites, no edge)**: `get_or_insert_recv(…)(entry.get_mut())`. SPEC defines callbacks through a named parameter, local or property. It does not say what callee ID a call of a call's result takes, or whether it gets an edge.
