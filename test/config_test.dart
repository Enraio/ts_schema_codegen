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
      expect(cfg.template, 'map');
      expect(cfg.fieldClassImport, isNull);
    });

    test('defaults: export=schema, deno=deno, template=map', () {
      final cfg = TsSchemaConfig.fromOptions({'source': 'schema.ts'});
      expect(cfg.source, 'schema.ts');
      expect(cfg.export, 'schema');
      expect(cfg.deno, 'deno');
      expect(cfg.template, 'map');
      expect(cfg.fieldClassImport, isNull);
    });

    test('accepts all options together', () {
      final cfg = TsSchemaConfig.fromOptions({
        'source': 'path/to/schema.ts',
        'export': 'FIELD_SCHEMA',
        'deno': '/usr/local/bin/deno',
        'template': 'field_definitions',
        'field_class_import': 'package:myapp/field_definition.dart',
      });
      expect(cfg.source, 'path/to/schema.ts');
      expect(cfg.export, 'FIELD_SCHEMA');
      expect(cfg.deno, '/usr/local/bin/deno');
      expect(cfg.template, 'field_definitions');
      expect(cfg.fieldClassImport, 'package:myapp/field_definition.dart');
    });
  });
}
