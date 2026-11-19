# connect-go call-graph review (v3)

**Summary:** precision 50/50; census ≈98.3% (49 wrong of 2888 in-scope); recall: 0 missed of 93 real calls; 0 non-calls

Scope: 3,575 edges total. In scope, after excluding `internal/gen/`, `testdata/`, `*.pb.go`, `*.connect.go` and `_test.go`: 2,888 edges (low 1,143 / high 894 / medium 810 / unknown 41). Of the 1,143 low edges, 908 are `is_external` and 235 are in-scan VTA edges.

Sample (`connect-go_v3_sample.py`, seed 3033): 18 low, 14 high, 13 medium and 5 unknown, over 30 files. All 50 are correct:
- **Low.** These are VTA implementation edges, for example protocol_connect.go:835 `io.PipeReader#Close`, client.go:362 `protoJSONCodec#Name`, main.go:567 `filedesc.Base#FullName` (promoted through `filedesc.Method`) and internal/example/client/main.go:32 `pingServiceClient#Ping`.
- **High.** In-scan functions, plus in-scan interface calls as written: client_stream.go:277 `StreamingClientConn#Spec`, memhttp.go:49 `memhttp.Option#apply`, duplex_http_call.go:420 `messagePayload#WriteTo`.
- **Medium.** Stdlib and protogen calls.
- **Unknown.** Function-value calls named by the variable, field or receiver: `unary`, `fromWire`, `f`, `onRequestSend`, `handle`.

Recall (0 missed, 0 non-calls in each):
- `Handler#ServeHTTP` (handler.go:261): 30 real calls, all present, including the callbacks `cancel`, `gate` and `implementation`.
- `connectUnaryRequestMarshaler#marshalWithGet` (protocol_connect.go:997): 30 real calls, all present. `m.write` resolves to the promoted `connectUnaryMarshaler#write`.
- `generateClientMethod` (cmd/protoc-gen-connect-go/main.go:371): 33 real calls, all present.

That makes 93 calls from the three functions, none missed. Outside the recall functions, 11 package-level `var` initializer calls are missed. They are listed as pattern 3 below and are not part of the census numerator, which counts wrong edges only.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| context.go:193 | `return c.responseSource.ResponseHeader()` | `clientCallInfo#ResponseHeader` → `StreamingClientConn#ResponseHeader`, low, method (beside the correct `responseSource#ResponseHeader` high) | low edges only for concrete implementations; `StreamingClientConn` is an interface | wrong callee | interface type listed as a VTA target |
| context.go:200 | `return c.responseSource.ResponseTrailer()` | → `StreamingClientConn#ResponseTrailer`, low, method | as above | wrong callee | interface type listed as a VTA target |
| connect.go:469 / 489 | `if err := initializer.maybe(conn.Spec(), &msg); err != nil {` | `receiveUnaryMessage` → `StreamingClientConn#Spec` and `StreamingHandlerConn#Spec`, low, method (4 edges) | only `receiveConn#Spec` as written, plus concrete types | wrong callee | interface type listed as a VTA target |
| handler.go:342 | `gateCtx, err := gate(ctx, h.spec, connCloser.Peer(), connCloser.RequestHeader())` | `Handler#ServeHTTP` → `StreamingHandlerConn#Peer` / `#RequestHeader`, low, method | `handlerConnCloser#…` high (present), plus concrete types | wrong callee | interface type (the embedded interface) listed as a VTA target |
| duplex_http_call.go:253 | `err := response.Body.Close()` | `duplexHTTPCall#CloseRead` → `io.Closer#Close`, low, method | `io.Closer` is an interface | wrong callee | interface type listed as a VTA target |
| duplex_http_call.go:239, handler.go:306 | `n, _ := request.Body.Read(b[:])` | → `io.Reader#Read`, low, method (2 edges) | `io.Reader` is an interface | wrong callee | interface type listed as a VTA target |
| client.go:258 | `conn:        c.newConn(ctx, StreamTypeBidi, nil),` | `Client#CallBidiStreamSimple` → `Client#newConn`, **medium**, direct, `is_external` | high: `Client#newConn` is defined in the scan (client.go:269) | wrong confidence | calls to generic in-scan functions/methods treated as external |
| handler.go:70 | `request, err := receiveUnaryRequest[Req](conn, config.Initializer)` | `NewUnaryHandler$2` → `receiveUnaryRequest`, medium, direct, `is_external` | high (connect.go) | wrong confidence | same as above |
| handler.go:77 | `peer:          request.Peer(),` | `NewUnaryHandler$2` → `Request#Peer`, medium, direct, `is_external` | high (`Request[T]` in connect.go) | wrong confidence | same as above |
| client_stream.go:433 | `return b.stream.Receive()` | `BidiStreamForClientSimple#Receive` → `BidiStreamForClient#Receive`, medium, `is_external` | high | wrong confidence | same as above |
| handler.go:126 | `return NewUnaryHandler(` | `NewUnaryHandlerSimple` → `NewUnaryHandler`, medium, `is_external` | high | wrong confidence | same as above (38 edges in total, pattern 2) |
| protocol_connect.go:65 | `var defaultConnectUserAgent = fmt.Sprintf("connect-go/%s (%s)", Version, runtime.Version())` | no edge | `connectrpc.com/connect` → `fmt.Sprintf` and `runtime.Version`, medium | missed call | package-level `var` initializers produce no edges |
| protocol.go:49 | `var errNoTimeout = errors.New("no timeout")` | no edge | `connectrpc.com/connect` → `errors.New`, medium | missed call | same (11 calls in total, pattern 3) |
| envelope.go:31 | `var errSpecialEnvelope = errorf(` | no edge | `connectrpc.com/connect` → `connectrpc.com/connect.errorf`, high | missed call | same |
| handler.go:69 | `implementation := func(ctx context.Context, conn StreamingHandlerConn) error {` | 22 edges with caller `NewUnaryHandler$2` | the Go note says `pkg.F$1`; the general rule says a local bound directly to a function literal is the named nested function `NewUnaryHandler.implementation` | spec gap | conflicting rules |
| error.go:204 and 5 other `err.Error()` sites | `return e.err.Error()` | 1 medium `error#Error` plus 103 low stdlib implementations per site (618 edges) | the Go note allows out-of-scan implementations "only with include_external", but the output does not record that option | spec gap | external VTA fan-out |

## Systematic patterns

1. **External VTA fan-out (spec gap, not counted): 897 low `is_external` edges.** The `err.Error()` sites have 103 edges each (6 sites, 618 edges). `Close` has 13 sites and 105 edges (1–13 per site). `Header` has 14 sites and 42 edges. `Write` has 3 sites and 37 edges (up to 17 per site). These are counted by `connect-go_v3_fanout.py`.
2. **Calls to generic in-scan functions and methods are medium and `is_external`: 38 edges, wrong confidence.** Every in-scope call to a generic declaration of the `connect` package gets medium, although the target is defined in the scan:
   - `NewUnaryHandler` 8, `Client#newConn` 5, `Request#Header` 3.
   - `receiveUnaryMessage`, `receiveUnaryRequest`, `receiveUnaryResponse`, `NewResponse`, `NewClientStreamHandler`, `NewServerStreamHandler`, `Request#Peer` and `Request#Spec` have 2 each.
   - 13 `BidiStreamForClient`/`ClientStreamForClient` methods have 1 each.

   No high edge to any of these IDs exists anywhere in the output. The census covers all 2,888 in-scope edges: these are the only medium edges with a `connectrpc.com/connect.` callee, apart from the correct `validate.NewInterceptor`.
3. **Package-level `var` initializer calls are missed: 11 calls, 0 edges.** They are listed by an AST script, `connect-go_v3_pkginit/main.go`, which parses the source and does not compile or run it:
   - `errors.New` at client_stream.go:26, error.go:39, interceptor.go:26, internal/memhttp/listener.go:24 and protocol.go:49.
   - `fmt.Errorf` at error.go:41 and protocol_grpc.go:55.
   - `errorf` at envelope.go:31.
   - `fmt.Sprintf` and `runtime.Version` at protocol_connect.go:65 and protocol_grpc.go:68.

   The current spec requires these as file-level code with the package as caller. Under the census rule they count as missed, not wrong.
4. **Interface types listed as low dispatch targets: 11 edges, wrong callee.** `StreamingClientConn` 4, `StreamingHandlerConn` 4, `io.Reader` 2, `io.Closer` 1. The script `connect-go_v3_iface.py` classifies in-scan interfaces from `type X interface` declarations and stdlib/protobuf interfaces with `go doc` or the module source. Each of these edges sits beside a correct as-written edge, and all 11 are flagged `is_external`, including the 8 whose types are in the scan.
5. **Nested-closure naming (spec gap, not counted): 26 caller edges.** The closures bound with `:=` directly to a function literal are `implementation` at handler.go:69 (22 edges as `NewUnaryHandler$2`) and `newConn` at client.go:278 (4 edges as `Client#newConn$1`). They follow the Go note (`pkg.F$1`), not the general named-nested-function rule (`outer.f`). The call `newConn(ctx, …)` at client.go:288 is emitted as a callback/unknown. That is defensible either way, because the variable is reassigned on line 286.

The census numerator counts patterns 2 and 4: 38 + 11 = 49 of 2,888, or 98.3%. Static calls, function-value callbacks (41 of 41 named correctly) and multi-call lines are clean. The 22 same-line duplicates are all real repeated calls, such as `errors.Is(…) || !errors.Is(…)`.

## Spec gaps

- **include_external.** The output does not say whether include_external was on, so the 897 external low VTA edges cannot be judged.
- **Go closures bound to locals.** The general rule ("local … `func` … is a named nested function `outer.f`") conflicts with the Go note ("closures `pkg.F$1`"). This affects 26 caller edges.
- **`call_type` for method calls.** The spec does not say when a statically dispatched method call should be `direct` rather than `method`. The tool uses `direct` for concrete methods, such as `bytes.Buffer#Reset`, and `method` for interface calls. Not judged.

## Previous findings

| Previous item | Status | Counts |
|---|---|---|
| Table rows memhttp.go:138 / handler.go:324: `defer cancel()` named `t6` / `t60` | **Fixed** | Both are now `cancel`, unknown, callback. 0 SSA-temp callees remain; 41 of 41 callback edges are named by variable or field. |
| Table row context.go:193: `StreamingClientConn#ResponseHeader` low | **Still present** | Unchanged; the sibling context.go:200 `#ResponseTrailer` has the same problem. |
| Table row connect.go:469: `StreamingClientConn#Spec` / `StreamingHandlerConn#Spec` low | **Still present** | 4 edges (lines 469 and 489). |
| Table row duplex_http_call.go:253: `io.Closer#Close` low | **Still present** | 1 edge. |
| Table row (spec gap): `err.Error()` stdlib fan-out | **Still present (spec gap), slightly reduced** | 6 sites, 618 low edges (103 per site), compared with 624 (about 104 per site). |
| Pattern 1: defer of a multi-value-assigned func value named with an SSA temporary | **Fixed** | 2 → 0. |
| Pattern 2: interface types as low dispatch targets | **Still present** | 11 → 11 (`StreamingClientConn` 4, `StreamingHandlerConn` 4, `io.Reader` 2, `io.Closer` 1). |
| Pattern 3: breadth of stdlib interface fan-out (spec gap) | **Still present (spec gap)** | 908 low `is_external` edges in total (897 excluding the interface-type rows). `Write` is now up to 17 per site, compared with 18–19. `Close` is 1–13 per site, compared with about 11. |
| Pattern 4: static calls clean | **Partly** | 50/50 sampled and 0 missed of 93 in recall. The full census now also finds 38 wrong-confidence edges to generic in-scan functions (pattern 2 here) and 11 missed package-level initializer calls (pattern 3 here), now in scope under the file-level caller rule. Neither was reported before. |
