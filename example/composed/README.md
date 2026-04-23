# example/composed — multi-file TS composition

The value proposition over a syntax-only parser: **real TS composition
works**. The schema is split across 4 files, uses shared traits, and
assembles via `Object.fromEntries`. Deno evaluates it as TypeScript
(which it is), so every import, spread, and runtime expression resolves
correctly before we see the JSON.

## Layout

```
schema/
  types.ts      # shared FieldDef / FieldSet type declarations
  traits.ts    # `identifiable` + `timestamped` — reusable field groups
  user.ts      # user fieldset, composes identifiable + timestamped
  project.ts   # project fieldset, composes the same traits
  index.ts     # exports SCHEMA = Object.fromEntries([...fieldsets])
```

## Run

```bash
cd example/composed
dart pub get
dart run build_runner build
dart run lib/main.dart
```

Expected output:

```
userFields (6):
  - id (text) *
  - name (text) *
  - email (text) *
  - plan (dropdown)
  - created_at (text)
  - updated_at (text)

projectFields (6):
  - id (text) *
  - name (text) *
  - visibility (dropdown)
  - tags (multiSelect)
  - created_at (text)
  - updated_at (text)
```

Both fieldsets pull `id`/`name` from the `identifiable` trait and
`created_at`/`updated_at` from `timestamped` — defined once, reused twice.
Change `traits.ts` and both fieldsets update on the next build.

## Why this works with ts_schema_codegen

The Builder shells out to Deno, which is a full TypeScript runtime. It
resolves imports across files, evaluates `Object.fromEntries(...)`, expands
spreads, and only then JSON-serializes the result. A syntax-only parser
(tree-sitter, etc.) would need to reimplement module resolution + const
evaluation to reach the same point — that's ~40% of a TS compiler.
