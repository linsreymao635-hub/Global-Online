import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_shop_mvp_full/models/models.dart';
import 'package:online_shop_mvp_full/services/telegram_auth_service.dart';

void main() {
  test('telegram auth parses real widget payload', () {
    final u = TelegramAuthService.userFromJson(
        '{"id":1234,"first_name":"Sok","last_name":"Heng","username":"sokheng","photo_url":"https://x/p.jpg","auth_date":1700000000,"hash":"abc"}');
    expect(u, isNotNull);
    expect(u!, isA<User>());
    expect(u.firstName, 'Sok');
    expect(u.lastName, 'Heng');
    expect(u.username, 'sokheng');
    expect(u.email, '');
    expect(u.image, 'https://x/p.jpg');
    expect(u.token, 'abc');
  });
  test('telegram auth falls back when username is empty', () {
    final u = TelegramAuthService.userFromJson('{"id":99,"first_name":"A"}');
    expect(u!.username, 'telegram_99');
  });
  test('telegram auth invalid json returns null', () {
    expect(TelegramAuthService.userFromJson('nope'), isNull);
  });

  test('telegram auth decodes tgAuthResult redirect payload', () {
    // Same payload as above, base64url-encoded (no padding needed here).
    const payload =
        '{"id":777,"first_name":"Mao","last_name":"Lin","username":"linmao",'
        '"photo_url":"https://t.me/i.jpg","auth_date":1700000001,"hash":"f00d"}';
    final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
    final u = TelegramAuthService.userFromTgAuthResult('#tgAuthResult=$encoded');
    expect(u, isNotNull);
    expect(u!.id, 777);
    expect(u.firstName, 'Mao');
    expect(u.lastName, 'Lin');
    expect(u.username, 'linmao');
    expect(u.image, 'https://t.me/i.jpg');
    expect(u.token, 'f00d');
  });

  test('telegram auth tgAuthResult tolerates padding and query form', () {
    const payload = '{"id":5,"first_name":"A"}';
    final encoded = base64Url.encode(utf8.encode(payload));
    // Query-style fragment (no leading #) with padding kept.
    final u = TelegramAuthService.userFromTgAuthResult('tgAuthResult=$encoded');
    expect(u, isNotNull);
    expect(u!.username, 'telegram_5');
  });

  test('telegram auth tgAuthResult junk returns null', () {
    expect(TelegramAuthService.userFromTgAuthResult('#tgAuthResult=!!!'), isNull);
    expect(TelegramAuthService.userFromTgAuthResult('#other=1'), isNull);
  });
}