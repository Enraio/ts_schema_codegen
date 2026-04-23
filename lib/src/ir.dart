/// Intermediate representation (IR) between the Deno JSON and the emitter.
///
/// Why: the raw JSON from Deno is a nested `Object?` — every emitter function
/// that wants to touch it has to re-do `is! Map` / `is! List` checks and
/// key lookups. Splitting that work out into [parseFieldDefinitionsIR]
/// produces typed classes emitters can trust, and gives us one canonical
/// place that answers "is this a valid `field_definitions` schema?"
///
/// The Deno side already validates the shape for `field_definitions` (see
/// [#3](https://github.com/Enraio/ts_schema_codegen/issues/3)). The Dart
/// parser re-validates because (a) it's cheap, (b) it produces typed IR
/// regardless, and (c) it's a safety net if the Deno validator ever misses
/// a case.
///
/// IR is specific to the `field_definitions` template. The `map` template
/// doesn't need one — it emits a raw nested map literal straight from the
/// JSON, with no shape expectation to enforce.
library;

/// Kind of input a [FieldDefIR] describes. Mirrors the three TS `type`
/// values (`'string'` / `'array'` / `'text'`) but under names that match
/// what the generated Dart code does with them — a dropdown for `string`,
/// a multi-select for `array`, a freeform text input for `text`.
enum FieldKind {
  dropdown,
  multiSelect,
  text,
}

/// The full parsed schema — an ordered list of fieldsets plus a flag for
/// whether a `common` fieldset exists (the emitter needs that to decide
/// whether to append `...commonFields` to non-common fieldsets).
class SchemaIR {
  const SchemaIR({
    required this.fieldsets,
    required this.hasCommon,
  });

  /// Fieldsets in TS-source insertion order. `common`, if present, may
  /// appear anywhere in the list — the emitter handles that.
  final List<FieldSetIR> fieldsets;

  /// True iff a fieldset with key `'common'` exists. Cached so the
  /// emitter doesn't have to re-scan.
  final bool hasCommon;
}

class FieldSetIR {
  const FieldSetIR({
    required this.key,
    required this.label,
    required this.categories,
    required this.subcategoryRoutes,
    required this.fields,
  });

  /// Fieldset identifier from the TS schema (e.g. `'signup'`, `'watch'`).
  /// Becomes the Dart variable prefix: `signupFields`, `watchFields`.
  final String key;

  /// Display label (e.g. `'SIGNUP'`).
  final String label;

  /// Top-level categories that route to this fieldset.
  final List<String> categories;

  /// Subcategory values that route here (checked before the category
  /// switch). Always a list — empty if the TS omitted the key.
  final List<String> subcategoryRoutes;

  /// Fields in declaration order.
  final List<FieldDefIR> fields;
}

class FieldDefIR {
  const FieldDefIR({
    required this.id,
    required this.kind,
    required this.label,
    this.options,
    this.hint,
    this.required = false,
    this.defaultValue,
  });

  /// Field identifier (e.g. `'email'`, `'fabric'`).
  final String id;

  /// Rendering kind — determines the `FieldType` enum value emitted.
  final FieldKind kind;

  /// UI label shown to the user.
  final String label;

  /// Allowed values for dropdown / multi-select. `null` when omitted in
  /// the source (valid for `text` kind; also valid on dropdown/multiSelect
  /// though unusual).
  final List<String>? options;

  /// Placeholder / help text in the UI.
  final String? hint;

  /// Whether the field must be filled.
  final bool required;

  /// Pre-populated default. Stringly-typed to match the TS source.
  final String? defaultValue;
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

/// Raised when the input to [parseFieldDefinitionsIR] doesn't match the
/// `field_definitions` shape. The [path] is a JSON-pointer-ish locator
/// inside the schema root (e.g. `SCHEMA.ticket.fields[2].type`) and the
/// [expected]/[actual] pair gives a crisp diagnostic.
class SchemaShapeError extends StateError {
  SchemaShapeError({
    required this.path,
    required this.expected,
    required this.actual,
  }) : super(
          'ts_schema_codegen: invalid schema at $path\n'
          '  expected: $expected\n'
          '  got:      $actual',
        );

  final String path;
  final String expected;
  final String actual;
}

String _whatIs(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return 'bool';
  if (v is num) return 'num';
  if (v is String) return "string '$v'";
  if (v is List) return 'array';
  if (v is Map) return 'object';
  return v.runtimeType.toString();
}

/// Parse the raw JSON (as returned by [jsonDecode] on Deno output) into a
/// typed [SchemaIR]. Throws [SchemaShapeError] with a JSON-pointer path on
/// bad input.
///
/// [rootPath] is used in error messages so users can map the path back to
/// their TS source (e.g. `SCHEMA.ticket.fields[2].type`). Defaults to
/// `'schema'`; callers typically pass the `export` name.
SchemaIR parseFieldDefinitionsIR(
  Object? raw, {
  String rootPath = 'schema',
}) {
  if (raw is! Map) {
    throw SchemaShapeError(
      path: rootPath,
      expected: 'object (Record<fieldsetKey, FieldSet>)',
      actual: _whatIs(raw),
    );
  }

  final fieldsets = <FieldSetIR>[];
  var hasCommon = false;

  for (final entry in raw.entries) {
    final key = entry.key.toString();
    if (key == 'common') hasCommon = true;
    fieldsets.add(
      _parseFieldSet(key, entry.value, '$rootPath.$key'),
    );
  }

  return SchemaIR(fieldsets: fieldsets, hasCommon: hasCommon);
}

FieldSetIR _parseFieldSet(String key, Object? raw, String path) {
  if (raw is! Map) {
    throw SchemaShapeError(
      path: path,
      expected: 'FieldSet object',
      actual: _whatIs(raw),
    );
  }

  final label = raw['label'];
  if (label is! String) {
    throw SchemaShapeError(
      path: '$path.label',
      expected: 'string',
      actual: _whatIs(label),
    );
  }

  final categories = _parseStringList(
    raw['categories'],
    '$path.categories',
    allowMissing: false,
  );

  final subcategoryRoutes = _parseStringList(
    raw['subcategoryRoutes'],
    '$path.subcategoryRoutes',
    allowMissing: true,
  );

  final fieldsRaw = raw['fields'];
  if (fieldsRaw is! List) {
    throw SchemaShapeError(
      path: '$path.fields',
      expected: 'FieldDef[]',
      actual: _whatIs(fieldsRaw),
    );
  }

  final fields = <FieldDefIR>[];
  for (var i = 0; i < fieldsRaw.length; i++) {
    fields.add(_parseFieldDef(fieldsRaw[i], '$path.fields[$i]'));
  }

  return FieldSetIR(
    key: key,
    label: label,
    categories: categories,
    subcategoryRoutes: subcategoryRoutes,
    fields: fields,
  );
}

List<String> _parseStringList(
  Object? raw,
  String path, {
  required bool allowMissing,
}) {
  if (raw == null) {
    if (allowMissing) return const <String>[];
    throw SchemaShapeError(
      path: path,
      expected: 'string[]',
      actual: 'missing',
    );
  }
  if (raw is! List) {
    throw SchemaShapeError(
      path: path,
      expected: 'string[]',
      actual: _whatIs(raw),
    );
  }
  final out = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final v = raw[i];
    if (v is! String) {
      throw SchemaShapeError(
        path: '$path[$i]',
        expected: 'string',
        actual: _whatIs(v),
      );
    }
    out.add(v);
  }
  return out;
}

FieldDefIR _parseFieldDef(Object? raw, String path) {
  if (raw is! Map) {
    throw SchemaShapeError(
      path: path,
      expected: 'FieldDef object',
      actual: _whatIs(raw),
    );
  }

  final id = raw['id'];
  if (id is! String) {
    throw SchemaShapeError(
      path: '$path.id',
      expected: 'string',
      actual: _whatIs(id),
    );
  }

  final label = raw['label'];
  if (label is! String) {
    throw SchemaShapeError(
      path: '$path.label',
      expected: 'string',
      actual: _whatIs(label),
    );
  }

  final type = raw['type'];
  final FieldKind kind;
  switch (type) {
    case 'string':
      kind = FieldKind.dropdown;
    case 'array':
      kind = FieldKind.multiSelect;
    case 'text':
      kind = FieldKind.text;
    default:
      throw SchemaShapeError(
        path: '$path.type',
        expected: "'string' | 'array' | 'text'",
        actual: _whatIs(type),
      );
  }

  final options = raw['options'] == null
      ? null
      : _parseStringList(raw['options'], '$path.options', allowMissing: false);

  final hint = raw['hint'];
  if (hint != null && hint is! String) {
    throw SchemaShapeError(
      path: '$path.hint',
      expected: 'string (or omit)',
      actual: _whatIs(hint),
    );
  }

  final requiredVal = raw['required'];
  if (requiredVal != null && requiredVal is! bool) {
    throw SchemaShapeError(
      path: '$path.required',
      expected: 'bool (or omit)',
      actual: _whatIs(requiredVal),
    );
  }

  final defaultValue = raw['defaultValue'];
  if (defaultValue != null && defaultValue is! String) {
    throw SchemaShapeError(
      path: '$path.defaultValue',
      expected: 'string (or omit)',
      actual: _whatIs(defaultValue),
    );
  }

  return FieldDefIR(
    id: id,
    kind: kind,
    label: label,
    options: options,
    hint: hint as String?,
    required: (requiredVal as bool?) ?? false,
    defaultValue: defaultValue as String?,
  );
}
