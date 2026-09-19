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
    if (!SupabaseService.testMode) {
      cloud = await SupabaseService.instance.orders(owner: owner);
    }
    final local = await AppSettings.loadAllOrders();
    final mine = owner == null || owner.isEmpty;
    final seen = <String>{};
    for (final o in [...cloud, ...local]) {
      // Device-local orders must match the account too, so a shared phone
      // does not leak one account's orders into another's history. Legacy
      // local rows with no owner at all stay visible to everyone (they
      // predate per-account ownership).
      if (!(mine || o.owner.isEmpty || o.owner == owner)) continue;
      if (seen.add(o.id)) orders.add(o);
    }
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
    await SupabaseService.instance.saveOrder(order);
  }

  /// Update the status of an order (used by the Admin panel) — locally and
  /// in the shared cloud.
  ///
  /// Returns true when the cloud write succeeded, so the admin UI can warn
  /// instead of silently pretending the shopper will see the new status.
  /// The local cache is NOT rewritten wholesale here: it holds every
  /// account's orders on this device, and overwriting it from the admin's
  /// in-memory list could clobber other users' data.
  Future<bool> setStatus(String id, String status) async {
    for (var i = 0; i < orders.length; i++) {
      if (orders[i].id == id && orders[i].status != status) {
        orders[i] = orders[i].copyWith(status: status);
        break;
      }
    }
    return SupabaseService.instance.updateOrderStatus(id, status);
  }
}
