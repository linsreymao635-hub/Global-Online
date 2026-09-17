import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../presenters/presenters.dart';
import '../repositories/repositories.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';

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
  const AdminPanelPage(
      {super.key,
      required this.admin,
      required this.repo,
      required this.orders,
      this.onLogout});

  @override
  State<AdminPanelPage> createState() => AdminPanelPageState();
}

class AdminPanelPageState extends State<AdminPanelPage> {
  String _page = 'companies'; // default landing page

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
  int _userPage = 0, _orderPage = 0, _productPage = 0, _catPage = 0,
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

  // Live filters for the searchable tables.
  String _search = '';

  // Orders page quick-filter (All / Processing / Shipped / ...).
  String _orderStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _reload();
    // Push-based live updates (no refresh needed).
    widget.repo.supa.watchFeedback(_onLiveFeedback);
    // Fallback: quietly refresh feedback every 20 seconds.
    _feedbackPoll = Timer.periodic(
        const Duration(seconds: 20), (_) => _onLiveFeedback());
  }

  @override
  void dispose() {
    _clearEditedTimer?.cancel();
    _feedbackPoll?.cancel();
    widget.repo.supa.cancelFeedbackWatch();
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
      final changed = feedbacks.length != _feedbacks.length;
      setState(() => _feedbacks = feedbacks);
      if (changed && _page != 'feedback') {
        _toast(AppLocalizations.of(context).t('New feedback received'));
      }
    } catch (_) {
      // Offline — keep showing the current list.
    } finally {
      _loadingFeedback = false;
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
    try {
      final products = await widget.repo.products();
      final cats = await widget.repo.categories();
      final users = await widget.repo.users();
      final orders = await widget.repo.orders();
      final feedbacks = await widget.repo.feedbacks();
      if (!mounted) return;
      setState(() {
        _products = products;
        _cats = cats;
        _users = users;
        _orders = orders;
        _feedbacks = feedbacks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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
      _search = '';
      _userPage = _orderPage = _productPage = _catPage = _feedbackPage = 0;
    });
    _reload();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          width: 340,
          behavior: SnackBarBehavior.floating));

  /// Admin logout: clear the session FIRST (so the app root swaps its home
  /// to the login page), then close the panel itself. Result: Logout in the
  /// admin always lands on the Sign In page — never the shop.
  void _logout() {
    widget.onLogout?.call();
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- sidebar

  Widget _sideItem(IconData icon, String label, String key,
      {bool chevron = false}) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon,
                  size: 18,
                  color: sel ? Colors.white : sch.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : sch.onSurface)),
              ),
              if (chevron)
                Icon(Icons.expand_more,
                    size: 18,
                    color:
                        sel ? Colors.white : sch.onSurfaceVariant),
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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        // Header exactly 64px tall — the SAME height as the top bar — with
        // the same bottom border, so the two header lines line up as one
        // continuous equal line across the whole screen.
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: sch.outlineVariant)),
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
            _sideItem(Icons.dashboard_outlined, tr('Dashboard'), 'dashboard',
                chevron: true),
            _sideItem(
                Icons.storefront_outlined, tr('Companies'), 'companies'),
            _sideItem(
                Icons.category_outlined, tr('Categories'), 'categories'),
            _sideItem(
                Icons.inventory_2_outlined, tr('Products'), 'products'),
            _sideItem(Icons.people_outline, tr('Users'), 'users'),
            _sideItem(
                Icons.receipt_long_outlined, tr('Orders'), 'orders'),
            _sideItem(Icons.rate_review_outlined, tr('Feedback'),
                'feedback'),
            _sideItem(Icons.bar_chart_outlined, tr('Reports'), 'reports'),
            _sideItem(Icons.notifications_none, tr('Notifications'),
                'notifications'),
            _sideItem(Icons.settings_outlined, tr('Settings'), 'settings'),
            _sideItem(Icons.verified_user_outlined, tr('Administration'),
                'administration',
                chevron: true),
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
                    style: TextStyle(
                        fontSize: 12, color: sch.onSurfaceVariant)),
              ]),
        ),
        // Admin identity chip: profile photo (or gradient initial), name
        // and email. Clicking it opens the profile card with the full
        // account details (name, role, email, phone, username, ...).
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showProfileCard,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  color: _adminAvatarImage == null
                      ? null
                      : sch.primaryContainer,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(widget.admin.email,
                        style: TextStyle(
                            fontSize: 10,
                            color: sch.onSurfaceVariant)),
                  ]),
              const SizedBox(width: 6),
              Icon(Icons.expand_more,
                  size: 18, color: sch.onSurfaceVariant),
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
            _profileRow(
                Icons.alternate_email,
                tr('Username'),
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
                                image: _adminAvatarImage!,
                                fit: BoxFit.cover)
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
                          border:
                              Border.all(color: sch.surface, width: 2),
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
                style:
                    TextStyle(fontSize: 12, color: sch.onSurfaceVariant))),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
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
        text: current != null && current.isNotEmpty && !current.startsWith('b64:')
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
              onPressed: () => Navigator.pop(dc),
              child: Text(tr('Cancel'))),
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
    await AppSettings.saveProfile(u, forKey: AppSettings.profileKeyOf(widget.admin));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerLowest,
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
    );
  }

  Widget _errorView() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    return Center(
      child:
          Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off, size: 56, color: sch.outline),
        const SizedBox(height: 12),
        Text(tr('No connection'),
            style: const TextStyle(fontSize: 16)),
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
    var list = _orders;
    // Status quick-filter chips above the table (All / Processing / ...).
    if (_orderStatusFilter != 'All') {
      list = list.where((o) => o.status == _orderStatusFilter).toList();
    }
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
        return CategoriesTablePage(
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
            onEdit: _editCategory,
            onDelete: _deleteCategory);
      case 'products':
        return ProductsTablePage(
            products: _filteredProducts,
            total: _products.length,
            page: _productPage,
            onPage: (p) => setState(() => _productPage = p),
            onSearch: (v) => setState(() {
                  _search = v;
                  _productPage = 0;
                }),
            onAdd: () => _editProduct(),
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
                onBack: () => setState(() => _selectedOrder = null))
            : OrdersTablePage(
                orders: _filteredOrders,
                allOrders: _orders,
                total: _filteredOrders.length,
                page: _orderPage,
                statusFilter: _orderStatusFilter,
                onFilter: (s) => setState(() {
                      _orderStatusFilter = s;
                      _orderPage = 0;
                    }),
                onPage: (p) => setState(() => _orderPage = p),
                onSearch: (v) => setState(() {
                      _search = v;
                      _orderPage = 0;
                    }),
                onOpen: (o) => setState(() => _selectedOrder = o),
                onStatus: _changeStatus);
      case 'reports':
      case 'notifications':
      case 'settings':
      case 'administration':
        return _placeholder();
      case 'feedback':
        return FeedbackTablePage(
            feedbacks: _filteredFeedbacks,
            total: _feedbacks.length,
            page: _feedbackPage,
            onPage: (p) => setState(() => _feedbackPage = p),
            onSearch: (v) => setState(() {
                  _search = v;
                  _feedbackPage = 0;
                }),
            onDelete: _deleteFeedback);
      default:
        return CompaniesTablePage(
            products: _filteredProducts,
            total: _products.length,
            page: _productPage,
            onPage: (p) => setState(() => _productPage = p),
            onSearch: (v) => setState(() {
                  _search = v;
                  _productPage = 0;
                }),
            onAdd: () => _editCompany(),
            onEdit: _editCompany,
            onDelete: _deleteProduct);
    }
  }

  Widget _placeholder() {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_outlined,
          size: 54, color: sch.outline),
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(tr('View All'),
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF5B4FE9)))),
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
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 2),
                    Text(k.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: sch.onSurfaceVariant)),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('#$id  •  ${d.day}/${d.month}/${d.year}',
                          style: TextStyle(
                              fontSize: 11,
                              color: sch.onSurfaceVariant)),
                    ]),
              ),
              const SizedBox(width: 8),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('No orders yet'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sch.onSurfaceVariant))))
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('All products in stock'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sch.onSurfaceVariant))))
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
                        Pill(
                            out ? tr('Out of stock') : '${p.stock}',
                            color: out
                                ? Colors.redAccent
                                : Colors.orange),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(tr('No categories yet'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sch.onSurfaceVariant))))
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
                                          fontWeight:
                                              FontWeight.w600))),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 6),
                            progress(const Color(0xFF5B4FE9),
                                e.value / maxCat),
                          ]));
                }).toList(),
          onViewAll: () => _go('categories'));
    }

    // ------------------------------------------------------------ assemble

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AdminProductEditDialog(repo: widget.repo, existing: p),
    );
    if (done == true) _reload();
  }

  /// Add / Edit from the Companies page: same product rows, but shown and
  /// edited as companies (Company, Location, Website, Verified, Status...).
  Future<void> _editCompany([Product? p]) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AdminCompanyEditDialog(repo: widget.repo, existing: p),
    );
    if (done == true) _reload();
  }

  Future<void> _deleteProduct(Product p) async {
    final tr = AppLocalizations.of(context).t;
    final ok = await _confirm('${tr('Delete')} "${p.title}"?');
    if (ok != true) return;
    await widget.repo.delete(p.id);
    _toast(tr('Product deleted'));
    _reload();
  }

  Future<void> _deleteFeedback(FeedbackItem f) async {
    final tr = AppLocalizations.of(context).t;
    final ok = await _confirm('${tr('Delete')} ${tr('Feedback')}?');
    if (ok != true) return;
    await widget.repo.deleteFeedback(f.id);
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
    _toast(tr('Category deleted'));
    _reload();
  }

  Future<void> _deleteUser(User u) async {
    final tr = AppLocalizations.of(context).t;
    if (u.username.trim().toLowerCase() ==
        ApiService.adminUsername) {
      _toast(tr('Cannot delete the built-in admin account'));
      return;
    }
    final ok = await _confirm('${tr('Delete')} "@${u.username}"?');
    if (ok != true) return;
    await widget.repo.deleteUser(u.username);
    _toast(tr('User deleted'));
    _reload();
  }

  Future<void> _changeStatus(Order o, String status) async {
    await widget.repo.setOrderStatus(o.id, status);
    await widget.orders.setStatus(o.id, status);
    _toast(AppLocalizations.of(context).t('Order status updated'));
    _reload();
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
                  backgroundColor:
                      Theme.of(dc).colorScheme.error),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      _isEdit
                          ? Icons.edit_outlined
                          : Icons.category_outlined,
                      color: Colors.white,
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _isEdit
                                ? tr('Edit Category')
                                : tr('Add Category'),
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
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
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
                Icon(Icons.info_outline,
                    size: 14, color: sch.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      tr('Only the name is required — the rest is optional.'),
                      style: TextStyle(
                          fontSize: 11, color: sch.onSurfaceVariant)),
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
                    icon: Icon(
                        _isEdit ? Icons.check : Icons.add, size: 18),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14)),
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
                child: Text('No records found',
                    style:
                        TextStyle(color: sch.onSurfaceVariant))),
          ...rows,
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text(showingLabel(page * rowsPerPageConst, rows.length),
            style: TextStyle(
                fontSize: 13, color: sch.onSurfaceVariant)),
        const Spacer(),
        IconButton(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left)),
        _pageChip(context, page + 1, active: true),
        IconButton(
            onPressed:
                page < totalPages - 1 ? () => onPage(page + 1) : null,
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
      constraints:
          const BoxConstraints(minWidth: 34, minHeight: 34),
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
      {super.key,
      this.header = false,
      this.color,
      this.maxLines = 1});
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)));
  }
}

// ============================================================================
// Companies page (brand/product catalog presented like the mock's table)
// ============================================================================

class CompaniesTablePage extends StatelessWidget {
  final List<Product> products;
  final int total;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
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
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages =
        (products.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        products.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(
              flex: 3, child: CellText(tr('Company'), header: true)),
          Expanded(
              flex: 3, child: CellText(tr('Location'), header: true)),
          Expanded(
              flex: 3, child: CellText(tr('Website'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Verified'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Status'), header: true)),
          Expanded(flex: 1, child: CellText(tr('Stock'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Price'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Actions'), header: true)),
        ]));

    Widget row(Product p) {
      final name = p.title.isNotEmpty ? p.title : p.brand;
      return InkWell(
        onTap: () => onEdit(p),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: sch.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(8)),
                        child: Text(
                            name.isNotEmpty
                                ? name
                                    .substring(0, 1)
                                    .toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    sch.onPrimaryContainer))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CellText(name,
                            color: const Color(0xFF5B4FE9))),
                  ])),
              Expanded(
                  flex: 3,
                  child: CellText(p.category.isEmpty
                      ? '—'
                      : p.category)),
              Expanded(
                  flex: 3,
                  child: CellText(p.thumbnail.isEmpty
                      ? '—'
                      : p.thumbnail,
                      color: const Color(0xFF5B4FE9))),
              Expanded(
                  flex: 2,
                  child: Pill(
                      p.verified
                          ? tr('Verified')
                          : tr('Unverified'),
                      color: p.verified
                          ? Colors.green
                          : Colors.orange)),
              Expanded(
                  flex: 2,
                  child: Pill(tr(p.status == 'Inactive' ? 'Inactive' : 'Active'),
                      color: p.status == 'Inactive'
                          ? Colors.grey
                          : Colors.green)),
              Expanded(flex: 1, child: CellText('${p.stock}')),
              Expanded(
                  flex: 2,
                  child: CellText(
                      '\$${p.price.toStringAsFixed(2)}')),
              // Edit / Delete actions for this company row.
              Expanded(
                  flex: 2,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: tr('Edit'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onEdit(p),
                          icon: const Icon(Icons.edit_outlined,
                              size: 19, color: Color(0xFF5B4FE9)),
                        ),
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
      searchHint: tr('Search companies...'),
      onSearch: onSearch,
      actionLabel: tr('New Company'),
      onAction: onAdd,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
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
      required this.onEdit,
      required this.onDelete,
      this.editedSlug});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages =
        (cats.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        cats.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(flex: 2, child: CellText('Slug', header: true)),
          Expanded(flex: 4, child: CellText(tr('Description'), header: true)),
          Expanded(flex: 3, child: CellText('URL', header: true)),
          const Expanded(flex: 1, child: SizedBox()),
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
                        color: cat.image.isEmpty
                            ? sch.primaryContainer
                            : null,
                        image: cat.image.isEmpty
                            ? null
                            : DecorationImage(
                                image: NetworkImage(cat.image),
                                fit: BoxFit.cover),
                        borderRadius: BorderRadius.circular(8)),
                    child: cat.image.isEmpty
                        ? Text(
                            cat.name.isNotEmpty
                                ? cat.name
                                    .substring(0, 1)
                                    .toUpperCase()
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
              child: CellText(cat.slug,
                  color: const Color(0xFF5B4FE9))),
          Expanded(
              flex: 4,
              child: CellText(
                  cat.description.isEmpty ? '—' : cat.description,
                  maxLines: 2)),
          Expanded(flex: 3, child: CellText(cat.url)),
          Expanded(
              flex: 1,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: tr('Edit'),
                        onPressed: () => onEdit(cat),
                        icon: const Icon(Icons.edit_outlined,
                            size: 20, color: Color(0xFF5B4FE9))),
                    IconButton(
                        tooltip: tr('Delete'),
                        onPressed: () => onDelete(cat),
                        icon: const Icon(Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent)),
                  ]))),
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
          'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
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
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages =
        (products.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        products.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 4, child: CellText(tr('Name'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Brand'), header: true)),
          Expanded(
              flex: 2,
              child: CellText(tr('Categories'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Price'), header: true)),
          Expanded(
              flex: 1, child: CellText(tr('Stock'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Rating'), header: true)),
          const Expanded(flex: 2, child: SizedBox()),
        ]));

    Widget row(Product p) => InkWell(
          onTap: () => onEdit(p),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                    flex: 4,
                    child: CellText(p.title,
                        color: const Color(0xFF5B4FE9))),
                Expanded(
                    flex: 2,
                    child: CellText(
                        p.brand.isEmpty ? '—' : p.brand)),
                Expanded(flex: 2, child: CellText(p.category)),
                Expanded(
                    flex: 2,
                    child: CellText(
                        '\$${p.price.toStringAsFixed(2)}')),
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
                      const Icon(Icons.star,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      CellText(p.rating.toStringAsFixed(1)),
                    ])),
                // Edit / Delete actions for this product row.
                Expanded(
                    flex: 2,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: tr('Edit'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onEdit(p),
                            icon: const Icon(Icons.edit_outlined,
                                size: 19, color: Color(0xFF5B4FE9)),
                          ),
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
          'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
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
    final totalPages =
        (users.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        users.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(
              flex: 3,
              child: CellText(tr('Username'), header: true)),
          Expanded(
              flex: 4, child: CellText(tr('Email'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Phone'), header: true)),
          Expanded(flex: 2, child: CellText('Role', header: true)),
          const Expanded(flex: 1, child: SizedBox()),
        ]));

    Widget row(User u) {
      final isAdmin = u.isAdmin ||
          u.username.trim().toLowerCase() ==
              ApiService.adminUsername;
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
                            ? const Color(0xFF5B4FE9)
                                .withValues(alpha: 0.15)
                            : Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                        child: Text(
                            u.fullName.isNotEmpty
                                ? u.fullName
                                    .substring(0, 1)
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    Color(0xFF5B4FE9)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: CellText(u.fullName.isEmpty
                            ? '@${u.username}'
                            : u.fullName)),
                  ])),
              Expanded(
                  flex: 3, child: CellText('@${u.username}')),
              Expanded(
                  flex: 4,
                  child: CellText(
                      u.email.isEmpty ? '—' : u.email)),
              Expanded(
                  flex: 2,
                  child: CellText(
                      u.phone.isEmpty ? '—' : u.phone)),
              Expanded(
                  flex: 2,
                  child: Pill(isAdmin ? tr('Admin') : tr('User'),
                      color: isAdmin
                          ? const Color(0xFF5B4FE9)
                          : Colors.green)),
              Expanded(
                  flex: 1,
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: isAdmin
                          ? const SizedBox()
                          : IconButton(
                              tooltip: tr('Delete'),
                              onPressed: () => onDelete(u),
                              icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color:
                                      Colors.redAccent)))),
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
          'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

class UserDetailPage extends StatelessWidget {
  final User user;
  final VoidCallback onBack;
  const UserDetailPage(
      {super.key, required this.user, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 110, child: CellText(k, header: true)),
          Expanded(child: CellText(v.isEmpty ? '—' : v)),
        ]));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Text(tr('User'),
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: sch.outlineVariant)),
        child: Column(children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: sch.primaryContainer,
              child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName
                          .substring(0, 1)
                          .toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: sch.onPrimaryContainer))),
          const SizedBox(height: 10),
          Text(
              user.fullName.isEmpty
                  ? '@${user.username}'
                  : user.fullName,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
          Text('@${user.username}',
              style: TextStyle(
                  fontSize: 13,
                  color: sch.onSurfaceVariant)),
          const Divider(height: 28),
          row(tr('Username'), user.username),
          row(tr('Email'), user.email),
          row(tr('Phone'), user.phone),
          row('Role', user.isAdmin ? tr('Admin') : tr('User')),
        ]),
      ),
    ]);
  }
}

// ============================================================================
// Orders page + detail
// ============================================================================

class OrdersTablePage extends StatelessWidget {
  final List<Order> orders;

  /// Unfiltered list — used for the summary cards and filter chips.
  final List<Order> allOrders;
  final int total;
  final int page;
  final String statusFilter;
  final ValueChanged<String> onFilter;
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
      required this.statusFilter,
      required this.onFilter,
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
    final totalPages =
        (orders.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        orders.skip(page * perPage).take(perPage).toList();
    const statuses = ['Processing', 'Shipped', 'Delivered', 'Cancelled'];

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(
              flex: 2, child: CellText(tr('Order ID'), header: true)),
          Expanded(
              flex: 3, child: CellText(tr('Customer'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Date'), header: true)),
          Expanded(flex: 2, child: CellText(tr('Total'), header: true)),
          Expanded(flex: 2, child: CellText('Status', header: true)),
          Expanded(
              flex: 2,
              child: CellText(tr('Update status'), header: true)),
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
                          style: TextStyle(
                              fontSize: 11, color: sch.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                    ])),
          ]),
        ),
      );
    }

    final revenue = allOrders.fold<double>(
        0, (sum, o) => sum + (o.status == 'Cancelled' ? 0 : o.total));

    // --------------------------------------------- status filter chips
    Widget chip(String label, int count) {
      final selected = statusFilter == label;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onFilter(label),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: selected ? const Color(0xFF5B4FE9) : sch.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? const Color(0xFF5B4FE9)
                        : sch.outlineVariant)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : sch.onSurfaceVariant)),
              const SizedBox(width: 6),
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.25)
                          : sch.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : sch.onSurfaceVariant))),
            ]),
          ),
        ),
      );
    }

    Widget row(Order o) {
      final date = o.date.toLocal().toString();
      final itemsCount =
          o.items.fold<int>(0, (sum, it) => sum + it.quantity);
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
                        Text('$itemsCount items',
                            style: TextStyle(
                                fontSize: 10,
                                color: sch.onSurfaceVariant)),
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
                        child: CellText(o.owner.isEmpty
                            ? tr('Guest')
                            : o.owner)),
                  ])),
              Expanded(
                  flex: 2,
                  child: CellText(date.split(' ').first)),
              Expanded(
                  flex: 2,
                  child: CellText(
                      '\$${o.total.toStringAsFixed(2)}')),
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
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(o.status),
                                    size: 13,
                                    color: _statusColor(o.status)),
                                const SizedBox(width: 5),
                                Text(o.status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor(
                                            o.status))),
                              ])))),
              Expanded(
                  flex: 2,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: sch.outlineVariant),
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: DropdownButton<String>(
                          value: o.status,
                          isExpanded: true,
                          underline:
                              const SizedBox.shrink(),
                          icon: Icon(Icons.expand_more,
                              size: 18,
                              color: sch.onSurfaceVariant),
                          items: statuses
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Row(children: [
                                    Icon(_statusIcon(s),
                                        size: 14,
                                        color: _statusColor(s)),
                                    const SizedBox(width: 6),
                                    Text(s,
                                        style: const TextStyle(
                                            fontSize: 12)),
                                  ])))
                              .toList(),
                          onChanged: (s) => s != null &&
                                  s != o.status
                              ? onStatus(o, s)
                              : null))),
            ])),
      );
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      // ------------------------------------------- summary cards row
      Row(children: [
        statCard(tr('Total Orders'), '${allOrders.length}',
            Icons.receipt_long_outlined, const Color(0xFF5B4FE9)),
        const SizedBox(width: 12),
        statCard(
            tr('Revenue'),
            '\\${revenue.toStringAsFixed(2)}',
            Icons.payments_outlined,
            const Color(0xFF15803D)),
        const SizedBox(width: 12),
        statCard(
            tr('Processing'),
            '${allOrders.where((o) => o.status == 'Processing').length}',
            Icons.autorenew,
            const Color(0xFFB45309)),
        const SizedBox(width: 12),
        statCard(
            tr('Delivered'),
            '${allOrders.where((o) => o.status == 'Delivered').length}',
            Icons.check_circle_outline,
            const Color(0xFF15803D)),
      ]),
      const SizedBox(height: 16),
      // ---------------------------------------------- filter chips
      Wrap(children: [
        chip('All', allOrders.length),
        ...statuses
            .map((s) => chip(s, allOrders.where((o) => o.status == s).length)),
      ]),
      const SizedBox(height: 12),
      // ------------------------------------------------ table card
      Container(
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sch.outlineVariant)),
        child: AdminTableScaffold(
          searchHint: tr('Search orders...'),
          onSearch: onSearch,
          page: page,
          totalPages: totalPages,
          onPage: onPage,
          showingLabel: (start, n) =>
              'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
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
  const OrderDetailPage(
      {super.key, required this.order, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final tr = AppLocalizations.of(context).t;
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 100,
                  child: CellText(k, header: true)),
              Expanded(child: CellText(v, maxLines: 3)),
            ]));
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Text('${tr('Order')} #${order.id}',
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: sch.outlineVariant)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(tr('Customer'),
                  order.owner.isEmpty ? tr('Guest') : order.owner),
              row(tr('Date'), order.date.toLocal().toString()),
              row(tr('Address'), order.deliveryAddress),
              row('Status', order.status),
              const Divider(height: 24),
              ...order.items.map((it) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                        child: CellText(it.product.title)),
                    CellText('x${it.quantity}'),
                    const SizedBox(width: 16),
                    SizedBox(
                        width: 80,
                        child: Text(
                            '\$${(it.product.price * it.quantity).toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w600))),
                  ]))),
              const Divider(height: 24),
              Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      '${tr('Total')}: \$${order.total.toStringAsFixed(2)}',
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
  final void Function(FeedbackItem) onDelete;
  const FeedbackTablePage(
      {super.key,
      required this.feedbacks,
      required this.total,
      required this.page,
      required this.onPage,
      required this.onSearch,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    const perPage = AdminTableScaffold.rowsPerPageConst;
    final totalPages =
        (feedbacks.length / perPage).ceil().clamp(1, 1 << 30);
    final slice =
        feedbacks.skip(page * perPage).take(perPage).toList();

    Widget headerRow() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Expanded(
              flex: 3, child: CellText(tr('Name'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('User'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Rating'), header: true)),
          Expanded(
              flex: 5, child: CellText(tr('Message'), header: true)),
          Expanded(
              flex: 2, child: CellText(tr('Date'), header: true)),
          const Expanded(flex: 1, child: SizedBox()),
        ]));

    Widget row(FeedbackItem f) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: CellText(
                  f.name.isEmpty ? tr('Guest') : f.name)),
          Expanded(
              flex: 2,
              child: CellText(f.owner.isEmpty ? '—' : '@${f.owner}')),
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
                  f.message.isEmpty ? '—' : f.message,
                  maxLines: 2)),
          Expanded(
              flex: 2,
              child: CellText(
                  f.date.toLocal().toString().substring(0, 16))),
          Expanded(
              flex: 1,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: tr('Delete'),
                    onPressed: () => onDelete(f),
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent),
                  ))),
        ]));

    return AdminTableScaffold(
      searchHint: tr('Search feedback...'),
      onSearch: onSearch,
      page: page,
      totalPages: totalPages,
      onPage: onPage,
      showingLabel: (start, n) =>
          'Showing ${n == 0 ? 0 : start + 1}-${start + n} of $total',
      header: headerRow(),
      rows: slice.map(row).toList(),
    );
  }
}

// ============================================================================
// Add/Edit product dialog (compact, table-context form)
// ============================================================================

class AdminProductEditDialog extends StatefulWidget {
  final AdminRepository repo;
  final Product? existing;
  const AdminProductEditDialog(
      {super.key, required this.repo, this.existing});

  @override
  State<AdminProductEditDialog> createState() =>
      _AdminProductEditDialogState();
}

class _AdminProductEditDialogState
    extends State<AdminProductEditDialog> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController brand =
      TextEditingController(text: widget.existing?.brand ?? '');
  late final TextEditingController category =
      TextEditingController(text: widget.existing?.category ?? '');
  late final TextEditingController price = TextEditingController(
      text: (widget.existing?.price ?? 0).toString());
  late final TextEditingController stock =
      TextEditingController(text: (widget.existing?.stock ?? 0).toString());
  late final TextEditingController rating = TextEditingController(
      text: (widget.existing?.rating ?? 0).toString());

  bool _saving = false;

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

  Future<void> _save() async {
    if (!(_f.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
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
        status: widget.existing?.status ?? 'Active');
    if (widget.existing == null) {
      await widget.repo.add(p);
    } else {
      await widget.repo.update(p);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      isEdit
                          ? Icons.edit_outlined
                          : Icons.storefront_outlined,
                      color: Colors.white,
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isEdit
                                ? tr('Edit Product')
                                : tr('New Company'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                            isEdit
                                ? tr('Update the company details')
                                : tr('Create a new company for the catalog'),
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
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? tr('Please enter a name')
                                  : null),
                      const SizedBox(height: 16),
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
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
                                              hint: 'beauty')),
                                    ])),
                          ]),
                      const SizedBox(height: 16),
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
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
                                              const TextInputType
                                                  .numberWithOptions(
                                                      decimal: true),
                                          decoration: _decoration(
                                            prefixText: '\$ ',
                                            hint: '0.00',
                                          ),
                                          validator: (v) =>
                                              (double.tryParse(v ?? '') ??
                                                      -1) <
                                                  0
                                                  ? tr(
                                                      'Enter a valid price')
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
                                              icon:
                                                  Icons.inventory_2_outlined,
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
                                              const TextInputType
                                                  .numberWithOptions(
                                                      decimal: true),
                                          decoration: _decoration(
                                              icon: Icons.star_outline,
                                              hint: '0.0',
                                          ),
                                          validator: (v) =>
                                              (double.tryParse(v ?? '') ??
                                                      -1) <
                                                  0
                                                  ? tr(
                                                      'Enter a valid rating')
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FE9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Icon(
                            isEdit ? Icons.check : Icons.add,
                            size: 18),
                    label: Text(isEdit
                        ? tr('Save')
                        : tr('Add Product')),
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
// Add/Edit company dialog (Companies page — product rows shown as companies)
// ============================================================================

class AdminCompanyEditDialog extends StatefulWidget {
  final AdminRepository repo;
  final Product? existing;
  const AdminCompanyEditDialog(
      {super.key, required this.repo, this.existing});

  @override
  State<AdminCompanyEditDialog> createState() =>
      _AdminCompanyEditDialogState();
}

class _AdminCompanyEditDialogState extends State<AdminCompanyEditDialog> {
  final _f = GlobalKey<FormState>();
  late final TextEditingController company = TextEditingController(
      text: widget.existing?.title ?? '');
  late final TextEditingController location = TextEditingController(
      text: widget.existing?.category ?? '');
  late final TextEditingController website = TextEditingController(
      text: widget.existing?.thumbnail ?? '');
  late final TextEditingController price = TextEditingController(
      text: (widget.existing?.price ?? 0).toString());
  late final TextEditingController stock = TextEditingController(
      text: (widget.existing?.stock ?? 0).toString());
  late final TextEditingController rating = TextEditingController(
      text: (widget.existing?.rating ?? 0).toString());

  late bool _verified = widget.existing?.verified ?? false;

  /// Company availability shown in the Status dropdown: Active / Inactive.
  late String _status = widget.existing?.status ?? 'Active';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      company,
      location,
      website,
      price,
      stock,
      rating,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_f.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final p = Product(
        id: widget.existing?.id ?? -1,
        title: company.text.trim(),
        price: double.tryParse(price.text) ?? 0,
        discountPercentage: widget.existing?.discountPercentage ?? 0,
        rating: double.tryParse(rating.text) ?? 0,
        stock: int.tryParse(stock.text) ?? 0,
        brand: widget.existing?.brand ?? '',
        category: location.text.trim().toLowerCase(),
        description: widget.existing?.description ?? '',
        thumbnail: website.text.trim(),
        images: widget.existing?.images ?? const [],
        status: _status,
        verified: _verified);
    if (widget.existing == null) {
      await widget.repo.add(p);
    } else {
      await widget.repo.update(p);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  InputDecoration _decoration({
    IconData? icon,
    String? prefixText,
    String? hint,
  }) {
    final sch = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefixText,
      prefixStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: sch.onSurfaceVariant),
      filled: true,
      fillColor: sch.surfaceContainerLowest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      isEdit
                          ? Icons.edit_outlined
                          : Icons.business_outlined,
                      color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          isEdit
                              ? tr('Edit Company')
                              : tr('New Company'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                          isEdit
                              ? tr('Update the company details')
                              : tr('Create a new company for the catalog'),
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
                      _label(tr('Company')),
                      TextFormField(
                          controller: company,
                          autofocus: !isEdit,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.business_outlined,
                            hint: 'e.g. Acme Corp',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? tr('Please enter a name')
                                  : null),
                      const SizedBox(height: 16),
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: _verified
                                                    ? const Color(0xFF5B4FE9)
                                                        .withValues(
                                                            alpha: 0.5)
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _verified
                                                          ? const Color(
                                                              0xFF5B4FE9)
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant))),
                                          Switch(
                                            value: _verified,
                                            activeTrackColor:
                                                const Color(0xFF5B4FE9),
                                            onChanged: (v) => setState(() =>
                                                _verified = v),
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
                                                child: Text(
                                                    s == 'Active'
                                                        ? tr('Active')
                                                        : tr('Inactive'))))
                                            .toList(),
                                        onChanged: (v) => setState(() =>
                                            _status = v ?? 'Active'),
                                      ),
                                    ])),
                          ]),
                      const SizedBox(height: 16),
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
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
                                              const TextInputType
                                                  .numberWithOptions(
                                                      decimal: true),
                                          decoration: _decoration(
                                            prefixText: '\$ ',
                                            hint: '0.00',
                                          ),
                                          validator: (v) =>
                                              (double.tryParse(v ?? '') ??
                                                      -1) <
                                                  0
                                                  ? tr(
                                                      'Enter a valid price')
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
                                              icon:
                                                  Icons.inventory_2_outlined,
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
                                              const TextInputType
                                                  .numberWithOptions(
                                                      decimal: true),
                                          decoration: _decoration(
                                              icon: Icons.star_outline,
                                              hint: '0.0',
                                          ),
                                          validator: (v) =>
                                              (double.tryParse(v ?? '') ??
                                                      -1) <
                                                  0
                                                  ? tr(
                                                      'Enter a valid rating')
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
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4FE9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14)),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Icon(
                            isEdit ? Icons.check : Icons.add,
                            size: 18),
                    label: Text(isEdit
                        ? tr('Save')
                        : tr('Add Company')),
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
