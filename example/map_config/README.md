# example/map_config — `map` template

The lightest-weight template. Emits the TS export as a nested
`const Object? schema` — just data, no opinions about structure. Use this
when your schema doesn't fit the fieldset shape, or when you want to parse
it into your own types at runtime.

## Run

```bash
cd example/map_config
dart pub get
dart run build_runner build
dart run lib/main.dart
```

Expected output:

```
Config v2.3.1
API: https://api.example.com

Feature flags:
  dark_mode: on (rollout: 100%)
  new_dashboard: off (rollout: 10%)
  experimental_search: on (rollout: 50%)
```

## Generated output

`lib/ts_schema.g.dart` contains:

```dart
const Object? schema = <String, Object?>{
  'version': '2.3.1',
  'api': <String, Object?>{
    'baseUrl': 'https://api.example.com',
    'timeoutMs': 30000,
    // ...
  },
  // ...
};
```

All nesting is preserved. Booleans, numbers, nulls, strings, arrays, and
objects survive the roundtrip; functions and circular refs fail the build
loudly.
