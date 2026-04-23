# Flutter live demo — `ts_schema_codegen`

A three-pane Flutter web app that shows the full pipeline at a glance:

1. **TypeScript schema** (`schema/index.ts`) — the source of truth.
2. **Generated Dart** (`lib/ts_schema.g.dart`) — produced by
   `ts_schema_codegen` at build time.
3. **Live form** — the generated `FieldDefinition` constants rendered as
   real Flutter widgets with validation + submit.

Use the chips at the top (ACCOUNT / FEEDBACK / TICKET) to switch between
fieldsets. Submitting a valid form renders the payload underneath.

## Run locally

```bash
# from example/flutter_forms
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# refresh the in-app code viewer assets so the displayed .g.dart matches
cp schema/index.ts assets/schema.ts
cp lib/ts_schema.g.dart assets/ts_schema.g.dart

flutter run -d chrome
```

## Layout

```
flutter_forms/
├── schema/index.ts             ← hand-written TS schema
├── build.yaml                  ← wires ts_schema_codegen → .g.dart
├── lib/
│   ├── field_definition.dart   ← user-owned model the generator targets
│   ├── ts_schema.g.dart        ← GENERATED — don't edit
│   ├── form_renderer.dart      ← renders fields as widgets
│   ├── code_viewer.dart        ← syntax-highlighted read-only source view
│   └── main.dart               ← app shell + 3-pane layout
└── assets/
    ├── schema.ts               ← copy displayed in the UI
    └── ts_schema.g.dart        ← copy displayed in the UI
```

The `assets/` copies exist only so the deployed web app can read the
source files through `rootBundle`. They are refreshed from the originals
during the GitHub Pages build.

## Deployed

This example is auto-deployed to GitHub Pages on every push to `main` —
see `.github/workflows/deploy-example.yml` at the repo root.
