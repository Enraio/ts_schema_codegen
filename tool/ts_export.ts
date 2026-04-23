// Bundled Deno evaluator for ts_schema_codegen.
//
// Invoked by the Dart Builder at build time. Given a path to a user's TS
// entry file, the name of an export, and a template name, dynamically
// imports the module, optionally validates the shape (for
// `field_definitions`), and prints `JSON.stringify(mod[exportName])` to
// stdout.
//
// Usage:
//   deno run --allow-read ts_export.ts <ts-path> <export-name> <template>
//
// Exit codes:
//   0 success
//   2 bad args
//   3 import failed
//   4 export not found
//   5 not JSON-serializable
//   6 validation failed (field_definitions shape mismatch)
//
// Errors go to stderr with JSON-pointer paths where applicable so the Dart
// side can surface them verbatim.

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

// ---------------------------------------------------------------------------
// Hand-rolled validator for the `field_definitions` template.
//
// Hand-rolled (no Zod) because this package already requires Deno; adding a
// network-fetched dep is worse than the ~80 lines below. Errors carry a
// JSON-pointer-ish `path` (e.g. `SCHEMA.ticket.fields[2].type`) so users can
// map the failure back to their TS source directly.

type Issue = { path: string; expected: string; got: string };

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function whatIs(v: unknown): string {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  return typeof v;
}

function validateFieldDefinitionsSchema(
  root: unknown,
  rootPath: string,
): Issue[] {
  const issues: Issue[] = [];

  if (!isObject(root)) {
    issues.push({
      path: rootPath,
      expected: 'object (Record<fieldsetKey, FieldSet>)',
      got: whatIs(root),
    });
    return issues;
  }

  for (const [fieldsetKey, fieldsetVal] of Object.entries(root)) {
    const fsPath = `${rootPath}.${fieldsetKey}`;

    if (!isObject(fieldsetVal)) {
      issues.push({
        path: fsPath,
        expected: 'FieldSet object',
        got: whatIs(fieldsetVal),
      });
      continue;
    }

    if (typeof fieldsetVal.label !== 'string') {
      issues.push({
        path: `${fsPath}.label`,
        expected: 'string',
        got: whatIs(fieldsetVal.label),
      });
    }

    if (!Array.isArray(fieldsetVal.categories)) {
      issues.push({
        path: `${fsPath}.categories`,
        expected: 'string[]',
        got: whatIs(fieldsetVal.categories),
      });
    } else {
      fieldsetVal.categories.forEach((c, i) => {
        if (typeof c !== 'string') {
          issues.push({
            path: `${fsPath}.categories[${i}]`,
            expected: 'string',
            got: whatIs(c),
          });
        }
      });
    }

    if (fieldsetVal.subcategoryRoutes !== undefined) {
      if (!Array.isArray(fieldsetVal.subcategoryRoutes)) {
        issues.push({
          path: `${fsPath}.subcategoryRoutes`,
          expected: 'string[] (or omit)',
          got: whatIs(fieldsetVal.subcategoryRoutes),
        });
      } else {
        fieldsetVal.subcategoryRoutes.forEach((r, i) => {
          if (typeof r !== 'string') {
            issues.push({
              path: `${fsPath}.subcategoryRoutes[${i}]`,
              expected: 'string',
              got: whatIs(r),
            });
          }
        });
      }
    }

    if (!Array.isArray(fieldsetVal.fields)) {
      issues.push({
        path: `${fsPath}.fields`,
        expected: 'FieldDef[]',
        got: whatIs(fieldsetVal.fields),
      });
      continue;
    }

    fieldsetVal.fields.forEach((field, i) => {
      const fPath = `${fsPath}.fields[${i}]`;
      if (!isObject(field)) {
        issues.push({
          path: fPath,
          expected: 'FieldDef object',
          got: whatIs(field),
        });
        return;
      }
      if (typeof field.id !== 'string') {
        issues.push({
          path: `${fPath}.id`,
          expected: 'string',
          got: whatIs(field.id),
        });
      }
      if (typeof field.label !== 'string') {
        issues.push({
          path: `${fPath}.label`,
          expected: 'string',
          got: whatIs(field.label),
        });
      }
      if (
        field.type !== 'string' &&
        field.type !== 'array' &&
        field.type !== 'text'
      ) {
        issues.push({
          path: `${fPath}.type`,
          expected: "'string' | 'array' | 'text'",
          got: typeof field.type === 'string'
            ? `'${field.type}'`
            : whatIs(field.type),
        });
      }
      if (field.options !== undefined && !Array.isArray(field.options)) {
        issues.push({
          path: `${fPath}.options`,
          expected: 'string[] (or omit)',
          got: whatIs(field.options),
        });
      }
      if (field.required !== undefined && typeof field.required !== 'boolean') {
        issues.push({
          path: `${fPath}.required`,
          expected: 'boolean (or omit)',
          got: whatIs(field.required),
        });
      }
      if (field.hint !== undefined && typeof field.hint !== 'string') {
        issues.push({
          path: `${fPath}.hint`,
          expected: 'string (or omit)',
          got: whatIs(field.hint),
        });
      }
    });
  }

  return issues;
}

function formatIssues(issues: Issue[], exportName: string): string {
  const lines = [`ts_schema_codegen: invalid schema in export "${exportName}"`];
  for (const issue of issues) {
    lines.push(`  at ${issue.path}`);
    lines.push(`    expected: ${issue.expected}`);
    lines.push(`    got:      ${issue.got}`);
  }
  return lines.join('\n');
}

// ---------------------------------------------------------------------------

if (import.meta.main) {
  const [tsPath, exportName, template = 'map'] = Deno.args;
  if (!tsPath || !exportName) {
    console.error(
      'ts_export: expected three arguments — <ts-path> <export-name> <template>',
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

  if (template === 'field_definitions') {
    const issues = validateFieldDefinitionsSchema(value, exportName);
    if (issues.length > 0) {
      console.error(formatIssues(issues, exportName));
      Deno.exit(6);
    }
  }

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
