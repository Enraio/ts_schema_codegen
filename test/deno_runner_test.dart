import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:ts_schema_codegen/src/deno_runner.dart';

/// Smoke test that exercises the real Deno CLI end-to-end. Skipped entirely
/// if `deno` isn't on PATH, so CI without Deno doesn't go red over it.
void main() {
  final denoAvailable = _commandExists('deno');
  final skip = denoAvailable ? null : 'deno not on PATH';

  group('DenoRunner.evaluate (integration)', () {
    late Directory tmp;
    late String exportScript;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ts_schema_codegen_test_');
      exportScript = p.absolute(
        p.join(Directory.current.path, 'tool', 'ts_export.ts'),
      );
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('evaluates a primitive export', () async {
      File(p.join(tmp.path, 'schema.ts'))
          .writeAsStringSync("export const answer = 42;\n");
      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final value = await runner.evaluate(
        tsPath: 'schema.ts',
        exportName: 'answer',
      );
      expect(value, 42);
    }, skip: skip);

    test('evaluates a composed object across multiple files', () async {
      File(p.join(tmp.path, 'common.ts')).writeAsStringSync(
        "export const condition = { options: ['New', 'Used'] };\n",
      );
      File(p.join(tmp.path, 'schema.ts')).writeAsStringSync('''
        import { condition } from './common.ts';
        export const SCHEMA = {
          common: { fields: [{ id: 'condition', ...condition }] },
        };
      ''');
      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      final value = await runner.evaluate(
        tsPath: 'schema.ts',
        exportName: 'SCHEMA',
      );
      expect(
        value,
        {
          'common': {
            'fields': [
              {
                'id': 'condition',
                'options': ['New', 'Used'],
              },
            ],
          },
        },
      );
    }, skip: skip);

    test('fails loudly when source file is missing', () async {
      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      await expectLater(
        runner.evaluate(tsPath: 'does_not_exist.ts', exportName: 'X'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('source file not found'),
          ),
        ),
      );
    }, skip: skip);

    test('fails loudly when the named export is missing', () async {
      File(p.join(tmp.path, 'schema.ts'))
          .writeAsStringSync("export const foo = 1;\n");
      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      await expectLater(
        runner.evaluate(tsPath: 'schema.ts', exportName: 'missing'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('deno exited'), contains('missing')),
          ),
        ),
      );
    }, skip: skip);

    test('fails loudly when export is not JSON-serializable', () async {
      File(p.join(tmp.path, 'schema.ts'))
          .writeAsStringSync("export const fn = () => 42;\n");
      final runner = DenoRunner(
        denoCommand: 'deno',
        exportScriptPath: exportScript,
        workingDirectory: tmp.path,
      );
      await expectLater(
        runner.evaluate(tsPath: 'schema.ts', exportName: 'fn'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            // A function JSON.stringify's to `undefined`, which our script
            // returns as empty stdout → the Dart side surfaces a parse error.
            anyOf(
              contains('non-JSON'),
              contains('not JSON-serializable'),
            ),
          ),
        ),
      );
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
