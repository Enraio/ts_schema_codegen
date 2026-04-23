// A generic application config with feature flags. The `map` template
// emits this as a nested `const Object? schema` — nothing typed, just data.

export const CONFIG = {
  version: '2.3.1',
  api: {
    baseUrl: 'https://api.example.com',
    timeoutMs: 30000,
    retry: { attempts: 3, backoffMs: 500 },
  },
  features: {
    dark_mode: { enabled: true, rollout: 1.0 },
    new_dashboard: { enabled: false, rollout: 0.1 },
    experimental_search: { enabled: true, rollout: 0.5, cohort: 'beta' },
  },
  supportedLocales: ['en', 'es', 'fr', 'de', 'ja'],
};
