# s-delta-rs (rust): blind call-graph review, round 18

precision 49/50; census ≈99.38% (352 wrong of 56489 in-scope); recall: 0 missed of 90 real calls; 0 non-calls

## Scope
The tool JSON (`kr40-A/s-delta-rs.v2.json`) has 73,870 edges (64,923 `.rs`, 8,946 `.py`, 1 `.js`). In scope: 56,489 edges whose `source_file` ends in `.rs` and has no path segment named `test`, `tests`, `spec`, `examples` or `docs`, across 187 files. Vendored code, benches, `test_utils/` and in-file `mod tests` are in scope, per Decisions 2026-11-09.
- Confidence: medium 25,977, low 20,574, high 9,900, unknown 38.
- call_type: method 42,321, macro 8,072, direct 6,058, callback 38.
- Split: low/method 20,476, medium/method 16,060, medium/macro 7,875, high/method 5,785, high/direct 3,918, medium/direct 2,042, high/macro 197, low/direct 98, unknown/callback 38.

The `measured_accuracy` field was ignored.

Method details:
- Sample: seed 18, quotas unknown 5 / high 8 / low 16 / medium 21, drawn from 33 files (`s-delta-rs_r18_sample.py`).
- Recall functions: `cast_record_batch` (kernel/schema/cast/mod.rs), `next_data_path` (writer/utils.rs) and `cleanup_expired_logs_for` (protocol/checkpoints.rs).
- Census scripts: `s-delta-rs_r18_*.py`, with the union in `s-delta-rs_r18_census.py`.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| crates/core/src/operations/delete.rs:1681 (sample #4) | `Action::Add(add(file_null, None, null_bytes.len() as i64)),` with `let add = \|path: &str, dt: Option<&str>, size: i64\| Add {` at 1625 | test_delete_partition_only_does_not_delete_null_partition_values → `add`, unknown, callback | `…values.add`, high, direct (named nested function; the node exists) | wrong callee | a let-bound closure called inside a macro argument (`vec![…]`) is not resolved |
| crates/core/src/delta_datafusion/mod.rs:1474 | `.any(\|range\| overlaps(range, &small_range)),` (inside `assert!`) | test_delta_scan_uses_parquet_column_pruning → `overlaps`, unknown, callback | `test_delta_scan_uses_parquet_column_pruning.overlaps`, high, direct | wrong callee | same: let-bound closure called inside macro arguments |
| crates/core/src/writer/utils.rs:56 (recall) | `compression_to_str(&compression)` (inside `format!`; `fn compression_to_str` is nested in `next_data_path`) | next_data_path → `compression_to_str`, low, direct | `next_data_path.compression_to_str`, high, direct | wrong callee / confidence | nested `fn` item called inside macro arguments is not resolved |
| crates/core/src/kernel/schema/cast/mod.rs:231 (recall) | `let struct_array = cast_struct(&s, target_schema.fields(), &cast_options, add_missing)?;` (`target_schema: ArrowSchemaRef`, `use arrow_schema::{…, SchemaRef as ArrowSchemaRef …}`) | cast_record_batch → `SchemaRef#fields`, medium, method | external type keeps its path because the scan defines `type SchemaRef = Arc<StructType>`: `arrow_schema::SchemaRef#fields`, medium | wrong callee | external alias written bare, so it collides with the scanned `SchemaRef` (C1) |
| crates/core/src/kernel/snapshot/stats_projection.rs:815 | `assert!(stats_schema.field("numRecords").is_some());` (`stats_schema` from `-> DeltaResult<KernelSchemaRef>`, `SchemaRef as KernelSchemaRef` from delta_kernel) | … → `SchemaRef#field`, medium | `delta_kernel::schema::SchemaRef#field`, medium | wrong callee | same; arrow, delta_kernel and scanned SchemaRef all share one ID |
| crates/core/src/operations/load_cdf.rs:577 | `.map(\|name\| schema.field_with_name(name).map(\|f\| f.to_owned()))` | CdfLoadBuilder#build_with_metrics → `ArrowSchemaRef#field_with_name`, medium | `arrow_schema::SchemaRef#field_with_name`, medium | wrong callee | a `use … as ArrowSchemaRef` rename in the declaring file (snapshot/mod.rs) names the type at a call site in another file |
| crates/core/src/delta_datafusion/find_files.rs:312 | `let mut builder = DeltaScanNext::builder()` (`DeltaScan as DeltaScanNext` re-exported in delta_datafusion/mod.rs:68) | collect_matching_files → `DeltaScanNext#builder`, medium | `DeltaScan#builder`, high (defined at next/mod.rs:705) | wrong callee / confidence | re-export rename not resolved to the scanned definition (C1) |
| crates/core/src/table/state.rs:279 | `if let Some(partition_schema) = self.inner.partitions_schema()? {` | Snapshot#add_actions_partition_batches → `KernelSnapshot#partitions_schema`, medium | `delta_kernel::snapshot::Snapshot#…` (path kept: the scan defines `Snapshot`) | wrong callee | rename name used as type ID |
| crates/core/src/kernel/arrow/engine_ext.rs:809 | `let stats_schema = table_configuration.stats_schema().unwrap();` (`use delta_kernel::{DeltaResult, …}`) | … → `DeltaResult#unwrap`, medium | `delta_kernel::DeltaResult#unwrap` (external alias, name collides with scanned `DeltaResult`) | wrong callee | external alias bare |
| crates/benchmarks/src/smoke.rs:20 | `let schema = Arc::new(arrow::datatypes::Schema::new(vec![` | run_smoke_once → `Schema#new`, medium | `arrow::datatypes::Schema#new`, medium (as the tool emits 50× elsewhere) | wrong callee | path dropped for a name the scan defines (`type Schema = StructType`); C2 |
| crates/core/src/delta_datafusion/physical.rs:173 | `self.input.poll_next_unpin(cx).map(\|x\| match x {` (`input: SendableRecordBatchStream` imported from datafusion) | MetricObserverStream#poll_next → `SendableRecordBatchStream#poll_next_unpin`, medium | datafusion's type with its path (scan defines its own `SendableRecordBatchStream`) | wrong callee | external alias bare |
| crates/core/src/operations/write/mod.rs:428 | `PROTOCOL.can_write_to(&snapshot)?` (`pub use self::protocol::INSTANCE as PROTOCOL;`, `static INSTANCE: LazyLock<ProtocolChecker>`) | … → `PROTOCOL.can_write_to`, low, method | typed static (decision A), as the tool types in-scan statics elsewhere (`LazyLock#captures`) | wrong callee / confidence | static imported through a rename is not typed |
| crates/core/src/protocol/checkpoints.rs:126 (recall) | `object_store.list(Some(log_path)).collect().await;` with `let object_store = log_store.object_store(operation_id);` and `fn object_store(…) -> Arc<dyn ObjectStore>;` | cleanup_expired_logs_for → `object_store.list`, low | `ObjectStore#list`, medium (let-bound to a scanned call with a declared return type) | wrong callee / confidence | let-bound call result not typed |
| crates/core/src/operations/merge/mod.rs:2255 | `assert_eq!(predicates.len(), 2);` with `let predicates = super::build_file_skipping_predicates(…);` `-> Vec<Expr>` | … → `predicates.len`, low | `Vec#len`, medium | wrong callee / confidence | let-bound call result (path-qualified callee) not typed |
| crates/core/src/operations/load.rs:148 | `let data = collect_sendable_stream(stream).await?;` (`use crate::operations::collect_sendable_stream;`, which is `pub use datafusion::physical_plan::common::collect as collect_sendable_stream;`) | test_load_local → `collect_sendable_stream`, low, direct | `datafusion::physical_plan::common::collect`, medium, direct | wrong callee / confidence | import through a re-export of an external fn is not resolved |
| crates/benchmarks/src/merge.rs:520 | `.filter(expr_fn::random().lt_eq(lit(params.sample_matched_rows)))?;` (`use deltalake_core::datafusion::{logical_expr::{cast, lit}, …}`) | prepare_source_and_table → `lit`, low, direct | imported fn, medium, with its path | wrong callee / confidence | explicitly imported external fn left as a bare low name |
| crates/benchmarks/src/merge.rs:520 | same line, `expr_fn::random()` | → `random`, medium, direct | module path kept (`…expr_fn::random`), medium | wrong callee | module path dropped |
| crates/core/src/operations/cdc.rs:43 | `lit(ScalarValue::Utf8(Some("update_preimage".to_string()))),` (only glob: `use datafusion::prelude::*;`) | CDCTracker#collect → `lit`, low | `datafusion::prelude::lit`, medium (as emitted 104× elsewhere with one prelude glob) | wrong callee / confidence | C2: single-glob import resolved elsewhere, not here |
| crates/core/src/delta_datafusion/expr.rs:1271 | `"get_field(get_field(_struct, 'nested'), 'b') = 20".to_string()` | test_expr_sql → `get_field` ×2, low, direct | no edge (text in a string literal) | not a call | string-literal contents inside `simple!` macro args parsed as calls |
| crates/core/src/test_utils/factories/data.rs:91 | `.and_then(\|min\| Integer.parse_scalar(&min).ok())` (`use PrimitiveType::*;`) | generate_random_array → `Integer.parse_scalar`, low | typed by the enum, `PrimitiveType#parse_scalar` | wrong callee / confidence | open defect rust/13 (enum-variant receivers) |

## Systematic patterns (scripted counts, union = 352)
1. **External-alias or rename names used as receiver type IDs: 271.**
   - Breakdown: `SchemaRef#*` 190, `ArrowSchemaRef#*` 17, `DeltaScanNext#*` 17, `Schema#*` 12, `KernelSchemaRef#*` 12, `DeltaResult#*` 7, `KernelSnapshot#*` 7, `SendableRecordBatchStream#*` 6, `DataFusionResult#*` 3.
   - Two failures share this pattern:
     - An external type whose name the scan also defines (`type SchemaRef = Arc<StructType>`, `type Schema = StructType`, `type DeltaResult`, `type SendableRecordBatchStream`) is emitted bare. It should keep its path (Rust note, C1) or, for the scanned alias, be expanded (2026-11-12 readings).
     - A `use X as Y` rename (or `pub use DeltaScan as DeltaScanNext`) leaks into the ID, including at call sites in other files. Per C1, `DeltaScanNext#*` should be `DeltaScan#*` at high.
   - Hand-checked: cast/mod.rs:231, stats_projection.rs:815, load_cdf.rs:577, find_files.rs:312, state.rs:279, engine_ext.rs:809, smoke.rs:20, physical.rs:173.
   - Every `SchemaRef#m` is wrong on either branch: a path-qualified external type, or an expansion to `Arc`/`StructType`.
2. **Renamed imported static not typed (`PROTOCOL.*`): 22.**
   - `INSTANCE: LazyLock<ProtocolChecker>` re-exported as `PROTOCOL`.
   - The tool types in-scan statics elsewhere (`DELTA_LOG_REGEX` → `LazyLock#captures`), so these low guesses are wrong under either reading of LazyLock (see spec gaps).
3. **Let-bound call result not typed: 21 (lower bound, single-line `let` only).**
   - 11 are `let object_store = ….object_store(…)`: `LogStore#object_store`/`Arc#object_store`, declared `-> Arc<dyn ObjectStore>`. These give `object_store.list/clone/as_ref/…` low.
   - 10 are other bindings: `table_root_url() -> Url` ×3, `super::build_file_skipping_predicates -> Vec<Expr>` ×2, `log_data() -> LogDataHandler`, `crate::writer::test_utils::get_delta_schema() -> StructType`, `logstore_prefix() -> Path`, `ensure_table_uri(…)? -> Url`, `value_and_file_id_batch(…)? -> TestResult<RecordBatch>`.
   - Excluded as honest lows: external `PyResult`/`DFResult` aliases.
4. **Nested named functions called inside macro arguments: 12.**
   - Let-bound closures `add` ×9 (in `vec![…]`) and `overlaps` ×2 (in `assert!`) are emitted as `name`, unknown, callback. Nested `fn compression_to_str` (in `format!`) is emitted as a low bare name.
   - All four nodes `outer.f` exist. The tool resolves the same constructs outside macros (66 high `outer.f` edges).
5. **Imported external functions left as low bare names: 12.**
   - `collect_sendable_stream` ×5 (a re-export of `datafusion::physical_plan::common::collect`), `provider_as_source` ×1 (explicit import), benchmarks `lit`/`cast` ×4 (explicit nested import), cdc.rs `lit` ×2 (single prelude glob, resolved elsewhere; C2).
   - Not counted: `lit`/`col` lows in update/tests.rs, write/mod.rs tests, delete.rs tests and merge/filter.rs tests. Each has two or more glob imports, so they are honest lows.
6. **Enum-variant receivers (open defect rust/13): 8.** `Integer/Long/Float/Double.parse_scalar` with `use PrimitiveType::*`.
7. **Module path dropped: 3.** `expr_fn::random()` → `random`.
8. **String-literal text as calls: 3.** expr.rs:1271 (×2) and 1275.

## Missed-call patterns (recall)
- No call was dropped in the three functions: 18 + 8 + 64 = 90 calls, every one emitted, no non-calls.
- 4 of the 90 carry wrong IDs, counted under patterns 1, 3 and 4: `SchemaRef#fields`, `compression_to_str`, `object_store.list`, `object_store.delete_stream`.
- No open-defect recall gaps (rust/05 fn-pointer fields) occurred in these functions.

## Spec gaps (counted separately, not wrong)
1. **`LazyLock`/`OnceLock` statics: 71 edges.** Example: `LazyLock#clone` 49, `LazyLock#captures` (`DELTA_LOG_REGEX.captures(path)`), `LazyLock#new_expression_evaluator`. Open question: the smart-pointer rule lists Box/Rc/Arc/&T and the borrow and lock guards. Does it cover `LazyLock<T>`/`OnceLock<T>`, whose method calls reach `T` through Deref, or is the lazy cell "its own type" like a container?
2. **Alias that names the same external type: 90 edges.** Example: `Runtime#block_on`/`Runtime#new`, with `type Runtime = tokio::runtime::Runtime;` in benches/smoke.rs. Open question: the scan "defines a type of the same name" only as an alias of that very external type. Must the external type keep its path (`tokio::runtime::Runtime#…`) everywhere?
3. **Calls inside `quote!` token streams (crates/derive): 12 edges.** Example: `match #parser(&val) {` → `parser`, callback, and `std::env::var` inside `quote! { … }`. Open question: "calls written inside macro arguments are separate ordinary edges". Does that hold for a quasi-quoting macro whose argument is generated code that the enclosing function never runs?
4. **Rust prelude free functions: 13 edges.** Example: `drop(tmp_dir);` → `drop`, low, direct. Open question: Python and Haskell builtins and Ruby `Kernel` have qualified medium IDs. Is a Rust prelude function (`std::mem::drop`) medium with its path, or a bare name not in the scan (low)?
5. **Slice- and array-typed constants: 9 edges.** Example: `NATIVE_SCHEMES.contains(service)` with `const NATIVE_SCHEMES: &[&str]`, and `INSERT_ONLY_CASES.iter()` with `[MergeTestCase; 6]`. Open question: decision A types statics. What ID names a method on a slice or array type, which has no type name, and does it cover `const` items as well as `static`?
6. **Unit-struct value receivers of a scanned struct: 2 edges.** Example: `NullCountStatsTransform.transform_struct(&expected_fields)` with `pub(crate) struct NullCountStatsTransform;`. Open question: the Rust constructor ruling types `T { .. }` literals and in-place chains. Does a bare unit-struct expression `T` type its receiver the same way?
