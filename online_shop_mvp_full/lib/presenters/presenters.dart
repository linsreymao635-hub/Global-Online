import '../models/models.dart';
import '../repositories/repositories.dart';

class LoginPresenter {
  final AuthRepository repo;
  LoginPresenter(this.repo);
  Future<User?> login(String u, String p) {
    if (u.trim().isEmpty || p.isEmpty)
      throw Exception('Username and password are required');
    return repo.login(u.trim(), p);
  }
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
      required String e}) {
    if ([f, l, u, p, e].any((x) => x.trim().isEmpty))
      throw Exception('Please fill in all fields');
    if (p != c) throw Exception('Passwords do not match');
    if (p.length < 6) throw Exception('Password must be at least 6 characters');
    return repo.signup(f.trim(), l.trim(), u.trim(), p, e.trim());
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
  int get count => items.fold(0, (s, i) => s + i.quantity);
  double get total => items.fold(0, (s, i) => s + i.subtotal);
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
  void create(List<CartItem> items, double total, Address a) {
    orders.insert(
        0,
        Order(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            date: DateTime.now(),
            items: items
                .map((x) => CartItem(product: x.product, quantity: x.quantity))
                .toList(),
            total: total,
            status: 'Processing',
            deliveryAddress: '${a.address}, ${a.city}, ${a.country}'));
  }
}
