// Smoke script. Run after `dart run build_runner build`:
//   dart run lib/main.dart

import 'field_definition.dart';
import 'ts_schema.g.dart' as g;

void main() {
  _printForm('signup', null);
  _printForm('feedback', null);
  // Subcategory 'bug' routes to the feedback fieldset even though the
  // category is 'feedback' either way — here we show the mechanism works.
  _printForm('other', 'bug');
}

void _printForm(String category, String? subcategory) {
  final fields = g.getFieldsForCategoryGenerated(
    category,
    subcategory: subcategory,
  );
  final sub = subcategory == null ? '' : ' / $subcategory';
  print('── form($category$sub) ────────────────────────');
  for (final f in fields) {
    final opts = f.options == null ? '' : '  [${f.options!.join(" | ")}]';
    final req = f.required ? ' *' : '';
    print('  ${f.label}$req  (${f.type.name})$opts');
  }
  print('');
}
