import 'package:flutter/material.dart';
import 'screens/authentication_screen.dart';
import 'screens/setup_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LogicBoutApp());
}

class LogicBoutApp extends StatelessWidget {
  const LogicBoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logic Bout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<AuthUser?> _session;

  @override
  void initState() {
    super.initState();
    _session = AuthService.instance.loadSavedUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _session,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData && snap.data != null) {
          return const SetupScreen();
        }
        return const AuthenticationScreen();
      },
    );
  }
}
