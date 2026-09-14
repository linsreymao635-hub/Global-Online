import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../presenters/presenters.dart';
import '../repositories/repositories.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';

ImageProvider? userImage(String? s) {
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('b64:')) return MemoryImage(base64Decode(s.substring(4)));
  return NetworkImage(s);
}

Widget socialButtons(
    BuildContext c, void Function(User) onLogin, String Function(String) tr) {
  Future<void> confirm(
      User u, String provider, IconData icon) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (dc) => AlertDialog(
        icon: Icon(icon, size: 36, color: Colors.blueAccent),
        title: Text(provider),
        content: Text('${tr('Continue as')} ${u.fullName}\n(${u.email})?',
            textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(tr('Continue'))),
        ],
      ),
    );
    if (ok == true) onLogin(u);
  }

  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => confirm(
            User(
                id: 999,
                firstName: 'Google',
                lastName: 'User',
                username: 'google_user',
                email: 'google.user@gmail.com'),
            tr('Continue with Google'),
            Icons.g_mobiledata,
          ),
          icon: Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/120px-Google_%22G%22_Logo.svg.png',
            width: 20,
            height: 20,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.g_mobiledata, color: Colors.blue, size: 26),
          ),
          label: Text(tr('Continue with Google'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF229ED9),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => confirm(
            User(
                id: 998,
                firstName: 'Telegram',
                lastName: 'User',
                username: 'telegram_user',
                email: 'telegram.user@telegram.org'),
            tr('Continue with Telegram'),
            Icons.send,
          ),
          icon: const Icon(Icons.send, size: 20),
          label: Text(tr('Continue with Telegram'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPassword();
}

class _ForgotPassword extends State<ForgotPasswordPage> {
  int step = 1;
  String code = '';
  final phone = TextEditingController();
  final codeInput = TextEditingController();
  final npass = TextEditingController();
  final cpass = TextEditingController();
  bool busy = false;
  bool show = false;

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x)));

  String rnd() => (100000 + Random().nextInt(900000)).toString();

  void sendCode() async {
    final tr = AppLocalizations.of(context).t;
    if (phone.text.trim().length < 8) {
      msg(tr('Please enter a valid phone number'));
      return;
    }
    setState(() {
      busy = true;
      code = rnd();
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => busy = false);
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        icon: const Icon(Icons.sms_outlined, size: 40, color: Colors.green),
        title: Text(tr('Verification code')),
        content: Text('${tr('We sent a code to')} ${phone.text.trim()}\n\n$code'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dc);
              setState(() => step = 2);
            },
            child: Text(tr('Continue')),
          ),
        ],
      ),
    );
  }

  void verifyCode() {
    final tr = AppLocalizations.of(context).t;
    if (codeInput.text.trim() != code) {
      msg(tr('Wrong code. Check your phone.'));
      return;
    }
    setState(() => step = 3);
  }

  void resetPassword() async {
    final tr = AppLocalizations.of(context).t;
    if (npass.text.length < 6) {
      msg(tr('Password must be at least 6 characters'));
      return;
    }
    if (npass.text != cpass.text) {
      msg(tr('Passwords do not match'));
      return;
    }
    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => busy = false);
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
        title: Text(tr('Password reset successful')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dc);
              Navigator.pop(context);
            },
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  Widget field(TextEditingController c, String t, IconData icon,
      {bool obscure = false, bool code_ = false}) =>
      TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: code_
            ? TextInputType.number
            : obscure
                ? TextInputType.visiblePassword
                : TextInputType.phone,
        maxLength: code_ ? 6 : null,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: t,
          prefixIcon: Icon(icon),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
        ),
      );

  @override
  void dispose() {
    phone.dispose();
    codeInput.dispose();
    npass.dispose();
    cpass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    IconData icon = Icons.lock_reset;
    String title = '';
    Widget body = const SizedBox();
    switch (step) {
      case 1:
        icon = Icons.sms_outlined;
        title = tr('Enter your phone number to receive a verification code');
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            field(phone, tr('Phone'), Icons.phone_android),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : sendCode,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(tr('Send code')),
            ),
          ],
        );
      case 2:
        icon = Icons.pin_outlined;
        title = '${tr('We sent a code to')} ${phone.text.trim()}';
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            field(codeInput, tr('Verification code'), Icons.password,
                code_: true),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: verifyCode,
              child: Text(tr('Verify code')),
            ),
          ],
        );
      case 3:
        icon = Icons.lock_reset;
        title = tr('Reset password');
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            field(npass, tr('New Password'), Icons.lock_outline,
                obscure: !show),
            const SizedBox(height: 14),
            field(cpass, tr('Confirm password'), Icons.lock_outline,
                obscure: !show),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => show = !show),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : resetPassword,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(tr('Reset password')),
            ),
          ],
        );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Forgot Password'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: sch.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 46, color: sch.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          body,
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final LoginPresenter p;
  final void Function(User) success;
  final VoidCallback signup;
  const LoginPage({super.key, required this.p, required this.success, required this.signup});
  @override
  State<LoginPage> createState() => _Login();
}

class _Login extends State<LoginPage> {
  final u = TextEditingController();
  final p = TextEditingController();
  bool busy = false;
  bool show = false;

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x)));

  Future<void> go() async {
    setState(() => busy = true);
    try {
      final x = await widget.p.login(u.text, p.text);
      if (x == null) {
        msg(AppLocalizations.of(context).t('Login failed'));
      } else {
        widget.success(x);
      }
    } catch (e) {
      msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String t, IconData icon) => TextField(
        controller: c,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: t,
          prefixIcon: Icon(icon),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [sch.primary, sch.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.shopping_bag,
                      size: 52, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text('Globle Online',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(tr('Sign in to continue shopping'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: sch.onSurfaceVariant)),
              const SizedBox(height: 32),
              field(u, tr('Username'), Icons.person_outline),
              const SizedBox(height: 14),
              TextField(
                controller: p,
                obscureText: !show,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: tr('Password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => show = !show),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage())),
                  child: Text(tr('Forgot Password?')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : go,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(tr('Sign In')),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: widget.signup,
                child: Text.rich(TextSpan(
                  text: '${tr('New to Globle Online?')} ',
                  children: [
                    TextSpan(
                      text: tr('Create Account'),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: sch.primary),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(tr('Or continue with'),
                        style: TextStyle(color: sch.onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              socialButtons(c, widget.success, tr),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupPage extends StatefulWidget {
  final SignupPresenter p;
  final void Function(User) success;
  const SignupPage({super.key, required this.p, required this.success});
  @override
  State<SignupPage> createState() => _Signup();
}

class _Signup extends State<SignupPage> {
  final f = TextEditingController();
  final l = TextEditingController();
  final e = TextEditingController();
  final p = TextEditingController();
  final cp = TextEditingController();
  bool busy = false;
  bool show = false;

  void msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x)));

  Future<void> go() async {
    final uname = (f.text.trim() + l.text.trim())
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    setState(() => busy = true);
    try {
      final x = await widget.p.signup(
          f: f.text, l: l.text, u: uname, p: p.text, c: cp.text, e: e.text);
      if (x == null) {
        msg(AppLocalizations.of(context).t('Could not create account'));
      } else {
        widget.success(x);
      }
    } catch (e) {
      msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String t, IconData icon,
          {bool s = false, Widget? trailing}) =>
      TextField(
          controller: c,
          obscureText: s,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
              labelText: t,
              prefixIcon: Icon(icon),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              suffixIcon: trailing));

  Widget eye() => IconButton(
        icon: Icon(show ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => show = !show),
      );

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sign Up'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [sch.primary, sch.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.person_add_alt_1,
                    size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('Create your account'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('Join Globle Online and start shopping'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
            const SizedBox(height: 24),
            field(f, tr('First name'), Icons.person_outline),
            const SizedBox(height: 12),
            field(l, tr('Last name'), Icons.person_outline),
            const SizedBox(height: 12),
            field(e, tr('Phone'), Icons.phone_android),
            const SizedBox(height: 12),
            field(p, tr('Password'), Icons.lock_outline,
                s: !show, trailing: eye()),
            const SizedBox(height: 12),
            field(cp, tr('Confirm password'), Icons.lock_outline,
                s: !show, trailing: eye()),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy ? null : go,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(tr('Create Account')),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(tr('Or continue with'),
                      style: TextStyle(color: sch.onSurfaceVariant)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            socialButtons(c, widget.success, tr),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final User user;
  final HomePresenter home;
  final CartPresenter cart;
  final FavoritePresenter fav;
  final OrderPresenter orders;
  final VoidCallback logout;
  final bool dark;
  final ValueChanged<bool> setTheme;
  final void Function(Locale) setLocale;
  const HomePage({
    super.key,
    required this.user,
    required this.home,
    required this.cart,
    required this.fav,
    required this.orders,
    required this.logout,
    required this.dark,
    required this.setTheme,
    required this.setLocale,
  });
  @override
  State<HomePage> createState() => _Home();
}

class _Home extends State<HomePage> {
  late Future<List<Product>> future;
  final q = TextEditingController();
  String? sort;
  int cols = 2;

  @override
  void initState() {
    super.initState();
    future = widget.home.products();
  }

  void search() {
    setState(() {
      future = widget.home.search(q.text);
    });
  }

  void clearSearch() => setState(() {
        q.clear();
        future = widget.home.products();
      });

  void detail(Product p) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductPage(p: p, cart: widget.cart, fav: widget.fav))).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext c) {
    final l10n = AppLocalizations.of(c);
    final tr = l10n.t;
    return Scaffold(
        appBar: AppBar(
          title: Text(tr('Shop')),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CartPage(cart: widget.cart, orders: widget.orders)))
                  .then((_) {
                if (mounted) setState(() {});
              }),
              icon: Badge(
                isLabelVisible: widget.cart.count > 0,
                label: Text('${widget.cart.count}'),
                child: const Icon(Icons.shopping_cart),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'fav') {
                  Navigator.push(c,
                      MaterialPageRoute(builder: (_) => FavoritePage(fav: widget.fav, cart: widget.cart, source: future)));
                }
                if (v == 'cat') {
                  Navigator.push(c,
                      MaterialPageRoute(builder: (_) => CategoryPage(cart: widget.cart, fav: widget.fav)));
                }
                if (v == 'profile') {
                  Navigator.push(c, MaterialPageRoute(builder: (_) => ProfilePage(
                      user: widget.user,
                      cart: widget.cart,
                      fav: widget.fav,
                      orders: widget.orders,
                      products: widget.home.products())));
                }
                if (v == 'orders') {
                  Navigator.push(c, MaterialPageRoute(builder: (_) => OrderPage(orders: widget.orders)));
                }
                if (v == 'settings') {
                  Navigator.push(c,
                      MaterialPageRoute(builder: (_) => SettingsPage(dark: widget.dark, setTheme: widget.setTheme, setLocale: widget.setLocale)));
                }
                if (v == 'logout') widget.logout();
              },
              itemBuilder: (_) {
                final tr = AppLocalizations.of(c).t;
                return [
                  PopupMenuItem(value: 'fav', child: Text(tr('Favorites'))),
                  PopupMenuItem(value: 'cat', child: Text(tr('Categories'))),
                  PopupMenuItem(value: 'orders', child: Text(tr('Order History'))),
                  PopupMenuItem(value: 'profile', child: Text(tr('Profile'))),
                  PopupMenuItem(value: 'settings', child: Text(tr('Settings'))),
                  PopupMenuItem(value: 'logout', child: Text(tr('Logout'))),
                ];
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: q,
                      onChanged: (_) => search(),
                      onSubmitted: (_) => search(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: tr('Search products or categories'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: q.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: clearSearch),
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: FilledButton(
                      onPressed: search,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              child: Row(
                children: [
                  Flexible(child: _sortButton(c, tr)),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('1 Column'),
                    isSelected: cols == 1,
                    onPressed: () => setState(() => cols = 1),
                    icon: const Icon(Icons.view_agenda_outlined),
                  ),
                  IconButton(
                    tooltip: tr('2 Columns'),
                    isSelected: cols == 2,
                    onPressed: () => setState(() => cols = 2),
                    icon: const Icon(Icons.grid_on),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: future,
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) {
                    return Center(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            future = widget.home.products();
                          });
                        },
                        child: Text(tr('Retry')),
                      ),
                    );
                  }
                  final list = s.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        q.text.trim().isEmpty
                            ? tr('No products')
                            : l10n.noProductsFor(q.text.trim()),
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }
                  final trimmed = q.text.trim();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trimmed.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                          child: Text(
                            list.length == 1
                                ? l10n.oneResult(trimmed)
                                : l10n.nResults(list.length, trimmed),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      Expanded(child: _grid(list)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _sortButton(BuildContext c, String Function(String) tr) {
    final sch = Theme.of(c).colorScheme;
    final label = sort == 'high'
        ? tr('Price: High to Low')
        : sort == 'low'
            ? tr('Price: Low to High')
            : tr('Sort');
    PopupMenuItem<String> item(String v, String t) => PopupMenuItem<String>(
          value: v,
          child: Row(
            children: [
              Icon(
                sort == v
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: sort == v ? sch.primary : null,
              ),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => sort = v == 'none' ? null : v),
      itemBuilder: (_) => [
        item('none', tr('Sort')),
        item('high', tr('Price: High to Low')),
        item('low', tr('Price: Low to High')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sch.surfaceContainerLow,
          border: Border.all(color: sch.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Product> list) {
    final l = [...list];
    if (sort == 'high') l.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'low') l.sort((a, b) => a.price.compareTo(b.price));
    return GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: cols == 2 ? .65 : 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final p = l[i];
                      return Card(
                        child: InkWell(
                          onTap: () => detail(p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(p.thumbnail,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: IconButton.filledTonal(
                                        onPressed: () => setState(() => widget.fav.toggle(p)),
                                        icon: Icon(widget.fav.has(p) ? Icons.favorite : Icons.favorite_border),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
                                child: Text('\$${p.price.toStringAsFixed(2)}'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
  }
}

class ProductPage extends StatefulWidget {
  final Product p;
  final CartPresenter cart;
  final FavoritePresenter fav;
  const ProductPage({super.key, required this.p, required this.cart, required this.fav});
  @override
  State<ProductPage> createState() => _Product();
}

class _Product extends State<ProductPage> {
  int _img = 0;

  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    final l10n = AppLocalizations.of(c);
    final tr = l10n.t;
    final sch = Theme.of(c).colorScheme;
    final disc = p.discountPercentage;
    final save = (p.price * disc / 100).toStringAsFixed(2);
    final original = (p.price / (1 - disc / 100)).toStringAsFixed(2);
    final images = p.images.isNotEmpty ? p.images : [p.thumbnail];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Product Details'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Container(
              color: sch.surfaceContainerLow,
              child: Image.network(images[_img], fit: BoxFit.contain),
            ),
          ),
          if (images.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _img = i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          width: 2,
                          color: i == _img
                              ? sch.primary
                              : sch.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(images[i],
                          width: 58, height: 58, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (p.category.isNotEmpty)
                      _chip(c, Icon(Icons.category_outlined, size: 15), tr(p.category)),
                    if (p.brand.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _chip(c, Icon(Icons.branding_watermark_outlined, size: 15), p.brand),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(p.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(p.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('•  ${tr('Stock')}: ${p.stock}',
                        style: TextStyle(color: sch.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p.price.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: sch.primary)),
                    if (disc > 0) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('\$$original',
                            style: TextStyle(
                                fontSize: 16,
                                color: sch.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough)),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: sch.errorContainer,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text('−${disc.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: sch.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (disc > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l10n.discountLine(
                        disc.toStringAsFixed(0), save),
                        style: TextStyle(
                            color: sch.error, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(tr('Description'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(l10n.productDescription(p.id, p.description),
                    style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: sch.surface,
          border: Border(top: BorderSide(color: sch.outlineVariant)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (disc > 0)
                    Text('\$$original',
                        style: TextStyle(
                            fontSize: 13,
                            color: sch.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough)),
                  Text('\$${p.price.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: sch.primary)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    widget.cart.add(p);
                    ScaffoldMessenger.of(c).showSnackBar(
                        SnackBar(content: Text(tr('Added to cart'))));
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(tr('Add to Cart')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext c, Icon icon, String label) {
    final sch = Theme.of(c).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sch.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: sch.onSecondaryContainer, fontSize: 13)),
        ],
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  final CartPresenter cart;
  final OrderPresenter orders;
  const CartPage({super.key, required this.cart, required this.orders});
  @override
  State<CartPage> createState() => _Cart();
}

class _Cart extends State<CartPage> {
  Future<void> checkout() async {
    if (widget.cart.items.isEmpty) return;
    final a = await Navigator.push<Address>(context, MaterialPageRoute(builder: (_) => const AddressPage()));
    if (a == null || !mounted) return;
    widget.orders.create(widget.cart.items, widget.cart.total, a);
    widget.cart.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('Order placed')),
        content: Text(AppLocalizations.of(context).t('Your order was created successfully.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).t('OK'))),
        ],
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
        appBar: AppBar(title: Text(tr('Cart'))),
        body: widget.cart.items.isEmpty
            ? Center(child: Text(tr('Your cart is empty')))
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.cart.items.length,
                      itemBuilder: (_, i) {
                        final x = widget.cart.items[i];
                        return ListTile(
                          leading: Image.network(x.product.thumbnail, width: 55),
                          title: Text(x.product.title),
                          subtitle: Text('\$${x.product.price.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  onPressed: () => setState(() => widget.cart.minus(x.product)),
                                  icon: const Icon(Icons.remove)),
                              Text('${x.quantity}'),
                              IconButton(
                                  onPressed: () => setState(() => widget.cart.add(x.product)),
                                  icon: const Icon(Icons.add)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('${tr('Total')}: \$${widget.cart.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(onPressed: checkout, child: Text(tr('Checkout'))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );
  }
}

class AddressPage extends StatefulWidget {
  final Address? initial;
  final bool saveMode;
  const AddressPage({super.key, this.initial, this.saveMode = false});
  @override
  State<AddressPage> createState() => _Address();
}

class _Address extends State<AddressPage> {
  late final TextEditingController n =
      TextEditingController(text: widget.initial?.fullName);
  late final TextEditingController ph =
      TextEditingController(text: widget.initial?.phone);
  late final TextEditingController a =
      TextEditingController(text: widget.initial?.address);
  late final TextEditingController city =
      TextEditingController(text: widget.initial?.city ?? 'Phnom Penh');
  late final TextEditingController country =
      TextEditingController(text: widget.initial?.country ?? 'Cambodia');
  late LatLng _pos;
  MapController? _ctrl;

  @override
  void initState() {
    super.initState();
    _pos = LatLng(
        widget.initial?.latitude ?? 11.5564, widget.initial?.longitude ?? 104.9282);
  }

  void _setPin(LatLng p) {
    setState(() => _pos = p);
  }

  Widget f(TextEditingController c, String t, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: t,
              prefixIcon: Icon(icon),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            )),
      );

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng');
      final r = await http.get(uri, headers: {'User-Agent': 'online_shop_mvp'});
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final m = j['address'] as Map<String, dynamic>? ?? {};
        final c = m['city'] ?? m['town'] ?? m['village'] ?? '';
        final country_ = m['country'] ?? '';
        if (a.text.isEmpty) a.text = j['display_name'] ?? '';
        if (c.toString().isNotEmpty) city.text = c.toString();
        if (country_.toString().isNotEmpty) country.text = country_.toString();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _onTapMap(TapPosition tp, LatLng p) {
    _setPin(p);
    _reverseGeocode(p.latitude, p.longitude);
  }

  void _useMapCenter() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final c = ctrl.camera.center;
    _setPin(c);
    _reverseGeocode(c.latitude, c.longitude);
  }

  void go() {
    if (n.text.isEmpty || ph.text.isEmpty || a.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppLocalizations.of(context).t('Please complete delivery information'))));
      return;
    }
    Navigator.pop(
        context,
        Address(
          fullName: n.text,
          phone: ph.text,
          address: a.text,
          city: city.text,
          country: country.text,
          latitude: _pos.latitude,
          longitude: _pos.longitude,
        ));
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.saveMode ? tr('My Address') : tr('Delivery Address'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 250,
              child: FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                  initialCenter: _pos,
                  initialZoom: 15,
                  onTap: _onTapMap,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.online_shop_mvp_full',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pos,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_pin,
                            size: 44, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(tr('Tap the map to select your delivery location'),
                style: TextStyle(color: sch.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _useMapCenter,
              icon: const Icon(Icons.center_focus_strong, size: 18),
              label: Text(tr('Use map center')),
            ),
          ),
          const SizedBox(height: 14),
          Text(tr('Contact information'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sch.onSurfaceVariant)),
          const SizedBox(height: 10),
          f(n, tr('Full name'), Icons.person_outline),
          f(ph, tr('Phone'), Icons.phone_outlined),
          f(a, tr('Address'), Icons.home_outlined),
          f(city, tr('City'), Icons.location_city_outlined),
          f(country, tr('Country'), Icons.public),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: go,
            icon: const Icon(Icons.check),
            label: Text(widget.saveMode ? tr('Save') : tr('Continue')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${_pos.latitude},${_pos.longitude}');
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.map_outlined, color: Color(0xFF4285F4)),
            label: Text(tr('Open in Google Maps')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4285F4),
              side: const BorderSide(color: Color(0xFF4285F4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  final CartPresenter cart;
  final FavoritePresenter fav;
  const CategoryPage({super.key, required this.cart, required this.fav});
  @override
  State<CategoryPage> createState() => _Cat();
}

class _Cat extends State<CategoryPage> {
  late final CategoryPresenter p;
  late Future<List<Category>> cats;
  final sq = TextEditingController();
  List<Product>? items;
  String? sort;
  int cols = 2;

  @override
  void initState() {
    super.initState();
    p = CategoryPresenter(ProductRepository(ApiService()));
    cats = p.categories();
  }

  Future<void> load(Future<List<Product>> f) async {
    setState(() => items = null);
    try {
      final l = await f;
      if (mounted) setState(() => items = l);
    } catch (_) {
      if (mounted) setState(() => items = const []);
    }
  }

  List<Product> get shown {
    final l = [...items!];
    if (sort == 'high') l.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'low') l.sort((a, b) => a.price.compareTo(b.price));
    return l;
  }

  void catClear() {
    sq.clear();
    setState(() => items = null);
  }

  Widget _sortButton(BuildContext c, String Function(String) tr) {
    final sch = Theme.of(c).colorScheme;
    final label = sort == 'high'
        ? tr('Price: High to Low')
        : sort == 'low'
            ? tr('Price: Low to High')
            : tr('Sort');
    PopupMenuItem<String> item(String v, String t) => PopupMenuItem<String>(
          value: v,
          child: Row(
            children: [
              Icon(
                sort == v
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: sort == v ? sch.primary : null,
              ),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => sort = v == 'none' ? null : v),
      itemBuilder: (_) => [
        item('none', tr('Sort')),
        item('high', tr('Price: High to Low')),
        item('low', tr('Price: Low to High')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sch.surfaceContainerLow,
          border: Border.all(color: sch.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext c, Product x) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
                builder: (_) =>
                    ProductPage(p: x, cart: widget.cart, fav: widget.fav))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(x.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filledTonal(
                      onPressed: () => setState(() => widget.fav.toggle(x)),
                      icon: Icon(
                          widget.fav.has(x) ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Text(x.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
              child: Text('\$${x.price.toStringAsFixed(2)}'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
        appBar: AppBar(title: Text(tr('Categories'))),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: sq,
                onChanged: (_) => load(p.search(sq.text)),
                onSubmitted: (_) => load(p.search(sq.text)),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('Search products or categories'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: sq.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.clear), onPressed: catClear),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(
              height: 88,
              child: FutureBuilder<List<Category>>(
                future: cats,
                builder: (_, s) => !s.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: s.data!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ActionChip(
                          label: Text(tr(s.data![i].name)),
                          onPressed: () => load(p.products(s.data![i].slug)),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
              child: Row(
                children: [
                  Flexible(child: _sortButton(c, tr)),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: tr('1 Column'),
                    isSelected: cols == 1,
                    onPressed: () => setState(() => cols = 1),
                    icon: const Icon(Icons.view_agenda_outlined),
                  ),
                  IconButton(
                    tooltip: tr('2 Columns'),
                    isSelected: cols == 2,
                    onPressed: () => setState(() => cols = 2),
                    icon: const Icon(Icons.grid_on),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1),
            Expanded(
              child: items == null
                  ? Center(child: Text(tr('Select a category or search')))
                  : shown.isEmpty
                      ? Center(child: Text(tr('No products found')))
                      : GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            childAspectRatio: cols == 2 ? 0.65 : 1.1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (_, i) => _cell(c, shown[i]),
                        ),
            ),
          ],
        ),
      );
  }
}

class FavoritePage extends StatefulWidget {
  final FavoritePresenter fav;
  final CartPresenter cart;
  final Future<List<Product>> source;
  const FavoritePage({super.key, required this.fav, required this.cart, required this.source});
  @override
  State<FavoritePage> createState() => _Fav();
}

class _Fav extends State<FavoritePage> {
  Widget cell(BuildContext c, Product p) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
                builder: (_) =>
                    ProductPage(p: p, cart: widget.cart, fav: widget.fav))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(p.thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      tooltip: tr('Remove from favorites'),
                      onPressed: () => setState(() => widget.fav.toggle(p)),
                      icon: const Icon(Icons.favorite, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(p.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('\$${p.price.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: sch.primary)),
                  ),
                  IconButton.filledTonal(
                    iconSize: 20,
                    tooltip: tr('Add to Cart'),
                    onPressed: () {
                      widget.cart.add(p);
                      ScaffoldMessenger.of(c).showSnackBar(
                          SnackBar(content: Text(tr('Added to cart'))));
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Favorites'))),
      body: FutureBuilder<List<Product>>(
        future: widget.source,
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final list = widget.fav.ids.isEmpty
              ? <Product>[]
              : s.data!.where((p) => widget.fav.has(p)).toList();
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 70, color: Theme.of(c).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(tr('No favorites'),
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.66,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => cell(c, list[i]),
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final User user;
  final CartPresenter cart;
  final FavoritePresenter fav;
  final OrderPresenter orders;
  final Future<List<Product>> products;
  const ProfilePage(
      {super.key,
      required this.user,
      required this.cart,
      required this.fav,
      required this.orders,
      required this.products});
  @override
  State<ProfilePage> createState() => _Profile();
}

class _Profile extends State<ProfilePage> {
  late User user;
  bool _imgFailed = false;

  @override
  void initState() {
    super.initState();
    final saved = AppSettings.savedProfile;
    user = saved == null
        ? widget.user
        : User(
            id: widget.user.id,
            firstName: saved.firstName,
            lastName: saved.lastName,
            username: saved.username,
            email: saved.email,
            image: saved.image ?? widget.user.image,
            token: widget.user.token);
    _imgFailed = false;
  }

  Future<void> _edit() async {
    final edited = await Navigator.push<User>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
    );
    if (edited != null && mounted) setState(() => user = edited);
  }

  void _openCart() {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => CartPage(cart: widget.cart, orders: widget.orders)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openFav() {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FavoritePage(
                    fav: widget.fav, cart: widget.cart, source: widget.products)))
        .then((_) => mounted ? setState(() {}) : null);
  }

  void _openOrders() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => OrderPage(orders: widget.orders)));
  }

  Future<void> _openAddress() async {
    final saved = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
          builder: (_) => AddressPage(initial: AppSettings.savedAddress, saveMode: true)),
    );
    if (saved != null && mounted) {
      await AppSettings.saveAddress(saved);
      setState(() {});
    }
  }

  Widget _stat(BuildContext c, IconData icon, int n, String label,
      VoidCallback onTap) {
    final sch = Theme.of(c).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: sch.primary, size: 24),
            const SizedBox(height: 6),
            Text('$n',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: sch.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: sch.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _action(
      BuildContext c, IconData icon, String label, VoidCallback onTap) {
    final sch = Theme.of(c).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sch.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: sch.onSecondaryContainer, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Profile')),
        actions: [
          IconButton(
            onPressed: _edit,
            tooltip: tr('Edit Profile'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [sch.primary, sch.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -50,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [Colors.white, Colors.white70],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white,
                              backgroundImage: user.image == null || _imgFailed
                                  ? null
                                  : userImage(user.image),
                              onBackgroundImageError: user.image == null
                                  ? null
                                  : (_, __) => setState(() => _imgFailed = true),
                              child: _imgFailed
                                  ? Icon(Icons.person, size: 60, color: sch.primary)
                                  : user.image == null
                                      ? Icon(Icons.person, size: 60, color: sch.primary)
                                      : null,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: GestureDetector(
                              onTap: _edit,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: sch.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(Icons.photo_camera,
                                    size: 16, color: sch.onPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2)),
                                ],
                              )),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('@${user.username}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.email_outlined,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(user.email,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.outlineVariant)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            child: _stat(c, Icons.shopping_cart_outlined,
                                widget.cart.count, tr('Cart'), _openCart)),
                        Container(width: 1, height: 44, color: sch.outlineVariant),
                        Expanded(
                            child: _stat(c, Icons.favorite_outline,
                                widget.fav.ids.length, tr('Favorites'), _openFav)),
                        Container(width: 1, height: 44, color: sch.outlineVariant),
                        Expanded(
                            child: _stat(c, Icons.receipt_long_outlined,
                                widget.orders.orders.length, tr('Orders'), _openOrders)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (AppSettings.savedAddress != null)
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: sch.outlineVariant)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openAddress,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: sch.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.location_on_outlined,
                                  color: sch.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${AppSettings.savedAddress!.fullName} · ${AppSettings.savedAddress!.phone}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${AppSettings.savedAddress!.address}, ${AppSettings.savedAddress!.city}, ${AppSettings.savedAddress!.country}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: sch.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: sch.outlineVariant)),
                  child: Column(
                    children: [
                      _action(c, Icons.shopping_cart_outlined, tr('Cart'), _openCart),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.favorite_outline, tr('Favorites'), _openFav),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.receipt_long_outlined, tr('Order History'), _openOrders),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.location_on_outlined, tr('My Address'), _openAddress),
                      Divider(height: 1, indent: 58, color: sch.outlineVariant),
                      _action(c, Icons.edit_outlined, tr('Edit Profile'), _edit),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final User user;
  const EditProfilePage({super.key, required this.user});
  @override
  State<EditProfilePage> createState() => _EditProfile();
}

class _EditProfile extends State<EditProfilePage> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController first =
      TextEditingController(text: widget.user.firstName);
  late final TextEditingController last =
      TextEditingController(text: widget.user.lastName);
  late final TextEditingController name =
      TextEditingController(text: widget.user.username);
  late final TextEditingController email =
      TextEditingController(text: widget.user.email);
  String _url = '';
  String? _b64;

  @override
  void dispose() {
    for (final c in [first, last, name, email]) {
      c.dispose();
    }
    super.dispose();
  }

  ImageProvider? get _preview {
    if (_b64 != null) return MemoryImage(base64Decode(_b64!));
    final s = _url.isNotEmpty ? _url : widget.user.image;
    return userImage(s);
  }

  Future<void> _changePhoto() async {
    final tr = AppLocalizations.of(context).t;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (bc) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Choose from gallery')),
              onTap: () => Navigator.pop(bc, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(tr('Enter image URL')),
              onTap: () => Navigator.pop(bc, 'url'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'gallery') return _pickGallery();
    if (choice == 'url') return _askUrl();
  }

  Future<void> _pickGallery() async {
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 900,
          maxHeight: 900,
          imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _b64 = base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).t(
                'Could not open the gallery. Please try entering an image URL.'))));
      }
    }
  }

  Future<void> _askUrl() async {
    final tr = AppLocalizations.of(context).t;
    final ctrl = TextEditingController(text: _url);
    final url = await showDialog<String>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('Enter image URL')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: tr('Image')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text(tr('Cancel'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(dc, ctrl.text.trim()),
              child: Text(tr('OK'))),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      if (mounted) setState(() {
        _url = url;
        _b64 = null;
      });
    }
  }

  Future<void> _save() async {
    if (!(_f.currentState?.validate() ?? false)) return;
    final u = User(
        id: widget.user.id,
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        username: name.text.trim(),
        email: email.text.trim(),
        image: _b64 != null
            ? 'b64:$_b64'
            : (_url.isNotEmpty ? _url : widget.user.image),
        token: widget.user.token);
    await AppSettings.saveProfile(u);
    if (mounted) Navigator.pop(context, u);
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Edit Profile'))),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: _changePhoto,
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: sch.secondaryContainer,
                      backgroundImage: _preview,
                      child: _preview == null
                          ? const Icon(Icons.person, size: 56)
                          : null,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: sch.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: sch.surface, width: 2),
                      ),
                      child: Icon(Icons.camera_alt, size: 18, color: sch.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _changePhoto,
                child: Text(tr('Change photo')),
              ),
            ),
            const SizedBox(height: 6),
            _field(c, first, tr('First Name'), Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, last, tr('Last Name'), Icons.people_outline,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, name, tr('Username'), Icons.badge_outlined,
                validator: (v) => v == null || v.trim().isEmpty ? ' ' : null),
            _field(c, email, tr('Email'), Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v != null && v.contains('@') ? null : ' '),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(tr('Save')),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext c, TextEditingController ctrl, String label,
      IconData icon,
      {String? Function(String?)? validator,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final bool dark;
  final ValueChanged<bool> setTheme;
  final void Function(Locale) setLocale;
  const SettingsPage(
      {super.key,
      required this.dark,
      required this.setTheme,
      required this.setLocale});
  @override
  State<SettingsPage> createState() => _Settings();
}

class _Settings extends State<SettingsPage> {
  late bool notifications = AppSettings.notifications;
  late bool dark = widget.dark;

  Future<void> _setNotifications(bool v) async {
    setState(() => notifications = v);
    await AppSettings.setNotifications(v);
  }

  void _chooseTheme(BuildContext c) {
    final l = AppLocalizations.of(c);
    showDialog(
      context: c,
      builder: (_) => SimpleDialog(
        title: Text(l.t('Theme')),
        children: [
          ListTile(
            leading: Icon(dark
                ? Icons.check_circle
                : Icons.circle_outlined),
            title: Text(l.t('Dark mode')),
            onTap: () {
              Navigator.pop(c);
              widget.setTheme(true);
              setState(() => dark = true);
            },
          ),
          ListTile(
            leading: Icon(!dark
                ? Icons.check_circle
                : Icons.circle_outlined),
            title: Text(l.t('Light mode')),
            onTap: () {
              Navigator.pop(c);
              widget.setTheme(false);
              setState(() => dark = false);
            },
          ),
        ],
      ),
    );
  }

  void _chooseLanguage(BuildContext c) {
    final l = AppLocalizations.of(c);
    showDialog(
      context: c,
      builder: (_) => SimpleDialog(
        title: Text(l.t('Language')),
        children: [
          ListTile(
            leading: Icon(
                l.locale.languageCode == 'en'
                    ? Icons.check_circle
                    : Icons.circle_outlined),
            title: const Text('English'),
            onTap: () {
              Navigator.pop(c);
              widget.setLocale(const Locale('en'));
            },
          ),
          ListTile(
            leading: Icon(
                l.locale.languageCode == 'km'
                    ? Icons.check_circle
                    : Icons.circle_outlined),
            title: const Text('ភាសាខ្មែរ'),
            onTap: () {
              Navigator.pop(c);
              widget.setLocale(const Locale('km'));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    return Scaffold(
        appBar: AppBar(title: Text(l.t('Settings'))),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(l.t('Theme')),
              subtitle: Text(dark ? l.t('Dark mode') : l.t('Light mode')),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _chooseTheme(c),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: Text(l.t('Notifications')),
              subtitle: Text(l.t('Receive discount alerts')),
              value: notifications,
              onChanged: _setNotifications,
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l.t('Language')),
              subtitle: Text(l.locale.languageCode == 'km'
                  ? 'ភាសាខ្មែរ'
                  : l.t('English')),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _chooseLanguage(c),
            ),
            const AboutListTile(
                applicationName: 'Globle Online', applicationVersion: '1.0.0'),
          ],
        ),
      );
  }
}

class OrderPage extends StatelessWidget {
  final OrderPresenter orders;
  const OrderPage({super.key, required this.orders});
  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    if (orders.orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Order History'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 70, color: sch.outline),
              const SizedBox(height: 12),
              Text(tr('No orders yet'), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Order History'))),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.orders.length,
        itemBuilder: (_, i) {
          final o = orders.orders[i];
          final statusColor = sch.primary;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: sch.outlineVariant)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: sch.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${tr('Order')} #${o.id}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(o.status,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sch.onPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(tr('Date') +
                          ': ${o.date.toLocal().toString().split(' ')[0]}'),
                    ],
                  ),
                  const Divider(height: 22),
                  Text(tr('Items'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sch.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Column(
                    children: o.items.map((it) {
                      final p = it.product;
                      final sub = it.subtotal.toStringAsFixed(2);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(p.thumbnail,
                                  width: 44, height: 44, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(p.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            Text('×${it.quantity}  ',
                                style:
                                    TextStyle(color: sch.onSurfaceVariant)),
                            Text('\$$sub',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 10),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(o.deliveryAddress,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(tr('Total'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('\$${o.total.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: sch.primary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}