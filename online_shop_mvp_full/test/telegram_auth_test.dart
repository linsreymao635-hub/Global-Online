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
}