import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/config.dart';

void main() {
  group('TsSchemaConfig.fromOptions', () {
    test('requires source', () {
      expect(
        () => TsSchemaConfig.fromOptions({}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('"source" option is required'),
          ),
        ),
      );
    });

    test('rejects empty source', () {
      expect(
        () => TsSchemaConfig.fromOptions({'source': ''}),
        throwsArgumentError,
      );
    });

    test('rejects non-string source', () {
      expect(
        () => TsSchemaConfig.fromOptions({'source': 42}),
        throwsArgumentError,
      );
    });

    test('rejects unknown template', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'source': 'schema.ts',
          'template': 'freezed_models',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('unknown template'), contains('freezed_models')),
          ),
        ),
      );
    });

    test('field_definitions template requires field_class_import', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'source': 'schema.ts',
          'template': 'field_definitions',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('"field_class_import"'),
          ),
        ),
      );
    });

    test('map template does not require field_class_import', () {
      final cfg = TsSchemaConfig.fromOptions({
        'source': 'schema.ts',
        'template': 'map',
      });
      expect(cfg.schemas.single.template, 'map');
      expect(cfg.schemas.single.fieldClassImport, isNull);
    });

    test('defaults: export=schema, deno=deno, template=map', () {
      final cfg = TsSchemaConfig.fromOptions({'source': 'schema.ts'});
      expect(cfg.schemas, hasLength(1));
      final entry = cfg.schemas.single;
      expect(entry.source, 'schema.ts');
      expect(entry.export, 'schema');
      expect(cfg.deno, 'deno');
      expect(entry.template, 'map');
      expect(entry.fieldClassImport, isNull);
      // Legacy single-schema form defaults output to lib/ts_schema.g.dart.
      expect(entry.output, 'lib/ts_schema.g.dart');
    });

    test('accepts all options together (legacy single-schema form)', () {
      final cfg = TsSchemaConfig.fromOptions({
        'source': 'path/to/schema.ts',
        'export': 'FIELD_SCHEMA',
        'deno': '/usr/local/bin/deno',
        'template': 'field_definitions',
        'field_class_import': 'package:myapp/field_definition.dart',
      });
      expect(cfg.schemas, hasLength(1));
      final entry = cfg.schemas.single;
      expect(entry.source, 'path/to/schema.ts');
      expect(entry.export, 'FIELD_SCHEMA');
      expect(cfg.deno, '/usr/local/bin/deno');
      expect(entry.template, 'field_definitions');
      expect(entry.fieldClassImport, 'package:myapp/field_definition.dart');
      expect(entry.output, 'lib/ts_schema.g.dart');
    });

    // --- Multi-schema form (#5) ---

    test('accepts multi-schema form with distinct outputs', () {
      final cfg = TsSchemaConfig.fromOptions({
        'schemas': [
          {
            'source': 'schema/forms.ts',
            'export': 'FORMS',
            'template': 'field_definitions',
            'field_class_import': 'package:app/field_definition.dart',
            'output': 'lib/forms.g.dart',
          },
          {
            'source': 'schema/config.ts',
            'template': 'map',
            'output': 'lib/config.g.dart',
          },
        ],
      });
      expect(cfg.schemas, hasLength(2));
      expect(cfg.schemas[0].source, 'schema/forms.ts');
      expect(cfg.schemas[0].export, 'FORMS');
      expect(cfg.schemas[0].template, 'field_definitions');
      expect(cfg.schemas[0].output, 'lib/forms.g.dart');
      expect(cfg.schemas[1].source, 'schema/config.ts');
      expect(cfg.schemas[1].export, 'schema'); // defaulted
      expect(cfg.schemas[1].template, 'map');
      expect(cfg.schemas[1].output, 'lib/config.g.dart');
    });

    test('rejects empty schemas list', () {
      expect(
        () => TsSchemaConfig.fromOptions({'schemas': <Object?>[]}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least one schema entry'),
          ),
        ),
      );
    });

    test('rejects non-list schemas option', () {
      expect(
        () => TsSchemaConfig.fromOptions({'schemas': 'not a list'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must be a list'),
          ),
        ),
      );
    });

    test('rejects duplicate output paths across schemas', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'schemas': [
            {'source': 'a.ts', 'output': 'lib/x.g.dart'},
            {'source': 'b.ts', 'output': 'lib/x.g.dart'},
          ],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('duplicate output path'),
          ),
        ),
      );
    });

    test('rejects output that doesn\'t start with lib/', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'schemas': [
            {'source': 'a.ts', 'output': 'generated/x.g.dart'},
          ],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must start with "lib/"'),
          ),
        ),
      );
    });

    test('rejects output that doesn\'t end with .dart', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'schemas': [
            {'source': 'a.ts', 'output': 'lib/x.txt'},
          ],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must end with ".dart"'),
          ),
        ),
      );
    });

    test('surfaces index in error path for multi-schema failures', () {
      expect(
        () => TsSchemaConfig.fromOptions({
          'schemas': [
            {'source': 'a.ts', 'output': 'lib/a.g.dart'},
            {'source': 'b.ts', 'output': 'lib/b.g.dart', 'template': 'xyz'},
          ],
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('schemas[1]'), contains('unknown template')),
          ),
        ),
      );
    });
  });
}
