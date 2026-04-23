// Source of truth for every form in the demo app.
//
// Generated into lib/ts_schema.g.dart by `dart run build_runner build`.
// The Flutter UI renders the resulting FieldDefinition lists as real widgets:
//   type: 'text'   → TextField
//   type: 'string' → DropdownButtonFormField
//   type: 'array'  → FilterChip set (multi-select)

export const FORM_SCHEMA = {
  // Appended to every non-common fieldset automatically.
  common: {
    label: 'COMMON',
    categories: [],
    fields: [
      {
        id: 'consent',
        type: 'string',
        label: 'I agree to the terms',
        options: ['Yes', 'No'],
        required: true,
      },
    ],
  },

  // Account signup.
  account: {
    label: 'ACCOUNT',
    categories: ['signup', 'register'],
    fields: [
      {
        id: 'email',
        type: 'text',
        label: 'Email',
        hint: 'you@example.com',
        required: true,
      },
      {
        id: 'role',
        type: 'string',
        label: 'Primary role',
        options: ['Engineer', 'Designer', 'Product', 'Other'],
      },
      {
        id: 'notifications',
        type: 'array',
        label: 'Notifications',
        options: ['Email', 'Push', 'SMS'],
        defaultValue: 'Email',
      },
    ],
  },

  // Feedback. Subcategory routing: 'bug' or 'feature-request' lands here
  // even if the category is something else.
  feedback: {
    label: 'FEEDBACK',
    categories: ['feedback'],
    subcategoryRoutes: ['bug', 'feature-request'],
    fields: [
      {
        id: 'severity',
        type: 'string',
        label: 'Severity',
        options: ['Low', 'Medium', 'High', 'Critical'],
      },
      {
        id: 'description',
        type: 'text',
        label: 'What happened?',
        hint: 'Steps to reproduce, expected vs actual…',
        required: true,
      },
      {
        id: 'tags',
        type: 'array',
        label: 'Tags',
        options: ['ui', 'backend', 'performance', 'docs'],
      },
    ],
  },

  // Support ticket.
  ticket: {
    label: 'TICKET',
    categories: ['ticket', 'support'],
    fields: [
      {
        id: 'subject',
        type: 'text',
        label: 'Subject',
        required: true,
      },
      {
        id: 'priority',
        type: 'string',
        label: 'Priority',
        options: ['P0', 'P1', 'P2', 'P3'],
      },
      {
        id: 'channels',
        type: 'array',
        label: 'Notify via',
        options: ['Email', 'Slack', 'Phone'],
      },
    ],
  },
} as const;
