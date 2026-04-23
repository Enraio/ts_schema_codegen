import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/emitter.dart';
import 'package:ts_schema_codegen/src/ir.dart';

// Small fixture builders so each test declares only what it exercises.
// Keeping these here (not in lib/src/) because they're test-only.

FieldDefIR _f(
  String id, {
  FieldKind kind = FieldKind.text,
  String? label,
  List<String>? options,
  String? hint,
  bool required = false,
  String? defaultValue,
}) =>
    FieldDefIR(
      id: id,
      kind: kind,
      label: label ?? id,
      options: options,
      hint: hint,
      required: required,
      defaultValue: defaultValue,
    );

FieldSetIR _fs(
  String key, {
  String? label,
  List<String> categories = const [],
  List<String> subcategoryRoutes = const [],
  List<FieldDefIR> fields = const [],
}) =>
    FieldSetIR(
      key: key,
      label: label ?? key.toUpperCase(),
      categories: categories,
      subcategoryRoutes: subcategoryRoutes,
      fields: fields,
    );

SchemaIR _ir(List<FieldSetIR> fieldsets) => SchemaIR(
      fieldsets: fieldsets,
      hasCommon: fieldsets.any((f) => f.key == 'common'),
    );

void main() {
  group('emitMapTemplate', () {
    test('emits null, bool, and num as-is', () {
      final out = emitMapTemplate(
        value: {'a': null, 'b': true, 'c': 42, 'd': 3.14},
        tsSourcePath: 'schema.ts',
        exportName: 'S',
      );
      expect(out, contains("'a': null"));
      expect(out, contains("'b': true"));
      expect(out, contains("'c': 42"));
      expect(out, contains("'d': 3.14"));
    });

    test('emits strings with single-quote and backslash escaping', () {
      final out = emitMapTemplate(
        value: {'apostrophe': "it's", 'slash': r'a\b'},
        tsSourcePath: 'schema.ts',
        exportName: 'S',
      );
      expect(out, contains(r"'it\'s'"));
      expect(out, contains(r"'a\\b'"));
    });

    test('emits nested maps and lists', () {
      final out = emitMapTemplate(
        value: {
          'items': [
            {'id': 1},
            {'id': 2},
          ],
        },
        tsSourcePath: 'schema.ts',
        exportName: 'S',
      );
      expect(
        out,
        contains(
          "'items': <Object?>[<String, Object?>{'id': 1}, <String, Object?>{'id': 2}]",
        ),
      );
    });

    test('handles empty list and empty map', () {
      final out = emitMapTemplate(
        value: {'a': <Object?>[], 'b': <String, Object?>{}},
        tsSourcePath: 'schema.ts',
        exportName: 'S',
      );
      expect(out, contains("'a': <Object?>[]"));
      expect(out, contains("'b': <String, Object?>{}"));
    });

    test('includes provenance header', () {
      final out = emitMapTemplate(
        value: null,
        tsSourcePath: 'path/to/schema.ts',
        exportName: 'FIELD_SCHEMA',
      );
      expect(out, startsWith('// GENERATED'));
      expect(out, contains('Source: path/to/schema.ts (export: FIELD_SCHEMA)'));
      expect(out, contains('dart run build_runner build'));
    });

    test('emits `Object` (non-nullable) when value is non-null', () {
      final out = emitMapTemplate(
        value: {'a': 1},
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(out, contains('const Object schema = '));
      expect(out, isNot(contains('const Object? schema')));
    });

    test('emits `Object?` when value is literally null', () {
      final out = emitMapTemplate(
        value: null,
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(out, contains('const Object? schema = null;'));
    });

    test('rejects non-JSON types', () {
      expect(
        () => emitMapTemplate(
          value: DateTime(2026),
          tsSourcePath: 's',
          exportName: 'S',
        ),
        throwsStateError,
      );
    });

    test('emits integers and doubles without type coercion', () {
      final out = emitMapTemplate(
        value: {'i': 42, 'd': 3.14, 'zero': 0, 'neg': -17, 'big': 9999999999},
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(out, contains("'i': 42"));
      expect(out, contains("'d': 3.14"));
      expect(out, contains("'zero': 0"));
      expect(out, contains("'neg': -17"));
      expect(out, contains("'big': 9999999999"));
    });

    test('preserves Unicode in strings', () {
      final out = emitMapTemplate(
        value: {'label': 'Café ☕ 漢字'},
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(out, contains("'Café ☕ 漢字'"));
    });

    test('handles deep nesting without stack issues', () {
      Object? current = 'leaf';
      for (var i = 0; i < 30; i++) {
        current = {'n': current};
      }
      final out = emitMapTemplate(
        value: {'deep': current},
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(out, contains("'leaf'"));
      expect("'n':".allMatches(out).length, 30);
    });

    test('preserves mixed-type lists', () {
      final out = emitMapTemplate(
        value: {
          'mixed': [
            1,
            'two',
            true,
            null,
            3.14,
            <String, Object?>{'k': 'v'}
          ],
        },
        tsSourcePath: 's',
        exportName: 'S',
      );
      expect(
        out,
        contains(
          "'mixed': <Object?>[1, 'two', true, null, 3.14, <String, Object?>{'k': 'v'}]",
        ),
      );
    });
  });

  group('emitFieldDefinitions', () {
    const import = 'package:testapp/field_definition.dart';

    String emit(SchemaIR schema) => emitFieldDefinitions(
          schema: schema,
          fieldClassImport: import,
          tsSourcePath: 's.ts',
          exportName: 'S',
        );

    test('handles empty schema (no fieldsets)', () {
      final out = emit(_ir([]));
      expect(out, contains("import '$import';"));
      expect(out, contains('getFieldsForCategoryGenerated'));
      // No common fieldset → default branch is an empty list, not commonFields.
      expect(out, contains('return const <FieldDefinition>[]'));
    });

    test('handles fieldset with empty fields list', () {
      final out = emit(_ir([
        _fs('empty', categories: ['empty']),
      ]));
      expect(out, contains('const emptyFields = <FieldDefinition>['));
      expect(out, isNot(contains('FieldDefinition(')));
    });

    test('maps FieldKind values to FieldType enum correctly', () {
      final out = emit(_ir([
        _fs('x', categories: [
          'x'
        ], fields: [
          _f('a', kind: FieldKind.dropdown),
          _f('b', kind: FieldKind.multiSelect),
          _f('c', kind: FieldKind.text),
        ]),
      ]));
      expect(out, contains('type: FieldType.dropdown'));
      expect(out, contains('type: FieldType.multiSelect'));
      expect(out, contains('type: FieldType.text'));
    });

    test('forwards optional props: options, hint, required, defaultValue', () {
      final out = emit(_ir([
        _fs('x', categories: [
          'x'
        ], fields: [
          _f(
            'size',
            kind: FieldKind.dropdown,
            label: 'Size',
            options: ['S', 'M', 'L'],
            hint: 'pick one',
            required: true,
            defaultValue: 'M',
          ),
        ]),
      ]));
      expect(out, contains("id: 'size'"));
      expect(out, contains("options: ['S', 'M', 'L']"));
      expect(out, contains("hint: 'pick one'"));
      expect(out, contains('required: true'));
      expect(out, contains("defaultValue: 'M'"));
    });

    test('omits options when absent; does not emit required:false', () {
      final out = emit(_ir([
        _fs('x', categories: [
          'x'
        ], fields: [
          _f('notes', kind: FieldKind.text),
        ]),
      ]));
      expect(out, isNot(contains('options:')));
      expect(out, isNot(contains('required:')));
      expect(out, isNot(contains('defaultValue:')));
      expect(out, isNot(contains('hint:')));
    });

    test('routing: subcategory routes take precedence over category switch',
        () {
      final out = emit(_ir([
        _fs('watch', categories: [
          'watch'
        ], subcategoryRoutes: [
          'watch',
          'smartwatch'
        ], fields: [
          _f('type', kind: FieldKind.dropdown),
        ]),
      ]));
      expect(
        out,
        contains(
          'switch (subcategory.toLowerCase()) {\n'
          "      case 'watch':\n"
          "      case 'smartwatch':\n"
          '        return watchFields;\n'
          '    }',
        ),
      );
    });

    test('common is never a category case; default falls to commonFields', () {
      final out = emit(_ir([
        _fs('common', fields: [_f('condition', kind: FieldKind.dropdown)]),
        _fs('clothing', categories: ['top'], fields: [_f('fabric')]),
      ]));
      expect(out, contains("case 'top':\n      return clothingFields;"));
      expect(out, contains('default:\n      return commonFields;'));
      expect(out, isNot(contains("case 'common':")));
    });

    test(
        'schemas without a common fieldset skip commonFields spread + fallback',
        () {
      final out = emit(_ir([
        _fs('user', categories: ['user'], fields: [_f('name')]),
      ]));
      expect(out, isNot(contains('...commonFields')));
      expect(out, isNot(contains('return commonFields')));
      expect(out, contains('return const <FieldDefinition>[]'));
    });

    test(
        'empty-categories fieldset with subcategory routes matches key as category',
        () {
      final out = emit(_ir([
        _fs('fragrance',
            categories: const [],
            subcategoryRoutes: ['perfume'],
            fields: [_f('conc', kind: FieldKind.dropdown)]),
      ]));
      expect(
        out,
        contains("case 'fragrance':\n      return fragranceFields;"),
      );
    });

    test('escapes single-quotes and backslashes in option values', () {
      final out = emit(_ir([
        _fs('x', categories: [
          'x'
        ], fields: [
          _f('h', kind: FieldKind.dropdown, options: ["it's", r'a\b']),
        ]),
      ]));
      expect(out, contains(r"'it\'s'"));
      expect(out, contains(r"'a\\b'"));
    });

    test('double quotes pass through unescaped in single-quoted strings', () {
      final out = emit(_ir([
        _fs('x', categories: [
          'x'
        ], fields: [
          _f('h', kind: FieldKind.dropdown, options: ['Flat (0-1")']),
        ]),
      ]));
      expect(out, contains("'Flat (0-1\")'"));
    });

    // --- Registry emission (#4) ---

    test('emits GeneratedFieldSet class for the registry', () {
      final out = emit(_ir([
        _fs('user', categories: ['user'], fields: [_f('name')]),
      ]));
      expect(out, contains('class GeneratedFieldSet {'));
      expect(out, contains('final String label;'));
      expect(out, contains('final List<String> categories;'));
      expect(out, contains('final List<String> subcategoryRoutes;'));
      expect(out, contains('final List<FieldDefinition> fields;'));
    });

    test('emits kFieldSets map with one entry per fieldset', () {
      final out = emit(_ir([
        _fs('common', fields: [_f('consent', kind: FieldKind.dropdown)]),
        _fs(
          'ticket',
          categories: ['ticket'],
          subcategoryRoutes: ['bug'],
          fields: [_f('severity', kind: FieldKind.dropdown)],
        ),
      ]));
      expect(out, contains('const kFieldSets = <String, GeneratedFieldSet>{'));
      expect(out, contains("'common': GeneratedFieldSet("));
      expect(out, contains("'ticket': GeneratedFieldSet("));
      expect(out, contains("label: 'COMMON'"));
      expect(out, contains("label: 'TICKET'"));
      expect(out, contains('categories: <String>[]'));
      expect(out, contains("categories: ['ticket']"));
      expect(out, contains("subcategoryRoutes: ['bug']"));
      expect(out, contains('fields: commonFields,'));
      expect(out, contains('fields: ticketFields,'));
    });

    test('registry omits subcategoryRoutes line when empty', () {
      final out = emit(_ir([
        _fs('x', categories: ['x'], fields: [_f('a')]),
      ]));
      final entryStart = out.indexOf("'x': GeneratedFieldSet(");
      final entryEnd = out.indexOf('),', entryStart);
      final entry = out.substring(entryStart, entryEnd);
      expect(entry, isNot(contains('subcategoryRoutes:')));
    });

    test('registry escapes special characters in label / routes / categories',
        () {
      final out = emit(_ir([
        _fs(
          'it_s',
          label: "it's",
          categories: ['a\\b'],
          subcategoryRoutes: ["c'd"],
          fields: [_f('x')],
        ),
      ]));
      expect(out, contains(r"label: 'it\'s'"));
      expect(out, contains(r"categories: ['a\\b']"));
      expect(out, contains(r"subcategoryRoutes: ['c\'d']"));
    });

    test('registry preserves IR fieldset order', () {
      final out = emit(_ir([
        _fs('zebra', categories: ['z'], fields: [_f('a')]),
        _fs('apple', categories: ['a'], fields: [_f('b')]),
      ]));
      final registryStart = out.indexOf('const kFieldSets');
      final zebraIdx = out.indexOf("'zebra': GeneratedFieldSet", registryStart);
      final appleIdx = out.indexOf("'apple': GeneratedFieldSet", registryStart);
      expect(zebraIdx, greaterThan(-1));
      expect(appleIdx, greaterThan(-1));
      expect(zebraIdx, lessThan(appleIdx));
    });
  });
}
