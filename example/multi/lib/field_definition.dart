enum FieldType { dropdown, multiSelect, text, number, slider, toggle }

class FieldDefinition {
  final String id;
  final String label;
  final FieldType type;
  final List<String>? options;
  final String? hint;
  final bool required;
  final Object? defaultValue;

  const FieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.hint,
    this.required = false,
    this.defaultValue,
  });
}
