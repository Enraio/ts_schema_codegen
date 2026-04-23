import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/emitter.dart';

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
        value: {"apostrophe": "it's", "slash": r'a\b'},
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
      // 30 nested 'n' keys.
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

    test('handles empty schema (no fieldsets)', () {
      final out = emitFieldDefinitions(
        schema: <String, Object?>{},
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("import '$import';"));
      expect(out, contains('getFieldsForCategoryGenerated'));
      // With no fieldsets there are no case labels — default branch must return an empty list.
      expect(out, contains('return const <FieldDefinition>[]'));
    });

    test('handles fieldset with empty fields list', () {
      final out = emitFieldDefinitions(
        schema: {
          'empty': {
            'label': 'EMPTY',
            'categories': ['empty'],
            'fields': <Object?>[],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains('const emptyFields = <FieldDefinition>['));
      // No FieldDefinition rows, and no commonFields spread either.
      expect(out, isNot(contains('FieldDefinition(')));
    });

    test('rejects fieldset without "fields" key', () {
      expect(
        () => emitFieldDefinitions(
          schema: {
            'broken': {
              'label': 'X',
              'categories': ['x']
            },
          },
          fieldClassImport: import,
          tsSourcePath: 's.ts',
          exportName: 'S',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('has no "fields" list'),
          ),
        ),
      );
    });

    test('rejects field missing required props (id/label/type)', () {
      expect(
        () => emitFieldDefinitions(
          schema: {
            'x': {
              'label': 'X',
              'categories': ['x'],
              'fields': [
                {'id': 'nolabel', 'type': 'text'},
              ],
            },
          },
          fieldClassImport: import,
          tsSourcePath: 's.ts',
          exportName: 'S',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('missing id/label/type'),
          ),
        ),
      );
    });

    test('tolerates extra unknown keys on FieldDef', () {
      // Real schemas (like outfii's) carry metadata the emitter doesn't care
      // about (abbreviation, aiRelevant, topLevelColumn, compactAs, scanHint).
      // Those should pass through silently.
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {
                'id': 'color',
                'type': 'string',
                'label': 'Color',
                'abbreviation': 'c',
                'aiRelevant': true,
                'topLevelColumn': false,
                'compactAs': 'string',
                'scanHint': 'pick one',
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("id: 'color'"));
      // None of the unknown keys should leak into the Dart output.
      expect(out, isNot(contains('abbreviation')));
      expect(out, isNot(contains('aiRelevant')));
      expect(out, isNot(contains('topLevelColumn')));
      expect(out, isNot(contains('compactAs')));
      expect(out, isNot(contains('scanHint')));
    });

    test('preserves Unicode in labels and options', () {
      final out = emitFieldDefinitions(
        schema: {
          'intl': {
            'label': 'INTL',
            'categories': ['intl'],
            'fields': [
              {
                'id': 'greeting',
                'type': 'string',
                'label': 'Gruß',
                'options': ['こんにちは', '你好', 'مرحبا'],
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("label: 'Gruß'"));
      expect(out, contains("'こんにちは'"));
      expect(out, contains("'你好'"));
      expect(out, contains("'مرحبا'"));
    });

    test('preserves insertion order of fieldsets in emitted output', () {
      // Consumers rely on ordering (e.g. Dart switch-case output) matching
      // the TS source. JSON preserves insertion order for string keys, and
      // Dart Map<String, _>.fromEntries does too — but we should guard
      // against a refactor that sorts alphabetically or otherwise.
      final out = emitFieldDefinitions(
        schema: {
          'zebra': {
            'label': 'Z',
            'categories': ['z'],
            'fields': [
              {'id': 'a', 'type': 'text', 'label': 'A'},
            ],
          },
          'apple': {
            'label': 'A',
            'categories': ['a'],
            'fields': [
              {'id': 'b', 'type': 'text', 'label': 'B'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      final zebraIdx = out.indexOf('zebraFields');
      final appleIdx = out.indexOf('appleFields');
      expect(zebraIdx, lessThan(appleIdx),
          reason: 'TS insertion order (zebra before apple) must be preserved');
    });

    test('rejects non-map root', () {
      expect(
        () => emitFieldDefinitions(
          schema: <Object?>[1, 2, 3],
          fieldClassImport: import,
          tsSourcePath: 's.ts',
          exportName: 'S',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('expected Map at schema root'),
          ),
        ),
      );
    });

    test('emits per-fieldset const lists with the right names', () {
      final out = emitFieldDefinitions(
        schema: {
          'common': {
            'label': 'COMMON',
            'categories': <String>[],
            'fields': [
              {
                'id': 'condition',
                'type': 'string',
                'label': 'Condition',
                'options': ['New', 'Used'],
              },
            ],
          },
          'clothing': {
            'label': 'TOPS',
            'categories': ['top', 'dress'],
            'fields': [
              {
                'id': 'fabric',
                'type': 'string',
                'label': 'Fabric',
                'options': ['Cotton'],
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 'schema.ts',
        exportName: 'FIELD_SCHEMA',
      );
      expect(out, contains("import '$import';"));
      expect(out, contains('const commonFields = <FieldDefinition>['));
      expect(out, contains('const clothingFields = <FieldDefinition>['));
      // common is NOT spread into itself; other fieldsets spread common.
      expect(
        out,
        predicate<String>(
          (s) => !s.contains(
              'const commonFields = <FieldDefinition>[\n  ...commonFields'),
        ),
      );
      expect(out, contains('...commonFields,'));
    });

    test('maps FieldDef types to FieldType enum correctly', () {
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {'id': 'a', 'type': 'string', 'label': 'A'},
              {'id': 'b', 'type': 'array', 'label': 'B'},
              {'id': 'c', 'type': 'text', 'label': 'C'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains('type: FieldType.dropdown'));
      expect(out, contains('type: FieldType.multiSelect'));
      expect(out, contains('type: FieldType.text'));
    });

    test('forwards optional props: options, hint, required, defaultValue', () {
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {
                'id': 'size',
                'type': 'string',
                'label': 'Size',
                'options': ['S', 'M', 'L'],
                'hint': 'pick one',
                'required': true,
                'defaultValue': 'M',
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("id: 'size'"));
      expect(out, contains("options: ['S', 'M', 'L']"));
      expect(out, contains("hint: 'pick one'"));
      expect(out, contains('required: true'));
      expect(out, contains("defaultValue: 'M'"));
    });

    test('omits options when absent; does not emit required:false', () {
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {'id': 'notes', 'type': 'text', 'label': 'Notes'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, isNot(contains('options:')));
      expect(out, isNot(contains('required:')));
      expect(out, isNot(contains('defaultValue:')));
      expect(out, isNot(contains('hint:')));
    });

    test('routing: subcategory routes take precedence over category switch',
        () {
      final out = emitFieldDefinitions(
        schema: {
          'watch': {
            'label': 'WATCH',
            'categories': ['watch'],
            'subcategoryRoutes': ['watch', 'smartwatch'],
            'fields': [
              {'id': 'type', 'type': 'string', 'label': 'Type'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
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

    test(
        'routing: common is never a category case; default falls to commonFields',
        () {
      final out = emitFieldDefinitions(
        schema: {
          'common': {
            'label': 'COMMON',
            'categories': <String>[],
            'fields': [
              {'id': 'condition', 'type': 'string', 'label': 'Condition'},
            ],
          },
          'clothing': {
            'label': 'TOPS',
            'categories': ['top'],
            'fields': [
              {'id': 'fabric', 'type': 'string', 'label': 'Fabric'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("case 'top':\n      return clothingFields;"));
      expect(out, contains('default:\n      return commonFields;'));
      // common must not appear as a case label.
      expect(out, isNot(contains("case 'common':")));
    });

    test(
        'schemas without a "common" fieldset skip commonFields spread + fallback',
        () {
      final out = emitFieldDefinitions(
        schema: {
          'user': {
            'label': 'USER',
            'categories': ['user'],
            'fields': [
              {'id': 'name', 'type': 'text', 'label': 'Name'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, isNot(contains('...commonFields')));
      expect(out, isNot(contains('return commonFields')));
      expect(out, contains('return const <FieldDefinition>[]'));
    });

    test(
        'routing: empty-categories fieldset with subcategory routes also matches key as category',
        () {
      // Backward-compat shape: a fieldset defined only via subcategoryRoutes
      // still matches `category == key` as a fallback.
      final out = emitFieldDefinitions(
        schema: {
          'fragrance': {
            'label': 'FRAGRANCE',
            'categories': <String>[],
            'subcategoryRoutes': ['perfume'],
            'fields': [
              {'id': 'conc', 'type': 'string', 'label': 'Concentration'},
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("case 'fragrance':\n      return fragranceFields;"));
    });

    test('escapes single-quotes and backslashes in option values', () {
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {
                'id': 'h',
                'type': 'string',
                'label': 'H',
                'options': ["it's", r'a\b'],
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      // Single quote must be escaped inside a single-quoted Dart string.
      expect(out, contains(r"'it\'s'"));
      // Backslash must be doubled.
      expect(out, contains(r"'a\\b'"));
    });

    test('double quotes pass through unescaped in single-quoted strings', () {
      final out = emitFieldDefinitions(
        schema: {
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {
                'id': 'h',
                'type': 'string',
                'label': 'H',
                'options': ['Flat (0-1")'],
              },
            ],
          },
        },
        fieldClassImport: import,
        tsSourcePath: 's.ts',
        exportName: 'S',
      );
      expect(out, contains("'Flat (0-1\")'"));
    });
  });
}
