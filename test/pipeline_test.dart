// Full-pipeline test: real TS source file on disk → DenoRunner evaluates it
// → emitter produces Dart source. Validates that every stage plays well with
// every other stage on realistic input.
//
// Skipped automatically if Deno isn't on PATH.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/deno_runner.dart';
import 'package:ts_schema_codegen/src/emitter.dart';

void main() {
  final skip = _commandExists('deno') ? null : 'deno not on PATH';

  group('pipeline: TS file → Deno eval → emitter', () {
    late Directory tmp;
    late String exportScript;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pipeline_test_');
      exportScript = p.absolute(
        p.join(Directory.current.path, 'tool', 'ts_export.ts'),
      );
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('field_definitions template against a realistic multi-fieldset schema',
        () async {
      File(p.join(tmp.path, 'schema.ts')).writeAsStringSync('''
        export const SCHEMA = {
          common: {
            label: 'COMMON',
            categories: [],
            fields: [
              { id: 'condition', type: 'string', label: 'Condition',
                options: ['New', 'Used'], defaultValue: 'New' },
            ],
          },
          user: {
            label: 'USER',
            categories: ['user', 'member'],
            fields: [
              { id: 'email', type: 'text', label: 'Email', required: true },
              { id: 'role', type: 'string', label: 'Role',
                options: ['Admin', 'Member'] },
              { id: 'tags', type: 'array', label: 'Tags',
                options: ['ops', 'dev', 'design'] },
            ],
          },
          ticket: {
            label: 'TICKET',
            categories: ['ticket'],
            subcategoryRoutes: ['bug', 'feature'],
            fields: [
              { id: 'severity', type: 'string', label: 'Severity',
                options: ['Low', 'High'] },
              { id: 'description', type: 'text', label: 'Description',
                hint: 'Steps to reproduce' },
            ],
          },
        };
      ''');

      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final raw = await runner.evaluate(
        tsPath: 'schema.ts',
        exportName: 'SCHEMA',
      );

      final dart = emitFieldDefinitions(
        schema: raw,
        fieldClassImport: 'package:fake/field_definition.dart',
        tsSourcePath: 'schema.ts',
        exportName: 'SCHEMA',
      );

      // Structural invariants — not a byte-exact golden (emitter formatting
      // evolves), but every meaningful artifact must be present.
      expect(dart, contains("import 'package:fake/field_definition.dart';"));
      expect(dart, contains('const commonFields = <FieldDefinition>['));
      expect(dart, contains('const userFields = <FieldDefinition>['));
      expect(dart, contains('const ticketFields = <FieldDefinition>['));

      // Field-level content survived the roundtrip.
      expect(dart, contains("id: 'condition'"));
      expect(dart, contains("id: 'email'"));
      expect(dart, contains("id: 'description'"));
      expect(dart, contains("defaultValue: 'New'"));
      expect(dart, contains('required: true'));
      expect(dart, contains("hint: 'Steps to reproduce'"));

      // Options mapped to correct FieldType enum values.
      expect(dart, contains('type: FieldType.dropdown')); // string
      expect(dart, contains('type: FieldType.multiSelect')); // array
      expect(dart, contains('type: FieldType.text')); // text

      // common is appended to non-common fieldsets.
      final userSpreadIdx = dart.indexOf('...commonFields', dart.indexOf('userFields'));
      final ticketSpreadIdx = dart.indexOf('...commonFields', dart.indexOf('ticketFields'));
      expect(userSpreadIdx, greaterThan(-1));
      expect(ticketSpreadIdx, greaterThan(-1));

      // Subcategory routes precede category switch, in declaration order.
      expect(
        dart,
        contains(
          "switch (subcategory.toLowerCase()) {\n"
          "      case 'bug':\n"
          "      case 'feature':\n"
          '        return ticketFields;\n'
          '    }',
        ),
      );

      // Category switch: user has two category labels, ticket has one.
      expect(dart, contains("case 'user':"));
      expect(dart, contains("case 'member':"));
      expect(dart, contains("case 'ticket':"));

      // Default branch returns common (because a common fieldset exists).
      expect(dart, contains('default:\n      return commonFields;'));
    }, skip: skip);

    test('map template: roundtrips a nested config through Deno + emitter',
        () async {
      File(p.join(tmp.path, 'config.ts')).writeAsStringSync('''
        export const CONFIG = {
          version: '1.0.0',
          api: { baseUrl: 'https://api.example.com', timeoutMs: 5000 },
          flags: { dark_mode: true, beta: false },
          locales: ['en', 'es', 'fr'],
          nested: { a: { b: { c: { d: 'deep' } } } },
        };
      ''');

      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final raw = await runner.evaluate(
        tsPath: 'config.ts',
        exportName: 'CONFIG',
      );

      final dart = emitMapTemplate(
        value: raw,
        tsSourcePath: 'config.ts',
        exportName: 'CONFIG',
      );

      expect(dart, contains('const Object? schema = '));
      expect(dart, contains("'version': '1.0.0'"));
      expect(dart, contains("'baseUrl': 'https://api.example.com'"));
      expect(dart, contains("'timeoutMs': 5000"));
      expect(dart, contains("'dark_mode': true"));
      expect(dart, contains("'beta': false"));
      expect(
        dart,
        contains(
          "'locales': <Object?>['en', 'es', 'fr']",
        ),
      );
      // Deep nesting survives.
      expect(dart, contains("'d': 'deep'"));
    }, skip: skip);

    test('preserves insertion order from TS source through the pipeline',
        () async {
      // Zebra defined first, apple second. JSON.stringify preserves insertion
      // order for string keys; jsonDecode in Dart returns an insertion-ordered
      // LinkedHashMap; our emitter iterates entries in order. The whole chain
      // must keep it.
      File(p.join(tmp.path, 's.ts')).writeAsStringSync('''
        export const SCHEMA = {
          zebra: { label: 'Z', categories: ['z'],
                   fields: [{ id: 'a', type: 'text', label: 'A' }] },
          apple: { label: 'A', categories: ['a'],
                   fields: [{ id: 'b', type: 'text', label: 'B' }] },
        };
      ''');

      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final raw = await runner.evaluate(tsPath: 's.ts', exportName: 'SCHEMA');

      final dart = emitFieldDefinitions(
        schema: raw,
        fieldClassImport: 'package:fake/field_definition.dart',
        tsSourcePath: 's.ts',
        exportName: 'SCHEMA',
      );

      final zebraIdx = dart.indexOf('zebraFields');
      final appleIdx = dart.indexOf('appleFields');
      expect(zebraIdx, greaterThan(-1));
      expect(appleIdx, greaterThan(-1));
      expect(zebraIdx, lessThan(appleIdx));
    }, skip: skip);

    test(
        'TS composition via imports + Object.fromEntries survives the pipeline',
        () async {
      // The defining scenario: a schema assembled from multiple files using
      // spread + runtime function calls. A syntax-only parser couldn't read
      // this; Deno handles it as normal TS.
      File(p.join(tmp.path, 'trait.ts')).writeAsStringSync('''
        export const named = [
          { id: 'name', type: 'text', label: 'Name', required: true },
        ];
      ''');
      File(p.join(tmp.path, 'user.ts')).writeAsStringSync('''
        import { named } from './trait.ts';
        export const user = {
          label: 'USER',
          categories: ['user'],
          fields: [
            ...named,
            { id: 'email', type: 'text', label: 'Email', required: true },
          ],
        };
      ''');
      File(p.join(tmp.path, 'index.ts')).writeAsStringSync('''
        import { user } from './user.ts';
        export const SCHEMA = Object.fromEntries([
          ['user', user],
        ]);
      ''');

      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final raw = await runner.evaluate(
        tsPath: 'index.ts',
        exportName: 'SCHEMA',
      );

      final dart = emitFieldDefinitions(
        schema: raw,
        fieldClassImport: 'package:fake/field_definition.dart',
        tsSourcePath: 'index.ts',
        exportName: 'SCHEMA',
      );

      // Both the spread-in field (name from trait) and the inline field
      // (email) must appear — confirms the whole TS composition flattened
      // correctly before we serialized.
      expect(dart, contains("id: 'name'"));
      expect(dart, contains("id: 'email'"));
      expect(dart, contains('const userFields = <FieldDefinition>['));
    }, skip: skip);
  });
}

bool _commandExists(String cmd) {
  try {
    final result = Process.runSync(
      Platform.isWindows ? 'where' : 'which',
      [cmd],
    );
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
