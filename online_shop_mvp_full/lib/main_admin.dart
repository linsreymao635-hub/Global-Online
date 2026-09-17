import 'package:flutter/material.dart';
import 'app_mode.dart';
import 'main.dart' show ShopApp;
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'repositories/repositories.dart';

/// ADMIN frontend — run it separately with:
///   flutter run -d windows -t lib/main_admin.dart
///   flutter run -d chrome  -t lib/main_admin.dart
/// Build a release bundle:
///   flutter build web -t lib/main_admin.dart
///
/// Boots the sign-in page, then goes straight to the admin dashboard.
/// The shop UI is never shown and non-admin accounts are rejected.
/// Same BACKEND as the user frontend: everything is read/written to the
/// shared Supabase cloud, so products, categories, users and orders stay
/// in sync with the user app running anywhere else.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppRunMode.mode = AppMode.adminOnly;
  await AppSettings.load();
  final api = ApiService();
  runApp(ShopApp(
      auth: AuthRepository(api),
      products: ProductRepository(api),
      adminOnly: true));
}
