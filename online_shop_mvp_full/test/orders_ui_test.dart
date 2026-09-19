import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_shop_mvp_full/l10n/app_localizations.dart';
import 'package:online_shop_mvp_full/models/models.dart';
import 'package:online_shop_mvp_full/presenters/presenters.dart';
import 'package:online_shop_mvp_full/views/admin_panel.dart';
import 'package:online_shop_mvp_full/views/views.dart';

Order makeOrder(String id, String status) {
  final p = Product(
      id: 1,
      title: 'Test Shirt',
      price: 12.5,
      discountPercentage: 0,
      rating: 4.5,
      stock: 3,
      brand: 'ACME',
      category: 'Clothing',
      description: 'x',
      thumbnail: '',
      images: const []);
  return Order(
      id: id,
      date: DateTime(2026, 1, 1),
      items: [CartItem(product: p, quantity: 2)],
      total: 25,
      status: status,
      deliveryAddress: 'Phnom Penh, Cambodia',
      owner: 'admin');
}

OrdersTablePage ordersTable(List<Order> orders) => OrdersTablePage(
    orders: orders,
    allOrders: orders,
    total: orders.length,
    page: 0,
    onPage: (_) {},
    onSearch: (_) {},
    onOpen: (_) {},
    onStatus: (_, __) {});

Widget wrap(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child));

void main() {
  testWidgets('admin Orders table renders with normal statuses',
      (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(wrap(ordersTable([
      makeOrder('1', 'Processing'),
      makeOrder('2', 'Shipped'),
      makeOrder('3', 'Delivered'),
      makeOrder('4', 'Cancelled'),
    ])));
    await t.pump();
    expect(find.byType(OrdersTablePage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('admin Orders table renders with unknown status',
      (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(wrap(ordersTable([
      makeOrder('1', 'Processing'),
      makeOrder('9', 'New'),
    ])));
    await t.pump();
    expect(find.byType(OrdersTablePage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shopper OrderPage renders with orders', (t) async {
    final presenter = OrderPresenter()
      ..orders.add(makeOrder('1', 'Processing'));
    await t.pumpWidget(wrap(OrderPage(orders: presenter)));
    await t.pump();
    expect(find.byType(OrderPage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shopper OrderPage empty state', (t) async {
    final presenter = OrderPresenter();
    await t.pumpWidget(wrap(OrderPage(orders: presenter)));
    await t.pump();
    expect(find.byType(OrderPage), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}