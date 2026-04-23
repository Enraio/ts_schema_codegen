/// Emits Dart source from a [SchemaIR] (for `field_definitions`) or raw
/// JSON (for `map`).
///
/// Two templates are supported:
///   * [emitMapTemplate]          — generic `const Object? schema = ...`
///                                  for any JSON-serializable value
///   * [emitFieldDefinitions]     — opinionated output for schemas parsed
///                                  into [SchemaIR]: per-fieldset
///                                  `const <FieldDefinition>[...]` lists +
///                                  a subcategory/category routing switch +
///                                  a `kFieldSets` registry
///
/// Both entry points return a Dart source string; the caller writes it to
/// an asset and runs `dart format`.
library;

import 'ir.dart';

const _header = '// GENERATED — DO NOT EDIT.';

/// Generic template: emit the schema as a nested `Object?`.
String emitMapTemplate({
  required Object? value,
  required String tsSourcePath,
  required String exportName,
}) {
  final buf = StringBuffer()
    ..writeln(_header)
    ..writeln('// Source: $tsSourcePath (export: $exportName)')
    ..writeln('// Regenerate: dart run build_runner build')
    ..writeln()
    ..writeln('const Object? schema = ${_literal(value)};')
    ..writeln();
  return buf.toString();
}

String _literal(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return value.toString();
  if (value is String) return _dartString(value);
  if (value is List) {
    if (value.isEmpty) return '<Object?>[]';
    final parts = value.map(_literal).join(', ');
    return '<Object?>[$parts]';
  }
  if (value is Map) {
    if (value.isEmpty) return '<String, Object?>{}';
    final entries = value.entries.map(
      (e) => '${_dartString(e.key.toString())}: ${_literal(e.value)}',
    );
    return '<String, Object?>{${entries.join(', ')}}';
  }
  throw StateError(
    'emit: cannot emit value of type ${value.runtimeType}: $value',
  );
}

String _dartString(String s) {
  final escaped = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}

// ---------------------------------------------------------------------------
// field_definitions template
// ---------------------------------------------------------------------------

/// Emits per-fieldset `FieldDefinition` const lists + a routing function +
/// a `kFieldSets` registry.
///
/// All shape interpretation lives in [parseFieldDefinitionsIR]; this
/// function trusts its typed [schema] argument and focuses on string
/// generation. That split keeps each concern testable on its own and
/// makes new templates purely additive.
String emitFieldDefinitions({
  required SchemaIR schema,
  required String fieldClassImport,
  required String tsSourcePath,
  required String exportName,
}) {
  final buf = StringBuffer()
    ..writeln(_header)
    ..writeln('// Source: $tsSourcePath (export: $exportName)')
    ..writeln('// Regenerate: dart run build_runner build')
    ..writeln()
    ..writeln("import '$fieldClassImport';")
    ..writeln()
    ..writeln(
      '/// Data carrier for the generated fieldset registry (`kFieldSets`).',
    )
    ..writeln('///')
    ..writeln('/// Provided by the generator so consumers can reflect on the')
    ..writeln(
      '/// schema at runtime — iterate [kFieldSets], build custom routing,',
    )
    ..writeln(
      '/// etc. — without depending on a consumer-authored wrapper class.',
    )
    ..writeln('class GeneratedFieldSet {')
    ..writeln('  final String label;')
    ..writeln('  final List<String> categories;')
    ..writeln('  final List<String> subcategoryRoutes;')
    ..writeln('  final List<FieldDefinition> fields;')
    ..writeln()
    ..writeln('  const GeneratedFieldSet({')
    ..writeln('    required this.label,')
    ..writeln('    required this.categories,')
    ..writeln('    this.subcategoryRoutes = const [],')
    ..writeln('    required this.fields,')
    ..writeln('  });')
    ..writeln('}')
    ..writeln();

  // Per-fieldset const lists. When a `common` fieldset exists, spread it
  // into every other fieldset so shared fields appear on every form.
  for (final fs in schema.fieldsets) {
    buf.writeln('const ${fs.key}Fields = <FieldDefinition>[');
    for (final field in fs.fields) {
      buf.writeln(_emitFieldDef(field));
    }
    if (schema.hasCommon && fs.key != 'common') {
      buf.writeln('  ...commonFields,');
    }
    buf.writeln('];');
    buf.writeln();
  }

  // Registry.
  buf
    ..writeln(
      '/// Registry of every fieldset emitted from the TS schema, keyed',
    )
    ..writeln(
      '/// by fieldset name. Reflectable — iterate [kFieldSets] to build',
    )
    ..writeln(
      '/// custom routing, UIs, or validation without regenerating Dart.',
    )
    ..writeln('const kFieldSets = <String, GeneratedFieldSet>{');
  for (final fs in schema.fieldsets) {
    buf.writeln("  '${_escape(fs.key)}': GeneratedFieldSet(");
    buf.writeln("    label: '${_escape(fs.label)}',");
    buf.writeln('    categories: ${_stringList(fs.categories)},');
    if (fs.subcategoryRoutes.isNotEmpty) {
      buf.writeln('    subcategoryRoutes: ${_stringList(fs.subcategoryRoutes)},');
    }
    buf.writeln('    fields: ${fs.key}Fields,');
    buf.writeln('  ),');
  }
  buf.writeln('};');
  buf.writeln();

  // Routing function.
  buf
    ..writeln('List<FieldDefinition> getFieldsForCategoryGenerated(')
    ..writeln('  String category, {')
    ..writeln('  String? subcategory,')
    ..writeln('}) {')
    ..writeln('  if (subcategory != null) {')
    ..writeln('    switch (subcategory.toLowerCase()) {');

  for (final fs in schema.fieldsets) {
    if (fs.subcategoryRoutes.isEmpty) continue;
    for (final r in fs.subcategoryRoutes) {
      buf.writeln("      case '${_escape(r)}':");
    }
    buf.writeln('        return ${fs.key}Fields;');
  }

  buf
    ..writeln('    }')
    ..writeln('  }')
    ..writeln()
    ..writeln('  switch (category.toLowerCase()) {');

  for (final fs in schema.fieldsets) {
    if (fs.key == 'common') continue;

    // Backward-compat: a fieldset with no top-level `categories` but at
    // least one subcategory route still matches its own key as a
    // category. Mirrors the original emitter's behavior.
    final cases = <String>{...fs.categories};
    if (cases.isEmpty && fs.subcategoryRoutes.isNotEmpty) {
      cases.add(fs.key);
    }
    if (cases.isEmpty) continue;

    for (final c in cases) {
      buf.writeln("    case '${_escape(c)}':");
    }
    buf.writeln('      return ${fs.key}Fields;');
  }

  buf.writeln('    default:');
  if (schema.hasCommon) {
    buf.writeln('      return commonFields;');
  } else {
    buf.writeln('      return const <FieldDefinition>[];');
  }
  buf
    ..writeln('  }')
    ..writeln('}')
    ..writeln();

  return buf.toString();
}

String _emitFieldDef(FieldDefIR f) {
  final lines = <String>[
    "    id: '${_escape(f.id)}'",
    "    label: '${_escape(f.label)}'",
    '    type: ${_fieldType(f.kind)}',
  ];
  if (f.options != null && f.options!.isNotEmpty) {
    final items = f.options!.map((o) => "'${_escape(o)}'").join(', ');
    lines.add('    options: [$items]');
  }
  if (f.hint != null && f.hint!.isNotEmpty) {
    lines.add("    hint: '${_escape(f.hint!)}'");
  }
  if (f.required) {
    lines.add('    required: true');
  }
  if (f.defaultValue != null && f.defaultValue!.isNotEmpty) {
    lines.add("    defaultValue: '${_escape(f.defaultValue!)}'");
  }
  return '  FieldDefinition(\n${lines.join(',\n')},\n  ),';
}

String _fieldType(FieldKind kind) {
  switch (kind) {
    case FieldKind.dropdown:
      return 'FieldType.dropdown';
    case FieldKind.multiSelect:
      return 'FieldType.multiSelect';
    case FieldKind.text:
      return 'FieldType.text';
  }
}

String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

/// Emit a `List<String>` as a Dart literal. Called only from inside a
/// `const` context (`const kFieldSets = {...}`) so no leading `const`
/// prefix — that would trip `unnecessary_const`.
String _stringList(List<String> value) {
  if (value.isEmpty) return '<String>[]';
  final items = value.map((e) => "'${_escape(e)}'").join(', ');
  return '[$items]';
}
