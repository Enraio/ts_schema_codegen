import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Invokes Deno to evaluate a TypeScript module and JSON-serialize one of its
/// exports. Returns the parsed JSON as a Dart [Object?].
///
/// The actual evaluation lives in `tool/ts_export.ts` inside this package —
/// that script dynamically imports the user's TS file and prints
/// `JSON.stringify(mod[exportName])` to stdout.
class DenoRunner {
  DenoRunner({
    required this.denoCommand,
    required this.exportScriptPath,
    required this.workingDirectory,
  });

  /// Executable used to run Deno (usually just `deno`; absolute path otherwise).
  final String denoCommand;

  /// Absolute path to `tool/ts_export.ts` in this package.
  final String exportScriptPath;

  /// Working directory the Deno child process is spawned in. All relative
  /// paths (the `source` option) resolve from here — set it to the consuming
  /// package's root so user paths behave as they wrote them.
  final String workingDirectory;

  /// Evaluate [tsPath] (relative to [workingDirectory]) and extract the
  /// named export [exportName]. Returns the parsed JSON.
  ///
  /// [template] is forwarded to `tool/ts_export.ts` so the Deno side can
  /// validate the shape before serialization. Unknown templates fall through
  /// to no validation — the emitter's own checks still apply.
  Future<Object?> evaluate({
    required String tsPath,
    required String exportName,
    String template = 'map',
  }) async {
    final absTs = p.isAbsolute(tsPath)
        ? tsPath
        : p.normalize(p.join(workingDirectory, tsPath));
    if (!File(absTs).existsSync()) {
      throw StateError(
        'ts_schema_codegen: source file not found at $absTs '
        '(workingDirectory=$workingDirectory, tsPath=$tsPath). '
        'Check the "source" option in build.yaml.',
      );
    }

    final result = await Process.run(
      denoCommand,
      [
        'run',
        // ts_export.ts reads the user's TS file; user files may import more
        // from sibling dirs, so allow full read access rooted at cwd.
        '--allow-read',
        exportScriptPath,
        absTs,
        exportName,
        template,
      ],
      workingDirectory: workingDirectory,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      throw StateError(
        'ts_schema_codegen: deno exited with code ${result.exitCode}.\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}',
      );
    }

    final stdout = result.stdout as String;
    try {
      return jsonDecode(stdout);
    } on FormatException catch (e) {
      throw StateError(
        'ts_schema_codegen: deno returned non-JSON output.\n'
        'Parse error: $e\n'
        'stdout (first 500 chars): ${stdout.substring(0, stdout.length.clamp(0, 500))}',
      );
    }
  }
}
