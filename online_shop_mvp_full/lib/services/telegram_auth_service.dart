import 'dart:convert';

import '../models/models.dart';
import 'app_settings.dart';

/// Real "Sign in with Telegram" using the official Telegram Login Widget.
///
/// The widget (https://telegram.org/js/telegram-widget.js) is embedded in a
/// local HTML page. When the user authorizes, the bot's OAuth page posts the
/// real account data back to that page, which forwards it to Flutter. No fake
/// user is ever created.
///
/// To make it work you need a Telegram bot: talk to @BotFather → /newbot and
/// put the bot's username below. Real bot usernames MUST end with "bot"
/// (Telegram rule) — a personal username like `Lin_Sreymao` will not work.
class TelegramAuthService {
  static const String defaultBotUsername = 'Lin_Sreymao';

  /// The effective bot username: the one configured in-app (Settings →
  /// Telegram) wins, otherwise the built-in default is used.
  static String get botUsername {
    final custom = AppSettings.telegramBotUsername.trim();
    return custom.isNotEmpty ? custom : defaultBotUsername;
  }

  static bool get isConfigured {
    final u = botUsername;
    return u.isNotEmpty && u != 'YourTelegramBot';
  }

  /// True when the current bot name ends with "bot" as Telegram requires.
  static bool botLooksValid(String username) {
    final u = username.trim().replaceAll('@', '').toLowerCase();
    if (u.isEmpty) return false;
    return u.endsWith('bot');
  }

  static const String _baseUrl = 'https://oauth.telegram.org';

  /// Inline page that renders the Telegram Login button for [botUsername].
  /// On success the widget calls `onAuth(user)` (the bot's OAuth iframe posts
  /// the result to this page via postMessage), which forwards the JSON payload
  /// to the `TelegramLogin` JavaScript channel handled by Flutter.
  static String widgetHtml() {
    final bot = botUsername;
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: #ffffff;
    font-family: -apple-system, Roboto, sans-serif;
  }
  #tip { color: #707579; font-size: 14px; margin-top: 18px; text-align: center; padding: 0 24px; }
  #hint { color: #b0b3b8; font-size: 12px; margin-top: 6px; padding: 0 24px; text-align: center; line-height: 1.5; }
  #err { color: #e53935; font-size: 13px; margin-top: 14px; text-align: center; padding: 0 24px; display: none; }
  #retry { margin-top: 16px; }
  a.btn {
    display: inline-block;
    background: #ffffff;
    border: 1px solid #d5d8dc;
    border-radius: 8px;
    color: #527daa;
    font-size: 14px;
    padding: 8px 18px;
    text-decoration: none;
  }
</style>
</head>
<body>
<script>
  window.onAuth = function (user) {
    try {
      if (typeof window.TelegramLogin !== 'undefined' && user) {
        window.TelegramLogin.postMessage(JSON.stringify(user));
      }
    } catch (e) {}
  };
</script>
<script async src="https://telegram.org/js/telegram-widget.js?22"
        data-telegram-login="$bot"
        data-size="large"
        data-radius="10"
        data-userpic="true"
        data-request-access="write"
        data-onauth="onAuth(user)">
</script>
<p id="tip">${jsonEncode('Loading Telegram login')}…</p>
<p id="hint" style="display:none"></p>
<p id="err" style="display:none"></p>
<p id="retry" style="display:none"><a class="btn" href="javascript:location.reload()">${jsonEncode('Retry')}</a></p>
<script>
  (function () {
    var hint = document.getElementById('hint');
    var err = document.getElementById('err');
    var retry = document.getElementById('retry');
    var tip = document.getElementById('tip');
    var shown = false;
    function show(message, isErr) {
      if (shown) return;
      shown = true;
      tip.style.display = 'none';
      err.style.display = isErr ? 'block' : 'none';
      hint.style.display = 'block';
      hint.textContent = message;
      hint.style.color = isErr ? '#8f8f8f' : '#b0b3b8';
      if (isErr) retry.style.display = 'block';
    }
    setTimeout(function () {
      var loaded = document.querySelector('iframe');
      if (loaded) { tip.style.display = 'none'; return; }
      show('If the button never appears, please check your internet connection and tap Retry.', true);
    }, 9000);
  })();
</script>
</body>
</html>
''';
  }

  /// Builds a [User] from the payload the Telegram Login Widget posts back:
  /// `{id, first_name, last_name, username, photo_url, auth_date, hash}`.
  static User? userFromJson(String json) {
    try {
      final m = jsonDecode(json);
      if (m is! Map<String, dynamic>) return null;
      final id = m['id'];
      final uid = id is num ? id.toInt() : 0;
      final username = m['username']?.toString().trim() ?? '';
      return User(
        id: uid,
        firstName: m['first_name']?.toString() ?? '',
        lastName: m['last_name']?.toString() ?? '',
        username: username.isEmpty ? 'telegram_$uid' : username,
        email: '',
        image: m['photo_url']?.toString(),
        token: m['hash']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static String get baseUrl => _baseUrl;
}