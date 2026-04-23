/// Options accepted from the consumer's `build.yaml` `options` block.
///
/// Supports two shapes:
///
/// **Multi-schema** (preferred for monorepos / multiple schemas):
///
/// ```yaml
/// options:
///   schemas:
///     - source: schema/forms.ts
///       export: FORMS
///       template: field_definitions
///       field_class_import: package:app/field_definition.dart
///       output: lib/forms.g.dart
///     - source: schema/config.ts
///       export: CONFIG
///       template: map
///       output: lib/config.g.dart
///   deno: deno  # optional, package-level
/// ```
///
/// **Single-schema** (legacy, still accepted):
///
/// ```yaml
/// options:
///   source: schema/index.ts
///   export: FIELD_SCHEMA
///   template: field_definitions
///   field_class_import: package:app/field_definition.dart
///   # output defaults to lib/ts_schema.g.dart for backward compat
/// ```
///
/// The `fromOptions` factory auto-detects the shape by the presence of the
/// `schemas` key. Validation errors surface with the offending key in the
/// message so users can map them back to their build.yaml directly.
class TsSchemaConfig {
  const TsSchemaConfig({required this.schemas, required this.deno});

  /// One or more schemas to process in this build. Guaranteed non-empty.
  final List<SchemaEntry> schemas;

  /// Command used to invoke Deno. Defaults to `deno`. Override to e.g.
  /// `/opt/homebrew/bin/deno` if Deno isn't on PATH. Package-level — the
  /// same Deno is used for every schema.
  final String deno;

  factory TsSchemaConfig.fromOptions(Map<String, dynamic> opts) {
    final deno = (opts['deno'] as String?) ?? 'deno';
    final rawSchemas = opts['schemas'];

    if (rawSchemas != null) {
      if (rawSchemas is! List) {
        throw ArgumentError(
          'ts_schema_codegen: "schemas" option must be a list.',
        );
      }
      if (rawSchemas.isEmpty) {
        throw ArgumentError(
          'ts_schema_codegen: "schemas" option must contain at least one '
          'schema entry.',
        );
      }
      final schemas = <SchemaEntry>[];
      for (var i = 0; i < rawSchemas.length; i++) {
        final raw = rawSchemas[i];
        if (raw is! Map) {
          throw ArgumentError(
            'ts_schema_codegen: schemas[$i] must be a map.',
          );
        }
        schemas.add(
          SchemaEntry._fromMap(
            Map<String, dynamic>.from(raw),
            contextPath: 'schemas[$i]',
          ),
        );
      }
      _validateUniqueOutputs(schemas);
      return TsSchemaConfig(schemas: schemas, deno: deno);
    }

    // Single-schema (legacy) shape. Output defaults to lib/ts_schema.g.dart
    // so existing consumers of 0.1.x keep working without touching build.yaml.
    if (!opts.containsKey('source')) {
      throw ArgumentError(
        'ts_schema_codegen: "source" option is required (or use the '
        '"schemas" list form for multi-schema).',
      );
    }
    final entry = SchemaEntry._fromMap(
      {
        'source': opts['source'],
        'export': opts['export'],
        'template': opts['template'],
        'field_class_import': opts['field_class_import'],
        'output': opts['output'] ?? 'lib/ts_schema.g.dart',
      },
      contextPath: '',
    );
    return TsSchemaConfig(schemas: [entry], deno: deno);
  }

  static void _validateUniqueOutputs(List<SchemaEntry> schemas) {
    final seen = <String>{};
    for (final s in schemas) {
      if (!seen.add(s.output)) {
        throw ArgumentError(
          'ts_schema_codegen: duplicate output path "${s.output}" — every '
          'schema entry must write to a distinct file.',
        );
      }
    }
  }
}

/// A single schema the builder should process.
class SchemaEntry {
  const SchemaEntry({
    required this.source,
    required this.export,
    required this.template,
    required this.fieldClassImport,
    required this.output,
  });

  /// Path to the TypeScript entry file, relative to the consuming package root.
  final String source;

  /// Name of the top-level export on the TS module to extract.
  /// Defaults to `schema`.
  final String export;

  /// Template controlling the Dart output shape: `map` or `field_definitions`.
  final String template;

  /// Package-qualified import path for the `FieldDefinition` class referenced
  /// by the `field_definitions` template. `null` for `map`.
  final String? fieldClassImport;

  /// Output path relative to the consuming package root. Must start with
  /// `lib/` and end with `.dart` (build_runner constraint — generated
  /// outputs can only live under `lib/`).
  final String output;

  factory SchemaEntry._fromMap(
    Map<String, dynamic> raw, {
    required String contextPath,
  }) {
    final where = contextPath.isEmpty ? '' : ' (at $contextPath)';

    final source = raw['source'];
    if (source is! String || source.isEmpty) {
      throw ArgumentError(
        'ts_schema_codegen: "source"$where is required and must be a '
        'non-empty string (path to the TypeScript entry file).',
      );
    }

    final template = (raw['template'] as String?) ?? 'map';
    if (template != 'map' && template != 'field_definitions') {
      throw ArgumentError(
        'ts_schema_codegen: unknown template "$template"$where. '
        'Supported: map, field_definitions.',
      );
    }

    final fieldClassImport = raw['field_class_import'] as String?;
    if (template == 'field_definitions' &&
        (fieldClassImport == null || fieldClassImport.isEmpty)) {
      throw ArgumentError(
        'ts_schema_codegen: template=field_definitions$where requires '
        '"field_class_import" (package-qualified import of FieldDefinition).',
      );
    }

    final output = raw['output'];
    if (output is! String || output.isEmpty) {
      throw ArgumentError(
        'ts_schema_codegen: "output"$where is required and must be a '
        'non-empty string (e.g. "lib/schema.g.dart").',
      );
    }
    if (!output.startsWith('lib/')) {
      throw ArgumentError(
        'ts_schema_codegen: "output"$where must start with "lib/" — '
        'build_runner only allows generated files under lib/. Got "$output".',
      );
    }
    if (!output.endsWith('.dart')) {
      throw ArgumentError(
        'ts_schema_codegen: "output"$where must end with ".dart". '
        'Got "$output".',
      );
    }

    return SchemaEntry(
      source: source,
      export: (raw['export'] as String?) ?? 'schema',
      template: template,
      fieldClassImport: fieldClassImport,
      output: output,
    );
  }
}
