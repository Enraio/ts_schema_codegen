# example/multi — multiple schemas in one build

Demonstrates the multi-schema config ([#5]): one `build.yaml`, two outputs.

## Layout

```
example/multi/
  pubspec.yaml
  build.yaml                    # declares both schema entries
  schema/
    forms.ts                    # field_definitions shape
    config.ts                   # raw data (map template)
  lib/
    field_definition.dart       # consumer-owned FieldDefinition class
    main.dart                   # reads both generated files
    forms.g.dart                # GENERATED
    config.g.dart               # GENERATED
```

The `build.yaml` options:

```yaml
schemas:
  - source: schema/forms.ts
    export: FORMS
    template: field_definitions
    field_class_import: package:<pkg>/field_definition.dart
    output: lib/forms.g.dart
  - source: schema/config.ts
    export: CONFIG
    template: map
    output: lib/config.g.dart
```

## Run

```bash
cd example/multi
dart pub get
dart run build_runner build
dart run lib/main.dart
```

Expected output:

```
Forms: signup
  - email (text) *
  - role (dropdown)

Config v1.0.0
API: https://api.example.com
  dark_mode: on
  beta_search: off
```

## Notes

- **Output paths must start with `lib/` and end with `.dart`** — that's a
  `build_runner` constraint, not a package one. Builder config validates
  both up front.
- **Outputs must be unique.** Collisions surface as an `ArgumentError` at
  config-parse time ("duplicate output path"), not as a silent last-write-wins.
- **Different templates per entry are fine.** You can mix `map` and
  `field_definitions` freely.

[#5]: https://github.com/Enraio/ts_schema_codegen/issues/5
