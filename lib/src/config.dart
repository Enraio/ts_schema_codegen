/// Options accepted from the consumer's `build.yaml` `options` block.
///
/// Surfaced as a typed object instead of reading the raw map in multiple
/// places so missing/invalid config fails loudly with a pointer to the
/// offending key.
class TsSchemaConfig {
  const TsSchemaConfig({
    required this.source,
    required this.export,
    required this.deno,
    required this.template,
    required this.fieldClassImport,
  });

  /// Path to the TypeScript entry file, relative to the consuming package root.
  /// e.g. `../supabase/functions/_shared/schema/index.ts`.
  final String source;

  /// Name of the top-level export on the TS module to extract.
  /// Defaults to `schema`.
  final String export;

  /// Command used to invoke Deno. Defaults to `deno`.
  /// Override to e.g. `/opt/homebrew/bin/deno` if Deno isn't on PATH.
  final String deno;

  /// Template controlling the Dart output shape. Supported:
  ///   - `map`                 — emits `const Map<String, dynamic> schema = {...}`
  ///   - `field_definitions`   — emits `FieldDefinition` const lists per
  ///                             fieldset + a `switch` routing function
  ///                             (outfii-shaped; requires [fieldClassImport]).
  final String template;

  /// Package-qualified import path for the class referenced by the
  /// `field_definitions` template. Ignored for the `map` template.
  /// e.g. `package:outfii/core/models/field_definition.dart`.
  final String? fieldClassImport;

  factory TsSchemaConfig.fromOptions(Map<String, dynamic> opts) {
    final source = opts['source'];
    if (source is! String || source.isEmpty) {
      throw ArgumentError(
        'ts_schema_codegen: "source" option is required and must be a string '
        '(path to the TypeScript entry file).',
      );
    }
    final template = (opts['template'] as String?) ?? 'map';
    if (template != 'map' && template != 'field_definitions') {
      throw ArgumentError(
        'ts_schema_codegen: unknown template "$template". '
        'Supported: map, field_definitions.',
      );
    }
    final fieldClassImport = opts['field_class_import'] as String?;
    if (template == 'field_definitions' && (fieldClassImport == null || fieldClassImport.isEmpty)) {
      throw ArgumentError(
        'ts_schema_codegen: template=field_definitions requires '
        '"field_class_import" (package-qualified import of FieldDefinition).',
      );
    }
    return TsSchemaConfig(
      source: source,
      export: (opts['export'] as String?) ?? 'schema',
      deno: (opts['deno'] as String?) ?? 'deno',
      template: template,
      fieldClassImport: fieldClassImport,
    );
  }
}
