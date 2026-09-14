import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const baseUrl = 'https://dummyjson.com';
  static const _cacheKey = 'cached_products';
  List<Product>? _all;
  Future<List<Product>> getProducts() async {
    if (_all != null) return _all!;
    final p = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse('$baseUrl/products?limit=200'));
      _ok(r);
      final j = jsonDecode(r.body);
      _all = (j['products'] as List).map((e) => Product.fromJson(e)).toList();
      await p.setString(_cacheKey, jsonEncode(j['products']));
      return _all!;
    } catch (e) {
      final c = p.getString(_cacheKey);
      if (c != null) {
        _all = (jsonDecode(c) as List).map((e) => Product.fromJson(e)).toList();
        return _all!;
      }
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String q) async {
    String strip(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final n = strip(q);
    if (n.isEmpty) return getProducts();
    final all = await getProducts();
    return all
        .where((p) =>
            strip(p.title).contains(n) ||
            strip(p.category).contains(n) ||
            strip(p.brand).contains(n))
        .toList();
  }

  Future<List<Product>> category(String slug) async {
    final r = await http.get(Uri.parse('$baseUrl/products/category/$slug'));
    _ok(r);
    final j = jsonDecode(r.body);
    return (j['products'] as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Category>> categories() async {
    final r = await http.get(Uri.parse('$baseUrl/products/categories'));
    _ok(r);
    return (jsonDecode(r.body) as List)
        .map((e) => Category.fromJson(e))
        .toList();
  }

  Future<User?> login(String u, String p) async {
    final r = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p}));
    if (r.statusCode != 200) return null;
    return User.fromJson(jsonDecode(r.body));
  }

  Future<User?> signup(String f, String l, String u, String p, String e) async {
    final r = await http.post(Uri.parse('$baseUrl/users/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': f,
          'lastName': l,
          'username': u,
          'password': p,
          'email': e
        }));
    if (r.statusCode != 200 && r.statusCode != 201) return null;
    return User.fromJson(jsonDecode(r.body));
  }

  void _ok(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception('API error ${r.statusCode}');
  }
}
