// Reads both generated files — the typed forms (field_definitions) and
// the raw config (map) — from a single build_runner invocation.
// Run after `dart run build_runner build`:
//   dart run lib/main.dart

import 'config.g.dart' as cfg;
import 'field_definition.dart';
import 'forms.g.dart' as forms;

void main() {
  print('Forms: ${forms.kFieldSets.keys.join(", ")}');
  for (final f in forms.signupFields) {
    print('  - ${f.id} (${f.type.name})${f.required ? " *" : ""}');
  }
  print('');

  final c = cfg.schema as Map<String, Object?>;
  print('Config v${c['version']}');
  print('API: ${(c['api'] as Map)['baseUrl']}');
  final flags = c['flags'] as Map<String, Object?>;
  flags.forEach((name, enabled) {
    print('  $name: ${enabled == true ? "on" : "off"}');
  });
}
