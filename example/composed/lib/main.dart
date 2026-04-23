// Smoke script — shows that fields composed via imports + spreads + a
// `Object.fromEntries(...)` call all land correctly in the generated Dart.
// Run after `dart run build_runner build`:
//   dart run lib/main.dart

import 'ts_schema.g.dart' as g;

void main() {
  print('userFields (${g.userFields.length}):');
  for (final f in g.userFields) {
    print('  - ${f.id} (${f.type.name})${f.required ? " *" : ""}');
  }
  print('');
  print('projectFields (${g.projectFields.length}):');
  for (final f in g.projectFields) {
    print('  - ${f.id} (${f.type.name})${f.required ? " *" : ""}');
  }
}
