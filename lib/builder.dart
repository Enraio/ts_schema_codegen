/// Entry point consumed by build_runner.
///
/// Consumers wire this builder in their `build.yaml`:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       ts_schema_codegen|ts_schema:
///         enabled: true
///         options:
///           source: ../schema/index.ts
///           export: FIELD_SCHEMA
///           template: field_definitions
///           field_class_import: package:your_app/models/field_definition.dart
/// ```
///
/// Then run: `dart run build_runner build`.
library;

import 'package:build/build.dart';

import 'src/builder_impl.dart';
import 'src/config.dart';

/// Factory referenced from `build.yaml`.
Builder tsSchemaBuilder(BuilderOptions options) => TsSchemaBuilder(TsSchemaConfig.fromOptions(options.config));
