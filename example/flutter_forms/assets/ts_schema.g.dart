// GENERATED — DO NOT EDIT.
// Source: schema/index.ts (export: FORM_SCHEMA)
// Regenerate: dart run build_runner build

import 'package:ts_schema_forms_demo/field_definition.dart';

/// Data carrier for the generated fieldset registry (`kFieldSets`).
///
/// Provided by the generator so consumers can reflect on the
/// schema at runtime — iterate [kFieldSets], build custom routing,
/// etc. — without depending on a consumer-authored wrapper class.
class GeneratedFieldSet {
  final String label;
  final List<String> categories;
  final List<String> subcategoryRoutes;
  final List<FieldDefinition> fields;

  const GeneratedFieldSet({
    required this.label,
    required this.categories,
    this.subcategoryRoutes = const [],
    required this.fields,
  });
}

const commonFields = <FieldDefinition>[
  FieldDefinition(
    id: 'consent',
    label: 'I agree to the terms',
    type: FieldType.dropdown,
    options: ['Yes', 'No'],
    required: true,
  ),
];

const accountFields = <FieldDefinition>[
  FieldDefinition(
    id: 'email',
    label: 'Email',
    type: FieldType.text,
    hint: 'you@example.com',
    required: true,
  ),
  FieldDefinition(
    id: 'role',
    label: 'Primary role',
    type: FieldType.dropdown,
    options: ['Engineer', 'Designer', 'Product', 'Other'],
  ),
  FieldDefinition(
    id: 'notifications',
    label: 'Notifications',
    type: FieldType.multiSelect,
    options: ['Email', 'Push', 'SMS'],
    defaultValue: 'Email',
  ),
  ...commonFields,
];

const feedbackFields = <FieldDefinition>[
  FieldDefinition(
    id: 'severity',
    label: 'Severity',
    type: FieldType.dropdown,
    options: ['Low', 'Medium', 'High', 'Critical'],
  ),
  FieldDefinition(
    id: 'description',
    label: 'What happened?',
    type: FieldType.text,
    hint: 'Steps to reproduce, expected vs actual…',
    required: true,
  ),
  FieldDefinition(
    id: 'tags',
    label: 'Tags',
    type: FieldType.multiSelect,
    options: ['ui', 'backend', 'performance', 'docs'],
  ),
  ...commonFields,
];

const ticketFields = <FieldDefinition>[
  FieldDefinition(
    id: 'subject',
    label: 'Subject',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'priority',
    label: 'Priority',
    type: FieldType.dropdown,
    options: ['P0', 'P1', 'P2', 'P3'],
  ),
  FieldDefinition(
    id: 'channels',
    label: 'Notify via',
    type: FieldType.multiSelect,
    options: ['Email', 'Slack', 'Phone'],
  ),
  ...commonFields,
];

/// Registry of every fieldset emitted from the TS schema, keyed
/// by fieldset name. Reflectable — iterate [kFieldSets] to build
/// custom routing, UIs, or validation without regenerating Dart.
const kFieldSets = <String, GeneratedFieldSet>{
  'common': GeneratedFieldSet(
    label: 'COMMON',
    categories: <String>[],
    fields: commonFields,
  ),
  'account': GeneratedFieldSet(
    label: 'ACCOUNT',
    categories: ['signup', 'register'],
    fields: accountFields,
  ),
  'feedback': GeneratedFieldSet(
    label: 'FEEDBACK',
    categories: ['feedback'],
    subcategoryRoutes: ['bug', 'feature-request'],
    fields: feedbackFields,
  ),
  'ticket': GeneratedFieldSet(
    label: 'TICKET',
    categories: ['ticket', 'support'],
    fields: ticketFields,
  ),
};

List<FieldDefinition> getFieldsForCategoryGenerated(
  String category, {
  String? subcategory,
}) {
  if (subcategory != null) {
    switch (subcategory.toLowerCase()) {
      case 'bug':
      case 'feature-request':
        return feedbackFields;
    }
  }

  switch (category.toLowerCase()) {
    case 'signup':
    case 'register':
      return accountFields;
    case 'feedback':
      return feedbackFields;
    case 'ticket':
    case 'support':
      return ticketFields;
    default:
      return commonFields;
  }
}

