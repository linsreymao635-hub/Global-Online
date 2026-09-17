import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../app_mode.dart';
import 'app_settings.dart';
import 'supabase_service.dart';

class ApiService {
  static const baseUrl = 'https://dummyjson.com';

  /// Shared cloud backend (shoppers + admin see the same data).
  final SupabaseService supa = SupabaseService.instance;
  static const _cacheKey = 'cached_products';
  static const _localCategoriesKey = 'local_categories';
  static const _hiddenCategoriesKey = 'hidden_categories';

  /// Built-in demo administrator account. The admin signs in on the
  /// COMPUTER with PHONE NUMBER + password ("066778213" / "admin123").
  static const adminUsername = 'admin';
  static const adminPassword = 'admin123';
  static const adminPhone = '066778213';

  static String _digitsOf(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// The admin identifier can be the phone number (spaces/dashes/country
  /// code ignored, suffix-matched like the password-reset lookup) or the
  /// classic "admin" username as an alias. The password must always match.
  static bool isAdminLogin(String identifier, String password) {
    if (password != adminPassword) return false;
    final id = identifier.trim().toLowerCase();
    if (id.isEmpty) return false;
    final digits = _digitsOf(id);
    final adminDigits = _digitsOf(adminPhone);
    final byPhone = digits.isNotEmpty &&
        adminDigits.isNotEmpty &&
        (digits == adminDigits ||
            adminDigits.endsWith(digits) ||
            digits.endsWith(adminDigits));
    return byPhone || id == adminUsername;
  }

  /// True on the computer: desktop platforms AND the web build (Chrome),
  /// which runs in a computer browser. Phones run the Android app instead,
  /// so phones never show admin UI and never accept the built-in admin
  /// login.
  ///
  /// The user-only frontend (lib/main_user.dart) forces this off so the
  /// shop app never shows admin UI and never accepts the admin login,
  /// even on a computer.
  static bool get isAdminDevice {
    if (AppRunMode.isUserApp) return false;
    if (kIsWeb) return true; // web build = computer browser (Chrome)
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  List<Product>? _all;
  Future<List<Product>> getProducts() async {
    if (_all != null) return _all!;
    // 1) Shared cloud catalog first — admin edits reach every device.
    final cloud = await supa.products();
    if (cloud.isNotEmpty) {
      _all = cloud;
      return _all!;
    }
    // 2) Offline / empty-cloud fallback: dummyjson + local cache.
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

  Future<User?> login(String u, String p) async {
    // The built-in admin account always wins, so a regular Sign Up can never
    // lock the shop owner out of the Admin panel — but ONLY on the computer.
    // On phones the admin account does not exist at all.
    if (isAdminLogin(u, p)) {
      if (!isAdminDevice) return null; // admin is desktop-only
      // Register the admin in the cloud directory so it shows up in the
      // admin's own Users table. NO password_hash is stored — the built-in
      // desktop check above is the only way in, so the cloud row can never
      // be used to sign in (and never bypasses the phone block).
      supa
          .upsertUser({
            'username': adminUsername,
            'first_name': 'Admin',
            'last_name': '',
            'email': 'admin@globalonline.demo',
            'phone': adminPhone,
            'image': '',
            'provider': 'local',
            'is_admin': true,
          })
          .catchError((_) => false);
      return User(
          id: 0,
          firstName: 'Admin',
          lastName: '',
          username: adminUsername,
          email: 'admin@globalonline.demo',
          phone: adminPhone,
          image: null,
          token: 'admin-demo-token',
          isAdmin: true);
    }
    // Cloud accounts (Supabase `app_users`): shared across ALL devices, so
    // an account created on the phone can sign in on the tablet too.
    final key = u.trim().toLowerCase();
    final cloud = await supa.userByUsername(key);
    if (cloud != null) {
      final stored = cloud['password_hash'] as String? ?? '';
      // Empty hash = social-login-only account (Google/Telegram): it can only
      // sign in through its provider, never with a typed password.
      if (stored.isNotEmpty && stored == SupabaseService.hashPassword(p)) {
        return User.fromSupabase(cloud);
      }
      return null; // wrong password, or passwordless cloud account
    }
    // Local device accounts kept as a fallback (offline signups, tests).
    final local = AppSettings.localAuth[key];
    if (local != null) {
      if (local['password'] == p) {
        // Mirror the account into the cloud so other devices can see it.
        await supa.upsertUser({
          'username': key,
          'first_name': local['firstName'] as String? ?? '',
          'last_name': local['lastName'] as String? ?? '',
          'email': (local['email'] as String? ?? '').toLowerCase(),
          'phone': local['phone'] as String? ?? '',
          'image': local['image'] as String? ?? '',
          'provider': 'local',
          'is_admin': false,
          'password_hash': SupabaseService.hashPassword(p),
        });
        return User(
            id: (local['id'] as num?)?.toInt() ?? 0,
            firstName: local['firstName'] as String? ?? '',
            lastName: local['lastName'] as String? ?? '',
            username: u.trim(),
            email: local['email'] as String? ?? '',
            phone: local['phone'] as String? ?? '',
            image: local['image'] as String?,
            token: local['token'] as String?);
      }
      // Password was changed on this device: the old one is no longer valid.
      return null;
    }
    final r = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p}));
    if (r.statusCode != 200) return null;
    final apiUser = User.fromJson(jsonDecode(r.body));
    // Mirror successful dummyjson logins into the cloud directory too.
    await supa.upsertUser({
      'username': apiUser.username.trim().toLowerCase(),
      'first_name': apiUser.firstName,
      'last_name': apiUser.lastName,
      'email': apiUser.email.toLowerCase(),
      'phone': apiUser.phone,
      'image': apiUser.image ?? '',
      'provider': 'local',
      'is_admin': false,
    });
    return apiUser;
  }

  Future<User?> signup(String f, String l, String u, String p, String e,
      String ph) async {
    // Store the account in the shared cloud directory so it works on every
    // device. Passwords are hashed (SHA-256 + salt), never sent as plain text.
    final uname = u.trim().toLowerCase();
    final inserted = await supa.upsertUser({
      'username': uname,
      'first_name': f,
      'last_name': l,
      'email': e.trim().toLowerCase(),
      'phone': ph,
      'image': '',
      'provider': 'local',
      'is_admin': false,
      'password_hash': SupabaseService.hashPassword(p),
    });
    // ALSO keep the device copy (offline fallback + existing tests).
    await AppSettings.saveLocalAccount(
        username: uname,
        password: p,
        firstName: f,
        lastName: l,
        email: e,
        phone: ph);
    if (!inserted) return null; // cloud down → old dummyjson path
    return User(
        id: 0,
        firstName: f,
        lastName: l,
        username: uname,
        email: e,
        phone: ph);
  }

  void _ok(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception('API error ${r.statusCode}');
  }

  // ---------------------------------------------------------------------
  // Admin management. dummyjson is a demo read-only API, so every change
  // the admin makes is applied to the SAME on-device catalog the shoppers
  // see (getProducts/search/category) and persisted in the local cache.
  // ---------------------------------------------------------------------

  Future<void> _persistProducts() async {
    if (_all == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey, jsonEncode(_all!.map((e) => {
              'id': e.id,
              'title': e.title,
              'price': e.price,
              'discountPercentage': e.discountPercentage,
              'rating': e.rating,
              'stock': e.stock,
              'brand': e.brand,
              'category': e.category,
              'description': e.description,
              'thumbnail': e.thumbnail,
              'images': e.images,
            }).toList()));
  }

  /// Add a product created by the admin. First written to the shared cloud
  /// catalog; locally-created products get a negative id so they never clash
  /// with catalog ids when offline.
  Future<void> addProduct(Product p) async {
    final ok = await supa.addProduct(p);
    if (ok) {
      _all = null; // re-fetch the shared catalog next time
      return;
    }
    // Offline fallback: device-local only.
    final all = await getProducts();
    var nextLocal = -1;
    for (final x in all) {
      if (x.id < 0 && x.id < nextLocal) nextLocal = x.id - 1;
    }
    final copy = Product(
        id: p.id < 0 ? p.id : nextLocal,
        title: p.title,
        price: p.price,
        discountPercentage: p.discountPercentage,
        rating: p.rating,
        stock: p.stock,
        brand: p.brand,
        category: p.category,
        description: p.description,
        thumbnail: p.thumbnail,
        images: p.images);
    all.insert(0, copy);
    await _persistProducts();
  }

  Future<void> updateProduct(Product p) async {
    final ok = await supa.updateProduct(p);
    if (ok) {
      _all = null; // re-fetch the shared catalog next time
      return;
    }
    final all = await getProducts();
    final i = all.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    all[i] = p;
    await _persistProducts();
  }

  Future<void> deleteProduct(int id) async {
    final ok = await supa.deleteProduct(id);
    if (ok) {
      _all = null;
      return;
    }
    if (_all == null) await getProducts();
    if (_all == null) return;
    _all!.removeWhere((x) => x.id == id);
    await _persistProducts();
  }

  Future<List<Category>> categories() async {
    final p = await SharedPreferences.getInstance();

    List<Category> local() {
      final raw = p.getString(_localCategoriesKey);
      if (raw == null) return [];
      try {
        return (jsonDecode(raw) as List)
            .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {
        return [];
      }
    }

    final hidden =
        (p.getStringList(_hiddenCategoriesKey) ?? const []).toSet();

    // Local categories added/edited by the admin lead the list (they win the
    // slug-dedupe below), then the source categories — every overwritten or
    // hidden slug is filtered out. Applied on top of the cloud list so edits
    // (including offline/local fallbacks) are always visible.
    List<Category> merge(List<Category> source) {
      final merged = [
        ...local().where((c) => !hidden.contains(c.slug)),
        ...source.where((c) => !hidden.contains(c.slug)),
      ];
      final seen = <String>{};
      return merged.where((c) => seen.add(c.slug)).toList();
    }

    // Shared cloud categories first (admin-managed, visible to everyone).
    final cloud = await supa.categories();
    if (cloud.isNotEmpty) return merge(cloud);

    final r = await http.get(Uri.parse('$baseUrl/products/categories'));
    _ok(r);
    final list = (jsonDecode(r.body) as List)
        .map((e) => Category.fromJson(e))
        .toList();

    return merge(list);
  }

  /// Same slug rules used everywhere when saving a category, exposed so the
  /// admin UI can show the final slug instantly after an edit.
  static String slugify(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

  String _slugify(String s) => ApiService.slugify(s);

  Future<void> addCategory(String name,
      {String slug = '',
      String description = '',
      String image = ''}) async {
    final label = name.trim();
    if (label.isEmpty) return;
    // Shared cloud first so every device sees the new category.
    if (await supa.addCategory(label,
        slug: slug, description: description, image: image)) {
      return;
    }
    final fromName = _slugify(label);
    final safeSlug =
        _slugify(slug.trim()).isEmpty ? fromName : _slugify(slug.trim());
    final finalSlug = safeSlug.isEmpty ? 'custom' : safeSlug;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_localCategoriesKey);
    final list = <Category>[];
    if (raw != null) {
      try {
        list.addAll((jsonDecode(raw) as List)
            .map((e) =>
                Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList());
      } catch (_) {}
    }
    final all = await categories();
    if (all.any((c) => c.slug == finalSlug)) return;
    list.add(Category(
        slug: finalSlug,
        name: label,
        url: '$baseUrl/products/category/$finalSlug',
        description: description.trim(),
        image: image.trim()));
    await p.setString(
        _localCategoriesKey,
        jsonEncode(list.map((c) => {
              'slug': c.slug,
              'name': c.name,
              'url': c.url,
              'description': c.description,
              'image': c.image,
            }).toList()));
  }

  /// Edit a category everywhere: Supabase rows are updated for every device;
  /// categories kept locally are replaced; read-only catalog categories are
  /// hidden and replaced by the edited copy.
  Future<void> updateCategory(Category original,
      {required String name,
      required String slug,
      String description = '',
      String image = ''}) async {
    // Cloud categories are edited for everyone.
    if (await supa.updateCategory(original.slug,
        name: name, newSlug: slug, description: description, image: image)) {
      return;
    }
    final fromName = _slugify(name);
    final safeSlug =
        _slugify(slug.trim()).isEmpty ? fromName : _slugify(slug.trim());
    final finalSlug = safeSlug.isEmpty ? 'custom' : safeSlug;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_localCategoriesKey);
    final local = <Category>[];
    if (raw != null) {
      try {
        local.addAll((jsonDecode(raw) as List)
            .map((e) =>
                Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList());
      } catch (_) {}
    }
    final updated = Category(
        slug: finalSlug,
        name: name.trim(),
        url: '$baseUrl/products/category/$finalSlug',
        description: description.trim(),
        image: image.trim());
    final idx = local.indexWhere((x) => x.slug == original.slug);
    if (idx >= 0) {
      // A category the admin created on this device: replace it in place.
      local[idx] = updated;
    } else {
      // A catalog (dummyjson) category: keep the edited copy locally so it
      // wins in the merged list. Replace any previous local copy of the
      // same slug so repeated edits keep saving.
      final localIdx = local.indexWhere((x) => x.slug == finalSlug);
      if (localIdx >= 0) {
        local[localIdx] = updated;
      } else {
        local.add(updated);
      }
      // Hide the original slug ONLY when it actually changed — hiding the
      // copy itself (same slug) used to make a simple rename (e.g.
      // Laptops -> Latop with the slug untouched) delete the category.
      if (finalSlug != original.slug) {
        final hidden =
            (p.getStringList(_hiddenCategoriesKey) ?? const []).toList();
        if (!hidden.contains(original.slug)) hidden.add(original.slug);
        await p.setStringList(
            _hiddenCategoriesKey, hidden.toSet().toList());
      }
    }
    await p.setString(
        _localCategoriesKey,
        jsonEncode(local.map((c) => {
              'slug': c.slug,
              'name': c.name,
              'url': c.url,
              'description': c.description,
              'image': c.image,
            }).toList()));
  }

  Future<void> deleteCategory(Category c) async {
    // Cloud categories are deleted for everyone.
    if (await supa.deleteCategory(c.slug)) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_localCategoriesKey);
    final local = <Category>[];
    if (raw != null) {
      try {
        local.addAll((jsonDecode(raw) as List)
            .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
            .toList());
      } catch (_) {}
    }
    final kept = local.where((x) => x.slug != c.slug).toList();
    if (kept.length != local.length) {
      // A category the admin created on this device: remove it for real. Also
      // eat it from the hidden list in case it was hiding a duplicate.
      await p.setString(
          _localCategoriesKey,
          jsonEncode(kept
              .map((x) => {
                    'slug': x.slug,
                    'name': x.name,
                    'url': x.url,
                    'description': x.description,
                    'image': x.image,
                  })
              .toList()));
      return;
    }
    // A catalog (dummyjson) category: hide it locally so it disappears from
    // the Categories screen across the whole app.
    final hidden = (p.getStringList(_hiddenCategoriesKey) ?? const []).toList();
    hidden.add(c.slug);
    await p.setStringList(_hiddenCategoriesKey, hidden.toSet().toList());
  }
}
