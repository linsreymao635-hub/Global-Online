import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';
import 'app_settings.dart';

/// A sign-in failure the user can act on: the message names the exact fix
/// (e.g. which URL to register in the Google Cloud Console). [isSetupError]
/// marks it as a developer configuration problem, so the UI shows it in full
/// instead of the generic "try again" text.
class GoogleSignInSetupException implements Exception {
  final String message;
  final bool isSetupError;
  GoogleSignInSetupException(this.message, {this.isSetupError = true});
  @override
  String toString() => message;
}

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
      '1021459048327-llu2ffticc2fed6da8dqt3ur2undrapm.apps.googleusercontent.com';

  /// The app's Android OAuth client ID — created in the Google Cloud Console
  /// as type "Android" with package name `com.example.online_shop_mvp_full`
  /// and SHA-1 `4E:5C:2B:40:E8:FD:72:97:C6:DE:01:3E:37:07:00:1B:B4:CB:04:B2`.
  /// This authorises THIS app to request Google tokens, so that after you pick
  /// an account the sign-in actually completes.
  /// You can also enter it at runtime in Settings → Google Sign-In
  /// (a value from [AppSettings] takes priority).
  static const String androidClientId =
      '1021459048327-llu2ffticc2fed6da8dqt3ur2undrapm.apps.googleusercontent.com';

  static const _fingerprintChannel =
      'com.example.online_shop_mvp_full/fingerprint';

  /// SHA-1 certificate fingerprints of the signing certificates that
  /// actually signed THIS installed build on Android. This is the value
  /// Google Cloud checks (package name + SHA-1) when it decides whether to
  /// grant a token — telling the user this number instead of a hard-coded
  /// one removes all guesswork. Returns empty on non-Android / web.
  static Future<List<String>> installedSigningSha1Fingerprints() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    try {
      const ch = MethodChannel(_fingerprintChannel);
      final res = await ch.invokeMethod<List<dynamic>>('signing_sha1');
      return (res ?? const []).cast<String>();
    } catch (_) {
      return const [];
    }
  }

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

  /// Turns a plugin exception into an actionable [GoogleSignInSetupException]
  /// when it is caused by the OAuth client configuration, e.g.:
  ///  - the current web origin is not an "Authorized JavaScript origin" of
  ///    the client (running via `flutter run -d chrome` on a random port, or
  ///    serving from an IP/hostname other than what the console allows),
  ///  - the client ID is wrong/deleted, or the consent screen is not set up.
  /// Always throws: either the setup exception, or the original error `e`.
  static Never _mapConfigError(Object e, String serverClientId) {
    final s = e.toString();
    final low = s.toLowerCase();

    // Client ID rejected outright (deleted client, wrong project, no consent
    // screen) — the browser popup shows Google's own "origin not allowed" or
    // "invalid client" page and the plugin surfaces it as an error.
    final bool clientRejected = low.contains('invalid_client') ||
        low.contains('origin') ||
        low.contains('redirect_uri') ||
        low.contains('idpiframe') ||
        (low.contains('client') &&
            (low.contains('not') || low.contains('unavail'))) ||
        (low.contains('popup') && low.contains('failed'));

    if (clientRejected && kIsWeb) {
      debugPrint('Google Sign-In configuration error: $s');
      debugPrint('OAuth client in use: $serverClientId');
      // NOTE: no interpolation here — the exact string is the l10n key.
      throw GoogleSignInSetupException(
        'Google Sign-In needs one more setup step: open '
        'https://console.cloud.google.com/apis/credentials, select your OAuth '
        '2.0 Client ID, and under "Authorized JavaScript origins" add the '
        'exact address shown in this browser\'s address bar (including the '
        'port). Then reload this page and try again.',
      );
    }
    throw e; // not a configuration problem — pass the original through
  }

  /// Opens the Google account picker. Returns the signed-in [User], or
  /// `null` only when the user closed the picker without choosing anything.
  Future<User?> signIn() async {
    await _ensureInit();
    debugPrint('GSIGN: authenticate() starting, serverClientId=$_serverClientId');
    final GoogleSignInAccount acct;
    try {
      acct = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint('GSIGN: GoogleSignInException code=${e.code} desc=${e.description}');      // Only a clean "nothing chosen" close is treated as a cancel.
      // Anything else (interrupted, uiUnavailable, invalid client…) is
      // mapped below so the user gets the real, actionable cause — otherwise
      // the user would silently stay on the sign-in page after picking an
      // account.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      // DEVELOPER_ERROR surfaces as "[28444] Developer console is not set up
      // correctly" — the running app (package name + keystore SHA-1) is not
      // recognized in the Google Cloud project that owns the Web client used
      // as the ID-token audience. This is the "picker opens, then fails after
      // choosing an account" failure on Android. Explain the exact fix in the
      // UI (GoogleSignInSetupException is shown verbatim), details in console.
      final desc = (e.description ?? '').toLowerCase();
      final isDeveloperError = desc.contains('28444') ||
          desc.contains('developer console') ||
          desc.contains('developer_error');
      if (isDeveloperError) {
        debugPrint('Google Sign-In DEVELOPER_ERROR: $e');
        debugPrint('Web client (serverClientId) in use: $_serverClientId');
        // Google rejects the running app based on the package name AND the
        // SHA-1 of the certificate that actually signed THIS installed APK.
        // Reading it on device (instead of printing a hard-coded value) gives
        // the user the exact number to register in the Google Cloud Console,
        // no matter which computer signed the build.
        final fingerprints =
            await installedSigningSha1Fingerprints();
        final sha1 = fingerprints.isEmpty
            ? '4E:5C:2B:40:E8:FD:72:97:C6:DE:01:3E:37:07:00:1B:B4:CB:04:B2'
            : fingerprints.first;
        debugPrint('Installed APK signing SHA-1: $sha1');
        // NOTE: message constructed dynamically — shown verbatim in the UI.
        throw GoogleSignInSetupException(
          'Google Sign-In setup incomplete: this app is not registered '
          'with Google. In console.cloud.google.com → APIs & Services → '
          'Credentials, create an OAuth client ID of type "Android" with '
          'package name com.example.online_shop_mvp_full and SHA-1 '
          '$sha1 (the fingerprint of THIS installed build), in the SAME '
          'project as your Web client. Save, wait a few minutes, then '
          'reinstall this build and try again.',
        );
      }
      _mapConfigError(e, _serverClientId); // throws setup error or rethrows
    } catch (e) {
      debugPrint('GSIGN: non-plugin exception: $e');
      // Web can also surface configuration problems as non-plugin exceptions
      // (e.g. PlatformException). Only clear config errors are remapped here;
      // everything else passes through to the caller's generic handler.
      _mapConfigError(e, _serverClientId);
    }
    debugPrint('GSIGN: authenticate() SUCCEEDED for ${acct.email}');
    final email = acct.email.trim().toLowerCase();
    final localPart = email.isEmpty ? '' : email.split('@').first;
    final name = (acct.displayName ?? '').trim();
    // Display name can be empty on some accounts. Fall back to the email
    // local-part so the profile always shows the same identity the account
    // picker presented, instead of a blank/unknown name.
    final parts = name.isEmpty
        ? (localPart.isEmpty
            ? const <String>[]
            : localPart.split(RegExp(r'[._\-]+')))
        : name.split(RegExp(r'\s+'));
    final first = parts.isEmpty ? localPart : parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return User(
      id: 0,
      firstName: first,
      lastName: last,
      username: localPart,
      email: email,
      image: acct.photoUrl,
      token: acct.authentication.idToken,
    );
  }

  Future<void> signOut() async {
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
  }
}