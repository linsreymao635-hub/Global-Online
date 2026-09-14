import 'package:flutter_test/flutter_test.dart';
import 'package:online_shop_mvp_full/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('search returns only the matching product', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService();
    final c = await api.searchProducts('Cucumber');
    expect(c.length, 1);
    expect(c.first.title, 'Cucumber');
    final d = await api.searchProducts('Dog Food');
    expect(d.length, 1);
    expect(d.first.title, 'Dog Food');
    final empty = await api.searchProducts('zzzzzz');
    expect(empty, isEmpty);
    final cat = await api.searchProducts('groceries');
    expect(cat, isNotEmpty);
    expect(cat.every((p) => p.category == 'groceries'), isTrue);
  });
}