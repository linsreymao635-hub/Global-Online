import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../presenters/presenters.dart';
import '../repositories/repositories.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'admin_sections.dart';

/// Polished Dark-mode color scheme shared by the admin panel and the app
/// root, so the shop, login and admin all switch to the SAME dark look:
/// deep indigo surfaces with the brand accent kept alive and readable.
const ColorScheme adminDarkColorScheme = ColorScheme.dark(
  primary: Color(0xFF9D92FF),
  onPrimary: Color(0xFF18105F),
  primaryContainer: Color(0xFF3F36B0),
  onPrimaryContainer: Color(0xFFE5E1FF),
  secondary: Color(0xFFC9C4FF),
  onSecondary: Color(0xFF2A2570),
  secondaryContainer: Color(0xFF3A348C),
  onSecondaryContainer: Color(0xFFE0DCFC),
  tertiary: Color(0xFFF2A9B5),
  onTertiary: Color(0xFF5C1A28),
  error: Color(0xFFFF7373),
  onError: Color(0xFF400000),
  errorContainer: Color(0xFF932323),
  onErrorContainer: Color(0xFFFFDAD5),
  surface: Color(0xFF151A26),
  onSurface: Color(0xFFE7EAF3),
  surfaceDim: Color(0xFF11151F),
  surfaceBright: Color(0xFF333A4B),
  surfaceContainerLowest: Color(0xFF0E121B),
  surfaceContainerLow: Color(0xFF131823),
  surfaceContainer: Color(0xFF151A26),
  surfaceContainerHigh: Color(0xFF1C2231),
  surfaceContainerHighest: Color(0xFF232A3B),
  onSurfaceVariant: Color(0xFFA8AFC4),
  outline: Color(0xFF525B72),
  outlineVariant: Color(0xFF293042),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE7EAF3),
  onInverseSurface: Color(0xFF12161F),
  inversePrimary: Color(0xFF6154E8),
);

/// SideQuest-style admin dashboard: fixed sidebar, top bar with admin chip,
/// and wide data tables (Companies / Categories / Products / Users / Orders).
/// All data lives in the shared Supabase backend, so what the admin changes
/// is what every shopper sees on every device.
class AdminPanelPage extends StatefulWidget {
  final User admin;
  final AdminRepository repo;
  final OrderPresenter orders;

  /// Called when the admin logs out from the sidebar/top bar. Clears the
  /// session in the app root so the app returns to the LOGIN page instead
  /// of the shop page.
  final VoidCallback? onLogout;

  /// Current theme state so the admin Settings page and the top-bar toggle
  /// show the right icon; toggling it rebuilds the whole app via the root.
  final bool dark;
  final ValueChanged<bool>? setTheme;

  /// Lets the admin Settings page switch the whole app's language live.
  final void Function(Locale)? setLocale;
  const AdminPanelPage(
      {super.key,
      required this.admin,
      required this.repo,
      required this.orders,
      this.dark = false,
      this.setTheme,
      this.onLogout,
      this.setLocale});

  @override
  State<AdminPanelPage> createState() => AdminPanelPageState();
}

class AdminPanelPageState extends State<AdminPanelPage> {
  String _page = 'companies'; // default landing page

  // Local theme state: the pushed route is never rebuilt with a fresh
  // `widget.dark`, so keep the value here and mirror it to the app root
  // (the same pattern the shopper Settings page uses).
  late bool _dark = widget.dark;

  // Cached data shared between pages (loaded once, refreshed on demand).
  List<Product> _products = [];
  List<Category> _cats = [];
  List<User> _users = [];
  List<Order> _orders = [];
  List<FeedbackItem> _feedbacks = [];
  bool _loading = true;
  String? _error;
  User? _selectedUser; // detail view opened from the Users list
  Order? _selectedOrder; // detail view opened from the Orders list
  Product? _selectedProduct; // detail view (Products + Shops pages)
  Category? _selectedCategory; // detail view opened from the Categories list
  FeedbackItem? _selectedFeedback; // detail view opened from the Feedback list
  int _userPage = 0,
      _orderPage = 0,
      _productPage = 0,
      _catPage = 0,
      _feedbackPage = 0;

  // Slug of the category row that was just saved to the editor dialog, so
  // the Categories table can highlight it for a couple of seconds.
  String? _justEditedSlug;
  Timer? _clearEditedTimer;

  // Live feedback: a Supabase realtime subscription pushes new feedback
  // the moment a shopper submits it; the periodic timer re-fetches every
  // 20s as a fallback (realtime may be unavailable or slightly delayed).
  Timer? _feedbackPoll;
  bool _loadingFeedback = false;

  // Live users: the same push+poll pattern as feedback, for the Users
  // table. A Supabase realtime subscription fires the moment a shopper
  // signs up / signs in (a new row in the shared cloud directory) and the
  // periodic timer quietly re-fetches every 20s as a fallback, so a new
  // user appears on the Users page instantly — even while the admin is
  // already looking at that page.
  Timer? _usersPoll;
  bool _loadingUsers = false;

  // Live orders: the same push+poll pattern, so a NEW order placed by a
  // shopper (a new row in the shared `orders` table) appears on the
  // Orders page instantly — even while the admin is already looking at
  // it. The realtime subscription fires on insert (new order) and update
  // (status change); a fast 6s periodic timer quietly re-fetches as the
  // fallback when realtime is unavailable.
  Timer? _ordersPoll;
  bool _loadingOrders = false;

  // Live filters for the searchable tables.
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
    // Push-based live updates (no refresh needed).
    widget.repo.supa.watchFeedback(_onLiveFeedback);
    // Fallback: quietly refresh feedback every 20 seconds.
    _feedbackPoll =
        Timer.periodic(const Duration(seconds: 20), (_) => _onLiveFeedback());
    // Live Users table: realtime insert events + the same 20s poll
    // fallback, so signups/sign-ins show up without leaving the page.
    widget.repo.supa
        .watchUsers(onInsert: _onLiveUsers, onDelete: (_) => _onLiveUsers());
    _usersPoll =
        Timer.periodic(const Duration(seconds: 20), (_) => _onLiveUsers());
    // Live Orders table: realtime insert (new order) + update (status
    // change) events + a fast 3s poll fallback, so a shopper's new
    // order appears on the Orders page almost instantly — without the
    // admin leaving the page (realtime pushes it the moment it happens;
    // the poll guarantees it even when realtime is unavailable or slow).
    widget.repo.supa
        .watchOrders(onInsert: _onLiveOrders, onChanged: _onLiveOrders);
    _ordersPoll =
        Timer.periodic(const Duration(seconds: 3), (_) => _onLiveOrders());
  }

  @override
  void dispose() {
    _clearEditedTimer?.cancel();
    _feedbackPoll?.cancel();
    _usersPoll?.cancel();
    _ordersPoll?.cancel();
    widget.repo.supa.cancelFeedbackWatch();
    widget.repo.supa.cancelUsersWatch();
    widget.repo.supa.cancelOrdersWatch();
    super.dispose();
  }

  /// A new feedback may have arrived (realtime event or the 20s poll):
  /// quietly refetch ONLY feedback so the page never flickers.
  Future<void> _onLiveFeedback() async {
    if (_loadingFeedback || !mounted) return;
    _loadingFeedback = true;
    try {
      final feedbacks = await widget.repo.feedbacks();
      if (!mounted) return;
      final known = _feedbacks.map((f) => f.id).toSet();
      final fresh = feedbacks.where((f) => !known.contains(f.id)).toList();
      setState(() => _feedbacks = feedbacks);
      if (_feedbacks.isNotEmpty && fresh.isNotEmpty && _page != 'feedback') {
        _toast(AppLocalizations.of(context).t('New feedback received'));
      }
    } catch (_) {
      // Offline — keep showing the current list.
    } finally {
      _loadingFeedback = false;
    }
  }

  /// The user list may have changed (new signup/sign-in pushed by realtime
  /// or picked up by the 20s poll, or an account deleted on another
  /// device): quietly refetch ONLY users so the page never flickers.
  Future<void> _onLiveUsers() async {
    if (_loadingUsers || !mounted) return;
    _loadingUsers = true;
    try {
      // Small delay to ensure the database transaction is fully committed
      // and visible to SELECT queries after a realtime insert event.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final users = await widget.repo.users();
      if (!mounted) return;
      final known = _users.map((u) => u.username).toSet();
      final fresh = users.where((u) => !known.contains(u.username)).toList();
      setState(() => _users = users);
      if (_users.isNotEmpty && fresh.isNotEmpty && _page != 'users') {
        _toast(AppLocalizations.of(context).t('New user signed in'));
      }
    } catch (_) {
      // Offline — keep showing the current list.
    } finally {
      _loadingUsers = false;
    }
  }

  /// The order list may have changed (a shopper placed a NEW order, pushed
  /// by realtime or picked up by the poll, or an order's status was
  /// changed on another device): quietly refetch ONLY orders so the page
  /// never flickers and existing rows are never duplicated (the whole
  /// list is replaced with the freshest cloud data, newest first — so the
  /// admin always sees exactly what the database holds).
  Future<void> _onLiveOrders() async {
    if (_loadingOrders || !mounted) return;
    _loadingOrders = true;
    try {
      // Small delay to ensure the database transaction is fully committed
      // and visible to SELECT queries after a realtime insert/update event.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final orders = await widget.repo.orders();
      if (!mounted) return;
      final byId = {for (final o in _orders) o.id: o};
      final newOnes = orders.where((o) => !byId.containsKey(o.id)).toList();
      final statusChanged = orders.where((o) {
        final old = byId[o.id];
        return old != null && old.status != o.status;
      }).toList();
      // Rebuild only when something actually changed (a new order, a status
      // change, or the row count moved). On quiet polls the page keeps its
      // current frame so repeated quiet refreshes never flash the table.
      if (newOnes.isNotEmpty ||
          statusChanged.isNotEmpty ||
          orders.length != _orders.length) {
        setState(() => _orders = orders);
      }
      if (_orders.isNotEmpty &&
          (newOnes.isNotEmpty || statusChanged.isNotEmpty) &&
          _page != 'orders') {
        _toast(AppLocalizations.of(context).t('New order received'));
      }
    } catch (_) {
      // Offline — keep showing the current list.
    } finally {
      _loadingOrders = false;
    }
  }

  Future<void> _reload() async {
    setState(() {
      // Only the very first load shows the full-page spinner; refreshes
      // keep the current content visible until fresh data arrives.
      if (_products.isEmpty &&
          _cats.isEmpty &&
          _users.isEmpty &&
          _orders.isEmpty &&
          _feedbacks.isEmpty) {
        _loading = true;
      }
      _error = null;
    });
    // Fire all five backend reads at the SAME time and wait for the whole
    // batch, so a page (Orders included) fills in as fast as the slowest
    // request instead of the sum of five sequential round-trips. A failed
    // dataset is recorded but never aborts the others.
    String? reloadError;
    List<Product>? products;
    List<Category>? cats;
    List<User>? users;
    List<Order>? orders;
    List<FeedbackItem>? feedbacks;
    await Future.wait<void>([
      widget.repo
          .products()
          .then<void>((v) => products = v)
          .catchError((Object e) {
        reloadError = e.toString();
      }),
      widget.repo
          .categories()
          .then<void>((v) => cats = v)
          .catchError((Object e) {
        reloadError = e.toString();
      }),
      widget.repo.users().then<void>((v) => users = v).catchError((Object e) {
        reloadError = e.toString();
      }),
      widget.repo.orders().then<void>((v) => orders = v).catchError((Object e) {
        reloadError = e.toString();
      }),
      widget.repo
          .feedbacks()
          .then<void>((v) => feedbacks = v)
          .catchError((Object e) {
        reloadError = e.toString();
      }),
    ]);
    if (!mounted) return;
    setState(() {
      if (products != null) _products = products!;
      if (cats != null) _cats = cats!;
      if (users != null) _users = users!;
      if (orders != null) _orders = orders!;
      if (feedbacks != null) _feedbacks = feedbacks!;
      _loading = false;
      _error = reloadError;
    });
  }

  /// Refetch only the categories in the background (no spinner) so it can
  /// be called right after the admin edits one — the list just updates.
  Future<void> _refreshCats() async {
    try {
      final cats = await widget.repo.categories();
      if (!mounted) return;
      setState(() => _cats = cats);
    } catch (_) {}
  }

  /// Refetch only the products in the background (no spinner) after the
  /// admin saves a product/company edit — the row is already updated
  /// locally, this just reconciles with Supabase / other devices.
  Future<void> _refreshProducts() async {
    try {
      final products = await widget.repo.products();
      if (!mounted) return;
      setState(() => _products = products);
    } catch (_) {}
  }

  /// Apply a saved product/company to the in-memory list immediately so the
  /// edit is visible the moment the dialog closes (before any network
  /// refresh). New rows are pinned to the top.
  void _applySavedProduct(Product saved) {
    setState(() {
      final i = _products.indexWhere((x) => x.id == saved.id);
      if (i >= 0) {
        _products[i] = saved;
      } else {
        _products.insert(0, saved);
      }
    });
  }

  // ------------------------------------------------------------- navigation

  void _go(String page) {
    if (page == 'logout') {
      _logout();
      return;
    }
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedUser = null;
      _selectedOrder = null;
      _selectedProduct = null;
      _selectedCategory = null;
      _selectedFeedback = null;
      _search = '';
      _userPage = _orderPage = _productPage = _catPage = _feedbackPage = 0;
    });
    _reload();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), width: 340, behavior: SnackBarBehavior.floating));

  /// Admin logout: clear the session FIRST (so the app root swaps its home
  /// to the login page), then close the panel itself. Result: Logout in the
  /// admin always lands on the Sign In page — never the shop.
  void _logout() {
    widget.onLogout?.call();
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- sidebar

  Widget _sideItem(IconData icon, String label, String key) {
    final sel = _page == key;
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: sel ? const Color(0xFF5B4FE9) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _go(key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon,
                  size: 18, color: sel ? Colors.white : sch.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : sch.onSurface)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    return Container(
      width: 210,
      color: sch.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header exactly 64px tall — the SAME height as the top bar — with
        // the same bottom border, so the two header lines line up as one
        // continuous equal line across the whole screen.
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: sch.outlineVariant)),
          ),
          child: Center(
            // Real shop logo, centered in the header.
            child: Image.asset('assets/images/image.png',
                height: 38, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _sideItem(Icons.dashboard_outlined, tr('Dashboard'), 'dashboard'),
            _sideItem(Icons.storefront_outlined, tr('Shops'), 'companies'),
            _sideItem(Icons.category_outlined, tr('Categories'), 'categories'),
            _sideItem(Icons.inventory_2_outlined, tr('Products'), 'products'),
            _sideItem(Icons.people_outline, tr('Users'), 'users'),
            _sideItem(Icons.receipt_long_outlined, tr('Orders'), 'orders'),
            _sideItem(Icons.rate_review_outlined, tr('Feedback'), 'feedback'),
            _sideItem(Icons.bar_chart_outlined, tr('Reports'), 'reports'),
            _sideItem(Icons.settings_outlined, tr('Settings'), 'settings'),
            _sideItem(Icons.verified_user_outlined, tr('Administration'),
                'administration'),
          ]),
        ),
        Divider(height: 1, color: sch.outlineVariant),
        _sideItem(Icons.logout, tr('Logout'), 'logout'),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ---------------------------------------------------------------- top bar

  Widget _topBar() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    final currentLang = AppLocalizations.of(context).locale.languageCode;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: sch.surface,
        border: Border(bottom: BorderSide(color: sch.outlineVariant)),
      ),
      child: Row(children: [
        // Page title with a live record count under it.
        Expanded(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pageTitle,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_pageSubtitle,
                    style:
                        TextStyle(fontSize: 12, color: sch.onSurfaceVariant)),
              ]),
        ),
        // Language switcher: quick EN/KM toggle next to the profile chip.
        PopupMenuButton<String>(
          tooltip: tr('Language'),
          onSelected: (code) async {
            if (code == currentLang) return;
            await AppSettings.saveLanguage(code);
            if (!mounted) return;
            widget.setLocale?.call(Locale(code));
          },
          itemBuilder: (c) => [
            PopupMenuItem(
                value: 'en',
                child: Row(children: [
                  Icon(
                      currentLang == 'en'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: currentLang == 'en'
                          ? const Color(0xFF5B4FE9)
                          : sch.outline),
                  const SizedBox(width: 10),
                  const Text('\u{1F1EC}\u{1F1E7}  English'),
                ])),
            PopupMenuItem(
                value: 'km',
                child: Row(children: [
                  Icon(
                      currentLang == 'km'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: currentLang == 'km'
                          ? const Color(0xFF5B4FE9)
                          : sch.outline),
                  const SizedBox(width: 10),
                  const Text('\u{1F1F0}\u{1F1ED}  ភាសាខ្មែរ'),
                ])),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sch.outlineVariant),
                color: sch.surface),
            child: Row(children: [
              Icon(Icons.language_outlined,
                  size: 18, color: sch.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(currentLang.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        // Theme switcher: Light/Dark mode, styled like the language chip
        // that sits right next to it, so the whole top bar stays even.
        PopupMenuButton<bool>(
          tooltip: tr('Theme'),
          initialValue: _dark,
          onSelected: (dark) {
            setState(() => _dark = dark);
            widget.setTheme?.call(dark);
          },
          itemBuilder: (c) => [
            PopupMenuItem(
                value: false,
                child: Row(children: [
                  Icon(
                      !_dark
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: !_dark ? const Color(0xFF5B4FE9) : sch.outline),
                  const SizedBox(width: 10),
                  const Icon(Icons.light_mode_outlined, size: 17),
                  const SizedBox(width: 8),
                  Text(tr('Light mode')),
                ])),
            PopupMenuItem(
                value: true,
                child: Row(children: [
                  Icon(
                      _dark
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: _dark ? const Color(0xFF5B4FE9) : sch.outline),
                  const SizedBox(width: 10),
                  const Icon(Icons.dark_mode_outlined, size: 17),
                  const SizedBox(width: 8),
                  Text(tr('Dark mode')),
                ])),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sch.outlineVariant),
                color: sch.surface),
            child: Row(children: [
              Icon(_dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 18, color: sch.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_dark ? tr('Dark') : tr('Light'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        // Admin identity chip: profile photo (or gradient initial), name
        // and email. Clicking it opens the profile card with the full
        // account details (name, role, email, phone, username, ...).
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showProfileCard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sch.outlineVariant),
                color: sch.surface),
            child: Row(children: [
              // Profile photo when the admin has one, otherwise a gradient
              // avatar with the first letter of the name.
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _adminAvatarImage == null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)])
                      : null,
                  color:
                      _adminAvatarImage == null ? null : sch.primaryContainer,
                  image: _adminAvatarImage != null
                      ? DecorationImage(
                          image: _adminAvatarImage!, fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: _adminAvatarImage == null
                    ? Text(
                        widget.admin.fullName.isNotEmpty
                            ? widget.admin.fullName
                                .substring(0, 1)
                                .toUpperCase()
                            : 'A',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.admin.fullName.isNotEmpty
                            ? widget.admin.fullName
                            : 'Admin',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(widget.admin.email,
                        style: TextStyle(
                            fontSize: 10, color: sch.onSurfaceVariant)),
                  ]),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: sch.onSurfaceVariant),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The signed-in admin merged with their OWN locally saved profile edits
  /// (photo changed in the profile card) so the chip stays fresh.
  User get _admin {
    final saved =
        AppSettings.savedProfileFor(AppSettings.profileKeyOf(widget.admin));
    if (saved == null) return widget.admin;
    return User(
        id: widget.admin.id,
        firstName: saved.firstName,
        lastName: saved.lastName,
        username: saved.username,
        email: saved.email,
        phone: saved.phone.isNotEmpty ? saved.phone : widget.admin.phone,
        image: saved.image ?? widget.admin.image,
        token: widget.admin.token,
        isAdmin: widget.admin.isAdmin);
  }

  /// Profile photo of the signed-in admin (network or base64), or null to
  /// fall back to the gradient initial avatar.
  ImageProvider? get _adminAvatarImage {
    final img = _admin.image;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('b64:')) {
      try {
        return MemoryImage(base64Decode(img.substring(4)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(img);
  }

  // ------------------------------------------------------------ profile card

  /// Opens the admin profile card: large photo (tap the camera badge to
  /// change it), name, role badge and every account detail (email, phone,
  /// username, user id) plus quick refresh / logout actions.
  void _showProfileCard() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        // Re-read the merged admin on every rebuild so a freshly picked
        // photo shows up immediately without closing the card.
        final admin = _admin;
        final name = admin.fullName.isNotEmpty ? admin.fullName : 'Admin';
        return Dialog(
          backgroundColor: sch.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            // ONE Stack holds the whole card so the avatar AND its camera
            // badge stay inside the Stack's hit-test bounds: Flutter renders
            // children painted outside a Stack (Clip.none) but never delivers
            // taps there — which is why the badge was not clickable before.
            child: Stack(alignment: Alignment.topCenter, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                // Gradient header band.
                Container(
                  height: 86,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)]),
                  ),
                ),
                // Room for the lower half of the overlapping avatar
                // (avatar bottom at y=132) plus an 8px gap before the name.
                const SizedBox(height: 54),
                Text(name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                // Role badge.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4FE9).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(tr('Super Admin'),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Color(0xFF5B4FE9))),
                ),
                const SizedBox(height: 14),
                _profileRow(Icons.alternate_email, tr('Username'),
                    admin.username.isNotEmpty ? admin.username : '—'),
                _profileRow(Icons.mail_outline, tr('Email'),
                    admin.email.isNotEmpty ? admin.email : '—'),
                _profileRow(Icons.phone_outlined, tr('Phone'),
                    admin.phone.isNotEmpty ? admin.phone : '—'),
                _profileRow(
                    Icons.badge_outlined, tr('User ID'), admin.id.toString()),
                const Divider(height: 20),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(tr('Cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE5484D),
                            foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _logout();
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(tr('Logout')),
                      ),
                    ),
                  ]),
                ),
              ]),
              // Avatar straddling the header edge — positioned INSIDE the
              // card Stack's bounds (top: 48 = 86 header - 38 half avatar)
              // so taps reach it. The 84x84 box leaves room at the edge for
              // the badge, keeping every pixel of it clickable.
              Positioned(
                top: 48,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(alignment: Alignment.center, children: [
                    // Tapping the big avatar also opens the change-photo
                    // sheet (bigger target than the badge alone).
                    GestureDetector(
                      onTap: () => _changePhoto(setDialogState),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _adminAvatarImage == null
                              ? null
                              : sch.primaryContainer,
                          gradient: _adminAvatarImage == null
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                      Color(0xFF5B4FE9),
                                      Color(0xFF9C6ADE)
                                    ])
                              : null,
                          image: _adminAvatarImage != null
                              ? DecorationImage(
                                  image: _adminAvatarImage!, fit: BoxFit.cover)
                              : null,
                          border: Border.all(color: sch.surface, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: _adminAvatarImage == null
                            ? Text(name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))
                            : null,
                      ),
                    ),
                    // Camera badge = change the photo. Sits at the edge of
                    // the 84x84 box, fully inside hit-test bounds.
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: () => _changePhoto(setDialogState),
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: sch.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: sch.surface, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  /// One labelled row of the profile card.
  Widget _profileRow(IconData icon, String label, String value) {
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: sch.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: sch.onSurfaceVariant))),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------- photo picker

  /// Change the admin profile photo: pick from the gallery, enter an image
  /// URL, or remove the current photo. Saved per account with
  /// [AppSettings.saveProfile] — the same store the shopper Edit Profile
  /// page uses — and applied everywhere at once (chip + card avatar).
  Future<void> _changePhoto([StateSetter? setDialogState]) async {
    final tr = AppLocalizations.of(context).t;
    final hasPhoto = _adminAvatarImage != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (bc) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(tr('Remove photo')),
              onTap: () => Navigator.pop(bc, 'remove'),
            ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'gallery') return _pickFromGallery(setDialogState);
    if (choice == 'url') return _askImageUrl(setDialogState);
    if (choice == 'remove') return _saveAdminImage(null, setDialogState);
  }

  Future<void> _pickFromGallery([StateSetter? setDialogState]) async {
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 900,
          maxHeight: 900,
          imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      await _saveAdminImage('b64:${base64Encode(bytes)}', setDialogState);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).t(
              'Could not open the gallery. Please try entering an image URL.'))));
    }
  }

  Future<void> _askImageUrl([StateSetter? setDialogState]) async {
    final tr = AppLocalizations.of(context).t;
    // Only prefill when the current photo is a URL (never a huge base64
    // blob from a gallery pick).
    final current = _admin.image;
    final ctrl = TextEditingController(
        text:
            current != null && current.isNotEmpty && !current.startsWith('b64:')
                ? current
                : '');
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
              onPressed: () => Navigator.pop(dc), child: Text(tr('Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(dc, ctrl.text.trim()),
              child: Text(tr('OK'))),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    await _saveAdminImage(url, setDialogState);
  }

  /// Persist the new photo for the admin account and refresh the UI so the
  /// top-bar chip and the profile card both show it right away.
  Future<void> _saveAdminImage(String? image,
      [StateSetter? setDialogState]) async {
    final a = _admin;
    final u = User(
        id: a.id,
        firstName: a.firstName,
        lastName: a.lastName,
        username: a.username,
        email: a.email,
        phone: a.phone,
        image: image,
        token: a.token,
        isAdmin: a.isAdmin);
    await AppSettings.saveProfile(u,
        forKey: AppSettings.profileKeyOf(widget.admin));
    if (!mounted) return;
    setState(() {});
    setDialogState?.call(() {});
  }

  /// The top bar always greets with the shop name, no matter which page
  /// (Companies / Categories / Products / ...) is selected.
  String get _pageTitle {
    final tr = AppLocalizations.of(context).t;
    return tr('Welcome to Global Online');
  }

  /// Kept in sync with the title: the greeting never changes between pages.
  String get _pageSubtitle {
    final tr = AppLocalizations.of(context).t;
    return tr('Welcome to Global Online');
  }

  // ------------------------------------------------------------------ body

  /// Applies the selected Light/Dark theme to the whole panel via a local
  /// [Theme] wrapper — so the color actually switches the moment `_dark`
  /// flips, even if the app root's callback is ever missing.
  ThemeData get _panelTheme => ThemeData(
      useMaterial3: true,
      colorScheme: _dark
          ? adminDarkColorScheme
          : ColorScheme.fromSeed(seedColor: Colors.blue));

  /// True while any list's detail view is open. Browser/system back should
  /// close the detail view FIRST and only pop the whole admin panel once no
  /// detail is open (otherwise back jumps straight out to the shop).
  bool get _detailOpen =>
      _selectedUser != null ||
      _selectedOrder != null ||
      _selectedProduct != null ||
      _selectedCategory != null ||
      _selectedFeedback != null;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _panelTheme,
      child: PopScope(
        canPop: !_detailOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Back was pressed while a detail view is open: close it and
          // return to the underlying table instead of leaving the panel.
          setState(() {
            _selectedUser = null;
            _selectedOrder = null;
            _selectedProduct = null;
            _selectedCategory = null;
            _selectedFeedback = null;
          });
        },
        child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: Row(children: [
          _sidebar(),
          Expanded(
            child: Column(children: [
              _topBar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _errorView()
                        : _pageBody(),
              ),
            ]),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _errorView() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off, size: 56, color: sch.outline),
        const SizedBox(height: 12),
        Text(tr('No connection'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: Text(tr('Retry'))),
      ]),
    );
  }

  List<Product> get _filteredProducts {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
  }

  List<User> get _filteredUsers {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users
        .where((u) =>
            u.username.toLowerCase().contains(q) ||
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.toLowerCase().contains(q))
        .toList();
  }

  List<Order> get _filteredOrders {
    final list = _orders;
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list
        .where((o) =>
            o.id.toLowerCase().contains(q) ||
            o.owner.toLowerCase().contains(q) ||
            o.status.toLowerCase().contains(q))
        .toList();
  }

  List<FeedbackItem> get _filteredFeedbacks {
    if (_search.isEmpty) return _feedbacks;
    final q = _search.toLowerCase();
    return _feedbacks
        .where((f) =>
            f.name.toLowerCase().contains(q) ||
            f.owner.toLowerCase().contains(q) ||
            f.message.toLowerCase().contains(q))
        .toList();
  }

  List<Category> get _filteredCats {
    if (_search.isEmpty) return _cats;
    final q = _search.toLowerCase();
    return _cats
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.slug.toLowerCase().contains(q))
        .toList();
  }

  Widget _pageBody() {
    switch (_page) {
      case 'dashboard':
        return _dashboardGrid();
      case 'categories':
        return _selectedCategory != null
            ? CategoryDetailPage(
                category: _selectedCategory!,
                onBack: () => setState(() => _selectedCategory = null))
            : CategoriesTablePage(
                cats: _filteredCats,
                total: _cats.length,
                page: _catPage,
                editedSlug: _justEditedSlug,
                onPage: (p) => setState(() => _catPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _catPage = 0;
                    }),
                onAdd: _addCategory,
                onOpen: (c) => setState(() => _selectedCategory = c),
                onEdit: _editCategory,
                onDelete: _deleteCategory);
      case 'products':
        return _selectedProduct != null
            ? ProductDetailPage(
                product: _selectedProduct!,
                onBack: () => setState(() => _selectedProduct = null))
            : ProductsTablePage(
                products: _filteredProducts,
                total: _products.length,
                page: _productPage,
                onPage: (p) => setState(() => _productPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _productPage = 0;
                    }),
                onAdd: () => _editProduct(),
                onOpen: (p) => setState(() => _selectedProduct = p),
                onEdit: _editProduct,
                onDelete: _deleteProduct);
      case 'users':
        return _selectedUser != null
            ? UserDetailPage(
                user: _selectedUser!,
                onBack: () => setState(() => _selectedUser = null))
            : UsersTablePage(
                users: _filteredUsers,
                total: _users.length,
                page: _userPage,
                onPage: (p) => setState(() => _userPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _userPage = 0;
                    }),
                onOpen: (u) => setState(() => _selectedUser = u),
                onDelete: _deleteUser);
      case 'orders':
        return _selectedOrder != null
            ? OrderDetailPage(
                order: _selectedOrder!,
                onBack: () => setState(() => _selectedOrder = null),
                onDelete: () => _deleteOrder(_selectedOrder!))
            : OrdersTablePage(
                orders: _filteredOrders,
                allOrders: _orders,
                total: _filteredOrders.length,
                page: _orderPage,
                onPage: (p) => setState(() => _orderPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _orderPage = 0;
                    }),
                onOpen: (o) => setState(() => _selectedOrder = o),
                onStatus: _changeStatus);
      case 'reports':
        return ReportsPage(orders: _orders, products: _products, users: _users);
      case 'settings':
        return AdminSettingsPage();
      case 'administration':
        return AdministrationPage(
            users: _users,
            repo: widget.repo,
            onUsersChanged: () => _onLiveUsers());
      case 'feedback':
        return _selectedFeedback != null
            ? FeedbackDetailPage(
                feedback: _selectedFeedback!,
                onBack: () => setState(() => _selectedFeedback = null))
            : FeedbackTablePage(
                feedbacks: _filteredFeedbacks,
                total: _feedbacks.length,
                page: _feedbackPage,
                onPage: (p) => setState(() => _feedbackPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _feedbackPage = 0;
                    }),
                onOpen: (f) => setState(() => _selectedFeedback = f),
                onDelete: _deleteFeedback);
      default:
        return _selectedProduct != null
            ? ShopDetailPage(
                shop: _selectedProduct!,
                onBack: () => setState(() => _selectedProduct = null))
            : CompaniesTablePage(
                products: _filteredProducts,
                total: _products.length,
                page: _productPage,
                onPage: (p) => setState(() => _productPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _productPage = 0;
                    }),
                onAdd: () => _editCompany(),
                onOpen: (p) => setState(() => _selectedProduct = p),
                onEdit: _editCompany,
                onDelete: _deleteProduct);
    }
  }

  Widget _placeholder() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_outlined, size: 54, color: sch.outline),
      const SizedBox(height: 10),
      Text(tr('This page is coming soon'),
          style: TextStyle(color: sch.onSurfaceVariant)),
    ]));
  }

  Widget _dashboardGrid() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;

    // ---- live stats computed from the shared backend data ----
    final totalOrders = _orders.length;
    final revenue = _orders
        .where((o) => o.status != 'Cancelled')
        .fold<num>(0, (s, o) => s + o.total);
    final inStock = _products.where((p) => p.stock > 0).length;
    final lowStock = _products.where((p) => p.stock <= 5).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final recent = [..._orders]..sort((a, b) => b.date.compareTo(a.date));

    Color statusColor(String s) {
      switch (s) {
        case 'Processing':
          return Colors.orange;
        case 'Shipped':
          return Colors.blue;
        case 'Delivered':
          return Colors.green;
        default:
          return Colors.redAccent;
      }
    }

    // ------------------------------------------------------------- sections

    /// Generic card with a heading, an optional "View All" action and the
    /// section body.
    Widget sectionCard(String title, List<Widget> children,
        {VoidCallback? onViewAll}) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sch.outlineVariant)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
            if (onViewAll != null)
              TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(tr('View All'),
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF5B4FE9)))),
          ]),
          const SizedBox(height: 6),
          ...children,
        ]),
      );
    }

    /// Thin rounded proportion bar used for the order health + category
    /// shares. frac is clamped so an empty data set never overflows.
    Widget progress(Color color, double frac) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
            color: sch.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: frac.clamp(0.0, 1.0),
          child: Container(
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(99))),
        ),
      );
    }

    // ------------------------------------------------------------- KPI tiles

    final kpis = <_KpiSpec>[
      _KpiSpec(
          icon: Icons.attach_money,
          title: tr('Total Revenue'),
          value: '\$${revenue.toStringAsFixed(2)}',
          gradient: const [Color(0xFF5B4FE9), Color(0xFF7B6BEF)],
          onTap: () => _go('orders')),
      _KpiSpec(
          icon: Icons.receipt_long_outlined,
          title: tr('Total Orders'),
          value: '$totalOrders',
          gradient: const [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
          onTap: () => _go('orders')),
      _KpiSpec(
          icon: Icons.people_outline,
          title: tr('Customers'),
          value: '${_users.length}',
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
          onTap: () => _go('users')),
      _KpiSpec(
          icon: Icons.inventory_2_outlined,
          title: tr('Products'),
          value: '$inStock/${_products.length}',
          gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          onTap: () => _go('products')),
      _KpiSpec(
          icon: Icons.storefront_outlined,
          title: tr('Shops'),
          value: '${_products.length}',
          gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
          onTap: () => _go('companies')),
      _KpiSpec(
          icon: Icons.category_outlined,
          title: tr('Categories'),
          value: '${_cats.length}',
          gradient: const [Color(0xFFEC4899), Color(0xFFF472B6)],
          onTap: () => _go('categories')),
    ];

    Widget kpiTile(_KpiSpec k) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: k.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: sch.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sch.outlineVariant)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: k.gradient),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(k.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(k.value,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 2),
                    Text(k.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: sch.onSurfaceVariant)),
                  ]),
            ),
          ]),
        ),
      );
    }

    // ------------------------------------------------------- order health

    final statuses = ['Processing', 'Shipped', 'Delivered', 'Cancelled'];
    Widget statusCard() {
      return sectionCard(
          tr('Order Status'),
          statuses.map((s) {
            final count = _orders.where((o) => o.status == s).length;
            final frac = _orders.isEmpty ? 0.0 : count / _orders.length;
            return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(tr(s),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        Text('$count',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      progress(statusColor(s), frac),
                    ]));
          }).toList(),
          onViewAll: () => _go('orders'));
    }

    // ------------------------------------------------- recent orders

    Widget orderRow(Order o) {
      final d = o.date.toLocal();
      final id = o.id.length > 8 ? o.id.substring(0, 8) : o.id;
      return InkWell(
        onTap: () => _go('orders'),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: sch.primaryContainer,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    o.owner.isEmpty
                        ? '#'
                        : o.owner.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: sch.onPrimaryContainer)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.owner.isEmpty ? tr('Guest') : o.owner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('#$id  •  ${d.day}/${d.month}/${d.year}',
                          style: TextStyle(
                              fontSize: 11, color: sch.onSurfaceVariant)),
                    ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${o.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Pill(tr(o.status), color: statusColor(o.status)),
              ]),
            ])),
      );
    }

    Widget recentCard() {
      return sectionCard(
          tr('Recent Orders'),
          recent.isEmpty
              ? [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('No orders yet'),
                              style: TextStyle(
                                  fontSize: 12, color: sch.onSurfaceVariant))))
                ]
              : recent.take(6).map(orderRow).toList(),
          onViewAll: () => _go('orders'));
    }

    // ------------------------------------------------------ low stock

    Widget lowCard() {
      return sectionCard(
          tr('Low Stock'),
          lowStock.isEmpty
              ? [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('All products in stock'),
                              style: TextStyle(
                                  fontSize: 12, color: sch.onSurfaceVariant))))
                ]
              : lowStock.take(5).map((p) {
                  final out = p.stock <= 0;
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Expanded(
                            child: Text(p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 10),
                        Pill(out ? tr('Out of stock') : '${p.stock}',
                            color: out ? Colors.redAccent : Colors.orange),
                      ]));
                }).toList(),
          onViewAll: () => _go('products'));
    }

    // ------------------------------------------------- top categories

    final catCounts = <String, int>{};
    for (final p in _products) {
      final key = p.category.trim().isEmpty ? tr('Unknown') : p.category;
      catCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    final topCats = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = topCats.isNotEmpty ? topCats.first.value : 1;

    Widget catCard() {
      return sectionCard(
          tr('Top Categories'),
          topCats.isEmpty
              ? [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('No categories yet'),
                              style: TextStyle(
                                  fontSize: 12, color: sch.onSurfaceVariant))))
                ]
              : topCats.take(5).map((e) {
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(e.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600))),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 6),
                            progress(const Color(0xFF5B4FE9), e.value / maxCat),
                          ]));
                }).toList(),
          onViewAll: () => _go('categories'));
    }

    // ------------------------------------------------------------ assemble

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.count(
            crossAxisCount: wide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: wide ? 3.4 : 2.5,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: kpis.map(kpiTile).toList(),
          ),
          const SizedBox(height: 18),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: statusCard()),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: recentCard()),
            ])
          else ...[
            statusCard(),
            const SizedBox(height: 14),
            recentCard(),
          ],
          const SizedBox(height: 18),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: lowCard()),
              const SizedBox(width: 14),
              Expanded(child: catCard()),
            ])
          else ...[
            lowCard(),
            const SizedBox(height: 14),
            catCard(),
          ],
        ]),
      );
    });
  }

  // ------------------------------------------------------------ actions

  Future<void> _editProduct([Product? p]) async {
    final tr = AppLocalizations.of(context).t;
    final saved = await showDialog<Product?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminProductEditDialog(repo: widget.repo, existing: p),
    );
    if (saved == null) return;
    _toast(p == null ? tr('Product added') : tr('Changes saved'));
    // Show the edit instantly, then persist (local-first) and reconcile
    // with the cloud in the background so the Save never blocks the UI.
    _applySavedProduct(saved);
    AppSettings.logAdminActivity(
        '${p == null ? 'Added' : 'Updated'} product "${saved.title}"');
    unawaited((p == null ? widget.repo.add(saved) : widget.repo.update(saved))
        .then((_) => _refreshProducts())
        .catchError((_) {}));
  }

  /// Add / Edit from the Shops page: same product rows, but shown and
  /// edited as shops (Shop, Location, Website, Verified, Status...).
  Future<void> _editCompany([Product? p]) async {
    final tr = AppLocalizations.of(context).t;
    final saved = await showDialog<Product?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminCompanyEditDialog(repo: widget.repo, existing: p),
    );
    if (saved == null) return;
    _toast(p == null ? tr('Shop added') : tr('Changes saved'));
    // Show the edit instantly, then persist (local-first) and reconcile
    // with the cloud in the background so the Save never blocks the UI.
    _applySavedProduct(saved);
    AppSettings.logAdminActivity(
        '${p == null ? 'Added' : 'Updated'} shop "${saved.title}"');
    unawaited((p == null ? widget.repo.add(saved) : widget.repo.update(saved))
        .then((_) => _refreshProducts())
        .catchError((_) {}));
  }

  Future<void> _deleteProduct(Product p) async {
    final tr = AppLocalizations.of(context).t;
    final ok = await _confirm('${tr('Delete')} "${p.title}"?');
    if (ok != true) return;
    await widget.repo.delete(p.id);
    AppSettings.logAdminActivity('Deleted product "${p.title}"');
    _toast(tr('Product deleted'));
    _reload();
  }

  Future<void> _deleteFeedback(FeedbackItem f) async {
    final tr = AppLocalizations.of(context).t;
    final ok = await _confirm('${tr('Delete')} ${tr('Feedback')}?');
    if (ok != true) return;
    await widget.repo.deleteFeedback(f.id);
    AppSettings.logAdminActivity('Deleted feedback from @${f.owner}');
    _toast(tr('Feedback deleted'));
    _reload();
  }

  /// Shared Add / Edit Category dialog. Collects the draft on submit, or
  /// returns null when cancelled. The caller persists the change.
  Future<_CategoryDraft?> _showCategoryDialog({Category? category}) {
    return showDialog<_CategoryDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryFormDialog(category: category),
    );
  }

  Future<void> _addCategory() async {
    final tr = AppLocalizations.of(context).t;
    final result = await _showCategoryDialog();
    if (result == null) return;
    await widget.repo.addCategory(result.name,
        slug: result.slug,
        description: result.description,
        image: result.image);
    AppSettings.logAdminActivity('Added category "${result.name.trim()}"');
    _toast(tr('Category added'));
    _reload();
  }

  Future<void> _editCategory(Category c) async {
    final tr = AppLocalizations.of(context).t;
    final result = await _showCategoryDialog(category: c);
    if (result == null) return;
    await widget.repo.updateCategory(c,
        name: result.name,
        slug: result.slug,
        description: result.description,
        image: result.image);
    AppSettings.logAdminActivity(
        'Updated category "${c.name}" → "${result.name.trim()}"');

    // Show the edit immediately on this row (before any network refresh),
    // using the exact same slug/url rules as ApiService.updateCategory.
    final fromName = ApiService.slugify(result.name);
    final safeSlug = ApiService.slugify(result.slug.trim()).isEmpty
        ? fromName
        : ApiService.slugify(result.slug.trim());
    final finalSlug = safeSlug.isEmpty ? 'custom' : safeSlug;
    final updated = Category(
        slug: finalSlug,
        name: result.name.trim(),
        url: '${ApiService.baseUrl}/products/category/$finalSlug',
        description: result.description.trim(),
        image: result.image.trim());
    setState(() {
      final i = _cats.indexWhere((x) => x.slug == c.slug);
      if (i >= 0) {
        _cats[i] = updated;
      } else {
        // The slug changed (or the cloud removed the row): show the edited
        // copy at the top until the quiet refresh reconciles the list.
        _cats.insert(0, updated);
      }
      _justEditedSlug = finalSlug;
    });
    _clearEditedTimer?.cancel();
    _clearEditedTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _justEditedSlug = null);
    });

    _toast('${tr('Category updated')}: ${result.name.trim()}');
    // Quietly refresh to sync with Supabase / other devices.
    _refreshCats();
  }

  Future<void> _deleteCategory(Category c) async {
    final tr = AppLocalizations.of(context).t;
    final ok = await _confirm('${tr('Delete')} "${c.name}"?');
    if (ok != true) return;
    await widget.repo.deleteCategory(c);
    AppSettings.logAdminActivity('Deleted category "${c.name}"');
    _toast(tr('Category deleted'));
    _reload();
  }

  Future<void> _deleteUser(User u) async {
    final tr = AppLocalizations.of(context).t;
    if (u.username.trim().toLowerCase() == ApiService.adminUsername) {
      _toast(tr('Cannot delete the built-in admin account'));
      return;
    }
    final ok = await _confirm('${tr('Delete')} "@${u.username}"?');
    if (ok != true) return;
    await widget.repo.deleteUser(u.username);
    AppSettings.logAdminActivity('Deleted user @${u.username}');
    // Drop the account from the in-memory list right away (no spinner),
    // then quietly reconcile with the cloud — the shopper's app is told
    // through the cloud delete (realtime / poll) to sign out by itself.
    setState(() => _users.removeWhere((x) => x.username == u.username));
    _toast(tr('User deleted'));
    _onLiveUsers();
  }

  Future<void> _changeStatus(Order o, String status) async {
    final tr = AppLocalizations.of(context).t;
    // Show the new status in the table immediately while the cloud write
    // runs, so the admin sees their choice instantly (the refresh after the
    // write re-syncs the row from the database, reverting any failed write).
    setState(() {
      _orders = [
        for (final x in _orders) x.id == o.id ? x.copyWith(status: status) : x,
      ];
    });
    final ok = await widget.orders.setStatus(o.id, status);
    if (!ok) {
      // The optimistic table value was not accepted by the database; restore
      // the last confirmed status immediately instead of leaving a lie onscreen.
      if (mounted) {
        setState(() {
          _orders = [
            for (final x in _orders)
              x.id == o.id ? x.copyWith(status: o.status) : x,
          ];
        });
      }
      _toast(tr('Could not reach the cloud. Status not saved.'));
    } else {
      AppSettings.logAdminActivity('Changed order ${o.id} to $status');
      _toast(tr('Order status updated'));
    }
    // Re-sync the whole list from the database so the table always shows
    // exactly what the cloud holds (single source of truth).
    await _reload();
  }

  /// Admin deletes an order: removes the row from the shared cloud so the
  /// shopper's Order History on every device stops showing it too.
  Future<void> _deleteOrder(Order o) async {
    final tr = AppLocalizations.of(context).t;
    final confirmed = await _confirm(
        '${tr('Delete')} ${tr('Order')} #${o.id.length > 8 ? o.id.substring(0, 8) : o.id}?');
    if (confirmed != true || !mounted) return;
    final deleted = await widget.repo.deleteOrder(o.id);
    if (deleted) {
      await widget.orders.remove(o.id);
      AppSettings.logAdminActivity('Deleted order ${o.id}');
      if (!mounted) return;
      setState(() {
        _selectedOrder = null;
        _orders = _orders.where((x) => x.id != o.id).toList();
      });
      _toast(tr('Order deleted'));
      _reload();
    } else {
      _toast(tr('Could not reach the cloud. Order not deleted.'));
    }
  }

  Future<bool?> _confirm(String message) {
    final tr = AppLocalizations.of(context).t;
    return showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('Are you sure?')),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(tr('Cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dc).colorScheme.error),
              onPressed: () => Navigator.pop(dc, true),
              child: Text(tr('Delete'))),
        ],
      ),
    );
  }
}

/// Values collected by the Add / Edit Category dialog.
class _CategoryDraft {
  final String name, slug, description, image;
  const _CategoryDraft(
      {required this.name,
      required this.slug,
      required this.description,
      required this.image});
}

/// Polished Add / Edit Category dialog: gradient header band, labelled
/// filled fields, live slug auto-generation and an image URL preview.
class _CategoryFormDialog extends StatefulWidget {
  /// When null the dialog is in "Add" mode, otherwise it edits this category.
  final Category? category;
  const _CategoryFormDialog({this.category});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _desc;
  late final TextEditingController _img;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _slug = TextEditingController(text: c?.slug ?? '');
    _desc = TextEditingController(text: c?.description ?? '');
    _img = TextEditingController(text: c?.image ?? '');
    _name.addListener(_refresh);
    _slug.addListener(_refresh);
    _img.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _desc.dispose();
    _img.dispose();
    super.dispose();
  }

  String _deriveSlug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Fill the slug from the typed category name (when the name is valid).
  void _autofillSlug() {
    final d = _deriveSlug(_name.text.trim());
    _slug.text = d.isEmpty ? 'custom' : d;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
        context,
        _CategoryDraft(
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            description: _desc.text.trim(),
            image: _img.text.trim()));
  }

  InputDecoration _decoration({
    required IconData icon,
    String? hint,
    Widget? suffix,
    String? helper,
    bool alignTop = false,
  }) {
    final sch = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      alignLabelWithHint: alignTop,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: sch.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(sch.outlineVariant, 1),
      focusedBorder: border(const Color(0xFF5B4FE9), 1.8),
      border: border(sch.outlineVariant, 1),
    );
  }

  Widget _label(String text) {
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: sch.onSurfaceVariant)),
    );
  }

  Widget _imgPreview() {
    final sch = Theme.of(context).colorScheme;
    final u = _img.text.trim();
    if (!u.startsWith('http')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          u,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: 36,
                  height: 36,
                  color: sch.surfaceContainerHighest,
                  child: Icon(Icons.image_outlined,
                      size: 18, color: sch.onSurfaceVariant)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    final derived = _deriveSlug(_name.text.trim());
    final slugHelper = _slug.text.trim().isEmpty
        ? '${tr('Will use:')} ${derived.isEmpty ? 'custom' : derived}'
        : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: sch.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // -------------------------------------------------- header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)]),
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      _isEdit ? Icons.edit_outlined : Icons.category_outlined,
                      color: Colors.white,
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? tr('Edit Category') : tr('Add Category'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                            _isEdit
                                ? tr('Update the category details')
                                : tr('Create a new category for the shop'),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ]),
                ),
              ]),
            ),
            // --------------------------------------------------- fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(tr('Name')),
                      TextFormField(
                          controller: _name,
                          autofocus: !_isEdit,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.label_outline,
                            hint: tr('e.g. Beauty & Skincare'),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('Please enter a name')
                              : null),
                      const SizedBox(height: 16),
                      _label(tr('Slug')),
                      TextFormField(
                          controller: _slug,
                          textCapitalization: TextCapitalization.none,
                          decoration: _decoration(
                            icon: Icons.link,
                            hint: 'beauty-skincare',
                            helper: slugHelper,
                            suffix: Tooltip(
                              message: tr('Auto-generate from name'),
                              child: IconButton(
                                onPressed: _autofillSlug,
                                icon: const Icon(Icons.auto_awesome,
                                    size: 19, color: Color(0xFF5B4FE9)),
                              ),
                            ),
                          )),
                      const SizedBox(height: 16),
                      _label(tr('Description')),
                      TextFormField(
                          controller: _desc,
                          minLines: 3,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            icon: Icons.notes_outlined,
                            hint: tr('Short description of this category'),
                            alignTop: true,
                          )),
                      const SizedBox(height: 16),
                      _label(tr('Image URL')),
                      TextFormField(
                          controller: _img,
                          keyboardType: TextInputType.url,
                          decoration: _decoration(
                            icon: Icons.image_outlined,
                            hint: 'https://...',
                            suffix: _imgPreview(),
                          )),
                    ]),
              ),
            ),
            // ------------------------------------------------- note + actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: sch.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      tr('Only the name is required — the rest is optional.'),
                      style:
                          TextStyle(fontSize: 11, color: sch.onSurfaceVariant)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('Cancel')),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FE9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    icon: Icon(_isEdit ? Icons.check : Icons.add, size: 18),
                    label: Text(_isEdit ? tr('Save') : tr('Add')),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared table widgets (search + header + rows + pagination, like the mock)
// ============================================================================

/// One KPI tile of the dashboard (Revenue / Orders / Customers / Products).
class _KpiSpec {
  final IconData icon;
  final String title, value;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _KpiSpec({
    required this.icon,
    required this.title,
    required this.value,
    required this.gradient,
    required this.onTap,
  });
}

class AdminTableScaffold extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearch;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget header;
  final List<Widget> rows;
  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;
  final String Function(int, int) showingLabel;

  const AdminTableScaffold({
    super.key,
    required this.searchHint,
    required this.onSearch,
    this.actionLabel,
    this.onAction,
    required this.header,
    required this.rows,
    required this.page,
    required this.totalPages,
    required this.onPage,
    required this.showingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final outline = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: sch.outlineVariant));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(
          child: TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: sch.surface,
              border: outline,
              enabledBorder: outline,
            ),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4FE9),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!)),
        ],
      ]),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sch.outlineVariant)),
        child: Column(children: [
          header,
          Divider(height: 1, color: sch.outlineVariant),
          if (rows.isEmpty)
            Padding(
                padding: const EdgeInsets.all(32),
                child: Text(AppLocalizations.of(context).t('No records found'),
                    style: TextStyle(color: sch.onSurfaceVariant))),
          ...rows,
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text(showingLabel(page * rowsPerPageConst, rows.length),
            style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
        const Spacer(),
        IconButton(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left)),
        _pageChip(context, page + 1, active: true),
        IconButton(
            onPressed: page < totalPages - 1 ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }

  static const rowsPerPageConst = 8;

  static Widget _pageChip(BuildContext c, int n, {bool active = false}) {
    final sch = Theme.of(c).colorScheme;
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: active ? const Color(0xFF5B4FE9) : Colors.transparent,
            borderRadius: BorderRadius.circular(8)),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        alignment: Alignment.center,
        child: Text('$n',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : sch.onSurface)));
  }
}

/// Header/row cells with the uppercase grey-label look from the mock.
class CellText extends StatelessWidget {
  final String text;
  final bool header;
  final Color? color;
  final int maxLines;
  const CellText(this.text,
      {super.key, this.header = false, this.color, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return Text(text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: header
            ? TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: sch.onSurfaceVariant)
            : TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? sch.onSurface));
  }
}

/// A small colored pill (Verified / Active / status badges).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)));
  }
}

// ============================================================================
// Shops page (brand/product catalog presented like the mock's table)
// ============================================================================

class CompaniesTablePage extends StatelessWidget {
  final List<Product> products;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final void Function(Product) onOpen;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  const CompaniesTablePage(
      {super.key,
      required this.products,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onAdd,
      required this.onOpen,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (products.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = products.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 4, child: CellText(tr('Shop'), header: true)),
          Expanded(flex: 3, child: CellText(tr('Location'), header: true)),
          Expanded(flex: 4, child: CellText(tr('Website'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Verified'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Status'), header: true)),
          Expanded(
              flex: 3,
              child: Center(child: CellText(tr('Actions'), header: true))),
        ]));

    Widget row(Product p) {
      final name = p.title.isNotEmpty ? p.title : p.brand;
      return InkWell(
        onTap: () => onEdit(p),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: sch.primaryContainer,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            name.isNotEmpty
                                ? name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: sch.onPrimaryContainer))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Tooltip(
                            message:
                                p.description.isNotEmpty ? p.description : name,
                            child: CellText(name,
                                color: const Color(0xFF5B4FE9)))),
                  ])),
              Expanded(
                  flex: 3,
                  child: CellText(p.category.isEmpty ? '—' : p.category)),
              Expanded(
                  flex: 4,
                  child: CellText(p.thumbnail.isEmpty ? '—' : p.thumbnail,
                      color: const Color(0xFF5B4FE9))),
              Expanded(
                  flex: 2,
                  child: Pill(p.verified ? tr('Verified') : tr('Unverified'),
                      color: p.verified ? Colors.green : Colors.orange)),
              Expanded(
                  flex: 2,
                  child: Pill(
                      tr(p.status == 'Inactive' ? 'Inactive' : 'Active'),
                      color:
                          p.status == 'Inactive' ? Colors.grey : Colors.green)),
              // View / Edit / Delete actions for this shop row (centered so
              // the Actions header sits directly above the buttons).
              Expanded(
                  flex: 3,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: tr('View detail'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onOpen(p),
                          icon: const Icon(Icons.visibility_outlined,
                              size: 19, color: Color(0xFF5B4FE9)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: tr('Edit'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onEdit(p),
                          icon: const Icon(Icons.edit_outlined,
                              size: 19, color: Color(0xFF5B4FE9)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: tr('Delete'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDelete(p),
                          icon: const Icon(Icons.delete_outline,
                              size: 19, color: Colors.redAccent),
                        ),
                      ])),
            ])),
      );
    }

    return AdminTableScaffold(
      searchHint: tr('Search shops...'),
      onSearch: onSearch,
      actionLabel: tr('New Shop'),
      onAction: onAdd,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

// ============================================================================
// Categories page
// ============================================================================

class CategoriesTablePage extends StatelessWidget {
  final List<Category> cats;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final void Function(Category) onOpen;
  final void Function(Category) onEdit;
  final void Function(Category) onDelete;
  final String? editedSlug;
  const CategoriesTablePage(
      {super.key,
      required this.cats,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onAdd,
      required this.onOpen,
      required this.onEdit,
      required this.onDelete,
      this.editedSlug});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (cats.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = cats.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Slug'), header: true)),
          Expanded(flex: 4, child: CellText(tr('Description'), header: true)),
          Expanded(flex: 3, child: CellText(tr('URL'), header: true)),
          Expanded(
              flex: 3,
              child: Center(child: CellText(tr('Actions'), header: true))),
        ]));

    Widget row(Category cat) {
      final sch = Theme.of(context).colorScheme;
      final isJustEdited = editedSlug == cat.slug;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: isJustEdited
            ? BoxDecoration(
                color: const Color(0xFF5B4FE9).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10))
            : null,
        child: Row(children: [
          // Name with a small image thumb when the category has one.
          Expanded(
              flex: 3,
              child: Row(children: [
                Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: cat.image.isEmpty ? sch.primaryContainer : null,
                        image: cat.image.isEmpty
                            ? null
                            : DecorationImage(
                                image: NetworkImage(cat.image),
                                fit: BoxFit.cover),
                        borderRadius: BorderRadius.circular(8)),
                    child: cat.image.isEmpty
                        ? Text(
                            cat.name.isNotEmpty
                                ? cat.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: sch.onPrimaryContainer))
                        : null),
                const SizedBox(width: 10),
                Expanded(child: CellText(cat.name)),
              ])),
          Expanded(
              flex: 2,
              child: CellText(cat.slug, color: const Color(0xFF5B4FE9))),
          Expanded(
              flex: 4,
              child: CellText(cat.description.isEmpty ? '—' : cat.description,
                  maxLines: 2)),
          Expanded(flex: 3, child: CellText(cat.url)),
          // View / Edit / Delete actions for this category row (centered so
          // the Actions header sits directly above the buttons).
          Expanded(
              flex: 3,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: tr('View detail'),
                    onPressed: () => onOpen(cat),
                    icon: const Icon(Icons.visibility_outlined,
                        size: 20, color: Color(0xFF5B4FE9))),
                const SizedBox(width: 6),
                IconButton(
                    tooltip: tr('Edit'),
                    onPressed: () => onEdit(cat),
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: Color(0xFF5B4FE9))),
                const SizedBox(width: 6),
                IconButton(
                    tooltip: tr('Delete'),
                    onPressed: () => onDelete(cat),
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent)),
              ])),
        ]),
      );
    }

    return AdminTableScaffold(
      searchHint: tr('Search categories...'),
      onSearch: onSearch,
      actionLabel: tr('Add Category'),
      onAction: onAdd,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

// ============================================================================
// Products page
// ============================================================================

class ProductsTablePage extends StatelessWidget {
  final List<Product> products;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final void Function(Product) onOpen;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  const ProductsTablePage(
      {super.key,
      required this.products,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onAdd,
      required this.onOpen,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (products.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = products.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 4, child: CellText(tr('Name'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Brand'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Categories'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Price'), header: true)),
          Expanded(flex: 1, child: CellText(tr('Stock'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Rating'), header: true)),
          Expanded(
              flex: 3,
              child: Center(child: CellText(tr('Actions'), header: true))),
        ]));

    Widget row(Product p) => InkWell(
          onTap: () => onEdit(p),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                    flex: 4,
                    child: CellText(p.title, color: const Color(0xFF5B4FE9))),
                Expanded(
                    flex: 2, child: CellText(p.brand.isEmpty ? '—' : p.brand)),
                Expanded(flex: 2, child: CellText(p.category)),
                Expanded(
                    flex: 2,
                    child: CellText('\$${p.price.toStringAsFixed(2)}')),
                Expanded(
                    flex: 1,
                    child: Pill('${p.stock}',
                        color: p.stock > 5
                            ? Colors.green
                            : p.stock > 0
                                ? Colors.orange
                                : Colors.red)),
                Expanded(
                    flex: 2,
                    child: Row(children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      CellText(p.rating.toStringAsFixed(1)),
                    ])),
                // View / Edit / Delete actions for this product row (centered
                // so the Actions header sits directly above the buttons).
                Expanded(
                    flex: 3,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: tr('View detail'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onOpen(p),
                            icon: const Icon(Icons.visibility_outlined,
                                size: 19, color: Color(0xFF5B4FE9)),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: tr('Edit'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onEdit(p),
                            icon: const Icon(Icons.edit_outlined,
                                size: 19, color: Color(0xFF5B4FE9)),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: tr('Delete'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDelete(p),
                            icon: const Icon(Icons.delete_outline,
                                size: 19, color: Colors.redAccent),
                          ),
                        ])),
              ])),
        );

    return AdminTableScaffold(
      searchHint: tr('Search products...'),
      onSearch: onSearch,
      actionLabel: tr('New Product'),
      onAction: onAdd,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

// ============================================================================
// Shop / Category / Product detail pages (opened via the View detail button)
// ============================================================================

/// Opens a URL from a detail card (shop website / category URL) in the
/// system browser. Silently ignores invalid or unopenable links.
Future<void> _launchDetailUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// One labelled row of a detail card — same look as the user profile rows.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final VoidCallback? onTap;
  const _DetailRow(this.icon, this.label, this.value,
      {this.maxLines = 1, this.onTap});
  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final valueStyle = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onTap != null ? const Color(0xFF5B4FE9) : null);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                  padding: EdgeInsets.only(top: maxLines > 1 ? 2 : 0),
                  child: Icon(icon, size: 18, color: sch.onSurfaceVariant)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 96,
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12.5, color: sch.onSurfaceVariant))),
              Expanded(
                child: onTap == null
                    ? Text(value.isEmpty ? '—' : value,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle)
                    : InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Flexible(
                                  child: Text(value.isEmpty ? '—' : value,
                                      maxLines: maxLines,
                                      overflow: TextOverflow.ellipsis,
                                      style: valueStyle)),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new,
                                  size: 14, color: Color(0xFF5B4FE9)),
                            ]))),
              ),
            ]));
  }
}

/// Detail card shared by the three pages below: gradient banner, optional
/// floating avatar, name block and an inset details table.
class _DetailCard extends StatelessWidget {
  final Widget? banner;
  final Widget? avatar;
  final Widget title;
  final Widget? subtitle;
  final Widget? badges;
  final List<Widget> rows;
  final List<Widget> extra;
  const _DetailCard(
      {this.banner,
      this.avatar,
      required this.title,
      this.subtitle,
      this.badges,
      required this.rows,
      this.extra = const []});
  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
              color: sch.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sch.outlineVariant),
              boxShadow: [
                BoxShadow(
                    color: sch.shadow.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (banner != null || avatar != null)
                Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      banner ??
                          Container(
                            height: 112,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                  Color(0xFF5B4FE9),
                                  Color(0xFF9C6ADE)
                                ])),
                          ),
                      if (avatar != null) Positioned(bottom: -46, child: avatar!),
                    ]),
              SizedBox(height: avatar != null ? 56 : 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [
                  title,
                  if (subtitle != null) ...[const SizedBox(height: 6), subtitle!],
                  if (badges != null) ...[
                    const SizedBox(height: 10),
                    badges!,
                  ],
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: sch.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sch.outlineVariant)),
                    child: Column(children: rows),
                  ),
                  ...extra,
                  const SizedBox(height: 20),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ShopDetailPage extends StatelessWidget {
  final Product shop;
  final VoidCallback onBack;
  const ShopDetailPage({super.key, required this.shop, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    final name = shop.title.isNotEmpty ? shop.title : shop.brand;
    final site = shop.thumbnail.trim();

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      _DetailCard(
        avatar: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sch.surface,
              boxShadow: [
                BoxShadow(
                    color: sch.shadow.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: CircleAvatar(
              radius: 42,
              backgroundColor: sch.primaryContainer,
              child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5B4FE9)))),
        ),
        title: Text(name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        subtitle: shop.category.isEmpty
            ? null
            : Text(shop.category,
                style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
        badges: Row(mainAxisSize: MainAxisSize.min, children: [
          Pill(shop.verified ? tr('Verified') : tr('Unverified'),
              color: shop.verified ? Colors.green : Colors.orange),
          const SizedBox(width: 8),
          Pill(tr(shop.status == 'Inactive' ? 'Inactive' : 'Active'),
              color:
                  shop.status == 'Inactive' ? Colors.grey : Colors.green),
        ]),
        rows: [
          _DetailRow(Icons.storefront_outlined, tr('Shop'), name),
          _DetailRow(
              Icons.location_on_outlined, tr('Location'), shop.category),
          _DetailRow(Icons.link, tr('Website'), site,
              onTap:
                  site.isEmpty ? null : () => _launchDetailUrl(site)),
          _DetailRow(Icons.star_outline, tr('Rating'),
              shop.rating.toStringAsFixed(1)),
          _DetailRow(
              Icons.badge_outlined, tr('ID'), shop.id.toString()),
          _DetailRow(Icons.notes_outlined, tr('Description'),
              shop.description,
              maxLines: 4),
        ],
      ),
    ]);
  }
}

class CategoryDetailPage extends StatelessWidget {
  final Category category;
  final VoidCallback onBack;
  const CategoryDetailPage(
      {super.key, required this.category, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    final url = category.url.trim();

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(category.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      _DetailCard(
        avatar: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sch.surface,
              boxShadow: [
                BoxShadow(
                    color: sch.shadow.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: CircleAvatar(
              radius: 42,
              backgroundColor: category.image.isEmpty
                  ? sch.primaryContainer
                  : null,
              backgroundImage: category.image.isEmpty
                  ? null
                  : NetworkImage(category.image),
              child: category.image.isEmpty
                  ? Text(
                      category.name.isNotEmpty
                          ? category.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5B4FE9)))
                  : null),
        ),
        title: Text(category.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        subtitle: category.slug.isEmpty
            ? null
            : Text(category.slug,
                style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
        rows: [
          _DetailRow(Icons.category_outlined, tr('Name'), category.name),
          _DetailRow(Icons.tag, tr('Slug'), category.slug),
          _DetailRow(Icons.link, tr('URL'), url,
              onTap: url.isEmpty ? null : () => _launchDetailUrl(url)),
          _DetailRow(Icons.notes_outlined, tr('Description'),
              category.description,
              maxLines: 4),
        ],
      ),
    ]);
  }
}

class ProductDetailPage extends StatelessWidget {
  final Product product;
  final VoidCallback onBack;
  const ProductDetailPage(
      {super.key, required this.product, required this.onBack});

  Widget _banner(ColorScheme sch) {
    Widget fallback() => Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)])),
        child: const Icon(Icons.inventory_2_outlined,
            size: 40, color: Colors.white70));
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: product.thumbnail.isEmpty
          ? fallback()
          : Image.network(product.thumbnail,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(product.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      _DetailCard(
        banner: _banner(sch),
        title: Text(product.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        subtitle: product.brand.isEmpty
            ? null
            : Text(product.brand,
                style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
        badges: Pill(tr(product.status == 'Inactive' ? 'Inactive' : 'Active'),
            color:
                product.status == 'Inactive' ? Colors.grey : Colors.green),
        rows: [
          _DetailRow(Icons.category_outlined, tr('Category'),
              product.category),
          _DetailRow(Icons.sell_outlined, tr('Price'),
              '\$${product.price.toStringAsFixed(2)}'),
          _DetailRow(
              Icons.percent,
              tr('Discount'),
              product.discountPercentage <= 0
                  ? ''
                  : '${product.discountPercentage.toStringAsFixed(0)}%'),
          _DetailRow(
              Icons.inventory_2_outlined, tr('Stock'), '${product.stock}'),
          _DetailRow(Icons.star_outline, tr('Rating'),
              '${product.rating.toStringAsFixed(1)} / 5'),
          _DetailRow(
              Icons.person_outline,
              tr('Vendor'),
              product.vendorUsername.isEmpty
                  ? ''
                  : '@${product.vendorUsername}'),
          _DetailRow(
              Icons.badge_outlined, tr('ID'), product.id.toString()),
          _DetailRow(Icons.notes_outlined, tr('Description'),
              product.description,
              maxLines: 4),
        ],
        extra: [
          if (product.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: product.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(product.images[i],
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 76,
                              height: 76,
                              color: sch.surfaceContainerHighest,
                              child:
                                  const Icon(Icons.image_outlined)))),
                ),
              ),
            ),
          ],
        ],
      ),
    ]);
  }
}

// ============================================================================
// Users page + detail
// ============================================================================

class UsersTablePage extends StatelessWidget {
  final List<User> users;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final void Function(User) onOpen;
  final void Function(User) onDelete;
  const UsersTablePage(
      {super.key,
      required this.users,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onOpen,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (users.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = users.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(flex: 3, child: CellText(tr('Username'), header: true)),
          Expanded(flex: 4, child: CellText(tr('Email'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Phone'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Role'), header: true)),
          Expanded(
              flex: 1,
              child: Center(child: CellText(tr('Actions'), header: true))),
        ]));

    Widget row(User u) {
      final isAdmin = u.isAdmin ||
          u.username.trim().toLowerCase() == ApiService.adminUsername;
      return InkWell(
        onTap: () => onOpen(u),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    CircleAvatar(
                        radius: 14,
                        backgroundColor: isAdmin
                            ? const Color(0xFF5B4FE9).withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: Text(
                            u.fullName.isNotEmpty
                                ? u.fullName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5B4FE9)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CellText(u.fullName.isEmpty
                            ? '@${u.username}'
                            : u.fullName)),
                  ])),
              Expanded(flex: 3, child: CellText('@${u.username}')),
              Expanded(
                  flex: 4, child: CellText(u.email.isEmpty ? '—' : u.email)),
              Expanded(
                  flex: 2, child: CellText(u.phone.isEmpty ? '—' : u.phone)),
              Expanded(
                  flex: 2,
                  child: Pill(isAdmin ? tr('Admin') : tr('User'),
                      color: isAdmin ? const Color(0xFF5B4FE9) : Colors.green)),
              Expanded(
                  flex: 1,
                  child: Align(
                      alignment: Alignment.center,
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                tooltip: tr('View detail'),
                                onPressed: () => onOpen(u),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 20)),
                            if (!isAdmin)
                              IconButton(
                                  tooltip: tr('Delete'),
                                  onPressed: () => onDelete(u),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: Colors.redAccent)),
                          ]))),
            ])),
      );
    }

    return AdminTableScaffold(
      searchHint: tr('Search users...'),
      onSearch: onSearch,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

class UserDetailPage extends StatelessWidget {
  final User user;
  final VoidCallback onBack;
  const UserDetailPage({super.key, required this.user, required this.onBack});

  /// Profile photo of the user (network or base64), or null to fall back to
  /// the gradient initial avatar — mirrors [AdminPanelPageState._adminAvatarImage].
  ImageProvider? _avatarImage(String? s) {
    if (s == null || s.isEmpty) return null;
    if (s.startsWith('b64:')) {
      try {
        return MemoryImage(base64Decode(s.substring(4)));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(s);
  }

  String _dateStr(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    final isAdminUser = user.isAdmin ||
        user.username.trim().toLowerCase() == ApiService.adminUsername;
    final avatarImg = _avatarImage(user.image);
    final name = user.fullName.isNotEmpty ? user.fullName : '@${user.username}';

    Widget profileRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: sch.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
              width: 96,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5, color: sch.onSurfaceVariant))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]));

    Widget avatarCircle() => CircleAvatar(
        radius: 42,
        backgroundColor: avatarImg == null
            ? (isAdminUser
                ? const Color(0xFF5B4FE9).withValues(alpha: 0.15)
                : sch.secondaryContainer)
            : sch.primaryContainer,
        foregroundColor: avatarImg == null
            ? (isAdminUser
                ? const Color(0xFF5B4FE9)
                : sch.onSecondaryContainer)
            : null,
        backgroundImage: avatarImg,
        child: avatarImg == null
            ? Text(
                user.fullName.isNotEmpty
                    ? user.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800))
            : null);

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      // ------------------------------------------------- profile card
      // Centered + width-capped so it reads as a profile card on wide
      // desktop screens instead of a stretched full-window banner.
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
                color: sch.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sch.outlineVariant),
                boxShadow: [
                  BoxShadow(
                      color: sch.shadow.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: 112,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                              Color(0xFF5B4FE9),
                              Color(0xFF9C6ADE)
                            ])),
                      ),
                      Positioned(
                        bottom: -46,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sch.surface,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        sch.shadow.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))
                              ]),
                          child: avatarCircle(),
                        ),
                      ),
                    ]),
                const SizedBox(height: 56),
                Text(name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (user.username.isNotEmpty)
                  Text('@${user.username}',
                      style: TextStyle(
                          fontSize: 13, color: sch.onSurfaceVariant)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: isAdminUser
                          ? const Color(0xFF5B4FE9).withValues(alpha: 0.10)
                          : Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(isAdminUser ? tr('Admin') : tr('User'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: isAdminUser
                              ? const Color(0xFF5B4FE9)
                              : Colors.green)),
                ),
                const SizedBox(height: 18),
                // ----------------------------------------- details card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: sch.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sch.outlineVariant)),
                    child: Column(children: [
                      profileRow(
                          Icons.person_outline, tr('First Name'), user.firstName),
                      profileRow(
                          Icons.person_outline, tr('Last Name'), user.lastName),
                      profileRow(
                          Icons.alternate_email, tr('Username'), user.username),
                      profileRow(Icons.mail_outline, tr('Email'), user.email),
                      profileRow(Icons.phone_outlined, tr('Phone'), user.phone),
                      profileRow(Icons.badge_outlined, tr('User ID'),
                          user.id.toString()),
                      profileRow(Icons.shield_outlined, tr('Role'),
                          isAdminUser ? tr('Admin') : tr('User')),
                      profileRow(Icons.calendar_today_outlined, tr('Joined'),
                          _dateStr(user.createdAt)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ============================================================================
// Orders page + detail
// ============================================================================

class OrdersTablePage extends StatelessWidget {
  final List<Order> orders;

  /// Unfiltered list — used for the summary cards.
  final List<Order> allOrders;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final void Function(Order) onOpen;
  final void Function(Order, String) onStatus;
  const OrdersTablePage(
      {super.key,
      required this.orders,
      required this.allOrders,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onOpen,
      required this.onStatus});

  Color _statusColor(String s) {
    switch (s) {
      case 'Processing':
        return const Color(0xFFB45309); // amber-700
      case 'Shipped':
        return const Color(0xFF1D4ED8); // blue-700
      case 'Delivered':
        return const Color(0xFF15803D); // green-700
      default:
        return const Color(0xFFB91C1C); // red-700
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'Processing':
        return const Color(0xFFFFF3E0);
      case 'Shipped':
        return const Color(0xFFE8F0FE);
      case 'Delivered':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFFDE8E8);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Processing':
        return Icons.autorenew;
      case 'Shipped':
        return Icons.local_shipping_outlined;
      case 'Delivered':
        return Icons.check_circle_outline;
      default:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (orders.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = orders.skip(page * perPage).take(perPage).toList();
    // Known statuses, plus any status already present in the data so the
    // DropdownButton always has an item matching each order (otherwise it
    // asserts with "There should be exactly one item" and blanks the page).
    final statuses = {
      'Processing',
      'Shipped',
      'Delivered',
      'Cancelled',
      ...allOrders.map((o) => o.status),
    }.toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 2, child: CellText(tr('Order ID'), header: true)),
          Expanded(flex: 3, child: CellText(tr('Customer'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Date'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Total'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Status'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Update status'), header: true)),
        ]));

    // ---------------------------------------------- summary stat cards
    Widget statCard(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: sch.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sch.outlineVariant)),
          child: Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(label,
                      style:
                          TextStyle(fontSize: 11, color: sch.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ])),
          ]),
        ),
      );
    }

    final revenue = allOrders.fold<double>(
        0, (sum, o) => sum + (o.status == 'Cancelled' ? 0 : o.total));

    Widget row(Order o) {
      final date = o.date.toLocal().toString();
      final itemsCount = o.items.fold<int>(0, (sum, it) => sum + it.quantity);
      return InkWell(
        onTap: () => onOpen(o),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              // Order ID + item count underneath.
              Expanded(
                  flex: 2,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CellText(
                            '#${o.id.length > 8 ? o.id.substring(0, 8) : o.id}',
                            color: const Color(0xFF5B4FE9)),
                        const SizedBox(height: 2),
                        Text(tr('$itemsCount items'),
                            style: TextStyle(
                                fontSize: 10, color: sch.onSurfaceVariant)),
                      ])),
              // Customer avatar + name.
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: sch.primaryContainer,
                            shape: BoxShape.circle),
                        child: Text(
                            (o.owner.isNotEmpty ? o.owner[0] : 'G')
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: sch.onPrimaryContainer))),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            CellText(o.owner.isEmpty ? tr('Guest') : o.owner)),
                  ])),
              Expanded(flex: 2, child: CellText(date.split(' ').first)),
              Expanded(
                  flex: 2, child: CellText('\$${o.total.toStringAsFixed(2)}')),
              // Colored status pill with icon.
              Expanded(
                  flex: 2,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: _statusBg(o.status),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_statusIcon(o.status),
                                size: 13, color: _statusColor(o.status)),
                            const SizedBox(width: 5),
                            Text(tr(o.status),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(o.status))),
                          ])))),
              Expanded(
                  flex: 2,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                          border: Border.all(color: sch.outlineVariant),
                          borderRadius: BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                          value: o.status,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          icon: Icon(Icons.expand_more,
                              size: 18, color: sch.onSurfaceVariant),
                          items: statuses
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Row(children: [
                                    Icon(_statusIcon(s),
                                        size: 14, color: _statusColor(s)),
                                    const SizedBox(width: 6),
                                    Text(tr(s),
                                        style: const TextStyle(fontSize: 12)),
                                  ])))
                              .toList(),
                          onChanged: (s) => s != null && s != o.status
                              ? onStatus(o, s)
                              : null))),
            ])),
      );
    }

    // NOTE: AdminTableScaffold is itself a vertical ListView, so it must
    // NOT be nested inside another unbounded vertical scrollable (that
    // throws "Vertical viewport was given unbounded height"). The summary
    // cards and filter chips stay pinned on top; the table scrolls below.
    return Column(children: [
      // ------------------------------------------- summary cards row
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(children: [
          statCard(tr('Total Orders'), '${allOrders.length}',
              Icons.receipt_long_outlined, const Color(0xFF5B4FE9)),
          const SizedBox(width: 12),
          statCard(tr('Revenue'), '\$${revenue.toStringAsFixed(2)}',
              Icons.payments_outlined, const Color(0xFF15803D)),
          const SizedBox(width: 12),
          statCard(
              tr('Processing'),
              '${allOrders.where((o) => o.status == 'Processing').length}',
              Icons.autorenew,
              const Color(0xFFB45309)),
          const SizedBox(width: 12),
          statCard(
              tr('Shipped'),
              '${allOrders.where((o) => o.status == 'Shipped').length}',
              Icons.local_shipping_outlined,
              const Color(0xFF1D4ED8)),
          const SizedBox(width: 12),
          statCard(
              tr('Delivered'),
              '${allOrders.where((o) => o.status == 'Delivered').length}',
              Icons.check_circle_outline,
              const Color(0xFF15803D)),
          const SizedBox(width: 12),
          statCard(
              tr('Cancelled'),
              '${allOrders.where((o) => o.status == 'Cancelled').length}',
              Icons.cancel_outlined,
              const Color(0xFFB91C1C)),
        ]),
      ),
      const SizedBox(height: 16),
      // ------------------------------------------------ table card
      Expanded(
        child: AdminTableScaffold(
          searchHint: tr('Search orders...'),
          onSearch: onSearch,
          page: page,
          totalPages: totalPages,
          onPage: onPage,
          showingLabel: (start, n) =>
              tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
          header: headerRow(),
          rows: slice.map(row).toList(),
        ),
      ),
    ]);
  }
}

class OrderDetailPage extends StatelessWidget {
  final Order order;
  final VoidCallback onBack;

  /// Called when the admin deletes this order (optional — hides the button).
  final VoidCallback? onDelete;
  const OrderDetailPage(
      {super.key, required this.order, required this.onBack, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: CellText(k, header: true)),
          Expanded(child: CellText(v, maxLines: 3)),
        ]));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${tr('Order')} #${order.id}',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        if (onDelete != null)
          IconButton(
              tooltip: tr('Delete Order'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sch.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          row(tr('Customer'), order.owner.isEmpty ? tr('Guest') : order.owner),
          row(tr('Date'), order.date.toLocal().toString()),
          row(tr('Address'), order.deliveryAddress),
          row(tr('Status'), tr(order.status)),
          const Divider(height: 24),
          ...order.items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: CellText(it.product.title)),
                CellText('x${it.quantity}'),
                const SizedBox(width: 16),
                SizedBox(
                    width: 80,
                    child: Text(
                        '\$${(it.product.price * it.quantity).toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))),
              ]))),
          const Divider(height: 24),
          Align(
              alignment: Alignment.centerRight,
              child: Text('${tr('Total')}: \$${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: sch.primary))),
        ]),
      ),
    ]);
  }
}

// ============================================================================
// Feedback page (feedback written by shoppers)
// ============================================================================

class FeedbackTablePage extends StatelessWidget {
  final List<FeedbackItem> feedbacks;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final void Function(FeedbackItem) onOpen;
  final void Function(FeedbackItem) onDelete;
  const FeedbackTablePage(
      {super.key,
      required this.feedbacks,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onOpen,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tr = l.t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages = (feedbacks.length / perPage).ceil().clamp(1, 1 << 30);
    final slice = feedbacks.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(flex: 2, child: CellText(tr('User'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Rating'), header: true)),
          Expanded(flex: 5, child: CellText(tr('Message'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Date'), header: true)),
          Expanded(
              flex: 2,
              child: Center(child: CellText(tr('Actions'), header: true))),
        ]));

    Widget row(FeedbackItem f) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
              flex: 3, child: CellText(f.name.isEmpty ? tr('Guest') : f.name)),
          Expanded(
              flex: 2, child: CellText(f.owner.isEmpty ? '—' : '@${f.owner}')),
          Expanded(
              flex: 2,
              child: Row(children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                CellText('${f.rating}/5'),
              ])),
          Expanded(
              flex: 5,
              child: CellText(
                  f.message.isEmpty ? '—' : l.feedbackMessage(f.message),
                  maxLines: 2)),
          Expanded(
              flex: 2,
              child: CellText(f.date.toLocal().toString().substring(0, 16))),
          // View / Delete actions for this feedback row (centered so the
          // Actions header sits directly above the buttons).
          Expanded(
              flex: 2,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: tr('View detail'),
                    onPressed: () => onOpen(f),
                    icon: const Icon(Icons.visibility_outlined,
                        size: 20, color: Color(0xFF5B4FE9))),
                const SizedBox(width: 6),
                IconButton(
                    tooltip: tr('Delete'),
                    onPressed: () => onDelete(f),
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent)),
              ])),
        ]));

    return AdminTableScaffold(
      searchHint: tr('Search feedback...'),
      onSearch: onSearch,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          tr('Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total'),
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

class FeedbackDetailPage extends StatelessWidget {
  final FeedbackItem feedback;
  final VoidCallback onBack;
  const FeedbackDetailPage(
      {super.key, required this.feedback, required this.onBack});

  String _dateStr(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final tr = l.t;
    final f = feedback;
    final name = f.name.isNotEmpty ? f.name : tr('Guest');

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 16),
      _DetailCard(
        avatar: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sch.surface,
              boxShadow: [
                BoxShadow(
                    color: sch.shadow.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]),
          child: CircleAvatar(
              radius: 42,
              backgroundColor: sch.primaryContainer,
              child: Text(
                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5B4FE9)))),
        ),
        title: Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        subtitle: f.owner.isEmpty
            ? null
            : Text('@${f.owner}',
                style: TextStyle(fontSize: 13, color: sch.onSurfaceVariant)),
        badges: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= f.rating ? Icons.star : Icons.star_border,
                size: 20, color: Colors.amber),
          const SizedBox(width: 6),
          Text('${f.rating}/5',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        rows: [
          _DetailRow(Icons.person_outline, tr('Name'), name),
          _DetailRow(Icons.alternate_email, tr('User'),
              f.owner.isEmpty ? '' : '@${f.owner}'),
          _DetailRow(Icons.star_outline, tr('Rating'), '${f.rating}/5'),
          _DetailRow(Icons.calendar_today_outlined, tr('Date'),
              _dateStr(f.date)),
          if (f.productId != null)
            _DetailRow(
                Icons.inventory_2_outlined, tr('Product'), '#${f.productId}'),
          _DetailRow(Icons.notes_outlined, tr('Message'),
              f.message.isEmpty ? '' : l.feedbackMessage(f.message),
              maxLines: 12),
        ],
      ),
    ]);
  }
}

// ============================================================================
// Add/Edit product dialog (compact, table-context form)
// ============================================================================

class AdminProductEditDialog extends StatefulWidget {
  final AdminRepository repo;
  final Product? existing;
  const AdminProductEditDialog({super.key, required this.repo, this.existing});

  @override
  State<AdminProductEditDialog> createState() => _AdminProductEditDialogState();
}

class _AdminProductEditDialogState extends State<AdminProductEditDialog> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController brand =
      TextEditingController(text: widget.existing?.brand ?? '');
  late final TextEditingController category =
      TextEditingController(text: widget.existing?.category ?? '');
  late final TextEditingController price =
      TextEditingController(text: (widget.existing?.price ?? 0).toString());
  late final TextEditingController stock =
      TextEditingController(text: (widget.existing?.stock ?? 0).toString());
  late final TextEditingController rating =
      TextEditingController(text: (widget.existing?.rating ?? 0).toString());

  @override
  void dispose() {
    for (final c in [
      title,
      brand,
      category,
      price,
      stock,
      rating,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Closes the dialog immediately with the edited product. The caller
  /// applies it to the list on screen and persists it in the background, so
  /// the Save button never waits on storage or the network.
  void _save() {
    if (!(_f.currentState?.validate() ?? false)) return;
    final p = Product(
        id: widget.existing?.id ?? -1,
        title: title.text.trim(),
        price: double.tryParse(price.text) ?? 0,
        discountPercentage: widget.existing?.discountPercentage ?? 0,
        rating: double.tryParse(rating.text) ?? 0,
        stock: int.tryParse(stock.text) ?? 0,
        brand: brand.text.trim(),
        category: category.text.trim().toLowerCase(),
        description: widget.existing?.description ?? '',
        thumbnail: widget.existing?.thumbnail ?? '',
        images: widget.existing?.images ?? const [],
        status: widget.existing?.status ?? 'Active',
        verified: widget.existing?.verified ?? false);
    Navigator.pop(context, p);
  }

  InputDecoration _decoration({
    IconData? icon,
    String? prefixText,
    String? hint,
    Widget? suffix,
    bool alignTop = false,
  }) {
    final sch = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignTop,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefixText,
      prefixStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: sch.onSurfaceVariant),
      suffixIcon: suffix,
      filled: true,
      fillColor: sch.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(sch.outlineVariant, 1),
      focusedBorder: border(const Color(0xFF5B4FE9), 1.8),
      border: border(sch.outlineVariant, 1),
    );
  }

  Widget _label(String text) {
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: sch.onSurfaceVariant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // -------------------------------------------------- header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)]),
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.storefront_outlined,
                      color: Colors.white,
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEdit ? tr('Edit Product') : tr('New Product'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                            isEdit
                                ? tr('Update the product details')
                                : tr('Create a new product for the catalog'),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ]),
                ),
              ]),
            ),
            // --------------------------------------------------- fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Form(
                key: _f,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(tr('Name')),
                      TextFormField(
                          controller: title,
                          autofocus: !isEdit,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.label_outline,
                            hint: tr('e.g. Beauty & Skincare'),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('Please enter a name')
                              : null),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Brand')),
                                  TextFormField(
                                      controller: brand,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: _decoration(
                                          icon: Icons.business_outlined,
                                          hint: tr('e.g. Essence'))),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Categories')),
                                  TextFormField(
                                      controller: category,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: _decoration(
                                          icon: Icons.category_outlined,
                                          hint: tr('beauty'))),
                                ])),
                          ]),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Price')),
                                  TextFormField(
                                      controller: price,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: _decoration(
                                        prefixText: '\$ ',
                                        hint: '0.00',
                                      ),
                                      validator: (v) =>
                                          (double.tryParse(v ?? '') ?? -1) < 0
                                              ? tr('Enter a valid price')
                                              : null),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Stock')),
                                  TextFormField(
                                      controller: stock,
                                      keyboardType: TextInputType.number,
                                      decoration: _decoration(
                                          icon: Icons.inventory_2_outlined,
                                          hint: '0')),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Rating')),
                                  TextFormField(
                                      controller: rating,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: _decoration(
                                        icon: Icons.star_outline,
                                        hint: '0.0',
                                      ),
                                      validator: (v) =>
                                          (double.tryParse(v ?? '') ?? -1) < 0
                                              ? tr('Enter a valid rating')
                                              : null),
                                ])),
                          ]),
                    ]),
              ),
            ),
            // ------------------------------------------------- note + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('Cancel')),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FE9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    icon: Icon(isEdit ? Icons.check : Icons.add, size: 18),
                    label: Text(isEdit ? tr('Save') : tr('Add Product')),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// Add/Edit shop dialog (Shops page — product rows shown as shops)
// ============================================================================

class AdminCompanyEditDialog extends StatefulWidget {
  final AdminRepository repo;
  final Product? existing;
  const AdminCompanyEditDialog({super.key, required this.repo, this.existing});

  @override
  State<AdminCompanyEditDialog> createState() => _AdminCompanyEditDialogState();
}

class _AdminCompanyEditDialogState extends State<AdminCompanyEditDialog> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController company =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController location =
      TextEditingController(text: widget.existing?.category ?? '');
  late final TextEditingController website =
      TextEditingController(text: widget.existing?.thumbnail ?? '');
  late final TextEditingController description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController rating =
      TextEditingController(text: (widget.existing?.rating ?? 0).toString());

  late bool _verified = widget.existing?.verified ?? false;

  /// Shop availability shown in the Status dropdown: Active / Inactive.
  late String _status = widget.existing?.status ?? 'Active';

  @override
  void dispose() {
    for (final c in [
      company,
      location,
      website,
      description,
      rating,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Closes the dialog immediately with the edited shop. The caller
  /// applies it to the list on screen and persists it in the background, so
  /// the Save button never waits on storage or the network.
  void _save() {
    if (!(_f.currentState?.validate() ?? false)) return;
    final p = Product(
        id: widget.existing?.id ?? -1,
        title: company.text.trim(),
        // Stock and Price were removed from the Shops page — keep the
        // existing values untouched so editing a shop never loses product
        // data (new shops default them to 0 like all new products).
        price: widget.existing?.price ?? 0,
        discountPercentage: widget.existing?.discountPercentage ?? 0,
        rating: double.tryParse(rating.text) ?? 0,
        stock: widget.existing?.stock ?? 0,
        brand: widget.existing?.brand ?? '',
        category: location.text.trim().toLowerCase(),
        description: description.text.trim(),
        thumbnail: website.text.trim(),
        images: widget.existing?.images ?? const [],
        status: _status,
        verified: _verified);
    Navigator.pop(context, p);
  }

  InputDecoration _decoration({
    IconData? icon,
    String? prefixText,
    String? hint,
    bool alignTop = false,
  }) {
    final sch = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignTop,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefixText,
      prefixStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: sch.onSurfaceVariant),
      filled: true,
      fillColor: sch.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(sch.outlineVariant, 1),
      focusedBorder: border(const Color(0xFF5B4FE9), 1.8),
      border: border(sch.outlineVariant, 1),
    );
  }

  Widget _label(String text) {
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: sch.onSurfaceVariant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // -------------------------------------------------- header band
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)]),
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.storefront_outlined,
                      color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(isEdit ? tr('Edit Shop') : tr('New Shop'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                          isEdit
                              ? tr('Update the shop details')
                              : tr('Create a new shop for the catalog'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ])),
              ]),
            ),
            // --------------------------------------------------- fields
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Form(
                key: _f,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(tr('Shop')),
                      TextFormField(
                          controller: company,
                          autofocus: !isEdit,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.storefront_outlined,
                            hint: tr('e.g. Acme Corp'),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('Please enter a name')
                              : null),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Location')),
                                  TextFormField(
                                      controller: location,
                                      decoration: _decoration(
                                          icon: Icons.location_on_outlined,
                                          hint: tr('City'))),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Website')),
                                  TextFormField(
                                      controller: website,
                                      keyboardType: TextInputType.url,
                                      decoration: _decoration(
                                          icon: Icons.public,
                                          hint: 'https://...')),
                                ])),
                          ]),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Verified')),
                                  Container(
                                    height: 50,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    decoration: BoxDecoration(
                                        color: _verified
                                            ? const Color(0xFF5B4FE9)
                                                .withValues(alpha: 0.10)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: _verified
                                                ? const Color(0xFF5B4FE9)
                                                    .withValues(alpha: 0.5)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant)),
                                    child: Row(children: [
                                      Icon(
                                          _verified
                                              ? Icons.verified_outlined
                                              : Icons.verified_user_outlined,
                                          size: 20,
                                          color: _verified
                                              ? const Color(0xFF5B4FE9)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .outline),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(
                                              _verified
                                                  ? tr('Verified')
                                                  : tr('Unverified'),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _verified
                                                      ? const Color(0xFF5B4FE9)
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant))),
                                      Switch(
                                        value: _verified,
                                        activeTrackColor:
                                            const Color(0xFF5B4FE9),
                                        onChanged: (v) =>
                                            setState(() => _verified = v),
                                      ),
                                    ]),
                                  ),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Status')),
                                  DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    decoration: _decoration(
                                        icon: Icons.verified_outlined),
                                    items: ['Active', 'Inactive']
                                        .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s == 'Active'
                                                ? tr('Active')
                                                : tr('Inactive'))))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _status = v ?? 'Active'),
                                  ),
                                ])),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  _label(tr('Rating')),
                                  TextFormField(
                                      controller: rating,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: _decoration(
                                        icon: Icons.star_outline,
                                        hint: '0.0',
                                      ),
                                      validator: (v) =>
                                          (double.tryParse(v ?? '') ?? -1) < 0
                                              ? tr('Enter a valid rating')
                                              : null),
                                ])),
                          ]),
                      const SizedBox(height: 16),
                      _label(tr('Description')),
                      TextFormField(
                          controller: description,
                          minLines: 2,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            icon: Icons.notes_outlined,
                            hint: tr('Short description of this shop'),
                            alignTop: true,
                          )),
                    ]),
              ),
            ),
            // ------------------------------------------------- note + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('Cancel')),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FE9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    icon: Icon(isEdit ? Icons.check : Icons.add, size: 18),
                    label: Text(isEdit ? tr('Save') : tr('Add Shop')),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
