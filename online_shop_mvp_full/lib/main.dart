import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_mode.dart';
import 'l10n/app_localizations.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'services/google_auth_service.dart';
import 'services/supabase_service.dart';
import 'repositories/repositories.dart';
import 'presenters/presenters.dart';
import 'models/models.dart';
import 'views/views.dart';
import 'views/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  final api = ApiService();
  runApp(ShopApp(auth: AuthRepository(api), products: ProductRepository(api)));
}

class ShopApp extends StatefulWidget {
  final AuthRepository auth;
  final ProductRepository products;

  /// Admin-only frontend (lib/main_admin.dart): after a successful admin
  /// sign-in, go straight to the admin dashboard — never the shop.
  final bool adminOnly;

  /// User-only frontend (lib/main_user.dart): the shop only, admin UI
  /// hidden everywhere.
  final bool userOnly;
  const ShopApp(
      {super.key,
      required this.auth,
      required this.products,
      this.adminOnly = false,
      this.userOnly = false});
  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  // The Navigator lives inside MaterialApp, so this key lets us navigate
  // from handlers defined above it (login/signup callbacks).
  final _navKey = GlobalKey<NavigatorState>();
  User? user;
  bool dark = false;
  Locale? locale;
  final cart = CartPresenter(),
      fav = FavoritePresenter(),
      orders = OrderPresenter();
  void login(User u) {
    // The admin-only frontend is for staff: a non-admin account is
    // rejected instead of landing on the shop.
    if (widget.adminOnly && !u.isAdmin) {
      ScaffoldMessenger.of(_navKey.currentContext ?? context).showSnackBar(
          const SnackBar(
              content: Text('This app is for administrators only.'),
              behavior: SnackBarBehavior.floating));
      return;
    }
    AppSettings.saveSession(u);
    setState(() => user = u);
    _startAccountWatch(u);
    _maybeOpenAdmin(u);
  }

  /// Admins land directly on the admin dashboard (Companies table) instead
  /// of the shop. The panel is pushed on top of the shop; its Logout clears
  /// the session so the app root swaps to the LOGIN page.
  void _maybeOpenAdmin(User u) {
    if (widget.userOnly) return; // user frontend never opens the admin panel
    if (!u.isAdmin || !ApiService.isAdminDevice) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navKey.currentState?.push(MaterialPageRoute(
          builder: (_) => AdminPanelPage(
              admin: u,
              repo: AdminRepository(widget.products.api),
              orders: orders,
              onLogout: logout)));
    });
  }

  void logout() {
    _stopAccountWatch();
    AppSettings.clearSession();
    // Also disconnect Google so the next "Continue with Google" shows the
    // account picker again instead of silently reusing the previous account.
    if (!widget.userOnly) {
      GoogleAuthService().signOut().catchError((_) {});
    }
    setState(() => user = null);
  }

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _loadOrders();
    if (AppSettings.restoredUser != null) {
      // The admin-only frontend ignores a restored non-admin session.
      final restored = AppSettings.restoredUser!;
      if (widget.adminOnly && !restored.isAdmin) {
        AppSettings.clearSession();
        return;
      }
      setState(() => user = restored);
      _startAccountWatch(restored);
      // A restored admin session also opens the dashboard right away.
      _maybeOpenAdmin(restored);
    }
  }

  @override
  void dispose() {
    _accountPoll?.cancel();
    super.dispose();
  }

  // ------------------------------------------------- deleted account watch

  /// When the admin deletes this account from the Users page, the shopper
  /// must be logged out AUTOMATICALLY — no restart, no manual sign-out.
  ///
  /// Two signals drive it, matching the live-feedback pattern in the admin
  /// panel: a Supabase realtime DELETE event pushes instantly, and a quiet
  /// 30s cloud poll is the fallback (realtime may be off or delayed).
  Timer? _accountPoll;
  String? _watchedUsername;

  /// Start watching the cloud directory for the deletion of [u]'s account.
  /// Guests and admins can never be deleted from the Users page, and a
  /// device-local account (created offline, never confirmed in the cloud
  /// directory) has no cloud row to check — none of them may ever be
  /// treated as "deleted", so the watch simply does not start for them.
  void _startAccountWatch(User u) {
    _stopAccountWatch();
    if (u.isAdmin) return;
    final uname = u.username.trim().toLowerCase();
    if (uname.isEmpty || uname == 'guest') return;
    if (!AppSettings.sessionCloudOk) return;
    _watchedUsername = uname;
    SupabaseService.instance
        .watchUsers(onDelete: _onAccountDeletedRemotely);
    _accountPoll = Timer.periodic(
        const Duration(seconds: 30), (_) => _checkAccountStillExists());
  }

  void _stopAccountWatch() {
    _accountPoll?.cancel();
    _accountPoll = null;
    if (_watchedUsername != null) {
      _watchedUsername = null;
      SupabaseService.instance.cancelUsersWatch();
    }
  }

  /// Realtime push: a cloud account row was deleted. Only acts when it is
  /// the account signed in on THIS device.
  void _onAccountDeletedRemotely(String username) {
    final u = user;
    if (u == null || u.isAdmin) return;
    if (username.trim().toLowerCase() !=
        u.username.trim().toLowerCase()) {
      return;
    }
    _forceLogoutForDeletedAccount();
  }

  /// Polling fallback: quietly confirm the signed-in account still exists.
  /// `userExists` answers null when the cloud is unreachable, so being
  /// offline NEVER logs anybody out.
  Future<void> _checkAccountStillExists() async {
    final u = user;
    final watched = _watchedUsername;
    if (u == null || watched == null || u.isAdmin) return;
    if (watched != u.username.trim().toLowerCase()) return;
    final exists = await SupabaseService.instance.userExists(watched);
    if (exists == false) _forceLogoutForDeletedAccount();
  }

  /// The signed-in account was deleted by the admin: clear the session so
  /// the app root swaps to the LOGIN page and tell the shopper why.
  void _forceLogoutForDeletedAccount() {
    if (!mounted) return;
    final u = user;
    if (u == null || u.isAdmin) return;
    _stopAccountWatch();
    final ctx = _navKey.currentContext;
    logout();
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          width: 340,
          behavior: SnackBarBehavior.floating,
          content: Text(
              AppLocalizations.of(ctx).t('Your account has been deleted'))));
    }
  }

  Future<void> _loadOrders() async {
    await orders.load();
    if (mounted) setState(() {});
  }

  Future<void> _loadLocale() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('language_code');
    if (mounted && code != null) setState(() => locale = Locale(code));
  }

  Future<void> setLocale(Locale l) async {
    setState(() => locale = l);
    final p = await SharedPreferences.getInstance();
    await p.setString('language_code', l.languageCode);
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue),
      home: user == null
          ? LoginPage(
              p: LoginPresenter(widget.auth),
              success: login,
              signup: () => _navKey.currentState!.push(MaterialPageRoute(
                  builder: (_) => SignupPage(
                      p: SignupPresenter(widget.auth),
                      success: (u) {
                        // Close Sign Up first so no stale route stays on the
                        // stack when the app swaps to HomePage.
                        _navKey.currentState!.pop();
                        login(u);
                      }))))
          : HomePage(
              user: user!,
              home: HomePresenter(widget.products),
              cart: cart,
              fav: fav,
              orders: orders,
              logout: logout,
              dark: dark,
              setTheme: (v) => setState(() => dark = v),
              setLocale: setLocale));
}
