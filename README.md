# ts_schema_codegen

> Keep your schema in TypeScript. Consume it from Dart.

A `build_runner` builder that evaluates a TypeScript module at build time and
emits typed Dart constants. Your TS stays the source of truth — the Dart side
breaks the build when TS drifts, instead of silently going stale.

```
  schema.ts                         ts_schema.g.dart
  ─────────                         ────────────────
  export const SCHEMA = {           const userFields = <FieldDefinition>[
    user: {                           FieldDefinition(id: 'name', ...),
      fields: [ ... ],                FieldDefinition(id: 'email', ...),
    },                              ];
  };                                getFieldsForCategoryGenerated(...) { ... }
       │                                         ▲
       │  dart run build_runner build            │
       └────────────────┐           ┌────────────┘
                        ▼           │
                  ┌───────────────────────┐
                  │  build_runner Builder │
                  │  ├─ shells out to Deno│
                  │  ├─ evaluates TS      │
                  │  ├─ grabs the export  │
                  │  └─ emits typed Dart  │
                  └───────────────────────┘
```

## Why

A backend and a Flutter app often need to agree on the same shape of data —
form fields, feature flags, item categories, design tokens. Maintaining two
copies (one in TS, one hand-translated in Dart) drifts the moment the backend
changes. Checking in a JSON intermediate works, but it's a manual step and
PR reviewers can't tell whether the JSON matches the TS source.

This package makes the Dart side a build-time derivative of the TS source.
Change the TS → rerun `build_runner` → Dart compiles against the new shape or
fails loudly.

## Features

- **TS composition just works.** Imports across files, `Object.fromEntries`,
  spreads, type narrowing via `as const` — all evaluated natively because
  the package uses Deno (a real TS runtime) as the evaluator, not a
  syntax-only parser.
- **Two templates out of the box.** `map` for raw data; `field_definitions`
  for opinionated per-fieldset `const <FieldDefinition>[...]` lists + a
  category routing switch. Adding a template is a ~50 line contribution.
- **Typed options.** `build.yaml` options are parsed through a typed config
  with explicit validation — misspelled keys or missing required values
  fail the build with a pointer to the offending line.
- **Dart-formatted output.** Runs `dart format --page-width 120` on the
  emitted file so diffs stay clean across developer runs.
- **Integrates where Dart already codegen's.** Drop into `dev_dependencies`
  alongside `freezed` and `json_serializable`; runs in the same
  `dart run build_runner build` invocation.

## How it stacks up

| | `ts_schema_codegen` | `quicktype` | `json_serializable` | tree-sitter TS |
|---|---|---|---|---|
| **Input format** | `.ts` source (evaluated) | JSON / JSON Schema / TS types | Dart annotations | `.ts` source (syntax only) |
| **Emits typed Dart values** (not just types) | ✓ | — | ✓ (from Dart) | would require reimplementing TS const-eval |
| **Runtime composition** (`Object.fromEntries`, spreads, imports) | ✓ | — | n/a | ✗ |
| **Requires Deno** | ✓ (v0.1) | — | — | — |

## Install

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.15
  ts_schema_codegen:
    git:
      url: https://github.com/Enraio/ts_schema_codegen
      ref: main
```

Also needs [Deno](https://deno.land) on `PATH`:

```bash
brew install deno
# or: curl -fsSL https://deno.land/install.sh | sh
```

## Configure

```yaml
# build.yaml
targets:
  $default:
    builders:
      ts_schema_codegen|ts_schema:
        enabled: true
        options:
          source: path/to/schema.ts         # required, relative to package root
          export: SCHEMA                     # default: "schema"
          template: field_definitions        # or "map" (default)
          field_class_import: package:your_app/field_definition.dart
          # deno: deno                       # override if not on PATH
```

## Run

```bash
dart run build_runner build
```

Output at `lib/ts_schema.g.dart`.

## Templates

### `map`

Generic. Emits the export as a nested `const Object? schema = {...}`.

```ts
export const CONFIG = { api: { baseUrl: 'https://...' }, flags: { a: true } };
```

becomes

```dart
const Object? schema = <String, Object?>{
  'api': <String, Object?>{'baseUrl': 'https://...'},
  'flags': <String, Object?>{'a': true},
};
```

Cast at the call site. Use when the schema doesn't fit a fieldset shape, or
when you want raw data and will parse it into your own types.

### `field_definitions`

Opinionated. For schemas shaped like `Record<fieldsetKey, FieldSet>` where
each `FieldSet` has `categories`, optional `subcategoryRoutes`, and a `fields`
list of `FieldDef`-shaped objects. Emits:

- one `const <fieldsetKey>Fields = <FieldDefinition>[...]` per fieldset
- a `getFieldsForCategoryGenerated(category, {subcategory})` routing function
- optional `common` fieldset appended to every other fieldset

You provide the `FieldDefinition` class via `field_class_import`. Recognized
properties on `FieldDef`: `id`, `type` (`string` → `FieldType.dropdown`,
`array` → `FieldType.multiSelect`, `text` → `FieldType.text`), `label`,
`options`, `hint`, `required`, `defaultValue`. Extra keys on `FieldDef` are
tolerated and ignored.

See [`example/`](example/) for a runnable end-to-end sample.

## Examples

Three runnable examples — open a folder, `dart pub get`, `dart run
build_runner build`, `dart run lib/main.dart`:

| Directory | Template | What it shows |
|---|---|---|
| [`example/`](example/) | `field_definitions` | Generic form schema (signup / feedback) with subcategory routing. The default walkthrough. |
| [`example/map_config/`](example/map_config/) | `map` | App config + feature flags — the lightweight path. |
| [`example/composed/`](example/composed/) | `field_definitions` | TS schema split across 4 files with shared traits, assembled via `Object.fromEntries`. The one that justifies picking Deno over a syntax-only parser. |

## Error surfaces

The build fails loudly when:

- **Deno not on `PATH`** — `Process.run` error with spawn failure
- **`source` file missing** — `ts_schema_codegen: source file not found at …`
- **Named `export` missing** — Deno side lists available exports
- **Export not JSON-serializable** (functions, circular refs) — `ts_schema_codegen: deno exited with code 5 …`
- **Malformed `build.yaml` options** — `ArgumentError` with the offending key

## Roadmap

- **v0.2** — bundle a WASM TS evaluator (swc/esbuild) so Deno becomes optional.
  Drop-in replacement inside `lib/src/deno_runner.dart`; API stays stable.
- **v0.3** — template registry. Users contribute their own emitters without
  forking.
- **pub.dev publish** once the API has settled and there's an external user
  running it in anger.

## Testing

```bash
dart test
```

45 tests covering:

- `TsSchemaConfig` validation (8) — required/default options, template
  cross-validation, error messages.
- Emitter output for both templates (24) — primitives, nested maps/lists,
  mixed-type lists, string escaping, Unicode, deep nesting, FieldType
  mapping, optional-prop forwarding, missing-prop rejection, extra-key
  tolerance, routing (subcategory precedence, category fallback,
  no-common-fieldset, insertion order).
- Deno runner integration (5) — real subprocess, happy path + four failure
  modes (missing file, missing export, non-JSON-serializable export,
  composed multi-file imports); skipped automatically if Deno isn't on
  `PATH`.
- Full pipeline (4) — TS file on disk → DenoRunner → emitter → Dart
  output, for realistic multi-fieldset schemas, the map template, ordering
  preservation, and composition via imports + `Object.fromEntries`.

## Contributing

PRs welcome. Start with the [examples](example/) to see the package in use,
then `lib/src/emitter.dart` is where most changes land — adding a new
template is a new function + a switch case in `lib/src/builder_impl.dart`.

## License

MIT.
