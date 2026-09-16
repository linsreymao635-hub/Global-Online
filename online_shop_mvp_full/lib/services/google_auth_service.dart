import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';
import 'app_settings.dart';

/// Wraps the platform Google Sign-In plugin so the app works with a real
/// Google account (name, email, photo, token) instead of a fake guest.
class GoogleAuthService {
  /// OAuth 2.0 client ID from https://console.cloud.google.com →
  /// APIs & Services → Credentials → Create Credentials → OAuth client ID →
  /// Web application. Paste the Client ID here (e.g. `xxx.apps.googleusercontent.com`).
  ///
  /// You can also enter it at runtime in Settings → Google Sign-In (no rebuild
  /// needed). A value from [AppSettings] takes priority over this constant.
  static const String serverClientId =
      '1021459048327-7odq6b4vl20b9d9lg1d3q2rkjnudo7q2.apps.googleusercontent.com';

  /// Optional standalone Android OAuth client ID (only needed if you are not
  /// using the Web client ID or a google-services.json file).
  /// The app's OAuth client ID on Android — create one in the Google Cloud
  /// Console as type "Android" using this app's package name and its keystore
  /// SHA-1 fingerprint. This authorises THIS app to request Google tokens, so
  /// that after you pick an account the sign-in actually completes.
  /// You can also enter it at runtime in Settings → Google Sign-In
  /// (a value from [AppSettings] takes priority).
  static const String androidClientId = '';

  static String get _serverClientId {
    final s = AppSettings.googleClientId;
    return s.isNotEmpty ? s : serverClientId;
  }

  static String get _clientId {
    final s = AppSettings.googleAndroidClientId;
    return s.isNotEmpty ? s : androidClientId;
  }

  static bool get isConfigured => _serverClientId.isNotEmpty || _clientId.isNotEmpty;

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (!isConfigured) {
      throw StateError(
          'Google Sign-In is not configured. Set the OAuth client ID in '
          'Settings → Google Sign-In, set GoogleAuthService.serverClientId, '
          'or add android/app/google-services.json.');
    }
    await GoogleSignIn.instance.initialize(
      clientId: _clientId.isEmpty ? null : _clientId,
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  /// Opens the Google account picker. Returns the signed-in [User], or
  /// `null` only when the user closed the picker without choosing anything.
  Future<User?> signIn() async {
    await _ensureInit();
    final GoogleSignInAccount acct;
    try {
      acct = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // Only a clean "nothing chosen" close is treated as a cancel.
      // Anything else (interrupted, uiUnavailable, invalid client…) is
      // rethrown so the caller can show the real Google error — otherwise the
      // user would silently stay on the sign-in page after picking an account.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
    final name = (acct.displayName ?? '').trim();
    final parts = name.isEmpty ? const <String>[] : name.split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return User(
      id: 0,
      firstName: first,
      lastName: last,
      username: acct.email.split('@').first,
      email: acct.email,
      image: acct.photoUrl,
      token: acct.authentication.idToken,
    );
  }

  Future<void> signOut() async {
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
  }
}