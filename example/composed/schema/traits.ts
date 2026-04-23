// A reusable "trait" — a slice of fields that multiple fieldsets share.
// Defined in its own file; imported by fieldset files; combined via spread.

export const identifiable = {
  id: {
    type: 'text' as const,
    label: 'ID',
    required: true,
  },
  name: {
    type: 'text' as const,
    label: 'Name',
    required: true,
  },
};

export const timestamped = {
  created_at: {
    type: 'text' as const,
    label: 'Created At',
  },
  updated_at: {
    type: 'text' as const,
    label: 'Updated At',
  },
};
