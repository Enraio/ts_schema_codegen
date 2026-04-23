import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'deno_runner.dart';
import 'emitter.dart';
import 'ir.dart';

/// Builder triggered once per consuming package (`$package$`).
///
/// Pipeline:
///   1. Read options from build.yaml (parsed into [TsSchemaConfig]).
///   2. For each configured schema: shell out to Deno with the bundled
///      `tool/ts_export.ts` script, passing the TS entry path, the export
///      name, and the template (so the Deno side can validate the shape).
///   3. Parse the resulting JSON, run it through the selected emitter.
///   4. Write the Dart source to the configured output path.
///   5. `dart format --page-width 120` every output so downstream diffs
///      stay clean across developer runs.
class TsSchemaBuilder implements Builder {
  TsSchemaBuilder(this.config);

  final TsSchemaConfig config;

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$package$': config.schemas.map((s) => s.output).toList(),
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

    for (final entry in config.schemas) {
      await _buildOne(
        buildStep: buildStep,
        entry: entry,
        runner: runner,
        pkgDir: pkgDir,
      );
    }
  }

  Future<void> _buildOne({
    required BuildStep buildStep,
    required SchemaEntry entry,
    required DenoRunner runner,
    required String pkgDir,
  }) async {
    final schema = await runner.evaluate(
      tsPath: entry.source,
      exportName: entry.export,
      template: entry.template,
    );

    final source = _emit(schema, entry);

    final output = AssetId(buildStep.inputId.package, entry.output);
    await buildStep.writeAsString(output, source);

    // Format after writing. The `dart format` subprocess takes the absolute
    // on-disk path — resolve it relative to the package root.
    await _dartFormat(p.join(pkgDir, entry.output));

    log.info(
      'ts_schema_codegen: wrote ${source.length} bytes to ${entry.output} '
      'from ${entry.source} (export=${entry.export}, '
      'template=${entry.template}).',
    );
  }

  String _emit(Object? schema, SchemaEntry entry) {
    switch (entry.template) {
      case 'field_definitions':
        // Parse raw JSON into the typed IR first. The parser validates
        // the shape with JSON-pointer error paths; the emitter trusts
        // the IR and focuses on string generation.
        final ir = parseFieldDefinitionsIR(schema, rootPath: entry.export);
        return emitFieldDefinitions(
          schema: ir,
          fieldClassImport: entry.fieldClassImport!,
          tsSourcePath: entry.source,
          exportName: entry.export,
        );
      case 'map':
      default:
        return emitMapTemplate(
          value: schema,
          tsSourcePath: entry.source,
          exportName: entry.export,
        );
    }
  }

  /// Locate `tool/ts_export.ts` bundled with this package, regardless of
  /// whether the package is resolved via `path:`, `git:`, or pub.
  String _locateExportScript() {
    final config = File(
      p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
    );
    if (!config.existsSync()) {
      throw StateError(
        'ts_schema_codegen: .dart_tool/package_config.json not found. '
        'Run `dart pub get` first.',
      );
    }

    final decoded =
        jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    final packages = decoded['packages'];
    if (packages is! List) {
      throw StateError(
        'ts_schema_codegen: package_config.json has no "packages" list. '
        'This looks like a corrupt pub cache; re-run `dart pub get`.',
      );
    }
    final entry =
        packages.cast<Object?>().whereType<Map<String, Object?>>().firstWhere(
              (p) => p['name'] == 'ts_schema_codegen',
              orElse: () => const <String, Object?>{},
            );
    final rawRoot = entry['rootUri'];
    if (rawRoot is! String) {
      throw StateError(
        'ts_schema_codegen: package not found in .dart_tool/package_config.json. '
        'Make sure `ts_schema_codegen` is in dev_dependencies.',
      );
    }

    // rootUri is relative to the .dart_tool/ directory (per dart-lang spec),
    // typically something like "../../packages/ts_schema_codegen" or a
    // "file:///absolute/path" when pub fetched it from a path dep.
    String rootPath;
    if (rawRoot.startsWith('file://')) {
      rootPath = Uri.parse(rawRoot).toFilePath();
    } else {
      final base = p.join(Directory.current.path, '.dart_tool');
      rootPath = p.normalize(p.join(base, rawRoot));
    }

    final scriptPath = p.join(rootPath, 'tool', 'ts_export.ts');
    if (!File(scriptPath).existsSync()) {
      throw StateError(
        'ts_schema_codegen: bundled evaluator not found at $scriptPath. '
        'Reinstall the package (pub cache repair).',
      );
    }
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
