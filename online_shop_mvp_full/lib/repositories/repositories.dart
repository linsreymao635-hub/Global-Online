import '../models/models.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';

class AuthRepository {
  final ApiService api;
  final GoogleAuthService _google = GoogleAuthService();
  AuthRepository(this.api);
  Future<User?> login(String u, String p) => api.login(u, p);
  Future<User?> signup(String f, String l, String u, String p, String e) =>
      api.signup(f, l, u, p, e);
  Future<User?> googleLogin() => _google.signIn();
}

class ProductRepository {
  final ApiService api;
  ProductRepository(this.api);
  Future<List<Product>> all() => api.getProducts();
  Future<List<Product>> search(String q) => api.searchProducts(q);
  Future<List<Product>> category(String s) => api.category(s);
  Future<List<Category>> categories() => api.categories();
}
