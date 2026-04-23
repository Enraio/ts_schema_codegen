/// Emits Dart source from the JSON representation of a TS schema.
///
/// Two templates are supported:
///   * [emitMapTemplate]          — generic `const Map<String, dynamic>`
///   * [emitFieldDefinitions]     — opinionated output for schemas shaped
///                                  like outfii's `FIELD_SCHEMA`: per-fieldset
///                                  `const <FieldDefinition>[...]` lists +
///                                  a subcategory/category routing switch.
///
/// Both entry points return a Dart source string; the caller is responsible
/// for writing it to the asset and running `dart format`.
library;

const _header = '// GENERATED — DO NOT EDIT.';

/// Generic template: emit the schema as a nested `Map<String, dynamic>`.
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
  // Match the JavaScript generator's escaping: backslash, single-quote.
  final escaped = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  return "'$escaped'";
}

// ---------------------------------------------------------------------------
// field_definitions template — outfii-shaped.
// ---------------------------------------------------------------------------

/// Emits outfii-style `FieldDefinition` constants + a category routing
/// function. Expects [schema] to have this JSON shape (produced by outfii's
/// `FIELD_SCHEMA` export):
///
/// ```
/// {
///   "<fieldsetKey>": {
///     "label": string,
///     "categories": string[],
///     "subcategoryRoutes"?: string[],
///     "fields": [
///       {
///         "id": string,
///         "type": "string" | "array" | "text",
///         "label": string,
///         "options"?: string[],
///         "hint"?: string,
///         "required"?: boolean,
///         "defaultValue"?: string,
///         ...  // other keys are tolerated and ignored by this template
///       }
///     ]
///   }
/// }
/// ```
///
/// The generated symbols are public (no leading underscore) so consumers
/// can import them as a standalone library. Hand-written logic (value
/// normalization, AI hint rendering, etc.) sits alongside in a separate
/// host file and delegates to [getFieldsForCategoryGenerated].
String emitFieldDefinitions({
  required Object? schema,
  required String fieldClassImport,
  required String tsSourcePath,
  required String exportName,
}) {
  if (schema is! Map) {
    throw StateError(
      'emitFieldDefinitions: expected Map at schema root, got '
      '${schema.runtimeType}.',
    );
  }
  final fieldsets = Map<String, Map<String, Object?>>.fromEntries(
    schema.entries.map((e) {
      final v = e.value;
      if (v is! Map) {
        throw StateError(
          'emitFieldDefinitions: fieldset "${e.key}" is not an object.',
        );
      }
      return MapEntry(e.key.toString(), Map<String, Object?>.from(v));
    }),
  );

  final hasCommon = fieldsets.containsKey('common');

  final buf = StringBuffer()
    ..writeln(_header)
    ..writeln('// Source: $tsSourcePath (export: $exportName)')
    ..writeln('// Regenerate: dart run build_runner build')
    ..writeln()
    ..writeln("import '$fieldClassImport';")
    ..writeln();

  // Emit one `const <key>Fields` list per fieldset. When a `common`
  // fieldset exists, spread it into every other fieldset so common
  // fields (e.g. consent, timestamps) appear on every form.
  for (final entry in fieldsets.entries) {
    final key = entry.key;
    final fields = entry.value['fields'];
    if (fields is! List) {
      throw StateError(
        'emitFieldDefinitions: fieldset "$key" has no "fields" list.',
      );
    }
    buf.writeln('const ${key}Fields = <FieldDefinition>[');
    for (final field in fields) {
      if (field is! Map) {
        throw StateError(
          'emitFieldDefinitions: fieldset "$key" contains non-object field.',
        );
      }
      buf.writeln(_emitFieldDef(Map<String, Object?>.from(field)));
    }
    if (hasCommon && key != 'common') {
      buf.writeln('  ...commonFields,');
    }
    buf.writeln('];');
    buf.writeln();
  }

  // Emit the routing function.
  buf
    ..writeln(
      'List<FieldDefinition> getFieldsForCategoryGenerated(',
    )
    ..writeln('  String category, {')
    ..writeln('  String? subcategory,')
    ..writeln('}) {')
    ..writeln('  if (subcategory != null) {')
    ..writeln('    switch (subcategory.toLowerCase()) {');

  for (final entry in fieldsets.entries) {
    final routes = entry.value['subcategoryRoutes'];
    if (routes is! List || routes.isEmpty) continue;
    for (final r in routes) {
      buf.writeln("      case '${_escape(r.toString())}':");
    }
    buf.writeln('        return ${entry.key}Fields;');
  }

  buf
    ..writeln('    }')
    ..writeln('  }')
    ..writeln()
    ..writeln('  switch (category.toLowerCase()) {');

  for (final entry in fieldsets.entries) {
    if (entry.key == 'common') continue;
    final categories = entry.value['categories'];
    final cases = <String>{};
    if (categories is List) {
      for (final c in categories) {
        cases.add(c.toString());
      }
    }
    // Categories-empty fieldsets (historically `watch`, `fragrance` under
    // the legacy schema) still match on the key itself if they have
    // subcategory routes. Preserve that behavior.
    final subRoutes = entry.value['subcategoryRoutes'];
    if (cases.isEmpty && subRoutes is List && subRoutes.isNotEmpty) {
      cases.add(entry.key);
    }
    if (cases.isEmpty) continue;
    for (final c in cases) {
      buf.writeln("    case '${_escape(c)}':");
    }
    buf.writeln('      return ${entry.key}Fields;');
  }

  // Default branch: return common fields if a common fieldset exists,
  // otherwise an empty list. Consumers that rely on "common fallback"
  // behavior should always include a `common` fieldset in their TS.
  buf.writeln('    default:');
  if (hasCommon) {
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

String _emitFieldDef(Map<String, Object?> f) {
  final lines = <String>[];
  final id = f['id'];
  final label = f['label'];
  final type = f['type'];
  if (id is! String || label is! String || type is! String) {
    throw StateError(
      'emitFieldDefinitions: field is missing id/label/type: $f',
    );
  }
  lines.add("    id: '${_escape(id)}'");
  lines.add("    label: '${_escape(label)}'");
  lines.add('    type: ${_fieldType(type)}');

  final options = f['options'];
  if (options is List && options.isNotEmpty) {
    final items = options.map((o) => "'${_escape(o.toString())}'").join(', ');
    lines.add('    options: [$items]');
  }
  final hint = f['hint'];
  if (hint is String && hint.isNotEmpty) {
    lines.add("    hint: '${_escape(hint)}'");
  }
  final required = f['required'];
  if (required == true) {
    lines.add('    required: true');
  }
  final defaultValue = f['defaultValue'];
  if (defaultValue is String && defaultValue.isNotEmpty) {
    lines.add("    defaultValue: '${_escape(defaultValue)}'");
  }

  return '  FieldDefinition(\n${lines.join(',\n')},\n  ),';
}

String _fieldType(String t) {
  switch (t) {
    case 'string':
      return 'FieldType.dropdown';
    case 'array':
      return 'FieldType.multiSelect';
    case 'text':
      return 'FieldType.text';
    default:
      return 'FieldType.text';
  }
}

String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
