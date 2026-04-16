import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TranscriptScreen extends StatefulWidget {
  final ApiService api;
  final String sessionId;
  final String topic;
  final int? score;
  final String? verdict;

  const TranscriptScreen({
    super.key,
    required this.api,
    required this.sessionId,
    required this.topic,
    this.score,
    this.verdict,
  });

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  String? _transcript;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await widget.api.getTranscript(widget.sessionId);
      if (!mounted) return;
      setState(() => _transcript = t);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Color get _scoreColor {
    final s = widget.score;
    if (s == null) return Colors.grey;
    if (s >= 8) return Colors.green;
    if (s >= 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transcript')),
      body: switch ((_transcript, _error)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (_, String e) => Center(child: Text('Error: $e')),
        (String transcript, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(widget.topic, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),

                if (widget.score != null) ...[
                  Row(
                    children: [
                      Text(
                        '${widget.score}/10',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.verdict != null)
                        Expanded(
                          child: Text(
                            widget.verdict!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 16),
                ],

                // Transcript blocks
                ..._parseTranscript(transcript).map(
                  (block) => _TranscriptBlock(block: block, theme: theme, colors: colors),
                ),
              ],
            ),
          ),
      },
    );
  }

  /// Parses the plain-text transcript into alternating user/ai blocks.
  List<({String speaker, String text})> _parseTranscript(String raw) {
    final blocks = <({String speaker, String text})>[];
    final lines = raw.split('\n');
    String currentSpeaker = '';
    final buffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('User: ')) {
        if (buffer.isNotEmpty) {
          blocks.add((speaker: currentSpeaker, text: buffer.toString().trim()));
          buffer.clear();
        }
        currentSpeaker = 'You';
        buffer.write(line.substring(6));
      } else if (line.startsWith('AI opponent: ')) {
        if (buffer.isNotEmpty) {
          blocks.add((speaker: currentSpeaker, text: buffer.toString().trim()));
          buffer.clear();
        }
        currentSpeaker = 'AI opponent';
        buffer.write(line.substring(13));
      } else if (line.startsWith('[Round') || line.startsWith('Topic:') || line.startsWith("User's position:")) {
        // skip metadata lines
      } else if (buffer.isNotEmpty && line.isNotEmpty) {
        buffer.write(' $line');
      }
    }
    if (buffer.isNotEmpty && currentSpeaker.isNotEmpty) {
      blocks.add((speaker: currentSpeaker, text: buffer.toString().trim()));
    }
    return blocks;
  }
}

class _TranscriptBlock extends StatelessWidget {
  final ({String speaker, String text}) block;
  final ThemeData theme;
  final ColorScheme colors;

  const _TranscriptBlock({
    required this.block,
    required this.theme,
    required this.colors,
  });

  bool get _isUser => block.speaker == 'You';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              block.speaker,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: _isUser
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_isUser ? 16 : 4),
                bottomRight: Radius.circular(_isUser ? 4 : 16),
              ),
            ),
            child: Text(
              block.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _isUser ? colors.onPrimaryContainer : colors.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
