import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'deno_runner.dart';
import 'emitter.dart';

/// Builder triggered once per consuming package (`$package$`).
///
/// Pipeline:
///   1. Read options from build.yaml (via constructor).
///   2. Shell out to Deno with the bundled `tool/ts_export.ts` script,
///      passing the user's TS entry path + export name.
///   3. Parse the resulting JSON, run it through the selected emitter.
///   4. Write the Dart source to `lib/ts_schema.g.dart` in the consumer.
///   5. Format the output via `dart format` so the result plays nicely
///      with CI diffs and IDEs.
class TsSchemaBuilder implements Builder {
  TsSchemaBuilder(this.config);

  final TsSchemaConfig config;

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$package$': ['lib/ts_schema.g.dart'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final pkgDir = Directory.current.path;
    final exportScript = _locateExportScript();

    final runner = DenoRunner(
      denoCommand: config.deno,
      exportScriptPath: exportScript,
      workingDirectory: pkgDir,
    );

    final schema = await runner.evaluate(
      tsPath: config.source,
      exportName: config.export,
    );

    final source = _emit(schema);

    final output = AssetId(
      buildStep.inputId.package,
      'lib/ts_schema.g.dart',
    );
    await buildStep.writeAsString(output, source);

    // Format after writing so downstream diffs stay clean.
    await _dartFormat(p.join(pkgDir, 'lib/ts_schema.g.dart'));

    log.info(
      'ts_schema_codegen: wrote ${source.length} bytes from ${config.source} '
      '(export=${config.export}, template=${config.template}).',
    );
  }

  String _emit(Object? schema) {
    switch (config.template) {
      case 'field_definitions':
        return emitFieldDefinitions(
          schema: schema,
          fieldClassImport: config.fieldClassImport!,
          tsSourcePath: config.source,
          exportName: config.export,
        );
      case 'map':
      default:
        return emitMapTemplate(
          value: schema,
          tsSourcePath: config.source,
          exportName: config.export,
        );
    }
  }

  /// Locate `tool/ts_export.ts` bundled with this package, regardless of
  /// whether the package is resolved via `path:`, `git:`, or pub.
  String _locateExportScript() {
    // Package-relative asset resolution: the Dart file we're executing from
    // is under .dart_tool/build/... at build time, so we can't use __file__.
    // Instead, resolve via Isolate.resolvePackageUri on our own package URI.
    // For MVP, rely on PACKAGE_CONFIG to find the package root.
    //
    // Simplest correct implementation: walk up from Directory.current looking
    // for the package's `tool/ts_export.ts`. Since build_runner resolves
    // package URIs for us, we rely on `package:ts_schema_codegen` pointing
    // into the right place on disk.
    final uri = Uri.parse('package:ts_schema_codegen/builder.dart');
    // Isolate.resolvePackageUri is async — we do it synchronously via the
    // package_config file in the consumer's .dart_tool directory.
    final config = File(
      p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
    );
    if (!config.existsSync()) {
      throw StateError(
        'ts_schema_codegen: .dart_tool/package_config.json not found. '
        'Run `dart pub get` first.',
      );
    }
    final raw = config.readAsStringSync();
    // Quick-and-dirty lookup — full JSON parse would be cleaner but pulls a
    // dep; a regex is enough for MVP and surface errors clearly on miss.
    final match = RegExp(
      r'"name"\s*:\s*"ts_schema_codegen"[^}]*"rootUri"\s*:\s*"([^"]+)"',
    ).firstMatch(raw);
    if (match == null) {
      throw StateError(
        'ts_schema_codegen: package not found in .dart_tool/package_config.json. '
        'Make sure `ts_schema_codegen` is in dev_dependencies.',
      );
    }
    var rootUri = match.group(1)!;
    // rootUri is typically "../../packages/ts_schema_codegen" — resolve
    // relative to the .dart_tool/ directory.
    final base = p.join(Directory.current.path, '.dart_tool');
    if (rootUri.startsWith('file://')) {
      rootUri = Uri.parse(rootUri).toFilePath();
    } else {
      rootUri = p.normalize(p.join(base, rootUri));
    }
    final scriptPath = p.join(rootUri, 'tool', 'ts_export.ts');
    if (!File(scriptPath).existsSync()) {
      throw StateError(
        'ts_schema_codegen: bundled evaluator not found at $scriptPath. '
        'Reinstall the package (pub cache repair).',
      );
    }
    // Silence the unused uri warning.
    uri.toString();
    return scriptPath;
  }

  Future<void> _dartFormat(String path) async {
    final result = await Process.run(
      'dart',
      ['format', '--page-width', '120', path],
    );
    if (result.exitCode != 0) {
      log.warning(
        'ts_schema_codegen: dart format exited with ${result.exitCode}.\n'
        'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    }
  }
}
