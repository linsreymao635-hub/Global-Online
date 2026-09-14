class User {
  final int id;
  final String firstName, lastName, username, email;
  final String? image, token;
  User(
      {required this.id,
      required this.firstName,
      required this.lastName,
      required this.username,
      required this.email,
      this.image,
      this.token});
  String get fullName => '$firstName $lastName'.trim();
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: j['id'] ?? 0,
      firstName: j['firstName'] ?? '',
      lastName: j['lastName'] ?? '',
      username: j['username'] ?? '',
      email: j['email'] ?? '',
      image: j['image'],
      token: j['token']);
}

class Product {
  final int id, stock;
  final String title, brand, category, description, thumbnail;
  final double price, discountPercentage, rating;
  final List<String> images;
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
      required this.images});
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
      images: List<String>.from(j['images'] ?? const []));
}

class Category {
  final String slug, name, url;
  Category({required this.slug, required this.name, required this.url});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
      slug: j['slug'] ?? '', name: j['name'] ?? '', url: j['url'] ?? '');
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
  Order(
      {required this.id,
      required this.date,
      required this.items,
      required this.total,
      required this.status,
      required this.deliveryAddress});
}
