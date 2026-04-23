# Changelog

## 0.1.3 — 2026-04-24

### Changed (internal)

- **Introduced an IR layer** between the Deno JSON and the emitter ([#7]).
  Typed Dart classes `SchemaIR` / `FieldSetIR` / `FieldDefIR` + a
  `FieldKind` enum replace the raw `Object?` input that the emitter used
  to walk. Parsing (shape validation + normalization) now lives in
  `parseFieldDefinitionsIR`; the emitter trusts its typed input and
  focuses on string generation.

  This is a refactor-only release — no consumer-visible behavior change.
  The `field_definitions` template still emits the same per-fieldset
  lists + registry + routing switch. Parser errors carry a JSON-pointer
  `path` (e.g. `SCHEMA.ticket.fields[2].type`) matching what the Deno
  validator produces, via a new `SchemaShapeError` class.

  Why: `emitter.dart` had shape-checking (`is! Map`, `is! List`) mixed in
  with string emission, which made adding templates require re-doing
  validation work each time. The IR split separates concerns, makes
  emitters unit-testable against hand-built IR fixtures, and sets up a
  clean extension point for future templates.

- `emitFieldDefinitions` signature: `schema` is now `SchemaIR` instead of
  `Object?`. The `map` template is unchanged (it takes `Object?` — raw
  JSON with no shape to enforce). Anyone calling `emitFieldDefinitions`
  directly will need to `parseFieldDefinitionsIR(raw)` first; users who
  only go through `build_runner` see no change.

### Tests

- 67 → 75. +15 IR parser cases (`test/ir_test.dart`), emitter tests
  rewritten to use IR fixtures (same 25 cases, now constructed via typed
  helpers instead of nested Map literals — ~40% less test boilerplate).

[#7]: https://github.com/Enraio/ts_schema_codegen/issues/7

## 0.1.2 — 2026-04-24

### Added

- **Multi-schema config** ([#5]). `build.yaml` now accepts a `schemas` list
  so one builder invocation can produce multiple outputs from multiple TS
  entries. Each entry has its own `source`, `export`, `template`,
  `field_class_import`, and `output`. The old single-schema shape
  (top-level `source`/`export`/etc.) is still accepted and defaults
  output to `lib/ts_schema.g.dart` for backward compat.
- **Configurable output path** ([#5]). `output:` option per schema.
  Must start with `lib/` (build_runner constraint) and end with `.dart`.
  Duplicate outputs across schemas are rejected at config-parse time.
- **Zod-style boundary validation** ([#3]). For `field_definitions` schemas,
  the Deno side now walks the export before `JSON.stringify` and emits
  JSON-pointer errors (`SCHEMA.ticket.fields[2].type: expected 'string' |
  'array' | 'text', got 'txt'`). Skipped for `map` template since that
  accepts any JSON-serializable value. Exit code 6 distinguishes
  validation failures from other Deno errors. No network deps — the
  validator is ~80 lines of hand-rolled TS.
- New `example/multi/` runnable example demonstrating the multi-schema
  config with one `field_definitions` + one `map` entry side by side.

### Changed

- `TsSchemaConfig.schemas: List<SchemaEntry>` replaces the flat
  `source`/`export`/`template`/... fields. External callers constructing
  the config programmatically (rare) will need to update; the build.yaml
  options surface stays backward-compatible.
- `DenoRunner.evaluate` takes an optional `template` parameter (default
  `'map'`) forwarded to `tool/ts_export.ts` to drive validation.

### Tests

- 55 → 67. +7 config cases for multi-schema + backward compat, +5
  validator pipeline cases (field-type typo, missing required keys,
  non-string in categories, happy path, map-template skip).

[#3]: https://github.com/Enraio/ts_schema_codegen/issues/3
[#5]: https://github.com/Enraio/ts_schema_codegen/issues/5

## 0.1.1 — 2026-04-24

### Added

- **Typed authoring API** ([#2]). Ship `types.ts` at the repo root with
  `defineSchema`, `FieldSet`, `FieldDef`, `FieldType`. Consumers import
  via pinned Deno URL (or vendor the ~40 lines) and wrap their schema in
  `defineSchema(...)` for IDE completion + edit-time typo detection.
- **Generated registry** ([#4], additive). The `field_definitions`
  template now emits a `GeneratedFieldSet` class and a
  `const kFieldSets = <String, GeneratedFieldSet>{...}` map alongside
  the existing per-fieldset lists and routing switch. Consumers can
  iterate `kFieldSets`, inspect metadata, and build custom routing
  without regenerating. Default routing path unchanged — this is purely
  additive.
- **Custom JSON replacer** ([#6]) in `tool/ts_export.ts`. `Date`,
  `BigInt`, `Map`, and `Set` now cross the Deno → Dart boundary as
  tagged objects (`{__type: 'Date', iso: '...'}` etc.) instead of
  silently mangling. Plain templates pass them through; future
  templates can recognize `__type` markers to materialize as typed
  Dart values.

### Fixed

- `builder_impl.dart` now parses `.dart_tool/package_config.json` with
  `jsonDecode` instead of a regex. The regex was brittle to any future
  field reordering; the typed lookup surfaces clearer errors
  (distinguishes a corrupt config from a missing dev-dependency).

### Tests

- 45 → 55. New cases: registry emission (5), JSON replacer roundtrips
  (5). See `test/` for the full list.

[#2]: https://github.com/Enraio/ts_schema_codegen/issues/2
[#4]: https://github.com/Enraio/ts_schema_codegen/issues/4
[#6]: https://github.com/Enraio/ts_schema_codegen/issues/6

## 0.1.0 — 2026-04-23

Initial release.

### Added
- `build_runner` builder (`ts_schema_codegen|ts_schema`) triggered on
  `$package$`, emitting `lib/ts_schema.g.dart`.
- Bundled Deno evaluator (`tool/ts_export.ts`) for TS schema extraction.
- Two templates:
  - `map` — nested `const Object? schema = {...}` for raw data.
  - `field_definitions` — per-fieldset `const <FieldDefinition>[...]`
    lists + a `getFieldsForCategoryGenerated(category, {subcategory})`
    routing function. Consumer supplies the `FieldDefinition` class via
    `field_class_import` option.
- Typed config with validation (`TsSchemaConfig`): fails the build with a
  clear pointer to the offending `build.yaml` option on bad input.
- Automatic `dart format --page-width 120` on emitted output.
- 45-test suite covering config validation, emitter output (both
  templates, Unicode, deep nesting, escape handling, insertion order),
  real-Deno integration, and full TS → Deno → emitter pipeline roundtrips.
- Three runnable examples under `example/`:
  - primary (dynamic form schema, `field_definitions`)
  - `map_config/` (feature flags, `map` template)
  - `composed/` (multi-file TS composition via imports + `Object.fromEntries`)

### Known limitations
- Requires [Deno](https://deno.land) on `PATH` at build time. A
  future release will bundle a WASM TS evaluator to remove this.
- Fixed output path `lib/ts_schema.g.dart`; not yet configurable.
- Only two templates. A template-registry API is planned.
