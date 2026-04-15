import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'transcript_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ApiService api;
  const HistoryScreen({super.key, required this.api});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>>? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getHistory();
      if (!mounted) return;
      setState(() => _history = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past debates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _history = null);
              _load();
            },
          ),
        ],
      ),
      body: switch ((_history, _error)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (_, String e) => Center(child: Text('Error: $e')),
        (List<Map<String, dynamic>> items, _) when items.isEmpty =>
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Text('No debates yet', style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        (List<Map<String, dynamic>> items, _) =>
          RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) => _DebateListTile(
                item: items[i],
                api: widget.api,
              ),
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _DebateListTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final ApiService api;

  const _DebateListTile({required this.item, required this.api});

  Color _scoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final score = item['score'] as int?;
    final completed = item['completed_rounds'] as int;
    final total = item['total_rounds'] as int;
    final isFinished = completed >= total && score != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        item['topic'] as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              _formatDate(item['created_at'] as String),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
            const SizedBox(width: 8),
            Text(
              isFinished ? 'Finished' : '$completed/$total rounds',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
          ],
        ),
      ),
      trailing: isFinished
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: _scoreColor(score).withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                '$score',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _scoreColor(score),
                ),
              ),
            )
          : Icon(Icons.hourglass_empty, color: colors.outlineVariant),
      onTap: isFinished
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TranscriptScreen(
                    api: api,
                    sessionId: item['session_id'] as String,
                    topic: item['topic'] as String,
                    score: score,
                    verdict: item['verdict'] as String?,
                  ),
                ),
              )
          : null,
    );
  }
}
