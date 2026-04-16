import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalysisScreen extends StatefulWidget {
  final ApiService api;
  final String sessionId;
  final String topic;

  const AnalysisScreen({
    super.key,
    required this.api,
    required this.sessionId,
    required this.topic,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Map<String, dynamic>? _analysis;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    try {
      final data = await widget.api.getAnalysis(widget.sessionId);
      if (!mounted) return;
      setState(() => _analysis = data);
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
        title: const Text('Your analysis'),
        automaticallyImplyLeading: false,
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _analysis == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analysing your arguments...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topic
                      Text(
                        widget.topic,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),

                      // Score
                      _ScoreCard(
                        score: _analysis!['persuasiveness_score'] as int,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),

                      // Verdict
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _analysis!['verdict'] as String,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Strong points
                      _PointsList(
                        title: 'Strong points',
                        points: List<String>.from(
                            _analysis!['strong_points'] as List),
                        isStrong: true,
                        colors: colors,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),

                      // Weak points
                      _PointsList(
                        title: 'Weak points',
                        points: List<String>.from(
                            _analysis!['weak_points'] as List),
                        isStrong: false,
                        colors: colors,
                        theme: theme,
                      ),
                      const SizedBox(height: 24),

                      // Suggested reading
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 18, color: colors.outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _analysis!['suggested_reading'] as String,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // Back button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context)
                              .popUntil((r) => r.isFirst),
                          child: const Text('New debate'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  final ColorScheme colors;

  const _ScoreCard({required this.score, required this.colors});

  Color get _scoreColor {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: _scoreColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _scoreColor,
            ),
          ),
          Text(
            '/10',
            style: TextStyle(
              fontSize: 24,
              color: colors.outline,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Persuasiveness score',
              style: TextStyle(color: colors.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsList extends StatelessWidget {
  final String title;
  final List<String> points;
  final bool isStrong;
  final ColorScheme colors;
  final ThemeData theme;

  const _PointsList({
    required this.title,
    required this.points,
    required this.isStrong,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...points.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isStrong ? Icons.check_circle_outline : Icons.cancel_outlined,
                    size: 18,
                    color: isStrong ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
