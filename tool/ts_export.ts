// Bundled Deno evaluator for ts_schema_codegen.
//
// Invoked by the Dart Builder at build time. Given a path to a user's TS
// entry file and the name of an export, dynamically imports the module and
// prints `JSON.stringify(mod[exportName])` to stdout.
//
// Usage:
//   deno run --allow-read ts_export.ts <absolute-path-to-user-ts> <export-name>
//
// Errors go to stderr with a non-zero exit code so the Dart side can surface
// a useful build-failure message.

if (import.meta.main) {
  const [tsPath, exportName] = Deno.args;
  if (!tsPath || !exportName) {
    console.error(
      'ts_export: expected two arguments — <ts-path> <export-name>',
    );
    Deno.exit(2);
  }

  // Dynamic import with file:// URL so absolute paths work cross-platform.
  const url = tsPath.startsWith('file://')
    ? tsPath
    : `file://${tsPath}`;

  let mod: Record<string, unknown>;
  try {
    mod = (await import(url)) as Record<string, unknown>;
  } catch (err) {
    console.error(
      `ts_export: failed to import ${tsPath}:\n${(err as Error).stack ?? err}`,
    );
    Deno.exit(3);
  }

  if (!(exportName in mod)) {
    const available = Object.keys(mod).join(', ');
    console.error(
      `ts_export: "${exportName}" is not exported from ${tsPath}. ` +
        `Available exports: ${available || '(none)'}`,
    );
    Deno.exit(4);
  }

  const value = mod[exportName];
  let serialized: string;
  try {
    serialized = JSON.stringify(value);
  } catch (err) {
    console.error(
      `ts_export: export "${exportName}" is not JSON-serializable ` +
        `(contains functions, circular refs, etc.): ${(err as Error).message}`,
    );
    Deno.exit(5);
  }

  // Write to stdout. The Dart side reads the full stream and jsonDecode's it.
  Deno.stdout.writeSync(new TextEncoder().encode(serialized));
}
