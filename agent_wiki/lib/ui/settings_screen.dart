import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/openrouter_provider.dart';
import 'state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  String? _primaryModel;
  String? _corroborationModel;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final key = await app.apiKey();
    if (!mounted) return;
    _keyController.text = key ?? '';
    _primaryModel = await app.settings.primaryModel();
    _corroborationModel = await app.settings.corroborationModel();
    setState(() {});
  }

  Future<void> _saveKey() async {
    final app = context.read<AppState>();
    await app.settings.setApiKey(
        _keyController.text.trim().isEmpty ? null : _keyController.text.trim());
    await app.reloadServices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('API key saved. Provider reloaded.')));
  }

  Future<void> _export() async {
    final app = context.read<AppState>();
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !mounted) return;
    app.repo.exportTo(dir);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wiki exported to $dir')));
  }

  Future<void> _rebuild() async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rebuild index?'),
        content: const Text(
            'Drops and rebuilds the search index from canonical files. '
            'No data is lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rebuild')),
        ],
      ),
    );
    if (ok == true) {
      app.repo.rebuild();
      app.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Index rebuilt from canonical files.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('AI (BYOK via OpenRouter)',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _keyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'OpenRouter API key',
                        hintText: 'sk-or-…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveKey,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save key'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _primaryModel,
                      decoration: const InputDecoration(
                          labelText: 'Primary model',
                          border: OutlineInputBorder()),
                      items: [
                        for (final m in OpenRouterProvider.modelPresets)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: _primaryModel == null
                          ? null
                          : (v) async {
                              if (v == null) return;
                              await app.settings.setPrimaryModel(v);
                              setState(() => _primaryModel = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _corroborationModel,
                      decoration: const InputDecoration(
                          labelText: 'Corroboration model (Flow B only)',
                          border: OutlineInputBorder()),
                      items: [
                        for (final m in OpenRouterProvider.modelPresets)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: _corroborationModel == null
                          ? null
                          : (v) async {
                              if (v == null) return;
                              await app.settings.setCorroborationModel(v);
                              setState(() => _corroborationModel = v);
                            },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cross-model corroboration runs only when promoting '
                      'drafts (never during Ask).',
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Wiki',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Location'),
                      subtitle: Text(app.wikiRoot,
                          style: theme.textTheme.bodySmall),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${app.pageCount} pages · '
                          '${app.claimCount} claims · ${app.sourceCount} '
                          'sources · ${app.revisionCount} revisions'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _export,
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: const Text('Export wiki'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _rebuild,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Rebuild index'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AgentWiki',
                        style: theme.textTheme.titleSmall!
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'A hosted LLM wiki where agents iterate on the same '
                      'files and reuse past results.\n\n'
                      'Canonical Markdown + JSON · derived SQLite/FTS5 index · '
                      'patch-based writes · evidence-backed claims.',
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
