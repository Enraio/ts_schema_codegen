import { identifiable, timestamped } from './traits.ts';
import type { FieldSet } from './types.ts';

export const project: FieldSet = {
  label: 'PROJECT',
  categories: ['project'],
  fields: [
    ..._fieldsFrom(identifiable),
    {
      id: 'visibility',
      type: 'string',
      label: 'Visibility',
      options: ['Private', 'Internal', 'Public'],
      defaultValue: 'Private',
    },
    {
      id: 'tags',
      type: 'array',
      label: 'Tags',
      options: ['frontend', 'backend', 'infra', 'ml', 'docs'],
    },
    ..._fieldsFrom(timestamped),
  ],
};

function _fieldsFrom(
  trait: Record<string, { type: 'string' | 'array' | 'text'; label: string; required?: boolean }>,
) {
  return Object.entries(trait).map(([id, rest]) => ({ id, ...rest }));
}
