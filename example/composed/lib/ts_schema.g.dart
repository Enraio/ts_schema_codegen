// GENERATED — DO NOT EDIT.
// Source: schema/index.ts (export: SCHEMA)
// Regenerate: dart run build_runner build

import 'package:ts_schema_codegen_composed_example/field_definition.dart';

const userFields = <FieldDefinition>[
  FieldDefinition(
    id: 'id',
    label: 'ID',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'name',
    label: 'Name',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'email',
    label: 'Email',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'plan',
    label: 'Plan',
    type: FieldType.dropdown,
    options: ['Free', 'Pro', 'Team', 'Enterprise'],
  ),
  FieldDefinition(
    id: 'created_at',
    label: 'Created At',
    type: FieldType.text,
  ),
  FieldDefinition(
    id: 'updated_at',
    label: 'Updated At',
    type: FieldType.text,
  ),
];

const projectFields = <FieldDefinition>[
  FieldDefinition(
    id: 'id',
    label: 'ID',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'name',
    label: 'Name',
    type: FieldType.text,
    required: true,
  ),
  FieldDefinition(
    id: 'visibility',
    label: 'Visibility',
    type: FieldType.dropdown,
    options: ['Private', 'Internal', 'Public'],
    defaultValue: 'Private',
  ),
  FieldDefinition(
    id: 'tags',
    label: 'Tags',
    type: FieldType.multiSelect,
    options: ['frontend', 'backend', 'infra', 'ml', 'docs'],
  ),
  FieldDefinition(
    id: 'created_at',
    label: 'Created At',
    type: FieldType.text,
  ),
  FieldDefinition(
    id: 'updated_at',
    label: 'Updated At',
    type: FieldType.text,
  ),
];

List<FieldDefinition> getFieldsForCategoryGenerated(
  String category, {
  String? subcategory,
}) {
  if (subcategory != null) {
    switch (subcategory.toLowerCase()) {
    }
  }

  switch (category.toLowerCase()) {
    case 'user':
    case 'member':
      return userFields;
    case 'project':
      return projectFields;
    default:
      return const <FieldDefinition>[];
  }
}

