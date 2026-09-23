import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/google_auth_service.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final ApiService api;
  final GoogleAuthService _google = GoogleAuthService();
  AuthRepository(this.api);
  Future<User?> login(String u, String p) => api.login(u, p);
  Future<User?> signup(
          String f, String l, String u, String p, String e, String ph) =>
      api.signup(f, l, u, p, e, ph);
  Future<User?> googleLogin() async {
    final u = await _google.signIn();
    if (u == null) return null;
    // Register the Google account in the shared cloud directory so the admin
    // (and other devices) can see it. No password → it can only sign in via
    // Google, never with a typed password. Awaited so we know whether the
    // account is really in the cloud (drives delete auto-logout) and the
    // async error does not slip through unawaited.
    final ok = await SupabaseService.instance.upsertUser({
      'username': u.username.trim().toLowerCase(),
      'first_name': u.firstName,
      'last_name': u.lastName,
      'email': u.email,
      'phone': u.phone,
      'image': u.image ?? '',
      'provider': 'google',
      'is_admin': false,
    }).catchError((_) => false);
    await AppSettings.markSessionCloudOk(ok);
    return u;
  }

  /// Register a Telegram account (returned by the Login Widget) in the shared
  /// cloud directory so the admin and other devices can see it, mirroring
  /// [googleLogin]. The Telegram payload already carries the user's real name,
  /// @username (e.g. Lin_Sreymao) and photo — no password is stored because
  /// the account can only sign in via Telegram. This is what turns a Telegram
  /// sign-in into a real, shared account instead of a throwaway guest.
  Future<User?> telegramLogin(User u) async {
    final ok = await SupabaseService.instance.upsertUser({
      'username': u.username.trim().toLowerCase(),
      'first_name': u.firstName,
      'last_name': u.lastName,
      'email': u.email,
      'phone': u.phone,
      'image': u.image ?? '',
      'provider': 'telegram',
      'is_admin': false,
    }).catchError((_) => false);
    await AppSettings.markSessionCloudOk(ok);
    return u;
  }
}

class ProductRepository {
  final ApiService api;
  ProductRepository(this.api);
  Future<List<Product>> all() => api.getProducts();
  Future<List<Product>> search(String q) => api.searchProducts(q);
  Future<List<Product>> category(String s) => api.category(s);
  Future<List<Category>> categories() => api.categories();
}

/// Admin-facing operations: manage products, categories, users and orders.
/// Everything reads/writes the shared Supabase backend so admin edits and
/// shopper activity are visible across all devices.
class AdminRepository {
  final ApiService api;
  AdminRepository(this.api);
  final SupabaseService supa = SupabaseService.instance;
  Future<List<Product>> products() => api.getProducts();
  Future<List<Category>> categories() => api.categories();
  Future<void> add(Product p) => api.addProduct(p);
  Future<void> update(Product p) => api.updateProduct(p);
  Future<void> delete(int id) => api.deleteProduct(id);
  Future<void> addCategory(String name,
          {String slug = '', String description = '', String image = ''}) =>
      api.addCategory(name, slug: slug, description: description, image: image);

  Future<void> updateCategory(Category original,
          {required String name,
          required String slug,
          String description = '',
          String image = ''}) =>
      api.updateCategory(original,
          name: name, slug: slug, description: description, image: image);
  Future<void> deleteCategory(Category c) => api.deleteCategory(c);

  /// All shop accounts registered in the cloud directory.
  Future<List<User>> users() async =>
      (await supa.allUsers()).map(User.fromSupabase).toList();

  /// Delete a shop account (admin action).
  Future<void> deleteUser(String username) => supa.deleteUser(username);

  /// Promote/demote an account to/from admin (Administration page). Returns
  /// true when the cloud accepted the change.
  Future<bool> setUserAdmin(String username, bool isAdmin) =>
      supa.updateUserRole(username, isAdmin);

  /// Promotion path for an existing shopper. The RLS migration permits this
  /// only to authenticated administrators.
  Future<bool> setUserVendor(String username, bool isVendor) =>
      supa.updateUserVendorRole(username, isVendor);

  /// Create a new staff/shopper account from the Administration page.
  /// Uploads the password hash so the account can actually sign in.
  Future<bool> createUser(
      {required String username,
      String firstName = '',
      String lastName = '',
      String email = '',
      String phone = '',
      String password = '',
      bool isAdmin = false,
      bool isVendor = false}) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty || password.isEmpty) return Future.value(false);
    return supa.upsertUser({
      'username': key,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'image': '',
      'is_admin': isAdmin,
      'role': isAdmin ? 'admin' : (isVendor ? 'vendor' : 'user'),
      'provider': 'local',
      'password_hash': SupabaseService.hashPassword(password),
    });
  }

  /// Every order in the shop (not just this device's).
  Future<List<Order>> orders() => supa.orders();

  /// Write the new status to the shared cloud. Returns true when the row
  /// was actually updated — the admin panel surfaces a warning otherwise
  /// (a failed write would leave the shopper's Order History stale).
  Future<bool> setOrderStatus(String id, String status) =>
      supa.updateOrderStatus(id, status);

  /// Delete an order row from the shared cloud so it disappears for the
  /// shopper on every device.
  Future<bool> deleteOrder(String id) => supa.deleteOrder(id);

  /// Feedback left by shoppers across all devices.
  Future<List<FeedbackItem>> feedbacks() => supa.feedbacks();
  Future<void> deleteFeedback(int id) => supa.deleteFeedback(id);
}

/// Vendor operations never accept an arbitrary owner from the UI. The signed
/// in vendor is fixed when this repository is constructed.
class VendorRepository {
  final String username;
  final SupabaseService supa = SupabaseService.instance;
  VendorRepository(String username) : username = username.trim().toLowerCase();

  Future<List<Product>> products() => supa.vendorProducts(username);
  Future<List<Order>> orders() => supa.vendorOrders();
  Future<List<FeedbackItem>> feedbacks() => supa.vendorFeedbacks();
  Future<bool> add(Product product) => supa
      .addProductRow(Product(
        id: product.id,
        title: product.title,
        price: product.price,
        discountPercentage: product.discountPercentage,
        rating: product.rating,
        stock: product.stock,
        brand: product.brand,
        category: product.category,
        description: product.description,
        thumbnail: product.thumbnail,
        images: product.images,
        status: product.status,
        vendorUsername: username,
      ))
      .then((row) => row != null);
  Future<bool> update(Product product) =>
      supa.updateVendorProduct(username, product);
  Future<bool> delete(int id) => supa.deleteVendorProduct(username, id);
}
