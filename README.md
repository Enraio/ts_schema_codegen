# ts_schema_codegen

> Keep your schema in TypeScript. Consume it from Dart.

A `build_runner` builder that evaluates a TypeScript module at build time and
emits typed Dart constants. Your TS stays the source of truth — the Dart
side breaks the build when TS drifts, instead of silently going stale.

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

## 60-second tour

**1. Your TS source of truth** (`schema.ts`):

```ts
export const FORMS = {
  signup: {
    label: 'Signup',
    categories: ['signup'],
    fields: [
      { id: 'email', type: 'text', label: 'Email', required: true },
      { id: 'role', type: 'string', label: 'Role',
        options: ['Engineer', 'Designer', 'Other'] },
    ],
  },
};
```

**2. Generated Dart** (`lib/ts_schema.g.dart`, after `dart run build_runner build`):

```dart
// GENERATED — DO NOT EDIT.
import 'package:your_app/field_definition.dart';

const signupFields = <FieldDefinition>[
  FieldDefinition(id: 'email', label: 'Email', type: FieldType.text, required: true),
  FieldDefinition(id: 'role', label: 'Role', type: FieldType.dropdown,
    options: ['Engineer', 'Designer', 'Other']),
];

List<FieldDefinition> getFieldsForCategoryGenerated(String category, {String? subcategory}) {
  switch (category.toLowerCase()) {
    case 'signup':
      return signupFields;
    default:
      return const <FieldDefinition>[];
  }
}
```

**3. Consumer code** (unchanged on every regeneration):

```dart
final fields = getFieldsForCategoryGenerated('signup');
for (final f in fields) {
  // render f.label as a form input of type f.type, etc.
}
```

Change the TS → rerun `build_runner` → Dart compiles against the new shape
or fails loudly. No hand-sync, no checked-in JSON.

## Why

A backend and a Flutter app often need to agree on the same shape of data —
form fields, feature flags, item categories, design tokens. Maintaining two
copies (one in TS, one hand-translated in Dart) drifts the moment the backend
changes. Checking in a JSON intermediate works, but it's a manual step and PR
reviewers can't tell whether the JSON matches the TS source.

This package makes the Dart side a build-time derivative of the TS source.

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

### 1. Install Deno

The builder shells out to Deno to evaluate your TS. v0.1 requires it at build
time (bundled WASM evaluator is on the roadmap for v0.2).

**macOS / Linux:**
```bash
brew install deno
# or: curl -fsSL https://deno.land/install.sh | sh
```

**Windows:**
```powershell
irm https://deno.land/install.ps1 | iex
```

Verify:
```bash
deno --version
```

### 2. Add the package

```bash
dart pub add --dev ts_schema_codegen
dart pub add --dev build_runner
```

Or in `pubspec.yaml`:

```yaml
dev_dependencies:
  build_runner: ^2.4.15
  ts_schema_codegen: ^0.1.0
```

### 3. Configure the builder

Create (or append to) `build.yaml` in your package root:

```yaml
targets:
  $default:
    builders:
      ts_schema_codegen|ts_schema:
        enabled: true
        options:
          source: schema/index.ts                # required — path to TS entry, relative to package root
          export: FORMS                          # default: "schema"
          template: field_definitions            # or "map" (default)
          field_class_import: package:your_app/field_definition.dart
          # deno: deno                           # override if not on PATH
```

### 4. Provide a `FieldDefinition` class

The `field_definitions` template emits references to `FieldDefinition` and
`FieldType`. Define them wherever you like and point `field_class_import` at
the file:

```dart
// lib/field_definition.dart
enum FieldType { dropdown, multiSelect, text, number, slider, toggle }

class FieldDefinition {
  final String id;
  final String label;
  final FieldType type;
  final List<String>? options;
  final String? hint;
  final bool required;
  final Object? defaultValue;

  const FieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.hint,
    this.required = false,
    this.defaultValue,
  });
}
```

Using the `map` template? Skip this step.

### 5. Generate

```bash
dart run build_runner build
```

Output lands at `lib/ts_schema.g.dart`. Add it to your `.gitignore` if you
prefer to regenerate on every checkout, or commit it to shortcut the
regen-on-pub-get cycle — both approaches are common.

For continuous regen during development:

```bash
dart run build_runner watch
```

## Templates

### `map`

Generic. Emits the export as a nested `const Object? schema = {...}`.

**Input:**
```ts
export const CONFIG = {
  version: '2.3.1',
  api: { baseUrl: 'https://api.example.com', timeoutMs: 30000 },
  features: { dark_mode: true, beta: false },
  locales: ['en', 'es', 'fr'],
};
```

**Generated output:**
```dart
const Object? schema = <String, Object?>{
  'version': '2.3.1',
  'api': <String, Object?>{'baseUrl': 'https://api.example.com', 'timeoutMs': 30000},
  'features': <String, Object?>{'dark_mode': true, 'beta': false},
  'locales': <Object?>['en', 'es', 'fr'],
};
```

**Call site:**
```dart
import 'ts_schema.g.dart';

final cfg = schema as Map<String, Object?>;
final baseUrl = (cfg['api'] as Map)['baseUrl'] as String;
final darkMode = (cfg['features'] as Map)['dark_mode'] as bool;
```

Use `map` when your schema doesn't fit a fieldset shape, or when you want raw
data and will parse it into your own types.

### `field_definitions`

Opinionated. For schemas shaped like `Record<fieldsetKey, FieldSet>` where
each `FieldSet` has `categories`, optional `subcategoryRoutes`, and a
`fields` list of `FieldDef`-shaped objects.

**Input:**
```ts
export const SCHEMA = {
  common: {
    label: 'COMMON',
    categories: [],
    fields: [
      { id: 'consent', type: 'string', label: 'I agree',
        options: ['Yes', 'No'], required: true },
    ],
  },
  ticket: {
    label: 'TICKET',
    categories: ['ticket'],
    subcategoryRoutes: ['bug', 'feature-request'],
    fields: [
      { id: 'severity', type: 'string', label: 'Severity',
        options: ['Low', 'Medium', 'High', 'Critical'] },
    ],
  },
};
```

**Generated output:** per-fieldset const lists + routing function:
```dart
const commonFields = <FieldDefinition>[
  FieldDefinition(id: 'consent', label: 'I agree', type: FieldType.dropdown,
    options: ['Yes', 'No'], required: true),
];

const ticketFields = <FieldDefinition>[
  FieldDefinition(id: 'severity', label: 'Severity', type: FieldType.dropdown,
    options: ['Low', 'Medium', 'High', 'Critical']),
  ...commonFields, // common appended to every non-common fieldset
];

List<FieldDefinition> getFieldsForCategoryGenerated(String category, {String? subcategory}) {
  if (subcategory != null) {
    switch (subcategory.toLowerCase()) {
      case 'bug':
      case 'feature-request':
        return ticketFields;
    }
  }
  switch (category.toLowerCase()) {
    case 'ticket':
      return ticketFields;
    default:
      return commonFields;
  }
}
```

**Call site:**
```dart
import 'ts_schema.g.dart';

// Direct access to a specific fieldset:
for (final f in ticketFields) { /* render */ }

// Category routing (with optional subcategory override):
final fields = getFieldsForCategoryGenerated('anything', subcategory: 'bug');
```

Recognized `FieldDef` properties: `id`, `type` (`string` → `FieldType.dropdown`,
`array` → `FieldType.multiSelect`, `text` → `FieldType.text`), `label`,
`options`, `hint`, `required`, `defaultValue`. Extra keys on `FieldDef` are
tolerated and ignored — carry whatever metadata you want, the emitter only
reads what it knows.

## Examples

Three runnable examples under `example/` — open a folder, `dart pub get`,
`dart run build_runner build`, `dart run lib/main.dart`:

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

- **v0.2** — bundle a WASM TS evaluator (swc/esbuild) so Deno becomes
  optional. Drop-in replacement inside `lib/src/deno_runner.dart`; API stays
  stable.
- **v0.3** — template registry. Users contribute their own emitters without
  forking.

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

MIT — see [LICENSE](LICENSE).
