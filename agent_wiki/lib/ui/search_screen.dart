import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/models.dart';
import 'page_screen.dart';
import 'state/app_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchHit> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    final app = context.read<AppState>();
    setState(() {
      _results = q.trim().isEmpty ? const [] : app.repo.search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Search the wiki…',
            border: InputBorder.none,
          ),
        ),
      ),
      // SafeArea: screen này là route full-screen (không có bottom nav bar) —
      // với edge-to-edge (targetSdk 36), nội dung đáy có thể chạy sau 3 nút
      // điều hướng Android nếu không pad theo system inset.
      body: SafeArea(
        child: _results.isEmpty
            ? Center(
                child: Text(
                  _controller.text.trim().isEmpty
                      ? 'Type to search pages & claims'
                      : 'No results for "${_controller.text.trim()}"',
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: theme.colorScheme.outline),
                ),
              )
            : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final hit = _results[i];
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => PageScreen(pageId: hit.pageId)),
                    ),
                    title: Text(
                      hit.title,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: hit.deprecated
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${hit.pageType.label}'
                      '${hit.snippet.isNotEmpty ? ' · ${_stripHtml(hit.snippet)}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');
}
