# Changelog

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
