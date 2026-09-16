import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_shop_mvp_full/services/app_settings.dart';
import 'package:online_shop_mvp_full/services/api_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSettings.localAuth = {};
    await AppSettings.load();
  });

  test('signup account can sign in with its password', () async {
    await AppSettings.saveLocalAccount(
        username: 'JohnDoe',
        password: 'abc123',
        firstName: 'John',
        lastName: 'Doe',
        phone: '012345678');
    final api = ApiService();
    final u = await api.login('johndoe', 'abc123');
    expect(u, isNotNull);
    expect(u!.username, 'johndoe');
    expect(u.firstName, 'John');
  });

  test('wrong password is rejected for local accounts', () async {
    await AppSettings.saveLocalAccount(
        username: 'jane', password: 'secret1', phone: '098765432');
    final api = ApiService();
    expect(await api.login('jane', 'wrongpass'), isNull);
  });

  test('reset password changes the accepted password', () async {
    await AppSettings.saveLocalAccount(
        username: 'emilys', password: 'oldpass', phone: '011223344');
    await AppSettings.setLocalPassword('emilys', 'newpass1');
    final api = ApiService();
    expect(await api.login('emilys', 'oldpass'), isNull);
    final u = await api.login('emilys', 'newpass1');
    expect(u, isNotNull);
  });

  test('find username by phone number ignores formatting', () async {
    await AppSettings.saveLocalAccount(
        username: 'sam', password: 'pass123', phone: '+855 (012) 345-678');
    expect(AppSettings.findUsernameByPhone('012 345 678'), 'sam');
    expect(AppSettings.findUsernameByPhone('999'), isNull);
  });
}
