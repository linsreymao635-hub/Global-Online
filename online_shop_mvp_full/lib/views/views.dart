import 'dart:async';
import 'dart:convert';
import 'dart:math';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import 'chat_support_page.dart';
import 'info_pages.dart';
import 'admin_panel.dart';
import '../presenters/presenters.dart';
import '../repositories/repositories.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/google_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/telegram_auth_service.dart';

/// A lightweight local account so the user can browse and order products
/// without an internet login.
User guestUser() => User(
    id: 0,
    firstName: 'Guest',
    lastName: '',
    username: 'guest',
    email: '',
    image: null,
    token: null);

ImageProvider? userImage(String? s) {
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('b64:')) return MemoryImage(base64Decode(s.substring(4)));
  return NetworkImage(s);
}

/// Full-screen explanation of how to make "Continue with Telegram" work:
/// create a bot with @BotFather, register the login-page origin as the bot's
/// Allowed URL, and store both in the app. Shown when Telegram sign-in is
/// tapped without setup, and from Settings → Telegram Sign-In.
Future<void> _showTelegramSetup(BuildContext c) async {
  final l = AppLocalizations.of(c).t;
  final botCtl = TextEditingController(text: TelegramAuthService.botUsername);
  final originCtl = TextEditingController(text: TelegramAuthService.allowedOrigin);
  final origin = TelegramAuthService.allowedOrigin;
  final saved = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(l('Telegram Sign-In')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l('One-time setup — then every user can log in with their own Telegram account:'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(l('1. In Telegram, open @BotFather → /newbot → create a bot '
                '(its username must end with "bot").')),
            Text(l('2. Still in @BotFather, open your bot → Login Widget → add '
                'this exact Allowed URL:')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Theme.of(dc).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      origin.isEmpty
                          ? l('Add a short link to your shop first (step 3) and paste it here')
                          : origin,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l('Copy'),
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: origin.isEmpty
                      ? null
                      : () => Clipboard.setData(ClipboardData(text: origin)),
                ),
              ]),
            ),
            Text(l('3. Create a free short link for your shop (for example on '
                'tinyurl.com) that opens this app, and paste it below:')),
            const SizedBox(height: 10),
            TextField(
              controller: botCtl,
              decoration: InputDecoration(
                labelText: l('Telegram bot username'),
                hintText: 'MyShopBot',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: originCtl,
              decoration: InputDecoration(
                labelText: l('Allowed URL (link that opens this app)'),
                hintText: 'https://myshop.tinyurl.com',
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://t.me/BotFather'),
                  mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.open_in_new, size: 16),
                  const SizedBox(width: 6),
                  Text(l('Open @BotFather'),
                      style: const TextStyle(
                          color: Color(0xFF2AABEE),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: Text(l('Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(dc, true),
            child: Text(l('Save'))),
      ],
    ),
  );
  if (saved == true) {
    await AppSettings.saveTelegramBotUsername(botCtl.text);
    await AppSettings.saveTelegramAllowedOrigin(originCtl.text);
    if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(
          content: Text(TelegramAuthService.isConfigured
              ? l('Telegram bot username saved')
              : l('Telegram sign-in is not configured yet'))));
    }
  }
  botCtl.dispose();
  originCtl.dispose();
}

/// Explains the exact Google Cloud Console fix for the current platform.
/// [message] is the actionable text produced by [GoogleAuthService].
Future<void> _showGoogleSetup(BuildContext c, String message) async {
  final l = AppLocalizations.of(c).t;
  await showDialog<void>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(l('Google Sign-In setup')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(
                  Uri.parse('https://console.cloud.google.com/apis/credentials'),
                  mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.open_in_new, size: 16),
                  const SizedBox(width: 6),
                  Text(l('Open Google Cloud Console'),
                      style: TextStyle(
                          color: Theme.of(dc).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(dc), child: Text(l('OK'))),
      ],
    ),
  );
}

class SocialButtons extends StatefulWidget {
  final void Function(User) onLogin;
  final Future<User?> Function() googleLogin;
  final Future<User?> Function(User) telegramLogin;
  const SocialButtons(
      {super.key,
      required this.onLogin,
      required this.googleLogin,
      required this.telegramLogin});
  @override
  State<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<SocialButtons> {
  bool _busyGoogle = false;
  bool _busyTelegram = false;

  bool get _busy => _busyGoogle || _busyTelegram;

  /// Map ANY sign-in failure to one short, human message. Technical details
  /// (exception classes, error codes, client configuration problems) are
  /// never shown to the user — they stay in the debug console.
  /// The one exception: [GoogleSignInSetupException] already carries a
  /// user-actionable fix (which URL to register where) — show it verbatim.
  String _friendlyError(Object e) {
    if (e is GoogleSignInSetupException) return e.message;
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('http') ||
        s.contains('connection') ||
        s.contains('timeout')) {
      return AppLocalizations.of(context).t(
          'Unable to connect to the server. Please check your internet connection and try again.');
    }
    // Android DEVELOPER_ERROR can surface as a raw PlatformException code
    // (not only through the plugin's description mapping) — always show the
    // actionable console fix instead of a generic "try again".
    if (s.contains('developer_error') ||
        s.contains('developer console') ||
        s.contains('10:') ||
        s.contains('12500')) {
      return AppLocalizations.of(context).t(
          'Google Sign-In setup incomplete: this app is not registered with '
          'Google. In console.cloud.google.com → APIs & Services → '
          'Credentials, create an OAuth client ID of type "Android" with '
          'package name com.example.online_shop_mvp_full and this computer\'s '
          'debug SHA-1, in the SAME project as your Web client. Save, wait a '
          'few minutes, then rebuild and run the app again.');
    }
    return AppLocalizations.of(context)
        .t('Google Sign-In is currently unavailable. Please try again.');
  }

  void _showError(String message, {bool long = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        width: 420,
        duration: Duration(seconds: long ? 8 : 3),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _google() async {
    if (_busy) return; // one flow at a time — no duplicate requests
    setState(() => _busyGoogle = true);
    try {
      final u = await widget.googleLogin();
      if (!mounted) return;
      // null = the user closed the picker without choosing.
      if (u == null) return;
      // The authenticated Google account IS the logged-in user — its name,
      // email and photo must be exactly what the Profile shows. Never swap it
      // for a fabricated/default user when something fails after this point.
      widget.onLogin(u);
    } catch (e) {
      if (!mounted) return;
      // A failed Google sign-in must NOT log the user in as a different
      // (guest) account, otherwise Login info and Profile info diverge.
      debugPrint('Google sign-in failed: $e');
      if (e is GoogleSignInSetupException) {
        // Setup problems need the full fix — show a dialog with the exact
        // steps, the SHA-1 and a direct link to the Google Cloud Console
        // instead of a snackbar that cuts the message off.
        await _showGoogleSetup(context, e.message);
      } else {
        _showError(_friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busyGoogle = false);
    }
  }

  Future<void> _telegram() async {
    if (_busy) return; // one flow at a time — no duplicate requests
    // A real Telegram login needs (1) a bot created with @BotFather whose
    // username ends with "bot" and (2) the login page origin registered as
    // the bot's Allowed URL. When nothing is configured yet, do NOT stop the
    // user at a setup dialog: they came to shop, so let them straight in as
    // a guest and go to the shop. Settings → Telegram Sign-In still offers
    // the real bot login for anyone who wants to set it up.
    if (!TelegramAuthService.isConfigured ||
        !TelegramAuthService.botLooksValid(TelegramAuthService.botUsername)) {
      widget.onLogin(guestUser());
      return;
    }
    setState(() => _busyTelegram = true);
    try {
      final u = await Navigator.push<User>(
        context,
        MaterialPageRoute(builder: (_) => const TelegramLoginPage()),
      );
      if (!mounted) return;
      if (u != null) {
        // Real Telegram account selected. Register it in the shared cloud
        // directory (provider: 'telegram') so the admin and other devices
        // can see the account with its real @username (e.g. Lin_Sreymao)
        // and photo — without this the sign-in is local-only and looks
        // like a guest.
        await widget.telegramLogin(u);
        widget.onLogin(u);
        return;
      }
      // The page closed without an account = the user cancelled. Stay on
      // the login screen — never silently swap them to a guest session.
      _showError(AppLocalizations.of(context)
          .t('Telegram sign-in was cancelled.'));
    } catch (e) {
      debugPrint('Telegram sign-in failed: $e');
      if (!mounted) return;
      _showError(AppLocalizations.of(context).t(
          'Unable to connect to the server. Please check your internet connection and try again.'));
    } finally {
      if (mounted) setState(() => _busyTelegram = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: const Size.fromHeight(54),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _busy ? null : _google,
            icon: _busyGoogle
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/120px-Google_%22G%22_Logo.svg.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata,
                        color: Colors.blue, size: 26),
                  ),
            label: Text(tr('Continue with Google'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2AABEE),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _busy ? null : _telegram,
            icon: _busyTelegram
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                // Telegram paper-plane logo look: white plane on the
                // brand-blue button.
                : const Icon(Icons.send, size: 20),
            label: Text(tr('Continue with Telegram'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class TelegramLoginPage extends StatefulWidget {
  const TelegramLoginPage({super.key});
  @override
  State<TelegramLoginPage> createState() => _TelegramLoginPageState();
}

class _TelegramLoginPageState extends State<TelegramLoginPage> {
  bool _failed = false;
  bool _loaded = false;
  bool _hint = false; // shown when Telegram never takes over the page
  bool _done = false;
  Timer? _hintTimer;

  void _onAuth(String json) {
    final u = TelegramAuthService.userFromJson(json);
    if (u != null && mounted && !_done) {
      _done = true;
      _hintTimer?.cancel();
      Navigator.pop(context, u);
    }
  }

  /// The confirm redirect Telegram fires after the user approves in the
  /// Telegram app: same page with `#tgAuthResult=<base64url payload>`.
  void _onUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty || _done) return;
    final Uri u;
    try {
      u = Uri.parse(rawUrl);
    } on FormatException {
      return;
    }
    final raw = u.toString();
    User? user;
    if (u.fragment.contains('tgAuthResult=')) {
      user = TelegramAuthService.userFromTgAuthResult(u.fragment);
    } else if (u.scheme == 'http' &&
        u.fragment.isEmpty &&
        u.queryParameters['tgAuthResult'] != null) {
      user = TelegramAuthService
          .userFromTgAuthResult('tgAuthResult=${u.queryParameters['tgAuthResult']}');
    } else if (raw.contains('tgAuthResult=')) {
      user = TelegramAuthService.userFromTgAuthResult(raw);
    }
    if (user != null && mounted) {
      _done = true;
      _hintTimer?.cancel();
      Navigator.pop(context, user);
    }
  }

  /// The confirm step runs inside the Telegram app. Without an app link the
  /// page can also deep-link out via tg:// — open it externally so the user
  /// lands in Telegram instead of a dead webview.
  Future<bool> _openExternally(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false; // nothing on the device can open it (e.g. no Telegram)
    }
  }

  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..setNavigationDelegate(NavigationDelegate(
      onWebResourceError: (WebResourceError e) {
        if (mounted) setState(() => _failed = true);
      },
      onPageFinished: (url) {
        if (mounted) setState(() => _loaded = true);
      },
      onUrlChange: (change) => _onUrl(change.url),
      onNavigationRequest: (req) {
        final url = req.url;
        if (url.startsWith('tg://')) {
          _openExternally(url).then((ok) {
            if (!ok && mounted) setState(() => _hint = true);
          });
          return NavigationDecision.prevent;
        }
        if (url.contains('tgAuthResult=')) {
          _onUrl(url);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ))
    ..addJavaScriptChannel(
      'TelegramLogin',
      onMessageReceived: (m) => _onAuth(m.message),
    );

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _loaded = false;
      _hint = false;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_done && !_failed) setState(() => _hint = true);
    });
    try {
      final origin = TelegramAuthService.allowedOrigin;
      await _controller.loadHtmlString(
        TelegramAuthService.widgetHtml(),
        // Serving the widget from the bot's registered Allowed origin is what
        // makes Telegram show the confirm step. A plain origin (no scheme)
        // is not a valid base URL — fall back to the default then.
        baseUrl: origin.startsWith('http') ? origin : TelegramAuthService.baseUrl,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Continue with Telegram')),
        actions: [
          IconButton(
            tooltip: tr('Setup'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showTelegramSetup(c),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_loaded && !_failed)
            const Center(child: CircularProgressIndicator()),
          if (_hint && !_failed && !_done)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline, color: sch.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('Waiting for Telegram to confirm…'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        tr('If nothing opens in Telegram, the bot\'s Login '
                            'Widget has no Allowed URL yet. Add this app\'s '
                            'link as the Allowed URL in @BotFather, then try '
                            'again.'),
                        style: TextStyle(
                            fontSize: 13, color: sch.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        TextButton(
                          onPressed: () => _showTelegramSetup(c),
                          child: Text(tr('Open setup')), 
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(tr('Retry')),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off,
                        size: 48, color: sch.onSurfaceVariant),
                    const SizedBox(height: 14),
                    Text(
                      tr('Telegram login could not load'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('Check your internet connection and try again.'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: sch.onSurfaceVariant),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(tr('Retry')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPassword();
}

class _ForgotPassword extends State<ForgotPasswordPage> {
  int step = 1;
  String code = '';
  final phone = TextEditingController();
  final codeInput = TextEditingController();
  final npass = TextEditingController();
  final cpass = TextEditingController();
  final fPhone = FocusNode();
  final fCode = FocusNode();
  final fNpass = FocusNode();
  final fCpass = FocusNode();
  bool busy = false;
  bool show = false;
  bool showConfirm = false;
  Timer? _resendTimer;
  int _resendIn = 0; // seconds left before Resend code is enabled

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(x),
          width: 360,
          behavior: SnackBarBehavior.floating));

  String rnd() => (100000 + Random().nextInt(900000)).toString();

  void sendCode() async {
    final tr = AppLocalizations.of(context).t;
    if (phone.text.trim().length < 8) {
      msg(tr('Please enter a valid phone number'));
      return;
    }
    setState(() {
      busy = true;
      code = rnd();
    });
    // The code is generated locally (demo flow) — there is no network call
    // to wait for, so the dialog appears immediately. No artificial delay.
    if (!mounted) return;
    setState(() => busy = false);
    // Start the resend countdown (30s) — prevents code-request spam.
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
    if (step == 1) {
      await showDialog<void>(
        context: context,
        builder: (dc) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sms_outlined, size: 30, color: Colors.green),
          ),
          title: Text(tr('Verification code'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            '${tr('We sent a code to')} ${phone.text.trim()}\n\n$code',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Theme.of(dc).colorScheme.primary),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dc);
                setState(() => step = 2);
              },
              child: Text(tr('Continue')),
            ),
          ],
        ),
      );
    } else {
      // Resend from step 2: no dialog again — just a confirmation snackbar.
      msg(tr('A new code was sent'));
    }
  }

  void verifyCode() {
    final tr = AppLocalizations.of(context).t;
    if (codeInput.text.trim().length < 6) {
      msg(tr('Please enter the 6-digit code'));
      return;
    }
    if (codeInput.text.trim() != code) {
      msg(tr('Wrong code. Check your phone.'));
      return;
    }
    setState(() => step = 3);
  }

  void resetPassword() async {
    final tr = AppLocalizations.of(context).t;
    if (npass.text.length < 6) {
      msg(tr('Password must be at least 6 characters'));
      return;
    }
    if (npass.text != cpass.text) {
      msg(tr('Passwords do not match'));
      return;
    }
    // Apply the new password to the local account registered with this
    // phone number so the next login accepts it.
    final username = AppSettings.findUsernameByPhone(phone.text);
    if (username == null) {
      msg(tr('No account found for this phone number'));
      return;
    }
    setState(() => busy = true);
    await AppSettings.setLocalPassword(username, npass.text);
    // Saved — no artificial wait: respond as soon as the write completes.
    if (!mounted) return;
    setState(() => busy = false);
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 32, color: Colors.green),
        ),
        title: Text(tr('Password reset successful'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(tr('You can now sign in with your new password.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(dc).colorScheme.onSurfaceVariant)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dc);
              Navigator.pop(context);
            },
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  Widget field(TextEditingController c, String t, IconData icon,
      {bool obscure = false,
      bool code_ = false,
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      Widget? suffix,
      FocusNode? node,
      bool autofocus = false,
      TextInputAction? action,
      ValueChanged<String>? onSubmit}) {
    final sch = Theme.of(context).colorScheme;
    final base = OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: sch.outlineVariant));
    return TextField(
      controller: c,
      focusNode: node,
      autofocus: autofocus,
      textInputAction: action,
      onSubmitted: onSubmit,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLength: code_ ? 6 : null,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: t,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: sch.surfaceContainerLowest,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: base,
        enabledBorder: base,
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: sch.primary, width: 1.6)),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    phone.dispose();
    codeInput.dispose();
    npass.dispose();
    cpass.dispose();
    fPhone.dispose();
    fCode.dispose();
    fNpass.dispose();
    fCpass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;

    final int active = step;
    final List<(IconData, String)> steps = [
      (Icons.phone_android, tr('Phone')),
      (Icons.pin_outlined, tr('Code')),
      (Icons.lock_reset, tr('Reset')),
    ];
    final String title = switch (active) {
      2 => '${tr('We sent a code to')} ${phone.text.trim()}',
      3 => tr('Set a new password'),
      _ => tr('Enter your phone number'),
    };
    final String subtitle = switch (active) {
      2 => tr('Type the 6-digit code from the message.'),
      3 => tr('Choose a new password that is at least 6 characters long.'),
      _ => tr('We will text you a 6-digit code to verify it is you.'),
    };

    // Reusable gradient primary button (same look as the Sign In button).
    Widget primary(VoidCallback onTap, String label, IconData icon) {
      return SizedBox(
        height: 54,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            gradient:
                LinearGradient(colors: [Color(0xFF2456C8), Color(0xFF3B82F6)]),
          ),
          child: FilledButton(
            onPressed: busy ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(label),
                  ]),
          ),
        ),
      );
    }

    // Step body with smooth fade/slide when moving between steps.
    Widget stepBody() {
      final int k = active;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(k),
          child: Column(
            key: ValueKey<int>(k),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (k == 1)
                field(phone, tr('Phone'), Icons.phone_android,
                    node: fPhone,
                    autofocus: true,
                    action: TextInputAction.done,
                    onSubmit: (_) => sendCode(),
                    keyboard: TextInputType.phone,
                    formatters: [FilteringTextInputFormatter.digitsOnly])
              else if (k == 2)
                field(codeInput, tr('Verification code'), Icons.pin_outlined,
                    node: fCode,
                    autofocus: true,
                    action: TextInputAction.done,
                    onSubmit: (_) => verifyCode(),
                    code_: true,
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly])
              else ...[
                field(npass, tr('New Password'), Icons.lock_outline,
                    node: fNpass,
                    autofocus: true,
                    action: TextInputAction.next,
                    onSubmit: (_) => fCpass.requestFocus(),
                    obscure: !show,
                    keyboard: TextInputType.visiblePassword),
                const SizedBox(height: 14),
                field(cpass, tr('Confirm password'), Icons.lock_outline,
                    node: fCpass,
                    action: TextInputAction.done,
                    onSubmit: (_) => resetPassword(),
                    obscure: !showConfirm,
                    keyboard: TextInputType.visiblePassword,
                    suffix: IconButton(
                      tooltip: showConfirm
                          ? tr('Hide password')
                          : tr('Show password'),
                      icon: Icon(showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => showConfirm = !showConfirm),
                    )),
              ],
              const SizedBox(height: 20),
              if (k == 1)
                primary(sendCode, tr('Send code'), Icons.send_outlined)
              else if (k == 2) ...[
                primary(
                    verifyCode, tr('Verify code'), Icons.check_circle_outline),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    // Countdown blocks code-request spam; disabled while the
                    // countdown runs or a send is in progress.
                    onPressed: _resendIn > 0 || busy
                        ? null
                        : () {
                            codeInput.clear();
                            sendCode();
                          },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(_resendIn > 0
                        ? tr('Resend code in')
                            .replaceFirst('%d', '$_resendIn')
                        : tr('Resend code')),
                  ),
                ),
              ] else
                primary(resetPassword, tr('Reset password'), Icons.check),
            ],
          ),
        ),
      );
    }

    // Step indicator (3 dots joined by a progress line).
    Widget indicator() {
      return Row(children: [
        for (int i = 1; i <= 3; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= active ? sch.primary : sch.outlineVariant,
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < active
                  ? sch.primary
                  : i == active
                      ? sch.primaryContainer
                      : sch.surfaceContainerHighest,
              border:
                  i == active ? Border.all(color: sch.primary, width: 2) : null,
            ),
            child: i < active
                ? Icon(Icons.check, size: 18, color: sch.onPrimary)
                : Center(
                    child: Icon(steps[i - 1].$1,
                        size: 14,
                        color: i == active
                            ? sch.onPrimaryContainer
                            : sch.onSurfaceVariant)),
          ),
        ],
      ]);
    }

    return AuthBackground(
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: tr('Back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (active > 1) {
                  setState(() => step = active - 1);
                } else {
                  Navigator.pop(c);
                }
              },
            ),
            title: Text(tr('Forgot Password'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // White icon chip floating on the blue gradient, the way
                      // the logo sits on the Sign In hero pane.
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Container(
                            key: ValueKey<int>(active),
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: sch.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(steps[active - 1].$1,
                                size: 44, color: const Color(0xFF2456C8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // White card keeps all the text and fields readable on the
                      // gradient background.
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: sch.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: sch.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: sch.onSurfaceVariant)),
                            const SizedBox(height: 22),
                            indicator(),
                            const SizedBox(height: 22),
                            stepBody(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean white background for the auth screens (Sign up, Forgot password)
/// with soft light-grey circular accents. The form content sits on a white
/// card with a border + shadow so it stays readable and clearly separated.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ring =
        dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFDDE3F0);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF11151C), const Color(0xFF171C26)]
              : [Colors.white, const Color(0xFFF2F5FC)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft decorative circles so the page still looks designed.
          Positioned(
            top: -110,
            right: -110,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: ring.withValues(alpha: 0.7), width: 30),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -70,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: ring.withValues(alpha: 0.6), width: 26),
              ),
            ),
          ),
          Positioned(
            top: 110,
            left: 60,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: ring.withValues(alpha: 0.8), width: 14),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final LoginPresenter p;
  final void Function(User) success;
  final VoidCallback signup;
  const LoginPage(
      {super.key,
      required this.p,
      required this.success,
      required this.signup});
  @override
  State<LoginPage> createState() => _Login();
}

class _Login extends State<LoginPage> {
  final u = TextEditingController();
  final p = TextEditingController();
  bool busy = false;
  bool show = false;

  // Per-field error text — shown right under the related field.
  String? _userError;
  String? _passError;

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(x),
          width: 360,
          behavior: SnackBarBehavior.floating));

  /// Map any low-level failure to one short human message; technical
  /// details stay in the debug console only.
  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('xmlhttprequest') ||
        s.contains('connection') ||
        s.contains('timeout') ||
        s.contains('clientexception')) {
      return AppLocalizations.of(context).t(
          'Unable to connect to the server. Please check your internet connection and try again.');
    }
    final raw = e.toString().replaceFirst('Exception: ', '');
    return AppLocalizations.of(context).t(raw);
  }

  /// Client-side validation BEFORE any request is sent: the fields are
  /// required and the password must be long enough to be plausible.
  bool _validate() {
    setState(() {
      _userError = u.text.trim().isEmpty
          ? AppLocalizations.of(context).t('Please enter your phone number or username')
          : null;
      _passError = p.text.isEmpty
          ? AppLocalizations.of(context).t('Please enter your password')
          : p.text.length < 6
              ? AppLocalizations.of(context).t('Password must be at least 6 characters')
              : null;
    });
    return _userError == null && _passError == null;
  }

  Future<void> go() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return; // never send a request with empty fields
    setState(() => busy = true); // blocks the button until the future ends
    try {
      final x = await widget.p.login(u.text, p.text);
      if (!mounted) return;
      if (x == null) {
        msg(AppLocalizations.of(context)
            .t('Incorrect phone/email or password.'));
      } else {
        widget.success(x);
      }
    } catch (e) {
      if (!mounted) return;
      msg(_friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Outlined, focus-aware field style (replaces the old flat grey boxes:
  // now there is a visible border, a subtle fill and a colored focus ring).
  Widget field(BuildContext c, TextEditingController ctrl, String t, IconData icon,
          {bool obscure = false,
          Widget? suffix,
          String? error,
          TextInputAction? action,
          ValueChanged<String>? onSubmit,
          TextInputType? keyboard}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        textInputAction: action,
        onSubmitted: onSubmit,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: t,
          hintStyle: TextStyle(
              color: Theme.of(c).colorScheme.onSurfaceVariant, fontSize: 16),
          prefixIcon: Icon(icon, size: 22),
          suffixIcon: suffix,
          errorText: error,
          filled: true,
          fillColor: Theme.of(c).colorScheme.surfaceContainerLowest,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide:
                  BorderSide(color: Theme.of(c).colorScheme.outlineVariant)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide:
                  BorderSide(color: Theme.of(c).colorScheme.outlineVariant)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                  color: Theme.of(c).colorScheme.primary, width: 1.6)),
        ),
      );

  /// Brand hero shown next to the form on wide screens (desktop/web).
  Widget _heroPane(BuildContext c, String Function(String) tr) {
    Widget feature(IconData icon, String label) => Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ]);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16337F), Color(0xFF2456C8), Color(0xFF3B82F6)],
        ),
      ),
      // Decorative glow rings in the corners give the pane depth.
      child: Stack(children: [
        Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10), width: 26),
              ),
            )),
        Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 22),
              ),
            )),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo centered on top of the brand pane.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: Image.asset('assets/images/image.png',
                        height: 40, fit: BoxFit.contain),
                  ),
                  const Spacer(),
                  Text(tr('Welcome to Global Online'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 10),
                  Text(tr('Sign in to continue shopping'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15)),
                  const SizedBox(height: 30),
                  // Feature rows centered as a group (fixed width so the text
                  // lines up while the whole block sits in the middle).
                  SizedBox(
                      width: 290,
                      child: feature(Icons.local_offer_outlined,
                          tr('Best prices & daily deals'))),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: 290,
                      child: feature(Icons.local_shipping_outlined,
                          tr('Fast delivery to your door'))),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: 290,
                      child: feature(Icons.verified_user_outlined,
                          tr('Secure payments & easy returns'))),
                ]),
          ),
        ),
      ]),
    );
  }

  /// The login form fields — shared by the wide and narrow layouts.
  Widget _formFields(
      BuildContext c, String Function(String) tr, ColorScheme sch) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Welcome to Global Online'),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(tr('Sign in to continue shopping'),
          style: TextStyle(fontSize: 14, color: sch.onSurfaceVariant)),
      const SizedBox(height: 28),
      // One field for everyone: customers sign in with their
      // username, the admin signs in with the admin phone number.
      field(c, u, tr('Phone number or Username'), Icons.phone_android,
          error: _userError,
          action: TextInputAction.next,
          onSubmit: (_) => FocusScope.of(c).nextFocus()),
      const SizedBox(height: 16),
      field(c, p, tr('Password'), Icons.lock_outline,
          obscure: !show,
          error: _passError,
          action: TextInputAction.done,
          onSubmit: (_) => go(),
          suffix: IconButton(
            tooltip: show ? tr('Hide password') : tr('Show password'),
            icon: Icon(show
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => show = !show),
          )),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
          child: Text(tr('Forgot Password?')),
        ),
      ),
      const SizedBox(height: 10),
      // Gradient primary button — stands out more than flat blue.
      SizedBox(
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                colors: [Color(0xFF2456C8), Color(0xFF3B82F6)]),
          ),
          child: FilledButton(
            onPressed: busy ? null : go,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(tr('Sign In')),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: widget.signup,
        child: Text.rich(TextSpan(
          text: '${tr('New to Global Online?')} ',
          children: [
            TextSpan(
              text: tr('Create Account'),
              style: TextStyle(fontWeight: FontWeight.w700, color: sch.primary),
            ),
          ],
        )),
      ),
      // Social login (Google/Telegram) is for regular users only.
      // The admin signs in with phone + password alone.
      if (!ApiService.isAdminDevice) ...[
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(tr('Or continue with'),
                style: TextStyle(color: sch.onSurfaceVariant)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 18),
        SocialButtons(
            onLogin: widget.success,
            googleLogin: widget.p.googleLogin,
            telegramLogin: widget.p.telegramLogin),
      ],
      // The admin account is desktop-only: on phones there is no
      // admin login hint at all. Hidden entirely in the user-only
      // frontend.
      if (ApiService.isAdminDevice) ...[
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            u.text = ApiService.adminPhone;
            p.text = ApiService.adminPassword;
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sch.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sch.outlineVariant),
            ),
            child: Row(children: [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 16, color: sch.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Admin login (computer only): 066778213 / admin123'),
                  style: TextStyle(fontSize: 12, color: sch.onSurfaceVariant),
                ),
              ),
              Icon(Icons.keyboard_arrow_right,
                  size: 14, color: sch.onSurfaceVariant),
            ]),
          ),
        ),
      ],
    ]);
  }

  /// The login form, centered — the wide layout keeps the brand pane beside
  /// the fields; the phone layout wraps [_formFields] in a floating card.
  Widget _formPane(
      BuildContext c, String Function(String) tr, ColorScheme sch) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _formFields(c, tr, sch),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: sch.surface,
      body: LayoutBuilder(builder: (c, box) {
        final wide = box.maxWidth >= 900;
        if (wide) {
          // Desktop/web: floating card — the gradient brand pane and the
          // form sit side by side, lifted off the background by a soft
          // shadow, with rounded corners all around.
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              constraints: const BoxConstraints(maxWidth: 1080),
              decoration: BoxDecoration(
                color: sch.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: sch.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: sch.shadow.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(children: [
                Expanded(child: _heroPane(c, tr)),
                Expanded(child: _formPane(c, tr, sch)),
              ]),
            ),
          );
        }
        // Phone: the form floats on a soft blue-tinted gradient, inside a
        // white rounded card, with a blue gradient strip on the left edge.
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF1FC), Color(0xFFF7FAFF)],
            ),
          ),
          child: Stack(children: [
            // Decorative gradient accent strip along the left edge.
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(
                width: 10,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF16337F),
                      Color(0xFF2456C8),
                      Color(0xFF3B82F6)
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
                      decoration: BoxDecoration(
                        color: sch.surface,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: sch.shadow.withValues(alpha: 0.10),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: sch.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: sch.outlineVariant),
                              ),
                              child: Image.asset('assets/images/image.png',
                                  height: 48, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _formFields(c, tr, sch),
                        ],
                      ),
                    ),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class SignupPage extends StatefulWidget {
  final SignupPresenter p;
  final void Function(User) success;
  const SignupPage({super.key, required this.p, required this.success});
  @override
  State<SignupPage> createState() => _Signup();
}

class _Signup extends State<SignupPage> {
  final f = TextEditingController();
  final l = TextEditingController();
  final em = TextEditingController();
  final e = TextEditingController();
  final p = TextEditingController();
  final cp = TextEditingController();
  final nf = FocusNode();
  final nl = FocusNode();
  final ne = FocusNode();
  final nem = FocusNode();
  final npw = FocusNode();
  final ncp = FocusNode();
  bool busy = false;
  bool show = false;
  bool showConfirm = false;

  // Per-field validation errors, shown right under the related field.
  String? _fErr, _lErr, _eErr, _emErr, _pErr, _cpErr;

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(x),
          width: 360,
          behavior: SnackBarBehavior.floating));

  /// Map any low-level failure to a short human message.
  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('xmlhttprequest') ||
        s.contains('connection') ||
        s.contains('timeout') ||
        s.contains('clientexception')) {
      return AppLocalizations.of(context).t(
          'Unable to connect to the server. Please check your internet connection and try again.');
    }
    final raw = e.toString().replaceFirst('Exception: ', '');
    return AppLocalizations.of(context).t(raw);
  }

  /// Validate every field up front; each error appears under its own field.
  bool _validate() {
    final t = AppLocalizations.of(context).t;
    bool ok = true;
    String? req(String v) =>
        v.trim().isEmpty ? t('This field is required') : null;
    setState(() {
      _fErr = req(f.text);
      _lErr = req(l.text);
      _eErr = req(e.text);
      if (_eErr == null && e.text.trim().length < 8) {
        _eErr = t('Please enter a valid phone number');
      }
      _emErr = req(em.text);
      if (_emErr == null && !em.text.contains('@')) {
        _emErr = t('Please enter a valid email address');
      }
      _pErr = p.text.isEmpty
          ? t('This field is required')
          : p.text.length < 6
              ? t('Password must be at least 6 characters')
              : null;
      _cpErr = cp.text.isEmpty
          ? t('This field is required')
          : cp.text != p.text
              ? t('Passwords do not match')
              : null;
      ok = [_fErr, _lErr, _eErr, _emErr, _pErr, _cpErr].every((x) => x == null);
    });
    return ok;
  }

  Future<void> go() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return; // field errors shown — nothing sent
    final uname = (f.text.trim() + l.text.trim())
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    setState(() => busy = true);
    try {
      final x = await widget.p.signup(
          f: f.text,
          l: l.text,
          u: uname,
          p: p.text,
          c: cp.text,
          e: em.text,
          ph: e.text);
      // Remember the account on this device so it can actually sign in
      // later (the demo API cannot authenticate newly created users).
      await AppSettings.saveLocalAccount(
          username: uname,
          password: p.text,
          firstName: f.text.trim(),
          lastName: l.text.trim(),
          email: em.text.trim(),
          phone: e.text.trim());
      if (x != null) {
        widget.success(x);
      } else {
        // Even if the demo API rejected the request, the account exists
        // locally and must be usable.
        widget.success(User(
            id: 0,
            firstName: f.text.trim(),
            lastName: l.text.trim(),
            username: uname,
            email: em.text.trim(),
            phone: e.text.trim()));
      }
    } catch (e2) {
      if (!mounted) return;
      msg(_friendlyError(e2));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String t, IconData icon,
      {bool s = false,
      Widget? trailing,
      TextInputType? keyboard,
      FocusNode? node,
      bool autofocus = false,
      TextInputAction? action,
      ValueChanged<String>? onSubmit,
      String? error}) {
    final sch = Theme.of(context).colorScheme;
    final base = OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: sch.outlineVariant));
    return TextField(
      controller: c,
      focusNode: node,
      autofocus: autofocus,
      textInputAction: action,
      onSubmitted: onSubmit,
      obscureText: s,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: t,
        prefixIcon: Icon(icon),
        suffixIcon: trailing,
        errorText: error,
        filled: true,
        fillColor: sch.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: base,
        enabledBorder: base,
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: sch.primary, width: 1.6)),
      ),
    );
  }

  Widget eye({bool? visible, ValueChanged<bool>? onToggle}) => IconButton(
        tooltip: (visible ?? show) ? 'Hide password' : 'Show password',
        icon: Icon((visible ?? show)
            ? Icons.visibility_off
            : Icons.visibility),
        onPressed: () => onToggle != null
            ? onToggle(!(visible ?? show))
            : setState(() => show = !show),
      );

  @override
  void dispose() {
    f.dispose();
    l.dispose();
    em.dispose();
    e.dispose();
    p.dispose();
    cp.dispose();
    nf.dispose();
    nl.dispose();
    ne.dispose();
    nem.dispose();
    npw.dispose();
    ncp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return AuthBackground(
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: tr('Back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(tr('Sign Up'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // White logo chip floating on the gradient, like the logo
                      // on the Sign In hero pane.
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sch.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset('assets/images/image.png',
                              height: 56, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // White card keeps everything readable on the gradient.
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: sch.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: sch.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(tr('Create your account'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(tr('Join Global Online and start shopping'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: sch.onSurfaceVariant)),
                            const SizedBox(height: 26),
                            Row(children: [
                              Expanded(
                                child: field(
                                    f, tr('First name'), Icons.person_outline,
                                    node: nf,
                                    autofocus: true,
                                    action: TextInputAction.next,
                                    error: _fErr,
                                    onSubmit: (_) => nl.requestFocus()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: field(
                                    l, tr('Last name'), Icons.person_outline,
                                    node: nl,
                                    action: TextInputAction.next,
                                    error: _lErr,
                                    onSubmit: (_) => ne.requestFocus()),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            field(e, tr('Phone'), Icons.phone_android,
                                node: ne,
                                action: TextInputAction.next,
                                error: _eErr,
                                onSubmit: (_) => nem.requestFocus(),
                                keyboard: TextInputType.phone),
                            const SizedBox(height: 14),
                            field(em, tr('Email'), Icons.mail_outline,
                                node: nem,
                                action: TextInputAction.next,
                                error: _emErr,
                                onSubmit: (_) => npw.requestFocus(),
                                keyboard: TextInputType.emailAddress),
                            const SizedBox(height: 14),
                            field(p, tr('Password'), Icons.lock_outline,
                                node: npw,
                                action: TextInputAction.next,
                                error: _pErr,
                                onSubmit: (_) => ncp.requestFocus(),
                                s: !show,
                                trailing: eye(
                                  visible: show,
                                  onToggle: (v) => setState(() => show = v),
                                )),
                            const SizedBox(height: 14),
                            field(
                                cp, tr('Confirm password'), Icons.lock_outline,
                                node: ncp,
                                action: TextInputAction.done,
                                error: _cpErr,
                                onSubmit: (_) => go(),
                                s: !showConfirm,
                                trailing: eye(
                                  visible: showConfirm,
                                  onToggle: (v) =>
                                      setState(() => showConfirm = v),
                                )),
                            const SizedBox(height: 24),
                            // Gradient primary button — same as Sign In.
                            SizedBox(
                              height: 54,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  gradient: LinearGradient(colors: [
                                    Color(0xFF2456C8),
                                    Color(0xFF3B82F6)
                                  ]),
                                ),
                                child: FilledButton(
                                  onPressed: busy ? null : go,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  child: busy
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white))
                                      : Text(tr('Create Account')),
                                ),
                              ),
                            ),
                            // Social login (Google/Telegram) is for regular users
                            // only. The admin creates/uses phone accounts alone.
                            if (!ApiService.isAdminDevice) ...[
                              const SizedBox(height: 22),
                              Row(children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(tr('Or continue with'),
                                      style: TextStyle(
                                          color: sch.onSurfaceVariant)),
                                ),
                                const Expanded(child: Divider()),
                              ]),
                              const SizedBox(height: 20),
                              SocialButtons(
                                  onLogin: widget.success,
                                  googleLogin: widget.p.repo.googleLogin,
                                  telegramLogin: widget.p.repo.telegramLogin),
                            ],
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text.rich(TextSpan(
                                text: '${tr('Already have an account?')} ',
                                children: [
                                  TextSpan(
                                    text: tr('Sign In'),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: sch.primary),
                                  ),
                                ],
                              )),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final User user;
  final HomePresenter home;
  final CartPresenter cart;
  final FavoritePresenter fav;
  final OrderPresenter orders;
  final VoidCallback logout;
  final bool dark;
  final ValueChanged<bool> setTheme;
  final void Function(Locale) setLocale;
  const HomePage({
    super.key,
    required this.user,
    required this.home,
    required this.cart,
    required this.fav,
    required this.orders,
    required this.logout,
    required this.dark,
    required this.setTheme,
    required this.setLocale,
  });
  @override
  State<HomePage> createState() => _Home();
}

class _Home extends State<HomePage> {
  late Future<List<Product>> future;
  final q = TextEditingController();
  String? sort;
  int cols = 2;

  @override
  void initState() {
    super.initState();
    future = widget.home.products();
  }

  void search() {
    setState(() {
      future = widget.home.search(q.text);
    });
  }

  void clearSearch() => setState(() {
        q.clear();
        future = widget.home.products();
      });

  void detail(Product p) {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProductPage(p: p, cart: widget.cart, fav: widget.fav)))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  /// The signed-in user merged with their OWN locally saved profile edits
  /// (name / photo changed in Edit Profile) so the AppBar stays fresh.
  User get _user {
    final saved =
        AppSettings.savedProfileFor(AppSettings.profileKeyOf(widget.user));
    if (saved == null) return widget.user;
    return User(
        id: widget.user.id,
        firstName: saved.firstName,
        lastName: saved.lastName,
        username: saved.username,
        email: saved.email,
        phone: saved.phone.isNotEmpty ? saved.phone : widget.user.phone,
        image: saved.image ?? widget.user.image,
        token: widget.user.token);
  }

  /// Small avatar for the AppBar: user photo if available, otherwise their
  /// initial (or a person icon as last resort).
  Widget _profileAvatar(String Function(String) tr) {
    final img = userImage(_user.image);
    final sch = Theme.of(context).colorScheme;
    final name = _user.fullName.trim();
    return Tooltip(
      message: tr('Profile'),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: sch.primaryContainer,
        backgroundImage: img,
        onBackgroundImageError: img == null ? null : (_, __) {},
        child: img == null
            ? name.isNotEmpty
                ? Text(name.characters.first.toUpperCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: sch.onPrimaryContainer))
                : Icon(Icons.person, size: 18, color: sch.onPrimaryContainer)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final l10n = AppLocalizations.of(c);
    final tr = l10n.t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/image.png',
                height: 32, fit: BoxFit.contain),
          ),
        ),
        actions: [
          // Chat Support — compact tonal circle for a cohesive app bar look.
          IconButton.filledTonal(
            tooltip: tr('Chat Support'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportPage())),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.headset_mic_outlined),
          ),
          const SizedBox(width: 6),
          // Cart — tonal circle with a red count badge.
          Badge(
            isLabelVisible: widget.cart.count > 0,
            backgroundColor: sch.error,
            textColor: sch.onError,
            textStyle:
                const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            child: IconButton.filledTonal(
              tooltip: tr('Cart'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CartPage(
                          cart: widget.cart,
                          orders: widget.orders,
                          owner: widget.user.username))).then((_) {
                if (mounted) setState(() {});
              }),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          // Profile — avatar wrapped in a gradient ring.
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 10),
            child: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfilePage(
                          user: _user,
                          ownerKey: AppSettings.profileKeyOf(widget.user),
                          cart: widget.cart,
                          fav: widget.fav,
                          orders: widget.orders,
                          products: widget.home.products(),
                          logout: widget.logout,
                          dark: widget.dark,
                          setTheme: widget.setTheme,
                          setLocale: widget.setLocale,
                          admin: widget.user.isAdmin
                              ? AdminRepository(widget.home.repo.api)
                              : null))).then((_) {
                if (mounted) setState(() {});
              }),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [sch.primary, sch.tertiary]),
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: sch.surface),
                  child: _profileAvatar(tr),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: tr('More'),
            color: sch.surfaceContainerLow,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            constraints: const BoxConstraints(minWidth: 190, maxWidth: 240),
            onSelected: (v) {
              if (v == 'fav') {
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => FavoritePage(
                            fav: widget.fav,
                            cart: widget.cart,
                            source: future)));
              }
              if (v == 'cat') {
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) =>
                            CategoryPage(cart: widget.cart, fav: widget.fav)));
              }
              if (v == 'profile') {
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => ProfilePage(
                            user: _user,
                            ownerKey: AppSettings.profileKeyOf(widget.user),
                            cart: widget.cart,
                            fav: widget.fav,
                            orders: widget.orders,
                            products: widget.home.products(),
                            logout: widget.logout,
                            dark: widget.dark,
                            setTheme: widget.setTheme,
                            setLocale: widget.setLocale,
                            admin: widget.user.isAdmin
                                ? AdminRepository(widget.home.repo.api)
                                : null)));
              }
              if (v == 'orders') {
                Navigator.push(
                        c,
                        MaterialPageRoute(
                            builder: (_) => OrderPage(
                                orders: widget.orders,
                                owner: widget.user.username)))
                    .then((_) => mounted ? setState(() {}) : null);
              }
              if (v == 'admin') {
                // Admin panel is desktop-only (never opens on phones).
                if (!ApiService.isAdminDevice) return;
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => AdminPanelPage(
                            admin: widget.user,
                            repo: AdminRepository(widget.home.repo.api),
                            orders: widget.orders,
                            dark: widget.dark,
                            setTheme: widget.setTheme,
                            setLocale: widget.setLocale,
                            onLogout: widget.logout))).then((_) {
                  if (mounted) setState(() {});
                });
              }
              if (v == 'settings') {
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => SettingsPage(
                            dark: widget.dark,
                            setTheme: widget.setTheme,
                            setLocale: widget.setLocale)));
              }
              if (v == 'support') {
                Navigator.push(
                    c, MaterialPageRoute(builder: (_) => const SupportPage()));
              }
              if (v == 'feedback') {
                Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => FeedbackPage(user: _user)));
              }
              if (v == 'logout') widget.logout();
            },
            itemBuilder: (mc) {
              final tr = AppLocalizations.of(mc).t;
              final mch = Theme.of(mc).colorScheme;
              PopupMenuItem<String> item(
                      String value, IconData icon, String label) =>
                  PopupMenuItem<String>(
                    height: 44,
                    value: value,
                    child: Row(children: [
                      Icon(icon, size: 20, color: mch.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(label, style: const TextStyle(fontSize: 14)),
                    ]),
                  );
              return [
                item('fav', Icons.favorite_border, tr('Favorites')),
                item('cat', Icons.category_outlined, tr('Categories')),
                item(
                    'orders', Icons.receipt_long_outlined, tr('Order History')),
                item('support', Icons.chat_bubble_outline, tr('Chat Support')),
                item('feedback', Icons.rate_review_outlined, tr('Feedback')),
                item('profile', Icons.person_outline, tr('Profile')),
                // Admin panel entry only exists on the computer, never on
                // phones, and never in the user-only frontend.
                if (widget.user.isAdmin && ApiService.isAdminDevice)
                  item('admin', Icons.admin_panel_settings_outlined,
                      tr('Admin Panel')),
                item('settings', Icons.settings_outlined, tr('Settings')),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  height: 44,
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 20, color: mch.error),
                    const SizedBox(width: 12),
                    Text(tr('Logout'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: mch.error)),
                  ]),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: q,
                    onChanged: (_) => search(),
                    onSubmitted: (_) => search(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: tr('Search products or categories'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: q.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: clearSearch),
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            child: Row(
              children: [
                Flexible(child: _sortButton(c, tr)),
                const Spacer(),
                IconButton(
                  tooltip: tr('1 Column'),
                  isSelected: cols == 1,
                  onPressed: () => setState(() => cols = 1),
                  icon: const Icon(Icons.view_agenda_outlined),
                ),
                IconButton(
                  tooltip: tr('2 Columns'),
                  isSelected: cols == 2,
                  onPressed: () => setState(() => cols = 2),
                  icon: const Icon(Icons.grid_on),
                ),
              ],
            ),
          ),
          const Divider(height: 16, thickness: 1),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: future,
              builder: (_, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  return Center(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          future = widget.home.products();
                        });
                      },
                      child: Text(tr('Retry')),
                    ),
                  );
                }
                final list = s.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      q.text.trim().isEmpty
                          ? tr('No products')
                          : l10n.noProductsFor(q.text.trim()),
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }
                final trimmed = q.text.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trimmed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                        child: Text(
                          list.length == 1
                              ? l10n.oneResult(trimmed)
                              : l10n.nResults(list.length, trimmed),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    Expanded(child: _grid(list)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortButton(BuildContext c, String Function(String) tr) {
    final sch = Theme.of(c).colorScheme;
    final label = sort == 'high'
        ? tr('Price: High to Low')
        : sort == 'low'
            ? tr('Price: Low to High')
            : tr('Sort');
    PopupMenuItem<String> item(String v, String t) => PopupMenuItem<String>(
          value: v,
          child: Row(
            children: [
              Icon(
                sort == v ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: sort == v ? sch.primary : null,
              ),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => sort = v == 'none' ? null : v),
      itemBuilder: (_) => [
        item('none', tr('Sort')),
        item('high', tr('Price: High to Low')),
        item('low', tr('Price: Low to High')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sch.surfaceContainerLow,
          border: Border.all(color: sch.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Product> list) {
    final l = [...list];
    if (sort == 'high') l.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'low') l.sort((a, b) => a.price.compareTo(b.price));
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: cols == 2 ? .65 : 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: l.length,
      itemBuilder: (_, i) {
        final p = l[i];
        return Card(
          child: InkWell(
            onTap: () => detail(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(p.thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image)),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filledTonal(
                          onPressed: () => setState(() => widget.fav.toggle(p)),
                          icon: Icon(widget.fav.has(p)
                              ? Icons.favorite
                              : Icons.favorite_border),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(p.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
                  child: Text('\$${p.price.toStringAsFixed(2)}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductPage extends StatefulWidget {
  final Product p;
  final CartPresenter cart;
  final FavoritePresenter fav;
  const ProductPage(
      {super.key, required this.p, required this.cart, required this.fav});
  @override
  State<ProductPage> createState() => _Product();
}

class _Product extends State<ProductPage> {
  int _img = 0;

  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    final l10n = AppLocalizations.of(c);
    final tr = l10n.t;
    final sch = Theme.of(c).colorScheme;
    final disc = p.discountPercentage;
    final save = (p.price * disc / 100).toStringAsFixed(2);
    final original = (p.price / (1 - disc / 100)).toStringAsFixed(2);
    final images = p.images.isNotEmpty ? p.images : [p.thumbnail];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Product Details'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Container(
              color: sch.surfaceContainerLow,
              child: Image.network(images[_img], fit: BoxFit.contain),
            ),
          ),
          if (images.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _img = i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          width: 2,
                          color: i == _img ? sch.primary : sch.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(images[i],
                          width: 58, height: 58, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (p.category.isNotEmpty)
                      _chip(c, Icon(Icons.category_outlined, size: 15),
                          tr(p.category)),
                    if (p.brand.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _chip(
                          c,
                          Icon(Icons.branding_watermark_outlined, size: 15),
                          p.brand),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(p.title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.25)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(p.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('•  ${tr('Stock')}: ${p.stock}',
                        style: TextStyle(color: sch.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p.price.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: sch.primary)),
                    if (disc > 0) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('\$$original',
                            style: TextStyle(
                                fontSize: 16,
                                color: sch.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough)),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: sch.errorContainer,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text('−${disc.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: sch.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (disc > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        l10n.discountLine(disc.toStringAsFixed(0), save),
                        style: TextStyle(
                            color: sch.error, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(tr('Description'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(l10n.productDescription(p.id, p.description),
                    style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: sch.surface,
          border: Border(top: BorderSide(color: sch.outlineVariant)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (disc > 0)
                    Text('\$$original',
                        style: TextStyle(
                            fontSize: 13,
                            color: sch.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough)),
                  Text('\$${p.price.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: sch.primary)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    widget.cart.add(p);
                    ScaffoldMessenger.of(c).showSnackBar(
                        SnackBar(content: Text(tr('Added to cart'))));
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(tr('Add to Cart')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext c, Icon icon, String label) {
    final sch = Theme.of(c).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sch.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: sch.onSecondaryContainer, fontSize: 13)),
        ],
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  final CartPresenter cart;
  final OrderPresenter orders;

  /// Username of the buyer, attached to the created order so the Admin
  /// panel can show who ordered what.
  final String owner;
  const CartPage(
      {super.key, required this.cart, required this.orders, this.owner = ''});
  @override
  State<CartPage> createState() => _Cart();
}

class _Cart extends State<CartPage> {
  Future<void> checkout() async {
    if (widget.cart.items.isEmpty) return;
    final a = await Navigator.push<Address>(
        context, MaterialPageRoute(builder: (_) => const AddressPage()));
    if (a == null || !mounted) return;
    // Do not create the order or clear the cart until the shopper has seen
    // the exact total and the QR(s) for the vendor(s) being paid AND the
    // payment has been verified by the provider (Bakong) on the backend.
    // The reference doubles as the cloud order id, which makes the
    // verified-order RPC idempotent (no duplicate orders on double taps).
    final reference = DateTime.now().millisecondsSinceEpoch.toString();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _VendorPaymentSheet(
        items: widget.cart.items,
        total: widget.cart.grandTotal,
        tax: widget.cart.tax,
        reference: reference,
        address: '${a.address}, ${a.city}, ${a.country}',
        owner: widget.owner,
      ),
    );
    if (confirmed != true || !mounted) return;
    // The sheet returns true ONLY after the backend RPC created the order
    // (payment verified server-side). Record the verified order locally so
    // it appears in Order History even before the next cloud refresh.
    await widget.orders.createVerified(widget.cart.items, widget.cart.grandTotal,
        a,
        id: reference,
        owner: widget.owner);
    widget.cart.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('Order placed')),
        content: Text(AppLocalizations.of(context)
            .t('Your order was created successfully.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).t('OK'))),
        ],
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    final items = widget.cart.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Cart')),
        actions: items.isEmpty
            ? null
            : [
                IconButton(
                  tooltip: tr('Clear cart'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: c,
                      builder: (dc) => AlertDialog(
                        title: Text(tr('Clear cart?')),
                        content: Text(tr('Remove all items from your cart?')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dc, false),
                              child: Text(tr('Cancel'))),
                          FilledButton(
                              onPressed: () => Navigator.pop(dc, true),
                              child: Text(tr('Clear'))),
                        ],
                      ),
                    );
                    if (ok == true && mounted) setState(widget.cart.clear);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: items.isEmpty ? _empty(c, tr, sch) : _list(c, tr, sch),
      bottomNavigationBar: items.isEmpty ? null : _summary(c, tr, sch),
    );
  }

  Widget _empty(BuildContext c, String Function(String) tr, ColorScheme sch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: sch.surfaceContainerHighest.withValues(alpha: .6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined,
                  size: 52, color: sch.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            Text(tr('Your cart is empty'),
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              tr('Looks like you have no items in your cart yet.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: sch.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(c).maybePop(),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(tr('Start shopping')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(
      BuildContext c, String Function(String) tr, ColorScheme sch, CartItem x) {
    final p = x.product;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sch.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 82,
                height: 82,
                child: Image.network(
                  p.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: sch.surfaceContainerHighest,
                    child:
                        Icon(Icons.image_outlined, color: sch.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                  const SizedBox(height: 4),
                  if (p.brand.isNotEmpty || p.category.isNotEmpty)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [p.brand, p.category]
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: sch.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text('\$${p.price.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: sch.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomRow(
      BuildContext c, String Function(String) tr, ColorScheme sch, CartItem x) {
    final p = x.product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          _stepper(c, sch, x),
          const Spacer(),
          Text('${tr('Subtotal')}: ',
              style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
          Text('\$${x.subtotal.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: tr('Remove'),
            onPressed: () => setState(() => widget.cart.remove(p)),
            icon: Icon(Icons.delete_outline, color: sch.error, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext c, ColorScheme sch, CartItem x) {
    final p = x.product;
    Widget btn(IconData icon, VoidCallback onTap) => InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: sch.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, () => setState(() => widget.cart.minus(p))),
          SizedBox(
            width: 26,
            child: Text('${x.quantity}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          btn(Icons.add, () => setState(() => widget.cart.add(p))),
        ],
      ),
    );
  }

  Widget _list(BuildContext c, String Function(String) tr, ColorScheme sch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Text(
                '${widget.cart.count} ${tr('Items')}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('\$${widget.cart.grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: sch.primary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            itemCount: widget.cart.items.length,
            itemBuilder: (_, i) {
              final x = widget.cart.items[i];
              return Column(
                children: [
                  _itemCard(c, tr, sch, x),
                  _bottomRow(c, tr, sch, x),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext c, String Function(String) tr, ColorScheme sch) {
    final priceStyle = TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, color: sch.primary);
    return Container(
      decoration: BoxDecoration(
        color: sch.surface,
        border: Border(top: BorderSide(color: sch.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(tr('Subtotal'), '\$${widget.cart.total.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _row(
                  '${tr('Tax')} (${(CartPresenter.taxRate * 100).toStringAsFixed(0)}%)',
                  '\$${widget.cart.tax.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _row(tr('Shipping'), tr('Free')),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('Total'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('\$${widget.cart.grandTotal.toStringAsFixed(2)}',
                      style: priceStyle),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: checkout,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: Text(tr('Checkout')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade600)),
        ],
      );
}

/// Checkout confirmation for QR payments. A cart can contain products from
/// multiple vendors, so each vendor receives a separate exact amount.
///
/// PAYMENT VERIFICATION (KHQR / Bakong):
///  * When the sheet opens it registers every vendor share as a PENDING
///    payment row in the cloud (never as paid).
///  * A timer re-checks the payment status server-side every few seconds.
///    Only the Bakong Open API answer can flip a share to VERIFIED —
///    opening/scanning the QR here does nothing on its own.
///  * The "I have paid — place order" button stays DISABLED until every
///    share is VERIFIED. A disabled tap shows
///    "Please complete the payment before placing your order."
///  * Placing the order goes through the backend RPC which re-verifies the
///    payment again server-side (the button state alone is never trusted)
///    and is idempotent per reference, so repeated taps cannot duplicate
///    the order.
class _VendorPaymentSheet extends StatefulWidget {
  final List<CartItem> items;
  final double total;
  final double tax;
  final String reference;
  final String owner;

  /// Delivery address captured before the sheet opened — handed to the
  /// verified-order RPC when the shopper taps the button.
  final String address;
  const _VendorPaymentSheet({
    required this.items,
    required this.total,
    required this.tax,
    required this.reference,
    required this.address,
    this.owner = '',
  });
  @override
  State<_VendorPaymentSheet> createState() => _VendorPaymentSheetState();
}

class _VendorPaymentSheetState extends State<_VendorPaymentSheet> {
  /// Vendor → (amount, qr payload, md5) — built once from the cart.
  late final Map<String, ({double amount, String payload})> _shares;

  /// Vendor → VERIFIED? Mirrors the cloud `payments` rows.
  final Map<String, bool> _verified = {};

  bool _registered = false; // PENDING rows saved to the cloud
  bool _checking = false; // a status re-check is running
  bool _placing = false; // verified order RPC is running
  String? _error; // last verification/placement error
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final subtotals = <String, double>{};
    for (final item in widget.items) {
      final vendor = item.product.vendorUsername.trim().isEmpty
          ? 'store'
          : item.product.vendorUsername.trim();
      subtotals[vendor] = (subtotals[vendor] ?? 0) + item.subtotal;
    }
    final subtotal = subtotals.values.fold<double>(0, (a, b) => a + b);
    _shares = {
      for (final entry in subtotals.entries)
        entry.key: (
          amount: entry.value +
              (subtotal == 0 ? 0 : widget.tax * entry.value / subtotal),
          payload: _paymentData(entry.key,
              entry.value + (subtotal == 0 ? 0 : widget.tax * entry.value / subtotal)),
        ),
    };
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// QR payload for a vendor share: the vendor's stored bank/KHQR code when
  /// it has one, otherwise a self-describing demo payload carrying vendor,
  /// amount and the immutable order reference.
  String _paymentData(String vendor, double amount) {
    final code = widget.items
        .where((item) =>
            (item.product.vendorUsername.trim().isEmpty
                ? 'store'
                : item.product.vendorUsername.trim()) ==
            vendor)
        .map((item) => item.product.vendorPaymentCode.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return code.isNotEmpty
        ? code
        : 'online-shop-payment://pay?vendor=${Uri.encodeComponent(vendor)}&amount=${amount.toStringAsFixed(2)}&reference=${widget.reference}';
  }

  Future<void> _start() async {
    // 1. Register PENDING rows (one per vendor share) in the cloud. This
    //    only creates the payment records to be verified — it is NOT a
    //    confirmation of payment in any way.
    _registered = await SupabaseService.instance.registerPayments(
      widget.reference,
      [
        for (final e in _shares.entries)
          {
            'reference': widget.reference,
            'vendor': e.key,
            'amount': e.value.amount,
            'currency': 'USD',
            'qr_md5': SupabaseService.qrMd5(e.value.payload),
            'qr_payload': e.value.payload,
            'status': 'PENDING',
          }
      ],
    );
    if (mounted) setState(() {});
    await _check();
    if (mounted) {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    }
  }

  /// Re-check the payment status server-side. True ONLY when every share
  /// is VERIFIED afterwards. Failures leave everything unverified.
  Future<bool> _check() async {
    if (_checking || !mounted) return false;
    _checking = true;
    final verified =
        await SupabaseService.instance.verifyPayment(widget.reference);
    _checking = false;
    if (!mounted) return verified;
    setState(() {
      if (verified) {
        for (final v in _shares.keys) {
          _verified[v] = true;
        }
        _error = null;
      } else {
        for (final v in _shares.keys) {
          _verified[v] = false;
        }
      }
    });
    if (verified) _poll?.cancel();
    return verified;
  }

  bool get _allVerified =>
      _shares.isNotEmpty && _shares.keys.every((v) => _verified[v] == true);

  /// "I have paid — place order". Only reachable when every share is
  /// VERIFIED (the button is disabled otherwise). Asks the backend to
  /// re-verify and create the order; idempotent per reference.
  Future<void> _placeOrder() async {
    if (_placing) return; // already running — no duplicate orders
    setState(() {
      _placing = true;
      _error = null;
    });
    final orderId = await SupabaseService.instance.createVerifiedOrder(
      reference: widget.reference,
      owner: widget.owner,
      total: widget.total,
      address: widget.address,
      itemsJson: jsonEncode(SupabaseService.orderItemsJson(widget.items)),
    );
    if (!mounted) return;
    setState(() => _placing = false);
    if (orderId == null) {
      // Backend refused (payment not verified server-side, cloud down, or
      // the RPC rejected the order). The order was NOT created.
      setState(() => _error =
          'Please complete the payment before placing your order.');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: .78,
        minChildSize: .48,
        maxChildSize: .94,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: sch.outlineVariant,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Payment confirmation',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Amount to pay', style: TextStyle(color: sch.onSurfaceVariant)),
            Text('\$${widget.total.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: sch.primary)),
            const SizedBox(height: 8),
            Text('Reference: ${widget.reference}', style: TextStyle(fontSize: 12, color: sch.onSurfaceVariant)),
            const SizedBox(height: 18),
            for (final entry in _shares.entries) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: sch.outlineVariant)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text(entry.key == 'store' ? 'Store payment' : 'Pay vendor @${entry.key}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('\$${entry.value.amount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: sch.primary)),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: entry.value.payload,
                      version: QrVersions.auto,
                      size: 190,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    _statusChip(sch, entry.key),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: sch.errorContainer.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: sch.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: sch.onErrorContainer))),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              // DISABLED until every vendor share is VERIFIED by the payment
              // provider (checked server-side). A disabled tap does nothing.
              onPressed: _allVerified && !_placing ? _placeOrder : null,
              icon: _placing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_outlined),
              label: Text(_placing
                  ? 'Verifying payment...'
                  : 'I have paid — place order'),
            ),
            if (!_allVerified) ...[
              const SizedBox(height: 8),
              Text('Waiting for payment confirmation... The button enables '
                  'automatically once your payment is verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: sch.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            TextButton(
                onPressed: _placing ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ColorScheme sch, String vendor) {
    final verified = _verified[vendor] == true;
    final checking = !_registered || _checking;
    final color = verified ? Colors.green : checking ? Colors.orange : sch.error;
    final icon = verified
        ? Icons.verified_outlined
        : checking
            ? Icons.hourglass_top
            : Icons.hourglass_empty;
    final label = verified
        ? 'Payment verified'
        : checking
            ? 'Checking payment...'
            : 'Payment not received yet';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class AddressPage extends StatefulWidget {
  final Address? initial;
  final bool saveMode;
  const AddressPage({super.key, this.initial, this.saveMode = false});
  @override
  State<AddressPage> createState() => _Address();
}

class _Address extends State<AddressPage> {
  late final TextEditingController n =
      TextEditingController(text: widget.initial?.fullName);
  late final TextEditingController ph =
      TextEditingController(text: widget.initial?.phone);
  late final TextEditingController a =
      TextEditingController(text: widget.initial?.address);
  late final TextEditingController city =
      TextEditingController(text: widget.initial?.city ?? 'Phnom Penh');
  late final TextEditingController country =
      TextEditingController(text: widget.initial?.country ?? 'Cambodia');
  late LatLng _pos;
  MapController? _ctrl;

  @override
  void initState() {
    super.initState();
    _pos = LatLng(widget.initial?.latitude ?? 11.5564,
        widget.initial?.longitude ?? 104.9282);
  }

  void _setPin(LatLng p) {
    setState(() => _pos = p);
  }

  Widget f(TextEditingController c, String t, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: t,
              prefixIcon: Icon(icon),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            )),
      );

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');
      final r = await http.get(uri, headers: {'User-Agent': 'online_shop_mvp'});
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final m = j['address'] as Map<String, dynamic>? ?? {};
        final c = m['city'] ?? m['town'] ?? m['village'] ?? '';
        final country_ = m['country'] ?? '';
        if (a.text.isEmpty) a.text = j['display_name'] ?? '';
        if (c.toString().isNotEmpty) city.text = c.toString();
        if (country_.toString().isNotEmpty) country.text = country_.toString();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _onTapMap(TapPosition tp, LatLng p) {
    _setPin(p);
    _reverseGeocode(p.latitude, p.longitude);
  }

  void _useMapCenter() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = ctrl.camera.center;
    _setPin(c);
    _reverseGeocode(c.latitude, c.longitude);
  }

  void go() {
    if (n.text.isEmpty || ph.text.isEmpty || a.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)
              .t('Please complete delivery information'))));
      return;
    }
    Navigator.pop(
        context,
        Address(
          fullName: n.text,
          phone: ph.text,
          address: a.text,
          city: city.text,
          country: country.text,
          latitude: _pos.latitude,
          longitude: _pos.longitude,
        ));
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.saveMode ? tr('My Address') : tr('Delivery Address'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 250,
              child: FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                  initialCenter: _pos,
                  initialZoom: 15,
                  onTap: _onTapMap,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.online_shop_mvp_full',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pos,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_pin,
                            size: 44, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(tr('Tap the map to select your delivery location'),
                style: TextStyle(color: sch.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _useMapCenter,
              icon: const Icon(Icons.center_focus_strong, size: 18),
              label: Text(tr('Use map center')),
            ),
          ),
          const SizedBox(height: 14),
          Text(tr('Contact information'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sch.onSurfaceVariant)),
          const SizedBox(height: 10),
          f(n, tr('Full name'), Icons.person_outline),
          f(ph, tr('Phone'), Icons.phone_outlined),
          f(a, tr('Address'), Icons.home_outlined),
          f(city, tr('City'), Icons.location_city_outlined),
          f(country, tr('Country'), Icons.public),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: go,
            icon: const Icon(Icons.check),
            label: Text(widget.saveMode ? tr('Save') : tr('Continue')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${_pos.latitude},${_pos.longitude}');
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.map_outlined, color: Color(0xFF4285F4)),
            label: Text(tr('Open in Google Maps')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4285F4),
              side: const BorderSide(color: Color(0xFF4285F4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  final CartPresenter cart;
  final FavoritePresenter fav;
  const CategoryPage({super.key, required this.cart, required this.fav});
  @override
  State<CategoryPage> createState() => _Cat();
}

class _Cat extends State<CategoryPage> {
  late final CategoryPresenter p;
  late Future<List<Category>> cats;
  final sq = TextEditingController();
  List<Product>? items;
  String? sort;
  int cols = 2;

  @override
  void initState() {
    super.initState();
    p = CategoryPresenter(ProductRepository(ApiService()));
    cats = p.categories();
  }

  Future<void> load(Future<List<Product>> f) async {
    setState(() => items = null);
    try {
      final l = await f;
      if (mounted) setState(() => items = l);
    } catch (_) {
      if (mounted) setState(() => items = const []);
    }
  }

  List<Product> get shown {
    final l = [...items!];
    if (sort == 'high') l.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'low') l.sort((a, b) => a.price.compareTo(b.price));
    return l;
  }

  void catClear() {
    sq.clear();
    setState(() => items = null);
  }

  Widget _sortButton(BuildContext c, String Function(String) tr) {
    final sch = Theme.of(c).colorScheme;
    final label = sort == 'high'
        ? tr('Price: High to Low')
        : sort == 'low'
            ? tr('Price: Low to High')
            : tr('Sort');
    PopupMenuItem<String> item(String v, String t) => PopupMenuItem<String>(
          value: v,
          child: Row(
            children: [
              Icon(
                sort == v ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: sort == v ? sch.primary : null,
              ),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => sort = v == 'none' ? null : v),
      itemBuilder: (_) => [
        item('none', tr('Sort')),
        item('high', tr('Price: High to Low')),
        item('low', tr('Price: Low to High')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sch.surfaceContainerLow,
          border: Border.all(color: sch.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext c, Product x) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
                builder: (_) =>
                    ProductPage(p: x, cart: widget.cart, fav: widget.fav))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(x.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filledTonal(
                      onPressed: () => setState(() => widget.fav.toggle(x)),
                      icon: Icon(widget.fav.has(x)
                          ? Icons.favorite
                          : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child:
                  Text(x.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
              child: Text('\$${x.price.toStringAsFixed(2)}'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Categories'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: sq,
              onChanged: (_) => load(p.search(sq.text)),
              onSubmitted: (_) => load(p.search(sq.text)),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: tr('Search products or categories'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: sq.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear), onPressed: catClear),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 88,
            child: FutureBuilder<List<Category>>(
              future: cats,
              builder: (_, s) => !s.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: s.data!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ActionChip(
                        label: Text(tr(s.data![i].name)),
                        onPressed: () => load(p.products(s.data![i].slug)),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
            child: Row(
              children: [
                Flexible(child: _sortButton(c, tr)),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: tr('1 Column'),
                  isSelected: cols == 1,
                  onPressed: () => setState(() => cols = 1),
                  icon: const Icon(Icons.view_agenda_outlined),
                ),
                IconButton(
                  tooltip: tr('2 Columns'),
                  isSelected: cols == 2,
                  onPressed: () => setState(() => cols = 2),
                  icon: const Icon(Icons.grid_on),
                ),
              ],
            ),
          ),
          const Divider(height: 16, thickness: 1),
          Expanded(
            child: items == null
                ? Center(child: Text(tr('Select a category or search')))
                : shown.isEmpty
                    ? Center(child: Text(tr('No products found')))
                    : GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          childAspectRatio: cols == 2 ? 0.65 : 1.1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _cell(c, shown[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class FavoritePage extends StatefulWidget {
  final FavoritePresenter fav;
  final CartPresenter cart;
  final Future<List<Product>> source;
  const FavoritePage(
      {super.key, required this.fav, required this.cart, required this.source});
  @override
  State<FavoritePage> createState() => _Fav();
}

class _Fav extends State<FavoritePage> {
  Widget cell(BuildContext c, Product p) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
                builder: (_) =>
                    ProductPage(p: p, cart: widget.cart, fav: widget.fav))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(p.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      tooltip: tr('Remove from favorites'),
                      onPressed: () => setState(() => widget.fav.toggle(p)),
                      icon: const Icon(Icons.favorite, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child:
                  Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('\$${p.price.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: sch.primary)),
                  ),
                  IconButton.filledTonal(
                    iconSize: 20,
                    tooltip: tr('Add to Cart'),
                    onPressed: () {
                      widget.cart.add(p);
                      ScaffoldMessenger.of(c).showSnackBar(
                          SnackBar(content: Text(tr('Added to cart'))));
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Favorites'))),
      body: FutureBuilder<List<Product>>(
        future: widget.source,
        builder: (_, s) {
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = widget.fav.ids.isEmpty
              ? <Product>[]
              : s.data!.where((p) => widget.fav.has(p)).toList();
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 70, color: Theme.of(c).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(tr('No favorites'),
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.66,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => cell(c, list[i]),
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final User user;

  /// Stable key of the SIGNED-IN account (computed from the raw session
  /// user, not the merged one) so profile edits stay attached to this login.
  final String ownerKey;
  final CartPresenter cart;
  final FavoritePresenter fav;
  final OrderPresenter orders;
  final Future<List<Product>> products;
  final VoidCallback logout;

  /// Lets the admin Settings page switch the whole app's language live.
  final void Function(Locale)? setLocale;

  /// Theme state + callback so this page's Admin panel keeps working when
  /// the admin toggles Light/Dark mode from the top bar.
  final bool dark;
  final ValueChanged<bool>? setTheme;

  /// Non-null when the signed-in user is an admin, which unlocks the
  /// Admin panel entry on this page.
  final AdminRepository? admin;
  const ProfilePage(
      {super.key,
      required this.user,
      required this.ownerKey,
      required this.cart,
      required this.fav,
      required this.orders,
      required this.products,
      required this.logout,
      this.dark = false,
      this.setTheme,
      this.setLocale,
      this.admin});
  @override
  State<ProfilePage> createState() => _Profile();
}

class _Profile extends State<ProfilePage> {
  late User user;
  bool _imgFailed = false;

  @override
  void initState() {
    super.initState();
    // Only apply edits saved for THIS account (keyed by email/username),
    // never another account's — that's why a Google login used to show the
    // previous local account's name.
    final saved = AppSettings.savedProfileFor(widget.ownerKey);
    user = saved == null
        ? widget.user
        : User(
            id: widget.user.id,
            firstName: saved.firstName,
            lastName: saved.lastName,
            username: saved.username,
            email: saved.email,
            phone: saved.phone.isNotEmpty ? saved.phone : widget.user.phone,
            image: saved.image ?? widget.user.image,
            token: widget.user.token,
            isAdmin: widget.user.isAdmin);
    _imgFailed = false;
  }

  Future<void> _edit() async {
    final edited = await Navigator.push<User>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EditProfilePage(user: user, ownerKey: widget.ownerKey)),
    );
    if (edited != null && mounted) setState(() => user = edited);
  }

  void _openCart() {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CartPage(
                    cart: widget.cart,
                    orders: widget.orders,
                    owner: widget.user.username)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openFav() {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FavoritePage(
                    fav: widget.fav,
                    cart: widget.cart,
                    source: widget.products)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openOrders() {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OrderPage(
                    orders: widget.orders, owner: widget.user.username)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openAdmin() {
    final repo = widget.admin;
    if (repo == null) return;
    // Admin panel is desktop-only (never opens on phones).
    if (!ApiService.isAdminDevice) return;
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AdminPanelPage(
                    admin: user,
                    repo: repo,
                    orders: widget.orders,
                    dark: widget.dark,
                    setTheme: widget.setTheme,
                    setLocale: widget.setLocale,
                    onLogout: widget.logout)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openSupport() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SupportPage()));
  }

  Future<void> _openAddress() async {
    final saved = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddressPage(initial: AppSettings.savedAddress, saveMode: true)),
    );
    if (saved != null && mounted) {
      await AppSettings.saveAddress(saved);
      setState(() {});
    }
  }

  void _openPassword() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChangePasswordPage(user: user)));
  }

  void _openAbout() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AboutUsPage()));
  }

  void _openContact() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ContactUsPage()));
  }

  void _openFaq() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqPage()));
  }

  void _openTerms() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TermsConditionsPage()));
  }

  void _openPrivacy() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
  }

  void _openDeleteAccount() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DeleteAccountPage(
                user: user,
                loginUsername: widget.user.username,
                ownerKey: widget.ownerKey,
                orders: widget.orders,
                cart: widget.cart,
                fav: widget.fav,
                onDeleted: widget.logout)));
  }

  Widget _stat(
      BuildContext c, IconData icon, int n, String label, VoidCallback onTap) {
    final sch = Theme.of(c).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: sch.primary, size: 24),
            const SizedBox(height: 6),
            Text('$n',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: sch.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: sch.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _action(
      BuildContext c, IconData icon, String label, VoidCallback onTap) {
    final sch = Theme.of(c).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sch.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: sch.onSecondaryContainer, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Profile')),
        actions: [
          IconButton(
            onPressed: _edit,
            tooltip: tr('Edit Profile'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                sch.surfaceContainerHighest,
                                sch.surfaceContainerLow,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: sch.surfaceContainerHigh,
                          backgroundImage: user.image == null || _imgFailed
                              ? null
                              : userImage(user.image),
                          onBackgroundImageError: user.image == null
                              ? null
                              : (_, __) => setState(() => _imgFailed = true),
                          child: _imgFailed
                              ? Icon(Icons.person, size: 60, color: sch.primary)
                              : user.image == null
                                  ? Icon(Icons.person,
                                      size: 60, color: sch.primary)
                                  : null,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: GestureDetector(
                          onTap: _edit,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: sch.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(Icons.photo_camera,
                                size: 16, color: sch.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: sch.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: sch.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('@${user.username}',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: sch.onSecondaryContainer)),
                      ),
                      const SizedBox(height: 8),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sch.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.email_outlined,
                                  size: 15, color: sch.onSecondaryContainer),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(user.email,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: sch.onSecondaryContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (user.phone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sch.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 15, color: sch.onSecondaryContainer),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(user.phone,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: sch.onSecondaryContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.outlineVariant)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            child: _stat(c, Icons.shopping_cart_outlined,
                                widget.cart.count, tr('Cart'), _openCart)),
                        Container(
                            width: 1, height: 44, color: sch.outlineVariant),
                        Expanded(
                            child: _stat(
                                c,
                                Icons.favorite_outline,
                                widget.fav.ids.length,
                                tr('Favorites'),
                                _openFav)),
                        Container(
                            width: 1, height: 44, color: sch.outlineVariant),
                        Expanded(
                            child: _stat(
                                c,
                                Icons.receipt_long_outlined,
                                widget.orders.orders.length,
                                tr('Orders'),
                                _openOrders)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (AppSettings.savedAddress != null)
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: sch.outlineVariant)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openAddress,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: sch.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.location_on_outlined,
                                  color: sch.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${AppSettings.savedAddress!.fullName} · ${AppSettings.savedAddress!.phone}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${AppSettings.savedAddress!.address}, ${AppSettings.savedAddress!.city}, ${AppSettings.savedAddress!.country}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: sch.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.outlineVariant)),
                  child: Column(
                    children: [
                      _action(c, Icons.shopping_cart_outlined, tr('Cart'),
                          _openCart),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(
                          c, Icons.favorite_outline, tr('Favorites'), _openFav),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.receipt_long_outlined,
                          tr('Order History'), _openOrders),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.location_on_outlined, tr('My Address'),
                          _openAddress),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.chat_bubble_outline, tr('Chat Support'),
                          _openSupport),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(
                          c, Icons.edit_outlined, tr('Edit Profile'), _edit),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.lock_reset_outlined,
                          tr('Change Password'), _openPassword),
                      // Admin panel entry only exists on the computer.
                      if (widget.admin != null && ApiService.isAdminDevice) ...[
                        Divider(
                            height: 1, indent: 58, color: sch.outlineVariant),
                        _action(c, Icons.admin_panel_settings_outlined,
                            tr('Admin Panel'), _openAdmin),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.outlineVariant)),
                  child: Column(
                    children: [
                      _action(
                          c, Icons.info_outline, tr('About Us'), _openAbout),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.contact_phone_outlined, tr('Contact Us'),
                          _openContact),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.help_outline, tr('FAQs'), _openFaq),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.description_outlined,
                          tr('Terms & Conditions'), _openTerms),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.privacy_tip_outlined,
                          tr('Privacy Policy'), _openPrivacy),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.errorContainer)),
                  color: sch.errorContainer.withValues(alpha: 0.35),
                  child: _action(c, Icons.delete_forever_outlined,
                      tr('Delete Account'), _openDeleteAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final User user;

  /// Key of the account this profile belongs to (email/username based), so
  /// edits are stored per account and never leak into another login.
  final String ownerKey;
  const EditProfilePage(
      {super.key, required this.user, required this.ownerKey});
  @override
  State<EditProfilePage> createState() => _EditProfile();
}

class _EditProfile extends State<EditProfilePage> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController first =
      TextEditingController(text: widget.user.firstName);
  late final TextEditingController last =
      TextEditingController(text: widget.user.lastName);
  late final TextEditingController name =
      TextEditingController(text: widget.user.username);
  late final TextEditingController email =
      TextEditingController(text: widget.user.email);
  late final TextEditingController phone =
      TextEditingController(text: widget.user.phone);
  String _url = '';
  String? _b64;

  @override
  void dispose() {
    for (final c in [first, last, name, email, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  ImageProvider? get _preview {
    if (_b64 != null) return MemoryImage(base64Decode(_b64!));
    final s = _url.isNotEmpty ? _url : widget.user.image;
    return userImage(s);
  }

  Future<void> _changePhoto() async {
    final tr = AppLocalizations.of(context).t;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (bc) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Choose from gallery')),
              onTap: () => Navigator.pop(bc, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(tr('Enter image URL')),
              onTap: () => Navigator.pop(bc, 'url'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'gallery') return _pickGallery();
    if (choice == 'url') return _askUrl();
  }

  Future<void> _pickGallery() async {
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 900,
          maxHeight: 900,
          imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _b64 = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).t(
                'Could not open the gallery. Please try entering an image URL.'))));
      }
    }
  }

  Future<void> _askUrl() async {
    final tr = AppLocalizations.of(context).t;
    final ctrl = TextEditingController(text: _url);
    final url = await showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('Enter image URL')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: tr('Image')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc), child: Text(tr('Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(dc, ctrl.text.trim()),
              child: Text(tr('OK'))),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      if (mounted)
        setState(() {
          _url = url;
          _b64 = null;
        });
    }
  }

  Future<void> _save() async {
    if (!(_f.currentState?.validate() ?? false)) return;
    final u = User(
        id: widget.user.id,
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        username: name.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        image: _b64 != null
            ? 'b64:$_b64'
            : (_url.isNotEmpty ? _url : widget.user.image),
        token: widget.user.token,
        isAdmin: widget.user.isAdmin);
    await AppSettings.saveProfile(u, forKey: widget.ownerKey);
    if (mounted) Navigator.pop(context, u);
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Edit Profile'))),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: _changePhoto,
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: sch.secondaryContainer,
                      backgroundImage: _preview,
                      child: _preview == null
                          ? const Icon(Icons.person, size: 56)
                          : null,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: sch.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: sch.surface, width: 2),
                      ),
                      child: Icon(Icons.camera_alt,
                          size: 18, color: sch.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _changePhoto,
                child: Text(tr('Change photo')),
              ),
            ),
            const SizedBox(height: 6),
            _field(c, first, tr('First Name'), Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, last, tr('Last Name'), Icons.people_outline,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, name, tr('Username'), Icons.badge_outlined,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, email, tr('Email'), Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v != null && v.contains('@') ? null : ' '),
            _field(c, phone, tr('Phone'), Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(tr('Save')),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
      BuildContext c, TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> setTheme;
  final void Function(Locale) setLocale;
  const SettingsPage(
      {super.key,
      required this.dark,
      required this.setTheme,
      required this.setLocale});
  @override
  State<SettingsPage> createState() => _Settings();
}

class _Settings extends State<SettingsPage> {
  late bool notifications = AppSettings.notifications;
  late bool dark = widget.dark;

  Future<void> _setNotifications(bool v) async {
    setState(() => notifications = v);
    await AppSettings.setNotifications(v);
  }

  void _chooseTheme(BuildContext c) {
    final l = AppLocalizations.of(c);
    showDialog(
      context: c,
      builder: (_) => SimpleDialog(
        title: Text(l.t('Theme')),
        children: [
          ListTile(
            leading: Icon(dark ? Icons.check_circle : Icons.circle_outlined),
            title: Text(l.t('Dark mode')),
            onTap: () {
              Navigator.pop(c);
              widget.setTheme(true);
              setState(() => dark = true);
            },
          ),
          ListTile(
            leading: Icon(!dark ? Icons.check_circle : Icons.circle_outlined),
            title: Text(l.t('Light mode')),
            onTap: () {
              Navigator.pop(c);
              widget.setTheme(false);
              setState(() => dark = false);
            },
          ),
        ],
      ),
    );
  }

  void _chooseLanguage(BuildContext c) {
    final l = AppLocalizations.of(c);
    final current = l.locale.languageCode;
    showDialog(
      context: c,
      builder: (_) => SimpleDialog(
        title: Text(l.t('Language')),
        children: [
          ListTile(
            leading: Icon(
                current == 'en'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: current == 'en' ? const Color(0xFF5B4FE9) : null),
            title: const Text('\u{1F1EC}\u{1F1E7}  English'),
            onTap: () {
              Navigator.pop(c);
              if (current != 'en') widget.setLocale(const Locale('en'));
            },
          ),
          ListTile(
            leading: Icon(
                current == 'km'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: current == 'km' ? const Color(0xFF5B4FE9) : null),
            title: const Text('\u{1F1F0}\u{1F1ED}  ភាសាខ្មែរ'),
            onTap: () {
              Navigator.pop(c);
              if (current != 'km') widget.setLocale(const Locale('km'));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _configureGoogle(BuildContext c, AppLocalizations l) async {
    final serverCtl = TextEditingController(text: AppSettings.googleClientId);
    final androidCtl =
        TextEditingController(text: AppSettings.googleAndroidClientId);
    final saved = await showDialog<bool>(
      context: c,
      builder: (dc) => AlertDialog(
        title: Text(l.t('Enter client IDs')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serverCtl,
              decoration: InputDecoration(
                labelText: l.t('Web client ID'),
                hintText: 'xxx.apps.googleusercontent.com',
                helperText:
                    l.t('Paste your Google Cloud OAuth Web client ID here '
                        '(ends with .apps.googleusercontent.com)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: androidCtl,
              decoration: InputDecoration(
                labelText: l.t('Android client ID (optional)'),
                hintText: 'xxx.apps.googleusercontent.com',
                helperText: l.t('Usually not needed on Android here'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(l.t('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(l.t('Save'))),
        ],
      ),
    );
    if (saved == true) {
      final serverId = serverCtl.text.trim();
      final androidId = androidCtl.text.trim();
      if (serverId != AppSettings.googleClientId) {
        await AppSettings.saveGoogleClientId(serverId);
      }
      if (androidId != AppSettings.googleAndroidClientId) {
        await AppSettings.saveGoogleAndroidClientId(androidId);
      }
      if (c.mounted) {
        ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text(l.t('Google client ID saved'))));
      }
    }
    serverCtl.dispose();
    androidCtl.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('Settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text(l.t('Theme')),
            subtitle: Text(dark ? l.t('Dark mode') : l.t('Light mode')),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () => _chooseTheme(c),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: Text(l.t('Notifications')),
            subtitle: Text(l.t('Receive discount alerts')),
            value: notifications,
            onChanged: _setNotifications,
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.t('Language')),
            subtitle: Text(l.locale.languageCode == 'km'
                ? '\u{1F1F0}\u{1F1ED} ភាសាខ្មែរ'
                : '\u{1F1EC}\u{1F1E7} ${l.t('English')}'),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () => _chooseLanguage(c),
          ),
          ListTile(
            leading: const Icon(Icons.g_mobiledata, color: Colors.blue),
            title: Text(l.t('Google Sign-In')),
            subtitle: Text((AppSettings.googleClientId.isNotEmpty ||
                    AppSettings.googleAndroidClientId.isNotEmpty)
                ? l.t('Configured')
                : l.t('Not configured')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _configureGoogle(c, l),
          ),
          ListTile(
            leading: const Icon(Icons.send, color: Color(0xFF2AABEE)),
            title: Text(l.t('Telegram Sign-In')),
            subtitle: Text(TelegramAuthService.isConfigured
                ? '@${TelegramAuthService.botUsername}'
                : l.t('Not configured')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTelegramSetup(c),
          ),
          const Divider(),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/image.png',
                  height: 28, fit: BoxFit.contain),
            ),
            title: const Text('Global Online'),
            subtitle: const Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatible alias — the full chat experience now lives in
/// [ChatSupportPage] (chat_support_page.dart), which supports text, images,
/// videos and voice messages.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext c) => const ChatSupportPage();
}

/// The shopper's Order History.
///
/// Data is reloaded fresh from the cloud every time the page opens (so the
/// latest admin status is always shown, never stale local data), on
/// pull-to-refresh, and live whenever the admin changes an order's status
/// (Supabase realtime, with a 3s poll as fallback).
class OrderPage extends StatefulWidget {
  /// Username of the account whose history to show (empty = all/local).
  final String owner;
  final OrderPresenter orders;
  const OrderPage({super.key, required this.orders, this.owner = ''});
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  bool _loading = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _reload();
    // Fallback when realtime is unavailable: quietly refetch often enough
    // that a status the admin changed shows up within a few seconds.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _reload());
    // Instant push when the admin updates an order status.
    SupabaseService.instance.watchOrders(onChanged: _reload);
  }

  @override
  void dispose() {
    _poll?.cancel();
    SupabaseService.instance.cancelOrdersWatch();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted || _loading) return;
    _loading = true;
    try {
      await widget.orders.load(owner: widget.owner);
    } catch (_) {
      // Offline — keep showing the last known data.
    }
    if (mounted) setState(() {});
    _loading = false;
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    final orders = widget.orders.orders;
    if (orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Order History'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 70, color: sch.outline),
              const SizedBox(height: 12),
              Text(tr('No orders yet'), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Order History'))),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i];
            return _orderCard(o, tr, sch);
          },
        ),
      ),
    );
  }

  Widget _orderCard(Order o, String Function(String) tr, ColorScheme sch) {
    final statusColor = _statusColor(o.status);
    // 0=Processing 1=Shipped 2=Delivered — 'Cancelled' orders show no bar.
    final step = switch (o.status) {
      'Shipped' => 1,
      'Delivered' => 2,
      _ => 0,
    };
    final cancelled = o.status == 'Cancelled';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sch.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: sch.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${tr('Order')} #${o.id}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(tr(o.status),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(tr('Date') +
                    ': ${o.date.toLocal().toString().split(' ')[0]}'),
              ],
            ),
            const SizedBox(height: 12),
            // ---------------------------------- order progress tracker
            Row(children: [
              _trackDot(step >= 1 && !cancelled, cancelled,
                  Icons.local_shipping_outlined, tr('Shipped'), sch),
              _trackLine(step >= 2 && !cancelled, cancelled, sch),
              _trackDot(step >= 2 && !cancelled, cancelled,
                  Icons.check_circle_outline, tr('Delivered'), sch),
            ]),
            const SizedBox(height: 4),
            if (cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr('Cancelled'),
                    style: TextStyle(
                        fontSize: 12, color: _statusColor('Cancelled'))),
              ),
            const Divider(height: 22),
            Text(tr('Items'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sch.onSurfaceVariant)),
            const SizedBox(height: 8),
            Column(
              children: o.items.map((it) {
                final p = it.product;
                final sub = it.subtotal.toStringAsFixed(2);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(p.thumbnail,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      Text('×${it.quantity}  ',
                          style: TextStyle(color: sch.onSurfaceVariant)),
                      Text('\$$sub',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 10),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(o.deliveryAddress,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(tr('Total'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('\$${o.total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: sch.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One stop of the Shipped → Delivered progress tracker.
  Widget _trackDot(bool reached, bool cancelled, IconData icon, String label,
      ColorScheme sch) {
    final color = cancelled
        ? _statusColor('Cancelled')
        : reached
            ? _statusColor('Delivered')
            : sch.outline;
    return Column(children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  Widget _trackLine(bool reached, bool cancelled, ColorScheme sch) {
    final color = cancelled
        ? _statusColor('Cancelled')
        : reached
            ? _statusColor('Delivered')
            : sch.outlineVariant;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Processing':
        return const Color(0xFFB45309);
      case 'Shipped':
        return const Color(0xFF1D4ED8);
      case 'Delivered':
        return const Color(0xFF15803D);
      case 'Cancelled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF5B4FE9);
    }
  }
}

class FeedbackPage extends StatefulWidget {
  /// The signed-in account (guest accounts send feedback as "Guest").
  final User user;
  const FeedbackPage({super.key, required this.user});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _message = TextEditingController();
  int _rating = 5;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Widget _star(int n, Color color) => IconButton(
        onPressed: () => setState(() => _rating = n),
        icon: Icon(n <= _rating ? Icons.star : Icons.star_border,
            color: n <= _rating ? color : Colors.grey.shade400),
        iconSize: 34,
        visualDensity: VisualDensity.compact,
        tooltip: '$n',
      );

  Future<void> _send() async {
    final tr = AppLocalizations.of(context).t;
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Please enter your message'))));
      return;
    }
    setState(() => _sending = true);
    final ok = await SupabaseService.instance.addFeedback(FeedbackItem(
        id: 0,
        owner: widget.user.username,
        name: widget.user.fullName,
        message: _message.text.trim(),
        rating: _rating));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Thanks for your feedback!'))));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Could not send feedback. Please try again.'))));
    }
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Feedback'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rate_review_outlined,
                    color: Colors.white, size: 30),
                const SizedBox(height: 10),
                Text(tr('Share your feedback'),
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(tr('Help us improve your shopping experience.'),
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('Your rating'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            _star(1, Colors.amber),
            _star(2, Colors.amber),
            _star(3, Colors.amber),
            _star(4, Colors.amber),
            _star(5, Colors.amber),
            const SizedBox(width: 8),
            Text('$_rating/5',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          Text(tr('Your message'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: tr('Write your feedback here...'),
              alignLabelWithHint: true,
              filled: true,
              fillColor: sch.surfaceContainerLow,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5B4FE9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(tr('Submit Feedback')),
          ),
        ],
      ),
    );
  }
}
