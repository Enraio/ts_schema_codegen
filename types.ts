// Typed authoring helpers for ts_schema_codegen.
//
// Consume from your TS schema via Deno URL import:
//
//   import {
//     defineSchema,
//     type FieldDef,
//     type FieldSet,
//     type FieldType,
//   } from 'https://raw.githubusercontent.com/Enraio/ts_schema_codegen/v0.1.1/types.ts';
//
// Pin to a tag (`v0.1.1`) rather than `main` so schema drift can't silently
// change types under your feet. Alternatively, vendor this file into your
// own repo — it's ~40 lines and stable.
//
// These types describe exactly what the `field_definitions` template in
// the Dart side emits; getting them wrong in TS will surface as either a
// TypeScript error at edit time (good) or a schema validation error at
// `dart run build_runner build` time (ok-ish — but you wanted the former,
// which is why this file exists).

/** Kind of input the Dart UI renders for this field. */
export type FieldType = 'string' | 'array' | 'text';

/** Single extractable attribute inside a fieldset. */
export interface FieldDef {
  /** Stable identifier (e.g. `'email'`, `'fabric'`). */
  id: string;
  /** `'string'` → dropdown, `'array'` → multi-select, `'text'` → freeform. */
  type: FieldType;
  /** UI label shown to the user. */
  label: string;
  /** Allowed values for dropdown / multi-select. */
  options?: readonly string[];
  /** Placeholder / help text in the UI. */
  hint?: string;
  /** Whether the field must be filled. */
  required?: boolean;
  /** Pre-populated default. */
  defaultValue?: string;
  /**
   * Any additional metadata your tooling needs (abbreviation, aiRelevant,
   * compactAs, etc.). Tolerated by the emitter — carry whatever shape you
   * want and read it from the registry at runtime.
   */
  readonly [key: string]: unknown;
}

/** Group of fields that applies to one or more item categories. */
export interface FieldSet {
  /** Display label for this fieldset (e.g. `'FORMS'`). */
  label: string;
  /** Top-level categories that route to this fieldset. */
  categories: readonly string[];
  /**
   * Subcategory values that also route here. Checked **before** the
   * category switch — useful for backward-compat routing of legacy
   * subcategories.
   */
  subcategoryRoutes?: readonly string[];
  /** Fields emitted as `const <key>Fields = <FieldDefinition>[...]`. */
  fields: readonly FieldDef[];
}

/**
 * Identity helper that pins the shape of your schema at author time.
 *
 * Wrap your schema in `defineSchema(...)` to get:
 *   - IDE completion on every fieldset and field key
 *   - Compile-time errors for misspelled keys (`subcategoryRoute` vs
 *     `subcategoryRoutes`)
 *   - Refactor safety when the types here evolve in a future release
 *
 * ```ts
 * export const SCHEMA = defineSchema({
 *   signup: {
 *     label: 'Signup',
 *     categories: ['signup'],
 *     fields: [
 *       { id: 'email', type: 'text', label: 'Email', required: true },
 *     ],
 *   },
 * });
 * ```
 *
 * The generic parameter `S` is inferred — your call sites see the concrete
 * shape of your schema, not the generic `Record<string, FieldSet>`.
 */
export const defineSchema = <S extends Record<string, FieldSet>>(schema: S): S =>
  schema;
