import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'services/google_auth_service.dart';
import 'repositories/repositories.dart';
import 'presenters/presenters.dart';
import 'models/models.dart';
import 'views/views.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  final api = ApiService();
  runApp(ShopApp(auth: AuthRepository(api), products: ProductRepository(api)));
}

class ShopApp extends StatefulWidget {
  final AuthRepository auth;
  final ProductRepository products;
  const ShopApp({super.key, required this.auth, required this.products});
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
    AppSettings.saveSession(u);
    setState(() => user = u);
  }

  void logout() {
    AppSettings.clearSession();
    // Also disconnect Google so the next "Continue with Google" shows the
    // account picker again instead of silently reusing the previous account.
    GoogleAuthService().signOut().catchError((_) {});
    setState(() => user = null);
  }

  @override
  void initState() {
    super.initState();
    _loadLocale();
    if (AppSettings.restoredUser != null) {
      setState(() => user = AppSettings.restoredUser);
    }
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
