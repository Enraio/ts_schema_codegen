import { defineSchema } from '../../../types.ts';

export const FORMS = defineSchema({
  signup: {
    label: 'SIGNUP',
    categories: ['signup'],
    fields: [
      { id: 'email', type: 'text', label: 'Email', required: true },
      {
        id: 'role',
        type: 'string',
        label: 'Role',
        options: ['Admin', 'Member', 'Guest'],
      },
    ],
  },
});
