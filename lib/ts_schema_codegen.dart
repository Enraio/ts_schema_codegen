/// Public entry point for `ts_schema_codegen`.
///
/// This package is a `build_runner` plugin — the Builder factory lives in
/// `builder.dart` and is referenced from the consumer's `build.yaml`, not
/// imported at runtime. This file re-exports `builder.dart` so tools that
/// look for `package:<name>/<name>.dart` (including pub.dev's publishing
/// conventions) find something sensible here.
library;

export 'builder.dart';
