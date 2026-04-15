import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/chat_bubble.dart';
import 'analysis_screen.dart';

class _ChatEntry {
  final String text;
  final bool isUser;
  bool isStreaming;

  _ChatEntry({required this.text, required this.isUser, this.isStreaming = false});
}

class DebateScreen extends StatefulWidget {
  final DebateSession session;
  const DebateScreen({super.key, required this.session});

  @override
  State<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends State<DebateScreen> {
  late final WebSocketService _ws;
  StreamSubscription<DebateMessage>? _messagesSub;
  final _api = ApiService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_ChatEntry> _entries = [];
  int _currentRound = 1;
  bool _aiThinking = false;
  bool _inputEnabled = true;

  @override
  void initState() {
    super.initState();
    _ws = WebSocketService();
    _ws.connect(widget.session.sessionId);
    _messagesSub = _ws.messages.listen(_handleMessage);
  }

  void _handleMessage(DebateMessage msg) {
    switch (msg.type) {
      case DebateMessageType.turnStart:
        setState(() {
          _aiThinking = true;
          final hasStreamingAiBubble = _entries.isNotEmpty &&
              !_entries.last.isUser &&
              _entries.last.isStreaming;
          if (!hasStreamingAiBubble) {
            _entries.add(_ChatEntry(text: '', isUser: false, isStreaming: true));
          }
        });
        _scrollToBottom();
        break;

      case DebateMessageType.token:
        setState(() {
          final token = msg.text ?? '';
          if (_entries.isEmpty || _entries.last.isUser || !_entries.last.isStreaming) {
            _entries.add(_ChatEntry(text: token, isUser: false, isStreaming: true));
          } else {
            final last = _entries.last;
            _entries[_entries.length - 1] = _ChatEntry(
              text: last.text + token,
              isUser: false,
              isStreaming: true,
            );
          }
        });
        _scrollToBottom();
        break;

      case DebateMessageType.turnEnd:
        setState(() {
          if (_entries.isNotEmpty && !_entries.last.isUser && _entries.last.isStreaming) {
            _entries[_entries.length - 1].isStreaming = false;
          }
          _currentRound = (msg.round ?? _currentRound) + 1;
          _aiThinking = false;
          _inputEnabled = !(msg.isFinished ?? false);
        });
        if (msg.isFinished ?? false) _onDebateFinished();
        break;

      case DebateMessageType.error:
        final debateFinished = _currentRound > widget.session.totalRounds;
        setState(() {
          _aiThinking = false;
          _inputEnabled = !debateFinished;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg.errorMessage ?? 'Unknown error')),
          );
        }
        break;
    }
  }

  void _sendArgument() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _aiThinking || !_inputEnabled) return;

    setState(() {
      _entries.add(_ChatEntry(text: text, isUser: true));
      _aiThinking = true;
      _inputEnabled = false;
    });
    _inputCtrl.clear();
    _ws.sendArgument(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onDebateFinished() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            api: _api,
            sessionId: widget.session.sessionId,
            topic: widget.session.topic,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalRounds = widget.session.totalRounds;
    final progress = (_currentRound - 1) / totalRounds;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session.topic,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
          ),
        ),
      ),
      body: Column(
        children: [
          // Round indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _inputEnabled
                  ? 'Round $_currentRound of $totalRounds'
                  : 'Debate complete',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),

          // Chat list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return ChatBubble(
                  text: e.text,
                  isUser: e.isUser,
                  isStreaming: e.isStreaming,
                );
              },
            ),
          ),

          // Input bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      enabled: _inputEnabled && !_aiThinking,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _inputEnabled
                            ? 'Make your argument...'
                            : 'Debate finished',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendArgument(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: (_inputEnabled && !_aiThinking) ? _sendArgument : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _ws.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
