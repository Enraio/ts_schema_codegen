import { identifiable, timestamped } from './traits.ts';
import type { FieldSet } from './types.ts';

// Fields for the user form — composed from `identifiable` + `timestamped`
// traits plus user-specific fields. Any TS construct that evaluates at
// module-load time is fair game: imports, spreads, computed keys, etc.

export const user: FieldSet = {
  label: 'USER',
  categories: ['user', 'member'],
  fields: [
    ..._fieldsFrom(identifiable),
    {
      id: 'email',
      type: 'text',
      label: 'Email',
      required: true,
    },
    {
      id: 'plan',
      type: 'string',
      label: 'Plan',
      options: ['Free', 'Pro', 'Team', 'Enterprise'],
    },
    ..._fieldsFrom(timestamped),
  ],
};

function _fieldsFrom(
  trait: Record<string, { type: 'string' | 'array' | 'text'; label: string; required?: boolean }>,
) {
  return Object.entries(trait).map(([id, rest]) => ({ id, ...rest }));
}
