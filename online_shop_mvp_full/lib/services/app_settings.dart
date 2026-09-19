import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AppSettings {
  static const _notificationsKey = 'notifications_enabled';
  static bool _notifications = true;
  static bool get notifications => _notifications;
  static bool get notificationsOff => !_notifications;
  static const _sessionKey = 'session_user';
  static User? restoredUser;

  /// True when the restored/signed-in account was confirmed to exist in the
  /// shared cloud directory (`app_users`). Set at login/signup when the cloud
  /// read or write succeeded. Only cloud-verified sessions can be
  /// auto-logged-out when the admin deletes the account — a device-local
  /// account (created offline, never mirrored) has no cloud row to check, so
  /// it must never be treated as "deleted".
  static const _sessionCloudKey = 'session_cloud_ok';
  static bool sessionCloudOk = false;
  static const _addressKey = 'saved_address';

  /// Delivery addresses stored PER ACCOUNT (keyed by [profileKeyOf]) so one
  /// login doesn't show another account's address card.
  static Map<String, Address> _addresses = {};

  /// The signed-in user's saved delivery address.
  static Address? get savedAddress => savedAddressFor(restoredUser);

  static Address? savedAddressFor(User? u) {
    if (u == null) return _addresses['anon'];
    return _addresses[profileKeyOf(u)] ?? _addresses['anon'];
  }

  /// Local credentials for accounts created/edited on this device.
  /// The demo API cannot persist passwords, so signups and password
  /// resets are stored here and checked first at login.
  static const _authKey = 'local_auth';
  static Map<String, Map<String, dynamic>> localAuth = {};

  static const _pf = 'profile_';

  /// Profile edits (name / username / email / photo) stored PER ACCOUNT in
  /// one JSON map keyed by [profileKeyOf]. Previously they lived in a single
  /// global spot, so after signing in with a different account (e.g. Google)
  /// the profile page still showed the previous account's data.
  static Map<String, Map<String, String>> _profiles = {};

  static const _googleClientIdKey = 'google_client_id';
  static String _googleClientId = '';

  /// Google OAuth web client ID entered in-app (takes priority over the
  /// hard-coded [GoogleAuthService] constants).
  static String get googleClientId => _googleClientId;
  static bool get googleConfigured => _googleClientId.trim().isNotEmpty;

  static const _googleAndroidClientIdKey = 'google_android_client_id';
  static String _googleAndroidClientId = '';

  /// Google OAuth Android client ID (registered with the app's package name +
  /// its SHA-1 fingerprint). Needed on Android so the account picker can
  /// actually grant a token after you select your Google account.
  static String get googleAndroidClientId => _googleAndroidClientId;
  static bool get googleAndroidConfigured =>
      _googleAndroidClientId.trim().isNotEmpty;

  static const _telegramBotKey = 'telegram_bot_username';
  static const _feedbackKey = 'offboarding_feedback';
  static String _telegramBot = '';

  /// Telegram bot username used by the Login Widget (takes priority over the
  /// default in [TelegramAuthService]). Real bot names must end with "bot".
  static String get telegramBotUsername => _telegramBot;
  static bool get telegramConfigured => _telegramBot.trim().isNotEmpty;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _notifications = p.getBool(_notificationsKey) ?? true;
    _storeName = p.getString(_storeNameKey) ?? 'Global Online';
    _storeEmail = p.getString(_storeEmailKey) ?? '';
    _storePhone = p.getString(_storePhoneKey) ?? '';
    _storeAddress = p.getString(_storeAddressKey) ?? '';
    _currency = p.getString(_currencyKey) ?? '\$';
    _taxRate = double.tryParse(p.getString(_taxRateKey) ?? '') ?? 0;
    _shippingFee = double.tryParse(p.getString(_shippingFeeKey) ?? '') ?? 0;
    _autoCancelOrders = p.getBool(_autoCancelKey) ?? false;
    _autoCancelDays = int.tryParse(p.getString(_autoCancelDaysKey) ?? '') ?? 7;
    _emailNotifications = p.getBool(_emailNotificationsKey) ?? true;
    _newOrderNotifications = p.getBool(_newOrderNotificationsKey) ?? true;
    _language = p.getString(_languageKey) ?? 'en';
    _googleClientId = p.getString(_googleClientIdKey) ?? '';
    _googleAndroidClientId = p.getString(_googleAndroidClientIdKey) ?? '';
    _telegramBot = p.getString(_telegramBotKey) ?? '';
    _loadProfiles(p);
    final s = p.getString(_sessionKey);
    if (s != null) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        restoredUser = User(
            id: m['id'] ?? 0,
            firstName: m['firstName'] ?? '',
            lastName: m['lastName'] ?? '',
            username: m['username'] ?? '',
            email: m['email'] ?? '',
            phone: m['phone'] ?? '',
            image: m['image'],
            token: m['token'],
            isAdmin: m['isAdmin'] == true || m['isAdmin'] == 'true');
      } catch (_) {
        restoredUser = null;
      }
    }
    final la = p.getString(_authKey);
    sessionCloudOk = p.getBool(_sessionCloudKey) ?? false;
    if (la != null) {
      try {
        final m = jsonDecode(la) as Map<String, dynamic>;
        localAuth = m.map((k, v) =>
            MapEntry(k.toLowerCase(), Map<String, dynamic>.from(v as Map)));
      } catch (_) {
        localAuth = {};
      }
    } else {
      localAuth = {};
    }
    _loadAddresses(p);
  }

  /// Decode the per-account address map, migrating the old single-address
  /// storage (`saved_address` JSON) to the signed-in (or 'anon') account.
  static void _loadAddresses(SharedPreferences p) {
    final raw = p.getString('${_addressKey}es_map');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _addresses = m.map((k, v) {
          final a = (v as Map).cast<String, dynamic>();
          return MapEntry(
              k,
              Address(
                  fullName: a['fullName'] ?? '',
                  phone: a['phone'] ?? '',
                  address: a['address'] ?? '',
                  city: a['city'] ?? '',
                  country: a['country'] ?? '',
                  latitude: (a['latitude'] as num?)?.toDouble(),
                  longitude: (a['longitude'] as num?)?.toDouble()));
        });
        return;
      } catch (_) {
        _addresses = {};
      }
    }
    final ad = p.getString(_addressKey);
    if (ad == null) return;
    try {
      final m = jsonDecode(ad) as Map<String, dynamic>;
      final a = Address(
          fullName: m['fullName'] ?? '',
          phone: m['phone'] ?? '',
          address: m['address'] ?? '',
          city: m['city'] ?? '',
          country: m['country'] ?? '',
          latitude: (m['latitude'] as num?)?.toDouble(),
          longitude: (m['longitude'] as num?)?.toDouble());
      // Belongs to whichever account is (or was last) signed in; guest if none.
      _addresses[restoredUser != null ? profileKeyOf(restoredUser!) : 'anon'] = a;
      awaitFuture(p.remove(_addressKey));
    } catch (_) {}
  }

  static Future<void> awaitFuture(Future<dynamic> f) => f.then((_) {});

  static Future<void> setNotifications(bool v) async {
    _notifications = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notificationsKey, v);
  }

  // ------------------------------------------------------- admin store settings

  static const _storeNameKey = 'admin_store_name';
  static String _storeName = 'Global Online';
  static const _storeEmailKey = 'admin_store_email';
  static String _storeEmail = '';
  static const _storePhoneKey = 'admin_store_phone';
  static String _storePhone = '';
  static const _storeAddressKey = 'admin_store_address';
  static String _storeAddress = '';
  static const _currencyKey = 'admin_currency';
  static String _currency = '\$';
  static const _taxRateKey = 'admin_tax_rate';
  static double _taxRate = 0;
  static const _shippingFeeKey = 'admin_shipping_fee';
  static double _shippingFee = 0;
  static const _autoCancelKey = 'admin_auto_cancel_orders';
  static bool _autoCancelOrders = false;
  static const _autoCancelDaysKey = 'admin_auto_cancel_days';
  static int _autoCancelDays = 7;
  static const _emailNotificationsKey = 'admin_email_notifications';
  static bool _emailNotifications = true;
  static const _newOrderNotificationsKey = 'admin_new_order_notifications';
  static bool _newOrderNotifications = true;
  static const _languageKey = 'admin_language';
  static String _language = 'en';

  static String get storeName => _storeName;
  static String get storeEmail => _storeEmail;
  static String get storePhone => _storePhone;
  static String get storeAddress => _storeAddress;
  static String get currency => _currency;
  static double get taxRate => _taxRate;
  static double get shippingFee => _shippingFee;
  static bool get autoCancelOrders => _autoCancelOrders;
  static int get autoCancelDays => _autoCancelDays;
  static bool get emailNotifications => _emailNotifications;
  static bool get newOrderNotifications => _newOrderNotifications;
  static String get language => _language;

  static Future<void> saveStoreName(String v) async {
    _storeName = v.trim().isEmpty ? 'Global Online' : v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_storeNameKey, _storeName);
  }

  static Future<void> saveStoreEmail(String v) async {
    _storeEmail = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_storeEmailKey, _storeEmail);
  }

  static Future<void> saveStorePhone(String v) async {
    _storePhone = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_storePhoneKey, _storePhone);
  }

  static Future<void> saveStoreAddress(String v) async {
    _storeAddress = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_storeAddressKey, _storeAddress);
  }

  static Future<void> saveCurrency(String v) async {
    _currency = v.trim().isEmpty ? '\$' : v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_currencyKey, _currency);
  }

  static Future<void> saveTaxRate(double v) async {
    _taxRate = v < 0 ? 0 : v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_taxRateKey, _taxRate.toString());
  }

  static Future<void> saveShippingFee(double v) async {
    _shippingFee = v < 0 ? 0 : v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_shippingFeeKey, _shippingFee.toString());
  }

  static Future<void> saveAutoCancel(bool on, int days) async {
    _autoCancelOrders = on;
    _autoCancelDays = days < 1 ? 7 : days;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoCancelKey, _autoCancelOrders);
    await p.setString(_autoCancelDaysKey, _autoCancelDays.toString());
  }

  static Future<void> saveEmailNotifications(bool v) async {
    _emailNotifications = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_emailNotificationsKey, v);
  }

  static Future<void> saveNewOrderNotifications(bool v) async {
    _newOrderNotifications = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_newOrderNotificationsKey, v);
  }

  static Future<void> saveLanguage(String v) async {
    _language = v == 'km' ? 'km' : 'en';
    final p = await SharedPreferences.getInstance();
    await p.setString(_languageKey, _language);
  }

  // ------------------------------------------------------------ activity log

  static const _activityKey = 'admin_activity_log';

  /// The most recent admin actions, newest first, persisted on this device
  /// (in 3.100 the list source fields are carried as static const keys).
  static Future<List<String>> loadActivityLog() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_activityKey) ?? [];
  }

  /// Append one admin action and keep only the newest 50 entries.
  static Future<void> logAdminActivity(String entry) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_activityKey) ?? <String>[];
    list.insert(0, '[${DateTime.now().toLocal().toString().substring(0, 16)}] $entry');
    if (list.length > 50) list.length = 50;
    await p.setStringList(_activityKey, list);
  }

  static Future<void> saveSession(User u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _sessionKey,
        jsonEncode({
          'id': u.id,
          'firstName': u.firstName,
          'lastName': u.lastName,
          'username': u.username,
          'email': u.email,
          'phone': u.phone,
          'image': u.image,
          'token': u.token,
          'isAdmin': u.isAdmin,
        }));
  }

  /// Record whether the current session's account exists in the cloud
  /// directory. In-memory first so callers that do not await it still see
  /// the new value immediately.
  static Future<void> markSessionCloudOk(bool ok) async {
    sessionCloudOk = ok;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_sessionCloudKey, ok);
  }

  static Future<void> clearSession() async {
    restoredUser = null;
    sessionCloudOk = false;
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
    await p.remove(_sessionCloudKey);
  }

  /// Key identifying the account a saved profile belongs to.
  static String profileKeyOf(User u) {
    final email = u.email.trim().toLowerCase();
    if (email.isNotEmpty) return 'email:$email';
    final username = u.username.trim().toLowerCase();
    return username.isNotEmpty ? 'user:$username' : 'anon';
  }

  /// Decode the per-account profile map, migrating the pre-account layout
  /// (flat `profile_firstName`… keys) so old edits are not lost.
  static void _loadProfiles(SharedPreferences p) {
    final raw = p.getString('${_pf}map');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _profiles = m.map((k, v) => MapEntry(
            k, (v as Map).map((kk, vv) => MapEntry(kk.toString(), vv.toString()))));
        return;
      } catch (_) {
        _profiles = {};
      }
    }
    // Legacy single-account data: attach it to the account the profile
    // itself describes (its email/username). If it belonged to the currently
    // restored session both keys are identical anyway; if it belonged to an
    // older account (the "profile shows another login's data" bug), the new
    // login correctly starts from its own Google/API data instead.
    final username = p.getString('${_pf}username');
    if (username == null) return; // nothing saved before
    final legacy = User(
        id: 0,
        firstName: p.getString('${_pf}firstName') ?? '',
        lastName: p.getString('${_pf}lastName') ?? '',
        username: username,
        email: p.getString('${_pf}email') ?? '',
        image: p.getString('${_pf}image'));
    final owner = profileKeyOf(legacy);
    _profiles[owner] = {
      'firstName': legacy.firstName,
      'lastName': legacy.lastName,
      'username': legacy.username,
      'email': legacy.email,
      'image': legacy.image ?? '',
    };
    p.setString('${_pf}map', jsonEncode(_profiles));
    for (final k in [
      'firstName', 'lastName', 'username', 'email', 'image'
    ]) {
      p.remove('$_pf$k');
    }
  }

  static User? get savedProfile =>
      savedProfileFor(restoredUser != null ? profileKeyOf(restoredUser!) : '');

  /// The saved profile edits for the account with this key, or `null` when
  /// that account has never edited its profile on this device.
  static User? savedProfileFor(String key) {
    final m = _profiles[key];
    if (m == null || (m['username'] ?? '').isEmpty) return null;
    return User(
        id: 0,
        firstName: m['firstName'] ?? '',
        lastName: m['lastName'] ?? '',
        username: m['username']!,
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        image: (m['image'] ?? '').isEmpty ? null : m['image']);
  }

  /// Persist the delivery address for the current account.
  static Future<void> saveAddress(Address a) async {
    final key = restoredUser != null ? profileKeyOf(restoredUser!) : 'anon';
    _addresses[key] = a;
    final p = await SharedPreferences.getInstance();
    await p.setString('${_addressKey}es_map', jsonEncode(
        _addresses.map((k, v) => MapEntry(k, {
              'fullName': v.fullName,
              'phone': v.phone,
              'address': v.address,
              'city': v.city,
              'country': v.country,
              'latitude': v.latitude,
              'longitude': v.longitude,
            }))));
  }

  /// Store (or replace) the password of a local account.
  static Future<void> setLocalPassword(String username, String password) async {
    final key = username.trim().toLowerCase();
    final entry = Map<String, dynamic>.from(localAuth[key] ?? {});
    entry['password'] = password;
    localAuth[key] = entry;
    final p = await SharedPreferences.getInstance();
    await p.setString(_authKey, jsonEncode(localAuth));
  }

  /// Remember a locally created account (Sign Up) so it can sign in.
  static Future<void> saveLocalAccount(
      {required String username,
      required String password,
      String firstName = '',
      String lastName = '',
      String email = '',
      String phone = ''}) async {
    final key = username.trim().toLowerCase();
    localAuth[key] = {
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(_authKey, jsonEncode(localAuth));
  }

  /// Remove a locally stored account (used by Delete Account).
  static Future<void> removeLocalAccount(String username) async {
    final key = username.trim().toLowerCase();
    localAuth.remove(key);
    final p = await SharedPreferences.getInstance();
    await p.setString(_authKey, jsonEncode(localAuth));
  }

  /// Remove the saved profile edits for the account with this key
  /// (used by Delete Account).
  static Future<void> removeProfile(String key) async {
    _profiles.remove(key);
    final p = await SharedPreferences.getInstance();
    await p.setString('${_pf}map', jsonEncode(_profiles));
  }

  /// Forget the saved delivery address of the current account
  /// (used by Delete Account).
  static Future<void> clearAddress() async {
    final key = restoredUser != null ? profileKeyOf(restoredUser!) : 'anon';
    _addresses.remove(key);
    final p = await SharedPreferences.getInstance();
    await p.setString('${_addressKey}es_map', jsonEncode(
        _addresses.map((k, v) => MapEntry(k, {
              'fullName': v.fullName,
              'phone': v.phone,
              'address': v.address,
              'city': v.city,
              'country': v.country,
              'latitude': v.latitude,
              'longitude': v.longitude,
            }))));
  }

  /// Find the username of the local account registered with this phone.
  /// Ignores formatting and matches numbers stored with/without a country
  /// code by comparing digits as suffixes of each other.
  static String? findUsernameByPhone(String phone) {
    String digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    final q = digits(phone);
    if (q.isEmpty) return null;
    for (final entry in localAuth.entries) {
      final v = digits(entry.value['phone']?.toString() ?? '');
      if (v.isEmpty) continue;
      if (v == q || v.endsWith(q) || q.endsWith(v)) return entry.key;
    }
    return null;
  }

  /// Persist profile edits for account [forKey] (see [profileKeyOf]).
  static Future<void> saveProfile(User u, {String? forKey}) async {
    final key = (forKey != null && forKey.isNotEmpty)
        ? forKey
        : profileKeyOf(u);
    _profiles[key] = {
'firstName': u.firstName,
        'lastName': u.lastName,
        'username': u.username,
        'email': u.email,
        'phone': u.phone,
        'image': u.image ?? '',
      };
      final p = await SharedPreferences.getInstance();
      await p.setString('${_pf}map', jsonEncode(_profiles));
    }

  static Future<void> saveGoogleClientId(String id) async {
    _googleClientId = id.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_googleClientIdKey, _googleClientId);
  }

  static Future<void> saveGoogleAndroidClientId(String id) async {
    _googleAndroidClientId = id.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_googleAndroidClientIdKey, _googleAndroidClientId);
  }

  static Future<void> saveTelegramBotUsername(String username) async {
    _telegramBot = username.trim().replaceAll('@', '');
    final p = await SharedPreferences.getInstance();
    await p.setString(_telegramBotKey, _telegramBot);
  }

  /// Append off-boarding feedback ("why are you leaving") so it can be
  /// reviewed later (used by Delete Account).
  static Future<void> saveFeedback(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_feedbackKey) ?? <String>[];
    list.add(value);
    await p.setStringList(_feedbackKey, list);
  }

  static const _ordersKey = 'all_orders_v1';

  /// All orders placed on this device, shared across accounts so the
  /// Admin panel can manage them. Persisted so order history (and the
  /// admin's order management) survives an app restart.
  static Future<List<Order>> loadAllOrders() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_ordersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final entries = (m['items'] as List? ?? const [])
            .map((it) => CartItem(
                product: Product.fromJson(
                    ((it as Map)['product'] as Map).cast<String, dynamic>()),
                quantity: (it['quantity'] as num?)?.toInt() ?? 1))
            .toList();
        return Order(
            id: m['id']?.toString() ?? '',
            date: DateTime.tryParse(m['date']?.toString() ?? '') ??
                DateTime.now(),
            items: entries,
            total: (m['total'] as num?)?.toDouble() ?? 0,
            status: m['status']?.toString() ?? 'Processing',
            deliveryAddress: m['address']?.toString() ?? '',
            owner: m['owner']?.toString() ?? '');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAllOrders(List<Order> orders) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _ordersKey,
        jsonEncode(orders.map((o) {
          Map<String, dynamic> productJson(Product x) => {
                'id': x.id,
                'title': x.title,
                'price': x.price,
                'discountPercentage': x.discountPercentage,
                'rating': x.rating,
                'stock': x.stock,
                'brand': x.brand,
                'category': x.category,
                'description': x.description,
                'thumbnail': x.thumbnail,
                'images': x.images,
              };
          return {
            'id': o.id,
            'date': o.date.toIso8601String(),
            'items': o.items
                .map((it) => {
                      'quantity': it.quantity,
                      'product': productJson(it.product),
                    })
                .toList(),
            'total': o.total,
            'status': o.status,
            'address': o.deliveryAddress,
            'owner': o.owner,
          };
        }).toList()));
  }
}