import 'package:flutter/material.dart';

import 'field_definition.dart';

/// Renders a list of [FieldDefinition]s as real form widgets and tracks
/// the values + validation state in a single place.
class FormRenderer extends StatefulWidget {
  const FormRenderer({
    super.key,
    required this.fields,
    required this.formKey,
    required this.values,
    required this.onChanged,
  });

  final List<FieldDefinition> fields;
  final GlobalKey<FormState> formKey;
  final Map<String, Object?> values;
  final VoidCallback onChanged;

  @override
  State<FormRenderer> createState() => _FormRendererState();
}

class _FormRendererState extends State<FormRenderer> {
  @override
  void didUpdateWidget(FormRenderer old) {
    super.didUpdateWidget(old);
    if (!identical(old.fields, widget.fields)) {
      _seedDefaults();
    }
  }

  @override
  void initState() {
    super.initState();
    _seedDefaults();
  }

  void _seedDefaults() {
    for (final f in widget.fields) {
      widget.values.putIfAbsent(f.id, () {
        if (f.type == FieldType.multiSelect) {
          return <String>{
            if (f.defaultValue is String) f.defaultValue as String,
          };
        }
        return f.defaultValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in widget.fields) ...[
            _fieldFor(f),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _fieldFor(FieldDefinition f) {
    switch (f.type) {
      case FieldType.text:
        return TextFormField(
          initialValue: widget.values[f.id] as String?,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: f.id == 'description' ? 4 : 1,
          validator: (v) {
            if (f.required && (v == null || v.isEmpty)) {
              return '${f.label} is required';
            }
            return null;
          },
          onChanged: (v) {
            widget.values[f.id] = v;
            widget.onChanged();
          },
        );

      case FieldType.dropdown:
        final opts = f.options ?? const <String>[];
        return DropdownButtonFormField<String>(
          initialValue: widget.values[f.id] as String?,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final o in opts)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          validator: (v) {
            if (f.required && v == null) return '${f.label} is required';
            return null;
          },
          onChanged: (v) {
            widget.values[f.id] = v;
            widget.onChanged();
          },
        );

      case FieldType.multiSelect:
        final opts = f.options ?? const <String>[];
        final selected = (widget.values[f.id] as Set<String>?) ?? <String>{};
        return InputDecorator(
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            border: const OutlineInputBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final o in opts)
                  FilterChip(
                    label: Text(o),
                    selected: selected.contains(o),
                    onSelected: (on) {
                      setState(() {
                        if (on) {
                          selected.add(o);
                        } else {
                          selected.remove(o);
                        }
                        widget.values[f.id] = selected;
                      });
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ),
        );

      default:
        return Text('Unsupported field type: ${f.type}');
    }
  }
}
