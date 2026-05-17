import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKeyUser = 'auth_user_json';

/// Signed-in user snapshot (enough for UI; extend when backend auth exists).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.providerId,
  });

  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String providerId;

}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email', 'profile'],
  );

  Future<AuthUser?> loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split('|');
      if (parts.length < 5) return null;
      return AuthUser(
        id: parts[0],
        displayName: parts[1],
        email: parts[2],
        photoUrl: parts[3].isEmpty ? null : parts[3],
        providerId: parts[4],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistUser(AuthUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_prefsKeyUser);
      return;
    }
    final encoded = [
      user.id,
      user.displayName,
      user.email,
      user.photoUrl ?? '',
      user.providerId,
    ].join('|');
    await prefs.setString(_prefsKeyUser, encoded);
  }

  Future<AuthUser> signInWithGoogle() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Google вхід на web потребує додаткового налаштування OAuth client.',
      );
    }
    final account = await _google.signIn();
    if (account == null) {
      throw StateError('Вхід скасовано');
    }
    final email = account.email;
    final user = AuthUser(
      id: account.id,
      displayName: account.displayName ?? email,
      email: email,
      photoUrl: account.photoUrl,
      providerId: 'google.com',
    );
    await _persistUser(user);
    return user;
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _persistUser(null);
  }
}
