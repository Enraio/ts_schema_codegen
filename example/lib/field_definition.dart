/// Field types for dynamic form rendering.
enum FieldType { dropdown, multiSelect, text, number, slider, toggle }

/// Definition of a single form field.
///
/// The generated code references this class by the name `FieldDefinition`
/// with these named constructor parameters. If you rename the class or
/// parameters, update the generator template accordingly.
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
