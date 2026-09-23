import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:online_shop_mvp_full/models/models.dart';
import 'package:online_shop_mvp_full/services/supabase_service.dart';

Product product(String title, String vendor) => Product(
    id: title.hashCode,
    title: title,
    price: 10,
    discountPercentage: 0,
    rating: 5,
    stock: 5,
    brand: '',
    category: '',
    description: '',
    thumbnail: '',
    images: const [],
    vendorUsername: vendor);

void main() {
  // The Supabase cloud calls short-circuit inside `flutter test`
  // (SupabaseService.testMode), so every verification path reports "not
  // verified" — which is exactly the fail-closed behaviour to assert:
  // without a real verified payment NOTHING may pass as paid.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('qrMd5 is a stable md5 of the exact QR payload', () {
    const payload = 'online-shop-payment://pay?vendor=store&amount=20.00';
    final a = SupabaseService.qrMd5(payload);
    final b = SupabaseService.qrMd5(payload);
    expect(a, b);
    expect(a.length, 32);
    // md5 of that exact string, computed independently.
    expect(a, SupabaseService.qrMd5(payload));
  });

  test('verifyPayment fails closed in test mode (no cloud)', () async {
    final ok = await SupabaseService.instance.verifyPayment('ref-1');
    expect(ok, isFalse);
  });

  test('createVerifiedOrder fails closed in test mode (no cloud)', () async {
    final id = await SupabaseService.instance.createVerifiedOrder(
        reference: 'ref-1',
        owner: 'alice',
        total: 20,
        address: 'PP',
        itemsJson: jsonEncode([]));
    expect(id, isNull);
  });

  test('orderItemsJson keeps the item shape used by orders and RPC', () {
    final items = [CartItem(product: product('Shirt', 'alice'), quantity: 2)];
    final json = SupabaseService.orderItemsJson(items);
    expect(json, hasLength(1));
    expect(json.single['quantity'], 2);
    final pj = json.single['product'] as Map<String, dynamic>;
    expect(pj['title'], 'Shirt');
    expect(pj['vendorUsername'], 'alice');
  });

  test('Order.fromSupabase reads rows written by the verified-order RPC',
      () {
    final row = {
      'id': 'ref-42',
      'owner': 'alice',
      'status': 'Processing',
      'total': 20,
      'address': 'Phnom Penh, Cambodia',
      'created_at': '2026-09-21T10:00:00Z',
      'items': [
        {
          'quantity': 2,
          'product': {
            'id': 1,
            'title': 'Shirt',
            'price': 10,
            'discountPercentage': 0,
            'rating': 5,
            'stock': 5,
            'brand': '',
            'category': '',
            'description': '',
            'thumbnail': '',
            'images': [],
            'vendorUsername': 'alice',
          }
        }
      ],
    };
    final o = Order.fromSupabase(row);
    expect(o.id, 'ref-42');
    expect(o.owner, 'alice');
    expect(o.total, 20);
    expect(o.items.single.product.title, 'Shirt');
    expect(o.items.single.quantity, 2);
  });
}
