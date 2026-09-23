import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/app_settings.dart';
import '../services/supabase_service.dart';

class LoginPresenter {
  final AuthRepository repo;
  LoginPresenter(this.repo);
  Future<User?> login(String u, String p) {
    if (u.trim().isEmpty || p.isEmpty)
      throw Exception('Username and password are required');
    return repo.login(u.trim(), p);
  }

  Future<User?> googleLogin() => repo.googleLogin();

  /// Register the Telegram account returned by the Login Widget in the shared
  /// cloud directory (provider: 'telegram') so it is a real account, not a
  /// guest. Mirrors [googleLogin].
  Future<User?> telegramLogin(User u) => repo.telegramLogin(u);
}

class SignupPresenter {
  final AuthRepository repo;
  SignupPresenter(this.repo);
  Future<User?> signup(
      {required String f,
      required String l,
      required String u,
      required String p,
      required String c,
      required String e,
      required String ph}) {
    if ([f, l, u, p, e, ph].any((x) => x.trim().isEmpty))
      throw Exception('Please fill in all fields');
    if (p != c) throw Exception('Passwords do not match');
    if (p.length < 6) throw Exception('Password must be at least 6 characters');
    if (!e.contains('@')) throw Exception('Please enter a valid email address');
    return repo.signup(f.trim(), l.trim(), u.trim(), p, e.trim(), ph.trim());
  }
}

class HomePresenter {
  final ProductRepository repo;
  HomePresenter(this.repo);
  Future<List<Product>> products() => repo.all();
  Future<List<Product>> search(String q) =>
      q.trim().isEmpty ? repo.all() : repo.search(q.trim());
}

class CategoryPresenter {
  final ProductRepository repo;
  CategoryPresenter(this.repo);
  Future<List<Category>> categories() => repo.categories();
  Future<List<Product>> products(String s) => repo.category(s);
  Future<List<Product>> search(String q) => repo.search(q);
}

class CartPresenter {
  final List<CartItem> items = [];
  static const double taxRate = 0.10;
  int get count => items.fold(0, (s, i) => s + i.quantity);
  double get total => items.fold(0, (s, i) => s + i.subtotal);
  double get tax => total * taxRate;
  double get grandTotal => total + tax;
  void add(Product p) {
    final i = items.indexWhere((x) => x.product.id == p.id);
    if (i < 0)
      items.add(CartItem(product: p));
    else
      items[i].quantity++;
  }

  void minus(Product p) {
    final i = items.indexWhere((x) => x.product.id == p.id);
    if (i < 0) return;
    if (items[i].quantity > 1)
      items[i].quantity--;
    else
      items.removeAt(i);
  }

  void remove(Product p) => items.removeWhere((x) => x.product.id == p.id);

  void clear() => items.clear();
}

class FavoritePresenter {
  final Set<int> ids = {};
  bool has(Product p) => ids.contains(p.id);
  void toggle(Product p) {
    if (!ids.add(p.id)) ids.remove(p.id);
  }
}

class OrderPresenter {
  final List<Order> orders = [];

  /// True while any order is still being processed ('pending').
  /// Used to block account deletion until those orders are settled.
  bool get hasPending => orders.any((o) => o.status == 'Processing');

  /// Restore this account's orders.
  ///
  /// Fetched fresh from the cloud every time (shared with the admin panel —
  /// statuses the admin changes are picked up here immediately), merged
  /// with any device-only orders (e.g. created while offline). [owner]
  /// limits the fetch to this account's orders so one user never sees (or
  /// gets) another user's orders; null/empty loads everything (admin).
  Future<void> load({String? owner}) async {
    orders.clear();
    var cloud = const <Order>[];
    var cloudReachable = false;
    if (!SupabaseService.testMode) {
      final result = await SupabaseService.instance.ordersResult(owner: owner);
      cloud = result.orders;
      cloudReachable = result.reachable;
    }
    final local = await AppSettings.loadAllOrders();
    final synced = await AppSettings.loadSyncedOrderIds();
    final merged = OrderPresenter.mergeOrders(
        cloud: cloud,
        cloudReachable: cloudReachable,
        local: local,
        synced: synced,
        owner: owner);
    orders.addAll(merged);

    // Persist the cloud-authoritative copies too. Previously this cache was
    // only written at checkout, leaving a `Processing` copy on the device
    // after an admin changed it to Shipped/Delivered. A later offline read
    // could then resurrect that stale status (or a deleted order).
    if (cloudReachable) {
      final allScope = owner == null || owner.isEmpty;
      bool belongsToScope(Order o) =>
          allScope || o.owner.isEmpty || o.owner == owner;
      final cloudIds = cloud.map((o) => o.id).toSet();
      final reconciled = <Order>[
        ...local.where((o) {
          if (!belongsToScope(o)) return true;
          // Keep purely offline orders. A cloud-synced row is replaced by its
          // newest cloud copy, or dropped when the admin deleted it.
          return !synced.contains(o.id);
        }),
        ...cloud,
      ];
      await AppSettings.saveAllOrders(reconciled);
      // A missing synced id was deleted in the cloud, so it must not be
      // treated as an unsent local order on the next refresh.
      for (final id in synced.where((id) =>
          !cloudIds.contains(id) &&
          local.any((o) => o.id == id && belongsToScope(o)))) {
        await AppSettings.unmarkOrderSynced(id);
      }
    }
  }

  /// Merge cloud + device-local orders, newest first.
  ///
  /// The cloud is the SOURCE OF TRUTH whenever it is reachable:
  ///  * cloud copies always win over device copies, so a status the admin
  ///    changed (Delivered / Shipped / …) is shown exactly as stored;
  ///  * a previously-synced order that is MISSING from a successful cloud
  ///    read was deleted by the admin, so its stale local copy is dropped;
  ///  * orders that never reached the cloud (placed while offline) are kept.
  ///
  /// [owner] limits the result to one account's orders (so one user never
  /// sees another user's orders); null/empty loads everything (admin).
  static List<Order> mergeOrders({
    required List<Order> cloud,
    required bool cloudReachable,
    required List<Order> local,
    required Set<String> synced,
    String? owner,
  }) {
    final mine = owner == null || owner.isEmpty;
    final byId = <String, Order>{};
    for (final o in cloud) {
      // Same account rule as the local rows below: the cloud query already
      // filters by owner, and this second pass guarantees one user's orders
      // can never leak into another user's history even if a caller passes
      // an unfiltered list. Legacy ownerless rows stay visible to everyone.
      if (!(mine || o.owner.isEmpty || o.owner == owner)) continue;
      byId[o.id] = o;
    }
    for (final o in local) {
      // Device-local orders must match the account too, so a shared phone
      // does not leak one account's orders into another's history. Legacy
      // local rows with no owner at all stay visible to everyone (they
      // predate per-account ownership).
      if (!(mine || o.owner.isEmpty || o.owner == owner)) continue;
      if (cloudReachable && synced.contains(o.id) && !byId.containsKey(o.id)) {
        continue; // deleted from the cloud — drop the stale local copy
      }
      byId.putIfAbsent(o.id, () => o);
    }
    return byId.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> create(List<CartItem> items, double total, Address a,
      {String owner = ''}) async {
    final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        items: items
            .map((x) => CartItem(product: x.product, quantity: x.quantity))
            .toList(),
        total: total,
        status: 'Processing',
        deliveryAddress: '${a.address}, ${a.city}, ${a.country}',
        owner: owner);
    orders.insert(0, order);
    await AppSettings.saveAllOrders(orders);
    // Push to the shared cloud so the Admin panel (any device) sees it.
    final ok = await SupabaseService.instance.saveOrder(order);
    // Remember the order reached the cloud: it is then treated as cloud
    // authority for existence (a later "missing" read means the admin
    // deleted it) while keeping working offline orders purely local.
    if (ok) await AppSettings.markOrderSynced(order.id);
  }

  /// Record a payment-verified order that the BACKEND already created
  /// (via `create_verified_order`). No second cloud write happens here —
  /// the id is the checkout reference, which the RPC used as the order id,
  /// so this only mirrors the cloud row into the local list/cache.
  Future<void> createVerified(List<CartItem> items, double total, Address a,
      {required String id, String owner = ''}) async {
    // Already loaded by the RPC path (e.g. hot-restart race) — nothing to do.
    if (orders.any((o) => o.id == id)) return;
    final order = Order(
        id: id,
        date: DateTime.now(),
        items: items
            .map((x) => CartItem(product: x.product, quantity: x.quantity))
            .toList(),
        total: total,
        status: 'Processing',
        deliveryAddress: '${a.address}, ${a.city}, ${a.country}',
        owner: owner);
    orders.insert(0, order);
    await AppSettings.saveAllOrders(orders);
    await AppSettings.markOrderSynced(order.id);
  }

  /// Update the status of an order (used by the Admin panel) — locally and
  /// in the shared cloud.
  ///
  /// Returns true when the cloud write succeeded, so the admin UI can warn
  /// instead of silently pretending the shopper will see the new status.
  Future<bool> setStatus(String id, String status) async {
    // Do not mutate the locally displayed/cache copy until PostgREST confirms
    // that the database row was actually updated. This avoids a false
    // "Delivered" state when a write is rejected or the network drops.
    final saved = await SupabaseService.instance.updateOrderStatus(id, status);
    if (!saved) return false;
    for (var i = 0; i < orders.length; i++) {
      if (orders[i].id == id && orders[i].status != status) {
        orders[i] = orders[i].copyWith(status: status);
        break;
      }
    }
    return true;
  }

  /// Remove an order (admin delete) from the in-memory list, the local
  /// cache and the cloud-synced marker so it disappears from every device.
  Future<void> remove(String id) async {
    final removed = orders.where((o) => o.id != id).toList();
    orders
      ..clear()
      ..addAll(removed);
    await AppSettings.saveAllOrders(orders);
    await AppSettings.unmarkOrderSynced(id);
  }
}
