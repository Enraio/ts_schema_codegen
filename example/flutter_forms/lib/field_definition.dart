/// Field types for dynamic form rendering.
enum FieldType { dropdown, multiSelect, text, number, slider, toggle }

/// Definition of a single form field — referenced by the generated
/// `ts_schema.g.dart`. Keep the class name and constructor parameters
/// aligned with the emitter in `ts_schema_codegen`.
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
