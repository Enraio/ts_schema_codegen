// A generic dynamic-form schema. Each fieldset is a section of a form,
// with fields that describe the inputs.
//
// The `field_definitions` template will emit one `const <key>Fields` list
// per section + a `getFieldsForCategoryGenerated(category, {subcategory})`
// function that routes a form kind to the right fieldset.

export const FORM_SCHEMA = {
  // Fields added to every form, regardless of kind.
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

  // Account signup form.
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

  // Feedback form. Routes via subcategory too — bug reports jump here even
  // if the top-level category is something more general.
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
} as const;
