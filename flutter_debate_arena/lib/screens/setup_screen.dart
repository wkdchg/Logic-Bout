import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'authentication_screen.dart';
import 'debate_screen.dart';
import 'history_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _api = ApiService();
  final _topicController = TextEditingController();
  final _positionController = TextEditingController();

  List<String> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    try {
      final topics = await _api.getTopicSuggestions();
      if (!mounted) return;
      setState(() => _suggestions = topics);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot load suggestions: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot load suggestions right now')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
  }

  Future<void> _start() async {
    final topic = _topicController.text.trim();
    final position = _positionController.text.trim();
    if (topic.isEmpty || position.isEmpty) return;

    setState(() => _starting = true);
    try {
      final session = await _api.startDebate(
        topic: topic,
        userPosition: position,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DebateScreen(session: session),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthenticationScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logic Bout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past bouts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(api: _api),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Обліковий запис',
            onSelected: (value) {
              if (value == 'logout') _signOut();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Вийти'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a topic', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                hintText: 'e.g. Remote work is better than office',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            // AI suggestions
            const SizedBox(height: 12),
            if (_loadingSuggestions)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((t) {
                  return ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _topicController.text = t,
                  );
                }).toList(),
              ),

            const SizedBox(height: 28),
            Text('Your position', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _positionController,
              decoration: const InputDecoration(
                hintText: 'e.g. I strongly support remote work',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),

            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _starting ? null : _start,
                child: _starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start bout', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    _positionController.dispose();
    super.dispose();
  }
}
