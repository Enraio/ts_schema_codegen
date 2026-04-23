// Re-export the shared types from the package's `types.ts` so fieldset
// files can import from a short local path. In your own project you'd
// typically import directly from the pinned URL; this indirection is just
// ergonomics for the example.

export { defineSchema, type FieldDef, type FieldSet, type FieldType } from '../../../types.ts';
