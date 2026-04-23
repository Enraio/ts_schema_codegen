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
//
// ---------------------------------------------------------------------------
// Non-JSON-serializable types
//
// `JSON.stringify` silently mangles common TS values — Date becomes an ISO
// string with no type marker; Map and Set become `{}` (empty object), losing
// their contents; BigInt throws. We wrap them as tagged objects:
//
//   Date   → { __type: 'Date',   iso:     string }
//   BigInt → { __type: 'BigInt', value:   string }        // stringified for precision
//   Map    → { __type: 'Map',    entries: [key, value][] }
//   Set    → { __type: 'Set',    values:  unknown[] }
//
// The Dart side sees these as plain Map<String, Object?> and can decide
// whether to materialize them as typed Dart values (DateTime, BigInt, etc.)
// — that's template work. For now, data survives the crossing.

function replacer(this: unknown, key: string, value: unknown): unknown {
  // `Date` has a built-in `toJSON()` that stringify calls BEFORE the
  // replacer, so by the time we see `value` for a Date it's already a
  // string. The unmodified value still sits on the holder object at
  // `this[key]` — reach into it directly.
  const raw = (this as Record<string, unknown> | null)?.[key];
  if (raw instanceof Date) {
    return { __type: 'Date', iso: raw.toISOString() };
  }
  if (typeof value === 'bigint') {
    return { __type: 'BigInt', value: value.toString() };
  }
  if (value instanceof Map) {
    return { __type: 'Map', entries: Array.from(value.entries()) };
  }
  if (value instanceof Set) {
    return { __type: 'Set', values: Array.from(value) };
  }
  return value;
}

if (import.meta.main) {
  const [tsPath, exportName] = Deno.args;
  if (!tsPath || !exportName) {
    console.error(
      'ts_export: expected two arguments — <ts-path> <export-name>',
    );
    Deno.exit(2);
  }

  // Dynamic import with file:// URL so absolute paths work cross-platform.
  const url = tsPath.startsWith('file://') ? tsPath : `file://${tsPath}`;

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
    serialized = JSON.stringify(value, replacer);
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
