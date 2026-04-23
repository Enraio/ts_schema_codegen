// Smoke script — reads the generated config and prints feature-flag state.
// Run after `dart run build_runner build`:
//   dart run lib/main.dart

import 'ts_schema.g.dart';

void main() {
  // The `map` template emits `const Object schema` (or `Object?` if the
  // TS export is literally null). Cast once at the
  // boundary; in a real app you'd wrap this in a typed config class.
  final cfg = schema as Map<String, Object?>;

  print('Config v${cfg['version']}');
  print('API: ${(cfg['api'] as Map)['baseUrl']}');
  print('');
  print('Feature flags:');
  final features = cfg['features'] as Map<String, Object?>;
  features.forEach((name, raw) {
    final f = raw as Map<String, Object?>;
    final state = (f['enabled'] as bool) ? 'on' : 'off';
    final rollout = ((f['rollout'] as num) * 100).toStringAsFixed(0);
    print('  $name: $state (rollout: $rollout%)');
  });
}
