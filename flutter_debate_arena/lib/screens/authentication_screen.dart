import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'setup_screen.dart';

/// Перший екран: вхід через Google або інші мережі (інші — після налаштування OAuth).
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  bool _busyGoogle = false;

  Future<void> _afterSignedIn() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SetupScreen()),
    );
  }

  Future<void> _onGoogle() async {
    setState(() => _busyGoogle = true);
    try {
      await AuthService.instance.signInWithGoogle();
      await _afterSignedIn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyGoogle = false);
    }
  }

  String _messageForError(Object e) {
    if (e is UnsupportedError) return e.message ?? e.toString();
    if (e is StateError) return e.message;
    return 'Не вдалося увійти: $e';
  }

  void _soon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name: додайте OAuth у консолі розробника та підключіть пакет '
          '(наприклад sign_in_with_apple / flutter_facebook_auth).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Icon(Icons.forum_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Logic Bout',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to save your debate history and sync your profile.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              _SocialButton(
                label: 'Google',
                icon: _GoogleMark(color: scheme.onSurface),
                onPressed: (kIsWeb || _busyGoogle) ? null : _onGoogle,
                busy: _busyGoogle,
                filled: true,
              ),
              const SizedBox(height: 12),
              Text(
                'Another',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _SocialButton(
                label: 'Apple',
                icon: Icon(Icons.apple, size: 22, color: scheme.onSurface),
                onPressed: () => _soon('Apple'),
              ),
              const SizedBox(height: 8),
              _SocialButton(
                label: 'Facebook',
                icon: Icon(Icons.facebook, size: 22, color: scheme.primary),
                onPressed: () => _soon('Facebook'),
              ),
              const SizedBox(height: 8),
              _SocialButton(
                label: 'Microsoft',
                icon: Icon(Icons.window, size: 20, color: scheme.onSurface),
                onPressed: () => _soon('Microsoft'),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 12),
                Text(
                  'На web спершу налаштуйте Google OAuth client для вашого хоста.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.filled = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 28, child: Center(child: icon)),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 16)),
            ],
          );

    if (filled) {
      return SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleMarkPainter(color),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  _GoogleMarkPainter(this.fallback);

  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    final bg = Paint()..color = Colors.white;
    canvas.drawRRect(r, bg);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = fallback.withValues(alpha: 0.2);
    canvas.drawRRect(r, border);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = Paint()..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    p.color = const Color(0xFF4285F4);
    canvas.drawLine(Offset(cx, cy), Offset(cx + 5, cy - 3), p);
    p.color = const Color(0xFFEA4335);
    canvas.drawLine(Offset(cx - 1, cy + 4), Offset(cx + 4, cy + 1), p);
    p.color = const Color(0xFFFBBC05);
    canvas.drawLine(Offset(cx - 5, cy - 1), Offset(cx - 1, cy + 4), p);
    p.color = const Color(0xFF34A853);
    canvas.drawLine(Offset(cx - 5, cy - 1), Offset(cx, cy - 4), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
