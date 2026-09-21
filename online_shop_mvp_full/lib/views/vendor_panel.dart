import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class VendorPanelPage extends StatefulWidget {
  final User vendor;
  final VendorRepository repo;
  const VendorPanelPage({super.key, required this.vendor, required this.repo});
  @override
  State<VendorPanelPage> createState() => _VendorPanelPageState();
}

class _VendorPanelPageState extends State<VendorPanelPage> {
  int tab = 0;
  late Future<List<Product>> products;
  late Future<List<Order>> orders;
  late Future<List<FeedbackItem>> feedback;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        products = widget.repo.products();
        orders = widget.repo.orders();
        feedback = widget.repo.feedbacks();
      });
  Future<void> _edit([Product? old]) async {
    final p = await showDialog<Product>(
        context: context, builder: (_) => _ProductDialog(product: old));
    if (p == null) return;
    final x = Product(
        id: p.id,
        title: p.title,
        price: p.price,
        discountPercentage: p.discountPercentage,
        rating: p.rating,
        stock: p.stock,
        brand: p.brand,
        category: p.category,
        description: p.description,
        thumbnail: p.thumbnail,
        images: p.images,
        status: p.status,
        vendorUsername: widget.vendor.username);
    final ok =
        old == null ? await widget.repo.add(x) : await widget.repo.update(x);
    if (ok && mounted) _reload();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Vendor workspace'), actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))
      ]),
      body: [_products(), _orders(), _payments(), _feedback()][tab],
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), label: 'Products'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined), label: 'Payments'),
            NavigationDestination(
                icon: Icon(Icons.star_outline), label: 'Feedback')
          ]));
  Widget _products() => FutureBuilder<List<Product>>(
      future: products,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        final a = s.data ?? const <Product>[];
        return Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(
                    child: Text('My products',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold))),
                FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'))
              ])),
          Expanded(
              child: ListView(children: [
            for (final p in a)
              ListTile(
                  title: Text(p.title),
                  subtitle: Text('${p.category} • Stock ${p.stock}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('\$${p.price.toStringAsFixed(2)}'),
                    IconButton(
                        onPressed: () => _edit(p),
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        onPressed: () async {
                          if (await widget.repo.delete(p.id) && mounted)
                            _reload();
                        },
                        icon: const Icon(Icons.delete_outline))
                  ]))
          ]))
        ]);
      });
  Widget _orders() => FutureBuilder<List<Order>>(
      future: orders,
      builder: (_, s) => _data(
          s,
          (a) => ListView(children: [
                for (final o in a)
                  ListTile(
                      title: Text('Order #${o.id}'),
                      subtitle: Text(
                          'Customer: ${o.owner.isEmpty ? 'Guest' : o.owner}\n${o.status}'),
                      isThreeLine: true,
                      trailing: Text('\$${o.total.toStringAsFixed(2)}'))
              ])));
  Widget _payments() => FutureBuilder<List<Order>>(
      future: orders,
      builder: (_, s) => _data(s, (a) {
            final r = a
                .where((o) => o.status != 'Cancelled')
                .fold<double>(0, (v, o) => v + o.total);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                  child: ListTile(
                      title: const Text('Sales revenue'),
                      subtitle: const Text('Non-cancelled orders'),
                      trailing: Text('\$${r.toStringAsFixed(2)}'))),
              for (final o in a.where((o) => o.status != 'Cancelled'))
                ListTile(
                    title: Text('Payment #${o.id}'),
                    subtitle: Text('${o.owner} • ${o.status}'),
                    trailing: Text('\$${o.total.toStringAsFixed(2)}'))
            ]);
          }));
  Widget _feedback() => FutureBuilder<List<FeedbackItem>>(
      future: feedback,
      builder: (_, s) => _data(
          s,
          (a) => ListView(children: [
                for (final f in a)
                  ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text('${f.rating}/5 • ${f.name}'),
                      subtitle: Text(f.message))
              ])));
  Widget _data<T>(AsyncSnapshot<List<T>> s, Widget Function(List<T>) b) =>
      s.connectionState != ConnectionState.done
          ? const Center(child: CircularProgressIndicator())
          : s.hasError
              ? const Center(child: Text('Could not load vendor data.'))
              : b(s.data ?? const []);
}

class _ProductDialog extends StatefulWidget {
  final Product? product;
  const _ProductDialog({this.product});
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final n = TextEditingController(text: widget.product?.title ?? '');
  late final d = TextEditingController(text: widget.product?.description ?? '');
  late final c = TextEditingController(text: widget.product?.category ?? '');
  late final p =
      TextEditingController(text: widget.product?.price.toString() ?? '');
  late final s =
      TextEditingController(text: widget.product?.stock.toString() ?? '');
  late final i = TextEditingController(text: widget.product?.thumbnail ?? '');
  @override
  Widget build(BuildContext x) => AlertDialog(
          title: Text(widget.product == null ? 'Add product' : 'Edit product'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            _f(n, 'Name'),
            _f(d, 'Description'),
            _f(c, 'Category'),
            _f(p, 'Price', true),
            _f(s, 'Stock', true),
            _f(i, 'Image URL')
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(x), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final a = double.tryParse(p.text);
                  final q = int.tryParse(s.text);
                  if (n.text.trim().isEmpty || a == null || q == null) return;
                  Navigator.pop(
                      x,
                      Product(
                          id: widget.product?.id ??
                              -DateTime.now().millisecondsSinceEpoch,
                          title: n.text.trim(),
                          price: a,
                          discountPercentage:
                              widget.product?.discountPercentage ?? 0,
                          rating: widget.product?.rating ?? 0,
                          stock: q,
                          brand: widget.product?.brand ?? '',
                          category: c.text.trim(),
                          description: d.text.trim(),
                          thumbnail: i.text.trim(),
                          images: i.text.trim().isEmpty
                              ? const []
                              : [i.text.trim()]));
                },
                child: const Text('Save'))
          ]);
  Widget _f(TextEditingController v, String l, [bool number = false]) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: v,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                  labelText: l, border: const OutlineInputBorder())));
}
