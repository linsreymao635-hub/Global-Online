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
  static const _addressKey = 'saved_address';
  static Address? savedAddress;

  static const _pf = 'profile_';
  static String? _firstName, _lastName, _username, _email, _image;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _notifications = p.getBool(_notificationsKey) ?? true;
    _firstName = p.getString('${_pf}firstName');
    _lastName = p.getString('${_pf}lastName');
    _username = p.getString('${_pf}username');
    _email = p.getString('${_pf}email');
    _image = p.getString('${_pf}image');
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
            image: m['image'],
            token: m['token']);
      } catch (_) {
        restoredUser = null;
      }
    }
    final ad = p.getString(_addressKey);
    if (ad != null) {
      try {
        final m = jsonDecode(ad) as Map<String, dynamic>;
        savedAddress = Address(
            fullName: m['fullName'] ?? '',
            phone: m['phone'] ?? '',
            address: m['address'] ?? '',
            city: m['city'] ?? '',
            country: m['country'] ?? '',
            latitude: (m['latitude'] as num?)?.toDouble(),
            longitude: (m['longitude'] as num?)?.toDouble());
      } catch (_) {
        savedAddress = null;
      }
    }
  }

  static Future<void> setNotifications(bool v) async {
    _notifications = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notificationsKey, v);
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
          'image': u.image,
          'token': u.token,
        }));
  }

  static Future<void> clearSession() async {
    restoredUser = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
  }

  static User? get savedProfile {
    if (_username == null) return null;
    return User(
        id: 0,
        firstName: _firstName ?? '',
        lastName: _lastName ?? '',
        username: _username!,
        email: _email ?? '',
        image: _image);
  }

  static Future<void> saveAddress(Address a) async {
    savedAddress = a;
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _addressKey,
        jsonEncode({
          'fullName': a.fullName,
          'phone': a.phone,
          'address': a.address,
          'city': a.city,
          'country': a.country,
          'latitude': a.latitude,
          'longitude': a.longitude,
        }));
  }

  static Future<void> saveProfile(User u) async {
    _firstName = u.firstName;
    _lastName = u.lastName;
    _username = u.username;
    _email = u.email;
    _image = u.image;
    final p = await SharedPreferences.getInstance();
    await p.setString('${_pf}firstName', u.firstName);
    await p.setString('${_pf}lastName', u.lastName);
    await p.setString('${_pf}username', u.username);
    await p.setString('${_pf}email', u.email);
    await p.setString('${_pf}image', u.image ?? '');
  }
}