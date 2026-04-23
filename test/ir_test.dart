import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/ir.dart';

void main() {
  group('parseFieldDefinitionsIR', () {
    test('parses a minimal valid schema', () {
      final ir = parseFieldDefinitionsIR({
        'user': {
          'label': 'USER',
          'categories': ['user'],
          'fields': [
            {'id': 'name', 'type': 'text', 'label': 'Name'},
          ],
        },
      }, rootPath: 'SCHEMA');

      expect(ir.fieldsets, hasLength(1));
      expect(ir.hasCommon, isFalse);
      final fs = ir.fieldsets.single;
      expect(fs.key, 'user');
      expect(fs.label, 'USER');
      expect(fs.categories, ['user']);
      expect(fs.subcategoryRoutes, isEmpty);
      expect(fs.fields, hasLength(1));
      expect(fs.fields.single.id, 'name');
      expect(fs.fields.single.kind, FieldKind.text);
    });

    test('detects hasCommon when a common fieldset exists', () {
      final ir = parseFieldDefinitionsIR({
        'common': {
          'label': 'COMMON',
          'categories': <String>[],
          'fields': <Object?>[],
        },
        'user': {
          'label': 'USER',
          'categories': ['user'],
          'fields': <Object?>[],
        },
      });
      expect(ir.hasCommon, isTrue);
      expect(ir.fieldsets, hasLength(2));
    });

    test('preserves TS-source insertion order', () {
      final ir = parseFieldDefinitionsIR({
        'zebra': {
          'label': 'Z',
          'categories': ['z'],
          'fields': <Object?>[],
        },
        'apple': {
          'label': 'A',
          'categories': ['a'],
          'fields': <Object?>[],
        },
      });
      expect(ir.fieldsets.map((f) => f.key).toList(), ['zebra', 'apple']);
    });

    test('maps type strings to FieldKind values', () {
      final ir = parseFieldDefinitionsIR({
        'x': {
          'label': 'X',
          'categories': ['x'],
          'fields': [
            {'id': 'a', 'type': 'string', 'label': 'A'},
            {'id': 'b', 'type': 'array', 'label': 'B'},
            {'id': 'c', 'type': 'text', 'label': 'C'},
          ],
        },
      });
      final kinds = ir.fieldsets.single.fields.map((f) => f.kind).toList();
      expect(kinds, [
        FieldKind.dropdown,
        FieldKind.multiSelect,
        FieldKind.text,
      ]);
    });

    test('reads optional field properties', () {
      final ir = parseFieldDefinitionsIR({
        'x': {
          'label': 'X',
          'categories': ['x'],
          'fields': [
            {
              'id': 'role',
              'type': 'string',
              'label': 'Role',
              'options': ['A', 'B'],
              'hint': 'pick one',
              'required': true,
              'defaultValue': 'A',
            },
          ],
        },
      });
      final f = ir.fieldsets.single.fields.single;
      expect(f.options, ['A', 'B']);
      expect(f.hint, 'pick one');
      expect(f.required, isTrue);
      expect(f.defaultValue, 'A');
    });

    test('omitted optional properties default sensibly', () {
      final ir = parseFieldDefinitionsIR({
        'x': {
          'label': 'X',
          'categories': ['x'],
          'fields': [
            {'id': 'notes', 'type': 'text', 'label': 'Notes'},
          ],
        },
      });
      final f = ir.fieldsets.single.fields.single;
      expect(f.options, isNull);
      expect(f.hint, isNull);
      expect(f.required, isFalse);
      expect(f.defaultValue, isNull);
    });

    test('tolerates extra unknown keys on FieldDef', () {
      // Outfii's real schema carries abbreviation/aiRelevant/topLevelColumn/
      // compactAs/scanHint. Parser shouldn't choke on them.
      final ir = parseFieldDefinitionsIR({
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
      });
      expect(ir.fieldsets.single.fields.single.id, 'color');
    });

    test('empty subcategoryRoutes = []', () {
      final ir = parseFieldDefinitionsIR({
        'x': {
          'label': 'X',
          'categories': ['x'],
          // omitted subcategoryRoutes
          'fields': <Object?>[],
        },
      });
      expect(ir.fieldsets.single.subcategoryRoutes, isEmpty);
    });

    // --- Error cases ---

    test('throws on non-map root', () {
      expect(
        () => parseFieldDefinitionsIR(<Object?>[1, 2, 3]),
        throwsA(
          isA<SchemaShapeError>()
              .having((e) => e.path, 'path', 'schema')
              .having((e) => e.expected, 'expected', contains('Record')),
        ),
      );
    });

    test('throws on non-map fieldset value', () {
      expect(
        () => parseFieldDefinitionsIR(
          {'bad': 'not a map'},
          rootPath: 'SCHEMA',
        ),
        throwsA(
          isA<SchemaShapeError>()
              .having((e) => e.path, 'path', 'SCHEMA.bad')
              .having((e) => e.expected, 'expected', 'FieldSet object'),
        ),
      );
    });

    test('throws on missing required FieldSet properties', () {
      expect(
        () => parseFieldDefinitionsIR({
          'bad': {'label': 'B'}, // missing categories + fields
        }),
        throwsA(isA<SchemaShapeError>()),
      );
    });

    test('throws with JSON-pointer path on bad field type', () {
      expect(
        () => parseFieldDefinitionsIR(
          {
            'user': {
              'label': 'USER',
              'categories': ['user'],
              'fields': [
                {'id': 'name', 'type': 'txt', 'label': 'Name'},
              ],
            },
          },
          rootPath: 'SCHEMA',
        ),
        throwsA(
          isA<SchemaShapeError>()
              .having((e) => e.path, 'path', 'SCHEMA.user.fields[0].type')
              .having(
                (e) => e.expected,
                'expected',
                "'string' | 'array' | 'text'",
              )
              .having((e) => e.actual, 'actual', contains('txt')),
        ),
      );
    });

    test('throws on non-string category entry', () {
      expect(
        () => parseFieldDefinitionsIR({
          'x': {
            'label': 'X',
            'categories': ['ok', 42],
            'fields': <Object?>[],
          },
        }),
        throwsA(
          isA<SchemaShapeError>().having(
            (e) => e.path,
            'path',
            endsWith('.categories[1]'),
          ),
        ),
      );
    });

    test('throws on non-bool required', () {
      expect(
        () => parseFieldDefinitionsIR({
          'x': {
            'label': 'X',
            'categories': ['x'],
            'fields': [
              {
                'id': 'a',
                'type': 'text',
                'label': 'A',
                'required': 'yes', // should be bool
              },
            ],
          },
        }),
        throwsA(
          isA<SchemaShapeError>().having(
            (e) => e.path,
            'path',
            endsWith('.required'),
          ),
        ),
      );
    });

    test('SchemaShapeError includes all locator info in message', () {
      try {
        parseFieldDefinitionsIR({
          'user': {
            'label': 'USER',
            'categories': ['user'],
            'fields': [
              {'id': 'name', 'type': 'bogus', 'label': 'Name'},
            ],
          },
        }, rootPath: 'FORMS');
        fail('should have thrown');
      } on SchemaShapeError catch (e) {
        expect(e.message, contains('FORMS.user.fields[0].type'));
        expect(e.message, contains('expected'));
        expect(e.message, contains('got'));
      }
    });
  });
}
