# example — dynamic form

A generic survey/form schema using the `field_definitions` template. Shows
the standard pattern: one fieldset per form kind, optional subcategory
routing, shared `common` fields appended to every form.

## Run

```bash
cd example
dart pub get
dart run build_runner build
dart run lib/main.dart
```

Expected output:

```
── form(signup) ────────────────────────
  Email *  (text)
  Primary role  (dropdown)  [Engineer | Designer | Product | Other]
  Notifications  (multiSelect)  [Email | Push | SMS]
  I agree to the terms *  (dropdown)  [Yes | No]

── form(feedback) ────────────────────────
  Severity  (dropdown)  [Low | Medium | High | Critical]
  What happened? *  (text)
  Tags  (multiSelect)  [ui | backend | performance | docs]
  I agree to the terms *  (dropdown)  [Yes | No]

── form(other / bug) ────────────────────────
  Severity  (dropdown)  [Low | Medium | High | Critical]
  What happened? *  (text)
  Tags  (multiSelect)  [ui | backend | performance | docs]
  I agree to the terms *  (dropdown)  [Yes | No]
```

## See also

- [`map_config/`](map_config) — same package with the `map` template for
  schemas that don't fit a fieldset shape.
- [`composed/`](composed) — TS schema split across multiple files,
  composed via imports.
