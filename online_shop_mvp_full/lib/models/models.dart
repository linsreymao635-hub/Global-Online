import 'dart:convert' as dart_convert;

class User {
  final int id;
  final String firstName, lastName, username, email, phone;
  final String? image, token;
  final bool isAdmin;
  User(
      {required this.id,
      required this.firstName,
      required this.lastName,
      required this.username,
      required this.email,
      this.phone = '',
      this.image,
      this.token,
      this.isAdmin = false});
  String get fullName => '$firstName $lastName'.trim();
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: j['id'] ?? 0,
      firstName: j['firstName'] ?? '',
      lastName: j['lastName'] ?? '',
      username: j['username'] ?? '',
      email: j['email'] ?? '',
      phone: j['phone'] ?? '',
      image: j['image'],
      token: j['token'],
      isAdmin: j['isAdmin'] == true || j['isAdmin'] == 'true');

  /// Row from the Supabase `app_users` table. The password hash is never
  /// carried on the model (token stays null) so it cannot leak into the
  /// persisted session JSON.
  factory User.fromSupabase(Map<String, dynamic> j) => User(
      id: (j['id'] as num?)?.toInt() ?? 0,
      firstName: j['first_name'] as String? ?? '',
      lastName: j['last_name'] as String? ?? '',
      username: j['username'] as String? ?? '',
      email: j['email'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      image: (j['image'] as String?)?.isEmpty == true ? null : j['image'] as String?,
      isAdmin: j['is_admin'] == true);
}

class Product {
  final int id, stock;
  final String title, brand, category, description, thumbnail;
  final double price, discountPercentage, rating;
  final List<String> images;

  /// Availability toggle managed from the Admin panel: 'Active' or
  /// 'Inactive'. Defaults to Active for older rows without the column.
  final String status;

  /// Verified flag managed from the Admin Companies panel. Defaults to
  /// false for older rows without the column.
  final bool verified;
  Product(
      {required this.id,
      required this.title,
      required this.price,
      required this.discountPercentage,
      required this.rating,
      required this.stock,
      required this.brand,
      required this.category,
      required this.description,
      required this.thumbnail,
      required this.images,
      this.status = 'Active',
      this.verified = false});
  factory Product.fromJson(Map<String, dynamic> j) => Product(
      id: j['id'] ?? 0,
      title: j['title'] ?? '',
      price: (j['price'] ?? 0).toDouble(),
      discountPercentage: (j['discountPercentage'] ?? 0).toDouble(),
      rating: (j['rating'] ?? 0).toDouble(),
      stock: j['stock'] ?? 0,
      brand: j['brand'] ?? '',
      category: j['category'] ?? '',
      description: j['description'] ?? '',
      thumbnail: j['thumbnail'] ?? '',
      images: List<String>.from(j['images'] ?? const []),
      status: j['status']?.toString() ?? 'Active',
      verified: j['verified'] == true);

  /// Row from the Supabase `products` table.
  factory Product.fromSupabase(Map<String, dynamic> j) => Product(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String? ?? '',
      price: (j['price'] as num? ?? 0).toDouble(),
      discountPercentage:
          (j['discount_percentage'] as num? ?? 0).toDouble(),
      rating: (j['rating'] as num? ?? 0).toDouble(),
      stock: (j['stock'] as num? ?? 0).toInt(),
      brand: j['brand'] as String? ?? '',
      category: j['category'] as String? ?? '',
      description: j['description'] as String? ?? '',
      thumbnail: j['thumbnail'] as String? ?? '',
      images: _images(j['images']),
      status: j['status'] as String? ?? 'Active',
      verified: j['verified'] == true);

  /// `images` may arrive as a JSON string ('["..."]'), a List, or null.
  static List<String> _images(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = dart_convert.jsonDecode(raw);
        if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }
}

class Category {
  final String slug, name, url;

  /// Extra details editable from the Admin panel. Optional — older rows
  /// and the local fallback simply leave them empty.
  final String description, image;
  Category(
      {required this.slug,
      required this.name,
      required this.url,
      this.description = '',
      this.image = ''});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
      slug: j['slug'] ?? '',
      name: j['name'] ?? '',
      url: j['url'] ?? '',
      description: j['description']?.toString() ?? '',
      image: j['image']?.toString() ?? '');

  /// Row from the Supabase `categories` table.
  factory Category.fromSupabase(Map<String, dynamic> j) => Category(
      slug: j['slug'] as String? ?? '',
      name: j['name'] as String? ?? '',
      url: j['url'] as String? ?? '',
      description: j['description'] as String? ?? '',
      image: j['image'] as String? ?? '');
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
  double get subtotal => product.price * quantity;
}

class Address {
  final String fullName, phone, address, city, country;
  final double? latitude, longitude;
  Address(
      {required this.fullName,
      required this.phone,
      required this.address,
      required this.city,
      required this.country,
      this.latitude,
      this.longitude});
}

class Order {
  final String id, status, deliveryAddress;
  final DateTime date;
  final List<CartItem> items;
  final double total;

  /// Username of the account that placed the order. Used by the Admin panel
  /// to show who ordered what. Empty for orders created before this field.
  final String owner;
  Order(
      {required this.id,
      required this.date,
      required this.items,
      required this.total,
      required this.status,
      required this.deliveryAddress,
      this.owner = ''});

  Order copyWith({String? status, String? owner}) => Order(
      id: id,
      date: date,
      items: items,
      total: total,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress,
      owner: owner ?? this.owner);

  /// Row from the Supabase `orders` table.
  factory Order.fromSupabase(Map<String, dynamic> j) {
    final rawItems = j['items'];
    List<CartItem> items = const [];
    if (rawItems is List) {
      items = rawItems.map((it) {
        final m = (it as Map).cast<String, dynamic>();
        final pj = (m['product'] as Map?)?.cast<String, dynamic>() ?? const {};
        return CartItem(
            product: Product.fromJson(pj),
            quantity: (m['quantity'] as num?)?.toInt() ?? 1);
      }).toList();
    } else if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final d = dart_convert.jsonDecode(rawItems);
        if (d is List) return Order.fromSupabase({...j, 'items': d});
      } catch (_) {}
    }
    return Order(
        id: j['id']?.toString() ?? '',
        date: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        items: items,
        total: (j['total'] as num? ?? 0).toDouble(),
        status: j['status'] as String? ?? 'Processing',
        deliveryAddress: j['address'] as String? ?? '',
        owner: j['owner'] as String? ?? '');
  }
}

/// Feedback message left by a shopper, reviewed in the Admin panel.
class FeedbackItem {
  final int id;

  /// Username of the account that left the feedback.
  final String owner;

  /// Display name the shopper typed next to their message.
  final String name;
  final String message;

  /// 1..5 star rating chosen by the shopper.
  final int rating;
  final DateTime date;
  FeedbackItem(
      {required this.id,
      required this.owner,
      required this.name,
      required this.message,
      this.rating = 5,
      DateTime? date})
      : date = date ?? DateTime.now();

  /// Row from the Supabase `feedback` table.
  factory FeedbackItem.fromSupabase(Map<String, dynamic> j) => FeedbackItem(
      id: (j['id'] as num).toInt(),
      owner: j['owner'] as String? ?? '',
      name: j['name'] as String? ?? '',
      message: j['message'] as String? ?? '',
      rating: (j['rating'] as num? ?? 5).toInt(),
      date: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now());

  /// Row from the local offline queue (feedback saved while the cloud was
  /// unreachable). Ids are negative so they never collide with cloud rows.
  factory FeedbackItem.fromJsonLocal(Map<String, dynamic> j) => FeedbackItem(
      id: (j['id'] as num? ?? 0).toInt(),
      owner: j['owner']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      message: j['message']?.toString() ?? '',
      rating: (j['rating'] as num? ?? 5).toInt(),
      date: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now());
}
