import 'package:flutter/material.dart';
import 'app_mode.dart';
import 'main.dart' show ShopApp;
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'repositories/repositories.dart';

/// USER frontend — run it separately with:
///   flutter run -d windows -t lib/main_user.dart
///   flutter run -d chrome  -t lib/main_user.dart
/// Build a release bundle:
///   flutter build web -t lib/main_user.dart
/// Or build the Android APK:
///   flutter build apk -t lib/main_user.dart
///
/// The shop only. Admin UI is hidden everywhere (sidebar entries, dashboard
/// shortcuts) and the built-in admin login is disabled even on a computer,
/// because [AppRunMode.isUserApp] forces `ApiService.isAdminDevice` off.
/// Same BACKEND as the admin frontend: the shared Supabase cloud.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppRunMode.mode = AppMode.userOnly;
  await AppSettings.load();
  final api = ApiService();
  runApp(ShopApp(
      auth: AuthRepository(api),
      products: ProductRepository(api),
      userOnly: true));
}
