# Changelog

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
