import 'package:flutter_test/flutter_test.dart';

import 'package:online_shop_mvp_full/models/models.dart';
import 'package:online_shop_mvp_full/presenters/presenters.dart';

Order makeOrder(String id, String status,
    {String owner = 'alice', DateTime? date}) {
  final p = Product(
      id: 1,
      title: 'Test Shirt',
      price: 10,
      discountPercentage: 0,
      rating: 4,
      stock: 5,
      brand: 'ACME',
      category: 'Clothing',
      description: 'x',
      thumbnail: '',
      images: const []);
  return Order(
      id: id,
      date: date ?? DateTime(2026, 1, 1),
      items: [CartItem(product: p, quantity: 1)],
      total: 10,
      status: status,
      deliveryAddress: 'Phnom Penh, Cambodia',
      owner: owner);
}

void main() {
  test('cloud status wins over a stale local copy (admin → user sync)', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: [makeOrder('1', 'Delivered')],
      cloudReachable: true,
      // The device still holds the Processing copy from when the shopper
      // placed the order — the cloud (admin's update) must win.
      local: [makeOrder('1', 'Processing')],
      synced: {'1'},
      owner: 'alice',
    );
    expect(merged.single.id, '1');
    expect(merged.single.status, 'Delivered');
  });

  test('each user only ever sees their own orders', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: [
        makeOrder('1', 'Delivered', owner: 'alice'),
        makeOrder('2', 'Shipped', owner: 'bob'),
      ],
      cloudReachable: true,
      local: [makeOrder('3', 'Processing', owner: 'charlie')],
      synced: const {},
      owner: 'alice',
    );
    expect(merged.map((o) => o.owner).toSet(), {'alice'});
  });

  test('admin (no owner) sees every order across all users', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: [
        makeOrder('1', 'Delivered', owner: 'alice'),
        makeOrder('2', 'Shipped', owner: 'bob'),
      ],
      cloudReachable: true,
      local: const [],
      synced: const {},
    );
    expect(merged.length, 2);
  });

  test('an order deleted from the cloud disappears when the cloud is up', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: const [],
      cloudReachable: true,
      // Local copy still exists, but the admin deleted the cloud row.
      local: [makeOrder('1', 'Processing')],
      synced: {'1'},
      owner: 'alice',
    );
    expect(merged, isEmpty);
  });

  test('offline keeps synced orders (cloud not reachable, no false delete)', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: const [],
      cloudReachable: false, // offline — the cloud is NOT the truth here
      local: [makeOrder('1', 'Processing')],
      synced: {'1'},
      owner: 'alice',
    );
    expect(merged.single.status, 'Processing');
  });

  test('an offline-created (never synced) order survives a cloud read', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: const [],
      cloudReachable: true,
      local: [makeOrder('1', 'Processing')],
      synced: const {}, // never reached the cloud — keep it local
      owner: 'alice',
    );
    expect(merged.single.id, '1');
  });

  test('merged orders are sorted newest first', () {
    final merged = OrderPresenter.mergeOrders(
      cloud: [makeOrder('old', 'Shipped', date: DateTime(2026, 1, 1))],
      cloudReachable: true,
      local: [
        makeOrder('newer', 'Processing', date: DateTime(2026, 2, 1)),
        makeOrder('dup', 'Delivered', date: DateTime(2026, 1, 20)),
      ],
      synced: const {},
      owner: 'alice',
    );
    expect(merged.map((o) => o.id).toList(), ['newer', 'dup', 'old']);
  });
}