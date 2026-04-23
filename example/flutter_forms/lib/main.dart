import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'code_viewer.dart';
import 'field_definition.dart';
import 'form_renderer.dart';
import 'ts_schema.g.dart' as g;

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ts_schema_codegen — live demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      ),
      home: const DemoHomePage(),
    );
  }
}

class _CodeTab {
  const _CodeTab({
    required this.label,
    required this.title,
    required this.asset,
    required this.language,
    required this.badge,
  });

  final String label;
  final String title;
  final String asset;
  final String language;
  final String badge;
}

const _codeTabs = <_CodeTab>[
  _CodeTab(
    label: 'schema.ts',
    title: 'schema/index.ts',
    asset: 'assets/schema.ts',
    language: 'typescript',
    badge: 'source of truth',
  ),
  _CodeTab(
    label: 'ts_schema.g.dart',
    title: 'lib/ts_schema.g.dart',
    asset: 'assets/ts_schema.g.dart',
    language: 'dart',
    badge: 'generated',
  ),
  _CodeTab(
    label: 'form_renderer.dart',
    title: 'lib/form_renderer.dart',
    asset: 'assets/form_renderer.dart',
    language: 'dart',
    badge: 'how it\'s used',
  ),
];

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  String _fieldsetKey = 'account';
  final _formKey = GlobalKey<FormState>();
  final Map<String, Object?> _values = {};
  final Map<String, String> _sources = {};
  String? _submitted;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    for (final tab in _codeTabs) {
      final src = await rootBundle.loadString(tab.asset);
      if (!mounted) return;
      setState(() => _sources[tab.asset] = src);
    }
  }

  List<FieldDefinition> get _fields {
    final fs = g.kFieldSets[_fieldsetKey];
    return fs?.fields ?? const <FieldDefinition>[];
  }

  void _selectFieldset(String key) {
    setState(() {
      _fieldsetKey = key;
      _values.clear();
      _submitted = null;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final serialized = <String, Object?>{};
      for (final entry in _values.entries) {
        final v = entry.value;
        serialized[entry.key] = v is Set ? v.toList() : v;
      }
      setState(() {
        _submitted = serialized.entries
            .map((e) => '  ${e.key}: ${e.value}')
            .join('\n');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, c) {
            final narrow = c.maxWidth < 1100;
            return Column(
              children: [
                _Header(
                  selectedKey: _fieldsetKey,
                  onSelect: _selectFieldset,
                ),
                const Divider(height: 1),
                Expanded(
                  child: narrow ? _narrowBody() : _wideBody(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wideBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _codePane()),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: _livePane()),
        ],
      ),
    );
  }

  Widget _narrowBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 520, child: _codePane()),
          const SizedBox(height: 16),
          _livePane(),
        ],
      ),
    );
  }

  Widget _codePane() {
    return DefaultTabController(
      length: _codeTabs.length,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF282C34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: const Color(0xFF21252B),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFF818CF8),
                indicatorWeight: 2.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  for (final tab in _codeTabs)
                    Tab(
                      height: 42,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.language == 'typescript'
                                ? Icons.code
                                : Icons.auto_awesome,
                            size: 13,
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(tab.label),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final tab in _codeTabs)
                    _sources[tab.asset] == null
                        ? const _Loading()
                        : CodeViewer(
                            title: tab.title,
                            source: _sources[tab.asset]!,
                            language: tab.language,
                            trailing: _Badge(text: tab.badge),
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _livePane() {
    final fs = g.kFieldSets[_fieldsetKey];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.dynamic_form,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  fs?.label ?? _fieldsetKey,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'live',
                    style: TextStyle(
                      color: Color(0xFF4338CA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_fields.length} fields rendered from the generated constants.',
              style: const TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            FormRenderer(
              key: ValueKey(_fieldsetKey),
              fields: _fields,
              formKey: _formKey,
              values: _values,
              onChanged: () => setState(() => _submitted = null),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit'),
              ),
            ),
            if (_submitted != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text(
                          'Valid — payload:',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _submitted!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.selectedKey, required this.onSelect});

  final String selectedKey;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = g.kFieldSets.entries.where((e) => e.key != 'common');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Row(
        children: [
          const Icon(Icons.hub, color: Color(0xFF6366F1)),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ts_schema_codegen',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'TypeScript schema → generated Dart → live Flutter form',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: [
              for (final e in entries)
                ChoiceChip(
                  label: Text(e.value.label),
                  selected: e.key == selectedKey,
                  onSelected: (_) => onSelect(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
