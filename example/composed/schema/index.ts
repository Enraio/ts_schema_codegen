import { user } from './user.ts';
import { project } from './project.ts';
import { defineSchema, type FieldSet } from './types.ts';

// The schema is assembled from pieces via `Object.fromEntries` — the exact
// kind of runtime composition that tree-sitter-style parsers can't handle.
// Deno evaluates this as normal TS at build time, so it just works.

const ORDERED: Array<[string, FieldSet]> = [
  ['user', user],
  ['project', project],
];

export const SCHEMA = defineSchema(Object.fromEntries(ORDERED));
