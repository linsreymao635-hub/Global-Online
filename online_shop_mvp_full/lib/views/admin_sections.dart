// Admin dashboard sections that replace the original "coming soon"
// placeholders: Reports, Notifications, Settings and Administration.
// They render inside the AdminPanelPage scaffold and are fed with the
// same cached backend lists (products / users / orders / feedback).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/supabase_service.dart';

/// Brand accent used across the whole admin panel.
const Color acColor = Color(0xFF5B4FE9);

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const List<String> _weekdays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];

/// "$12.99" — keeps the admin currency, drops a trailing ".00".
String moneyOf(num v) {
  var s = v.toStringAsFixed(2);
  if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
  return '${AppSettings.currency}$s';
}

/// "1.2k" / "3.4M" for chart axis values.
String compactNum(num v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

/// "2m ago" / "3h ago" / "5d ago".
String timeAgoOf(DateTime t, {String justNow = 'now'}) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return justNow;
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}

Color statusColorOf(String status) {
  switch (status) {
    case 'Processing':
      return Colors.orange;
    case 'Shipped':
      return Colors.blue;
    case 'Delivered':
      return Colors.green;
    case 'Cancelled':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}

// ============================================================================
// Shared layout helpers
// ============================================================================

/// A bordered card with an optional actions row next to its title.
Widget sectionCard(BuildContext context, String title, Widget body,
    {List<Widget> actions = const []}) {
  final sch = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: sch.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sch.outlineVariant)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (title.isNotEmpty)
        Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
          ...actions,
        ]),
      if (title.isNotEmpty) const SizedBox(height: 12),
      body,
    ]),
  );
}

/// Responsive wrap grid so cards never overflow on narrower windows.
Widget fluidGrid(List<Widget> items, {int columns = 2}) {
  return LayoutBuilder(builder: (context, cons) {
    final width = cons.maxWidth;
    final gap = 12.0;
    final cols = width >= 720 ? columns : (width >= 420 ? 2 : 1);
    final itemWidth = (width - gap * (cols - 1)) / cols;
    return Wrap(spacing: gap, runSpacing: gap, children: [
      for (final it in items) SizedBox(width: itemWidth, child: it),
    ]);
  });
}

/// A big number + label tile (Sales Overview / Revenue cards).
class KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? sub;
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: sch.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sch.outlineVariant)),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: sch.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: sch.primary)),
                ],
              ]),
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: color),
        ),
      ]),
    );
  }
}

/// A name/value row with an optional progress bar underneath (used by the
/// Product Performance list).
class PerfRow extends StatelessWidget {
  final String title, right;
  final double ratio;
  final Color color;
  const PerfRow({
    super.key,
    required this.title,
    required this.right,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5)),
          ),
          Text(right,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: sch.outlineVariant),
        ),
      ]),
    );
  }
}

// ============================================================================
// Charts (hand-painted — no chart package is installed)
// ============================================================================

class _BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;
  const _BarChart({
    required this.values,
    required this.labels,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    final chartMax = values.fold<double>(0.0, (m, v) => v > m ? v : m);
    final maxScale = chartMax <= 0 ? 1.0 : chartMax;
    final labelsLen = labels.length;
    return SizedBox(
      height: height,
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                            values[i] <= 0 ? '' : compactNum(values[i]),
                            style: TextStyle(
                                fontSize: 8.5,
                                color: sch.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Container(
                          height: (height - 42) *
                              (values[i] / maxScale).clamp(0.005, 1.0),
                          decoration: BoxDecoration(
                              color: acColor,
                              borderRadius:
                                  const BorderRadius.vertical(
                                      top: Radius.circular(4))),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            i < labelsLen ? labels[i] : '',
                            style: TextStyle(
                                fontSize: 9.5,
                                color: sch.onSurfaceVariant)),
                      ]),
                ),
              ),
          ]),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<double> values;
  final double height;
  const _LineChart({required this.values, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _LinePainter(
        values,
        acColor,
        sch.primaryContainer.withValues(alpha: 0.35),
        sch.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color line, fill, dots;
  _LinePainter(this.values, this.line, this.fill, this.dots);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final pad = 10.0;
    final chartW = size.width - pad * 2;
    final chartH = size.height - pad * 2;
    if (chartW <= 0 || chartH <= 0) return;
    final maxV = values.fold<double>(0.0, (m, v) => v > m ? v : m);
    final span = maxV <= 0 ? 1.0 : maxV;

    Offset point(int i) {
      final x = values.length == 1
          ? size.width / 2
          : pad + chartW * (i / (values.length - 1));
      final y = pad + chartH * (1 - (values[i] / span).clamp(0.0, 1.0));
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < values.length; i++) point(i)];

    if (pts.length > 1) {
      final fillPath = Path()
        ..moveTo(pts.first.dx, pad + chartH)
        ..lineTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        fillPath.lineTo(pts[i].dx, pts[i].dy);
      }
      fillPath
        ..lineTo(pts.last.dx, pad + chartH)
        ..close();
      canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fill, fill.withValues(alpha: 0.0)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        linePath.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
          linePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = line);
    }

    if (values.length <= 24) {
      final dot = Paint()..color = dots;
      for (final p in pts) {
        canvas.drawCircle(p, 2.4, dot);
      }
    }
    if (pts.isNotEmpty) {
      final mark = Paint()..color = line;
      canvas.drawCircle(pts.last, 4, mark);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      values != old.values || line != old.line;
}

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

class _DonutChart extends StatelessWidget {
  final List<_Slice> slices;
  final String centerValue;
  final String centerLabel;
  const _DonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sch = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(
        width: 130,
        height: 130,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: const Size(130, 130),
            painter: _DonutPainter(
                [for (final s in slices) s.value],
                [for (final s in slices) s.color],
                sch.surfaceContainerHighest),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(centerValue,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(centerLabel,
                style: TextStyle(fontSize: 10, color: sch.onSurfaceVariant)),
          ]),
        ]),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                    Text(s.value.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color empty;
  _DonutPainter(this.values, this.colors, this.empty);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final total = values.fold<double>(0.0, (a, b) => a + b);
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    if (total <= 0) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = empty);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      values != old.values || colors != old.colors;
}

// ============================================================================
// Reports
// ============================================================================

class ReportsPage extends StatelessWidget {
  final List<Order> orders;
  final List<Product> products;
  final List<User> users;
  const ReportsPage({
    super.key,
    required this.orders,
    required this.products,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    final orders = this.orders;

    final active = orders.where((o) => o.status != 'Cancelled').toList();
    final totalSales = active.fold<num>(0, (s, o) => s + o.total);
    final count = (String status) =>
        orders.where((o) => o.status == status).length;
    final processing = count('Processing');
    final shipped = count('Shipped');
    final delivered = count('Delivered');
    final cancelled = count('Cancelled');
    final otherStatusCount =
        orders.length - processing - shipped - delivered - cancelled;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    DateTime local(DateTime d) => d.toLocal();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    num revenueIn(bool Function(DateTime) inside) =>
        orders
            .where((o) => o.status != 'Cancelled')
            .fold<num>(0, (s, o) => s + (inside(local(o.date)) ? o.total : 0));

    final revenueToday = revenueIn((d) => sameDay(d, now));
    final weekStart = startOfDay.subtract(Duration(days: now.weekday - 1));
    final revenueWeek = revenueIn((d) => !d.isBefore(weekStart));
    final monthStart = DateTime(now.year, now.month, 1);
    final revenueMonth = revenueIn((d) => !d.isBefore(monthStart));
    final yearStart = DateTime(now.year, 1, 1);
    final revenueYear = revenueIn((d) => !d.isBefore(yearStart));

    // Sales by day (last 7 days) + by month (last 6) + trend (last 12).
    final dayLabels = <String>[];
    final dayData = <double>[];
    for (var i = 6; i >= 0; i--) {
      final day = startOfDay.subtract(Duration(days: i));
      dayLabels.add(_weekdays[day.weekday - 1]);
      dayData.add(revenueIn((d) => sameDay(d, day)).toDouble());
    }
    final monthLabels = <String>[];
    final monthData = <double>[];
    final trendData = <double>[];
    for (var i = 11; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final next = DateTime(m.year, m.month + 1, 1);
      if (i < 6) monthLabels.add(_months[m.month - 1]);
      final amount = revenueIn((d) => !d.isBefore(m) && d.isBefore(next));
      if (i < 6) monthData.add(amount.toDouble());
      trendData.add(amount.toDouble());
    }

    // Product performance.
    final units = <int, int>{};
    for (final o in active) {
      for (final it in o.items) {
        units[it.product.id] = (units[it.product.id] ?? 0) + it.quantity;
      }
    }
    int unitsOf(Product p) => units[p.id] ?? 0;
    final byUnits = [...products]..sort(
        (a, b) => unitsOf(b).compareTo(unitsOf(a)));
    final bestSelling =
        byUnits.where((p) => unitsOf(p) > 0).take(5).toList();
    final lowSales =
        [...byUnits.reversed].take(5).toList();
    final byRating = [...products]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final topRated = byRating.take(5).toList();
    final lowStock = products.where((p) => p.stock <= 5).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    final maxUnits = units.isEmpty ? 1 : units.values.reduce(math.max);

    // Customer statistics.
    final totalUsers = users.length;
    final admins = users.where((u) => u.isAdmin).length;
    final newUsers = users.where((u) {
          final t = u.createdAt?.toLocal();
          return t != null && t.year == now.year && t.month == now.month;
        }).length;
    final owners = orders
        .map((o) => o.owner.trim().toLowerCase())
        .where((x) => x.isNotEmpty)
        .toSet();
    final activeUsers = owners.length;

    // ------------------------------------------------------------- sections

    final salesKpis = [
      KpiCard(
          label: tr('Total Sales'),
          value: moneyOf(totalSales),
          icon: Icons.payments_outlined,
          color: acColor),
      KpiCard(
          label: tr('Total Orders'),
          value: '${orders.length}',
          icon: Icons.receipt_long_outlined,
          color: Colors.blue),
      KpiCard(
          label: tr('Completed Orders'),
          value: '$delivered',
          icon: Icons.check_circle_outline,
          color: Colors.green),
      KpiCard(
          label: tr('Cancelled Orders'),
          value: '$cancelled',
          icon: Icons.cancel_outlined,
          color: Colors.redAccent),
    ];

    KpiCard revCard(String label, num value) => KpiCard(
        label: label, value: moneyOf(value), icon: Icons.attach_money, color: Colors.teal);

    Widget productList(List<Product> list, String emptyText) {
      if (list.isEmpty) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
      }
      return Column(children: [
        for (final p in list)
          PerfRow(
              title: p.title,
              right: unitsOf(p) > 0 ? '${unitsOf(p)} sold' : '0 sold',
              ratio: unitsOf(p) / maxUnits,
              color: acColor),
      ]);
    }

    Widget statLine(String label, String value, IconData icon, Color color) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        );

    final statusSlices = [
      _Slice(tr('Processing'), processing.toDouble(), Colors.orange),
      _Slice(tr('Shipped'), shipped.toDouble(), Colors.blue),
      _Slice(tr('Delivered'), delivered.toDouble(), Colors.green),
      _Slice(tr('Cancelled'), cancelled.toDouble(), Colors.redAccent),
      if (otherStatusCount > 0)
        _Slice(tr('Other'), otherStatusCount.toDouble(), Colors.grey),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Sales Overview'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        fluidGrid(salesKpis, columns: 4),
        const SizedBox(height: 16),
        Text(tr('Revenue'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        fluidGrid([
          revCard(tr('Today'), revenueToday),
          revCard(tr('This Week'), revenueWeek),
          revCard(tr('This Month'), revenueMonth),
          revCard(tr('This Year'), revenueYear),
        ], columns: 4),
        const SizedBox(height: 16),
        fluidGrid([
          sectionCard(context, tr('Sales by Day (Last 7 Days)'),
              _BarChart(values: dayData, labels: dayLabels)),
          sectionCard(context, tr('Sales by Month (Last 6 Months)'),
              _BarChart(values: monthData, labels: monthLabels)),
        ], columns: 2),
        const SizedBox(height: 12),
        fluidGrid([
          sectionCard(context, tr('Orders by Status'),
              _DonutChart(
                  slices: statusSlices,
                  centerValue: '${orders.length}',
                  centerLabel: tr('Orders'))),
          sectionCard(context, tr('Revenue Trend (Last 12 Months)'),
              _LineChart(values: trendData)),
        ], columns: 2),
        const SizedBox(height: 16),
        Text(tr('Product Performance'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        fluidGrid([
          sectionCard(context, tr('Best Selling'),
              productList(bestSelling, tr('No sales yet'))),
          sectionCard(context, tr('Low Sales'),
              productList(lowSales, tr('No products'))),
          sectionCard(
              context,
              tr('Top Rated'),
              Column(children: [
                for (final p in topRated)
                  PerfRow(
                      title: p.title,
                      right: p.rating.toStringAsFixed(1),
                      ratio: (p.rating / 5).clamp(0.0, 1.0),
                      color: Colors.amber),
              ])),
          sectionCard(
              context,
              tr('Low Stock'),
              Column(children: [
                if (lowStock.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr('No low stock right now'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                else
                  for (final p in lowStock.take(8))
                    PerfRow(
                        title: p.title,
                        right: '${p.stock} left',
                        ratio: (p.stock / 20).clamp(0.0, 1.0),
                        color: Colors.orange),
              ])),
        ], columns: 2),
        const SizedBox(height: 16),
        Text(tr('Customer Statistics'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        sectionCard(
            context,
            '',
            Column(children: [
              statLine(tr('Total Users'), '$totalUsers',
                  Icons.people_outline, Colors.blue),
              const Divider(height: 4),
              statLine(tr('New Users (This Month)'), '$newUsers',
                  Icons.person_add_alt, Colors.green),
              const Divider(height: 4),
              statLine(tr('Active Users'), '$activeUsers',
                  Icons.shopping_bag_outlined, acColor),
              const Divider(height: 4),
              statLine(tr('Admin Users'), '$admins', Icons.admin_panel_settings,
                  Colors.indigo),
            ])),
        if (users.isNotEmpty &&
            users.every((u) => u.createdAt == null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                tr('New user counts reflect accounts registered after this update.'),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

// ============================================================================
// Settings
// ============================================================================

class AdminSettingsPage extends StatefulWidget {
  /// Which settings section is expanded first ('payments',
  /// 'notifications' or 'security'). Defaults to payments.
  final String initialSection;
  const AdminSettingsPage({super.key, this.initialSection = 'payments'});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late final TextEditingController _currency =
      TextEditingController(text: AppSettings.currency);
  late final TextEditingController _taxRate =
      TextEditingController(text: AppSettings.taxRate.toString());

  late final TextEditingController _cur =
      TextEditingController();
  late final TextEditingController _newP =
      TextEditingController();
  late final TextEditingController _conf =
      TextEditingController();

  late String _section = widget.initialSection;
  bool _emailNotif = AppSettings.emailNotifications;
  bool _newOrderNotif = AppSettings.newOrderNotifications;
  bool _twoFactor = AppSettings.twoFactorEnabled;
  final Set<String> _methods = {
    ...AppSettings.paymentMethods,
    'Cash on Delivery' // fall back so the list is never empty
  };
  static const _methodOptions = [
    'Cash on Delivery', 'Card', 'Mobile Banking', 'QR',
  ];

  static const _menu = [
    (Icons.payments_outlined, 'Payments', 'payments'),
    (Icons.notifications_none, 'Notifications', 'notifications'),
    (Icons.security_outlined, 'Security', 'security'),
  ];

  @override
  void dispose() {
    _currency.dispose();
    _taxRate.dispose();
    _cur.dispose();
    _newP.dispose();
    _conf.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          width: 340,
          behavior: SnackBarBehavior.floating));

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? kb, bool enabled = true, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: kb,
        style: const TextStyle(fontSize: 14.5),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _saveButton(VoidCallback onSaved) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: acColor),
            onPressed: onSaved,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Changes'),
          ),
        ),
      );

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged,
          {String? subtitle}) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: acColor,
        onChanged: onChanged,
      );

  // ------------------------------------------------------- section builders

  // Icon + subtitle for every payment method option. Keys match the
  // strings stored by AppSettings.paymentMethods (also shown at checkout).
  static const _methodMeta = <String, (IconData, String)>{
    'Cash on Delivery': (
        Icons.local_shipping_outlined, 'Customers pay the courier in cash.'),
    'Card': (Icons.credit_card, 'Visa, Mastercard and debit cards.'),
    'Mobile Banking': (
        Icons.account_balance_outlined, 'ABA, Wing and other bank apps.'),
    'QR': (Icons.qr_code_2, 'KHQR scan-to-pay at checkout.'),
  };

  IconData _methodIcon(String m) => _methodMeta[m]?.$1 ?? Icons.payment;

  String _methodSubtitle(String m) =>
      _methodMeta[m]?.$2 ?? 'Custom payment option.';

  List<Widget> _paymentsSection() {
    final tr = AppLocalizations.of(context).t;
    final sch = Theme.of(context).colorScheme;

    // Summary tile shown above the form (Sales Overview style).
    Widget summary(IconData icon, Color color, String label, String value) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: sch.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sch.outlineVariant)),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: sch.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
          ),
        ]),
      );
    }

    // A tappable method tile: icon badge, name, hint and a check indicator.
    Widget methodTile(String m) {
      final on = _methods.contains(m);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: on ? acColor.withValues(alpha: 0.08) : sch.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              if (on) {
                _methods.remove(m);
              } else {
                _methods.add(m);
              }
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: on ? acColor : sch.outlineVariant,
                      width: on ? 1.4 : 1)),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: on
                          ? acColor.withValues(alpha: 0.15)
                          : sch.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(_methodIcon(m),
                      size: 20,
                      color: on ? acColor : sch.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: on ? acColor : null)),
                        Text(tr(_methodSubtitle(m)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: sch.onSurfaceVariant)),
                      ]),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? acColor : Colors.transparent,
                      border: Border.all(
                          color: on ? acColor : sch.outline, width: 1.6)),
                  child: on
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return [
      Text(tr('Currency, tax and which payment methods shoppers can use.'),
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      // At-a-glance summary of the current configuration.
      fluidGrid([
        summary(Icons.attach_money, acColor, tr('Currency'),
            AppSettings.currency),
        summary(Icons.percent_outlined, Colors.orange,
            tr('Tax Rate (%)'), '${AppSettings.taxRate.toStringAsFixed(0)}%'),
        summary(Icons.payments_outlined, Colors.green, tr('Payment Methods'),
            '${_methods.length} / ${_methodOptions.length}'),
      ], columns: 3),
      const SizedBox(height: 16),
      // Currency & tax inputs inside a titled card.
      sectionCard(
          context,
          tr('Payment Settings'),
          Column(children: [
            _field(_currency, tr('Currency Symbol'), Icons.attach_money),
            _field(_taxRate, tr('Tax Rate (%)'), Icons.percent_outlined,
                kb: TextInputType.number),
          ])),
      const SizedBox(height: 14),
      // Payment methods picker: tap-to-toggle tiles with icons.
      sectionCard(
          context,
          tr('Payment Methods'),
          Column(children: [
            Text(
                tr('Select the checkout options available to shoppers.'),
                style: TextStyle(
                    fontSize: 11.5, color: sch.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final m in _methodOptions) methodTile(m),
            if (_methods.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 15, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        tr('At least one method is recommended so shoppers can pay.'),
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.orange.shade700)),
                  ),
                ]),
              ),
          ])),
      _saveButton(() async {
        await AppSettings.saveCurrency(_currency.text);
        await AppSettings.saveTaxRate(
            double.tryParse(_taxRate.text) ?? 0);
        await AppSettings.savePaymentMethods(_methods.toList());
        await AppSettings.logAdminActivity('Updated payment settings');
        if (!mounted) return;
        _toast(tr('Saved'));
        setState(() {}); // refresh the summary tiles
      }),
    ];
  }

  List<Widget> _notificationsSection() {
    final tr = AppLocalizations.of(context).t;
    return [
      Text(tr('Which shop events send you a notification.'),
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      _switchTile(tr('New order notifications'), _newOrderNotif, (v) async {
        setState(() => _newOrderNotif = v);
        await AppSettings.saveNewOrderNotifications(v);
        _toast(tr('Saved'));
      }, subtitle: tr('Get an alert the moment a shopper places an order.')),
      _switchTile(tr('Email notifications'), _emailNotif, (v) async {
        setState(() => _emailNotif = v);
        await AppSettings.saveEmailNotifications(v);
        _toast(tr('Saved'));
      }, subtitle: tr('Receive order summaries by email.')),
    ];
  }

  List<Widget> _securitySection() {
    final tr = AppLocalizations.of(context).t;
    Widget blockLabel(String s) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800)),
        );
    return [
      Text(tr('Keep the admin account safe.'),
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      blockLabel(tr('Change Password')),
      _field(_cur, tr('Current Password'), Icons.lock_outline, obscure: true),
      _field(_newP, tr('New Password'), Icons.lock_reset_outlined, obscure: true),
      _field(_conf, tr('Confirm New Password'), Icons.lock_outline, obscure: true),
      _saveButton(_changePassword),
      const Divider(height: 24),
      blockLabel(tr('Two-Factor Authentication')),
      _switchTile(tr('Require a 6-digit code on login'), _twoFactor, (v) async {
        setState(() => _twoFactor = v);
        await AppSettings.saveTwoFactorEnabled(v);
        _toast(tr('Saved'));
      }, subtitle: tr('A code generator can be connected here in a future release.')),
      const Divider(height: 24),
      blockLabel(tr('Login Sessions')),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.desktop_windows_outlined, size: 20),
        title: Text(tr('This device'), style: const TextStyle(fontSize: 13.5)),
        subtitle: Text(tr('Current session'), style: const TextStyle(fontSize: 12)),
        trailing: Pill(tr('Active'), color: Colors.green),
      ),
      Text(tr('Sessions on other devices appear here after signing in.'),
          style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ];
  }

  Future<void> _changePassword() async {
    final tr = AppLocalizations.of(context).t;
    if (_cur.text != ApiService.adminPassword) {
      _toast(tr('Current password is incorrect'));
      return;
    }
    if (_newP.text.length < 6) {
      _toast(tr('Password must be at least 6 characters'));
      return;
    }
    if (_newP.text != _conf.text) {
      _toast(tr('Passwords do not match'));
      return;
    }
    if (_newP.text == _cur.text) {
      _toast(tr('New password must be different from the current one'));
      return;
    }
    await AppSettings.setAdminPassword(_newP.text);
    await AppSettings.logAdminActivity('Changed the admin password');
    _cur.clear();
    _newP.clear();
    _conf.clear();
    if (!mounted) return;
    _toast(tr('Password changed successfully'));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    final sch = Theme.of(context).colorScheme;

    // ChoiceChip tab, styled exactly like the Administration page tabs.
    Widget tab(String key, String label, IconData icon) {
      final sel = _section == key;
      return ChoiceChip(
        avatar: Icon(icon,
            size: 16, color: sel ? Colors.white : sch.onSurfaceVariant),
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: acColor,
        labelStyle: TextStyle(
            fontSize: 12.5, color: sel ? Colors.white : sch.onSurfaceVariant),
        onSelected: (_) => setState(() => _section = key),
      );
    }

    // The selected section body: centered, capped like the previous page.
    Widget section(List<Widget> children) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, children: [
          for (final (icon, label, key) in _menu) tab(key, tr(label), icon),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _section == 'payments'
            ? section(_paymentsSection())
            : _section == 'notifications'
                ? section(_notificationsSection())
                : section(_securitySection()),
      ),
    ]);
  }
}

// ============================================================================
// Administration
// ============================================================================

class AdministrationPage extends StatefulWidget {
  final List<User> users;
  final AdminRepository repo;
  final VoidCallback onUsersChanged;
  const AdministrationPage({
    super.key,
    required this.users,
    required this.repo,
    required this.onUsersChanged,
  });

  @override
  State<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends State<AdministrationPage> {
  String _section = 'admins';
  String? _busyUser;
  bool _adding = false;

  List<String> _logEntries = [];
  bool _logLoading = false;
  bool _dbOnline = false;
  bool _checkingDb = false;

  // Roles & Permissions state (loaded from AppSettings in initState).
  List<Map<String, dynamic>> _roles = [];
  bool _rolesLoading = true;

  static const _menu = [
    (Icons.admin_panel_settings_outlined, 'Admin Users', 'admins'),
    (Icons.verified_user_outlined, 'Roles & Permissions', 'roles'),
    (Icons.receipt_long_outlined, 'Activity Logs', 'logs'),
    (Icons.dns_outlined, 'System Management', 'system'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadRoles();
    _dbOnline = !SupabaseService.instance.unavailable;
  }

  Future<void> _loadRoles() async {
    final roles = await AppSettings.loadRoles();
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _rolesLoading = false;
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          width: 340,
          behavior: SnackBarBehavior.floating));

  Future<void> _loadLogs() async {
    setState(() => _logLoading = true);
    final entries = await AppSettings.loadActivityLog();
    if (!mounted) return;
    setState(() {
      _logEntries = entries;
      _logLoading = false;
    });
  }

  Future<void> _checkDatabase() async {
    setState(() => _checkingDb = true);
    try {
      await widget.repo.users();
      if (!mounted) return;
      setState(() => _dbOnline = !SupabaseService.instance.unavailable);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dbOnline = false);
    } finally {
      if (mounted) setState(() => _checkingDb = false);
    }
  }

  Future<void> _toggleAdmin(User u) async {
    final tr = AppLocalizations.of(context).t;
    if (u.username.trim().toLowerCase() == ApiService.adminUsername) return;
    setState(() => _busyUser = u.username);
    final ok = await widget.repo.setUserAdmin(u.username, !u.isAdmin);
    if (!mounted) return;
    setState(() => _busyUser = null);
    if (ok) {
      await AppSettings.logAdminActivity(
          u.isAdmin
              ? 'Demoted @${u.username} from admin'
              : 'Promoted @${u.username} to admin');
      widget.onUsersChanged();
      _toast(tr(u.isAdmin ? 'Admin role removed' : 'Admin role granted'));
    } else {
      _toast(tr('Could not reach the cloud. Role not saved.'));
    }
  }

  Future<void> _addAdmin() async {
    final tr = AppLocalizations.of(context).t;
    final draft = await showDialog<_StaffDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddStaffDialog(),
    );
    if (draft == null || !mounted) return;
    setState(() => _adding = true);
    final ok = await widget.repo.createUser(
      username: draft.username,
      firstName: draft.firstName,
      lastName: draft.lastName,
      email: draft.email,
      phone: draft.phone,
      password: draft.password,
      isAdmin: draft.isAdmin,
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (ok) {
      await AppSettings.logAdminActivity(
          'Created ${draft.isAdmin ? 'admin' : 'staff'} account @${draft.username}');
      widget.onUsersChanged();
      _toast(tr('Account created'));
    } else {
      _toast(tr('Could not reach the cloud. Account not saved.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    final sch = Theme.of(context).colorScheme;
    final users = widget.users;

    Widget tab(String key, String label, IconData icon) {
      final sel = _section == key;
      return ChoiceChip(
        avatar: Icon(icon, size: 16, color: sel ? Colors.white : sch.onSurfaceVariant),
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: acColor,
        labelStyle: TextStyle(
            fontSize: 12.5, color: sel ? Colors.white : sch.onSurfaceVariant),
        onSelected: (_) => setState(() => _section = key),
      );
    }

    // ------------------------------------------------ Admin Users section
    Widget adminsTab() {
      final superAdmins =
          users.where((u) => u.username.trim().toLowerCase() == ApiService.adminUsername);
      final admins = users.where((u) => u.isAdmin).toList();

      Widget userRow(User u, {bool builtIn = false}) {
        final isBusy = _busyUser == u.username;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: sch.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sch.outlineVariant)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B4FE9), Color(0xFF9C6ADE)],
                  ),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  u.fullName.isNotEmpty
                      ? u.fullName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(u.fullName.isEmpty ? '@${u.username}' : u.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  if (builtIn)
                    Pill(tr('Super Admin'), color: acColor)
                  else if (u.isAdmin)
                    Pill(tr('Admin'), color: Colors.indigo)
                  else
                    Pill(tr('User'), color: sch.onSurfaceVariant),
                ]),
                Text('@${u.username}${u.email.isNotEmpty ? ' • ${u.email}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: sch.onSurfaceVariant)),
                if (u.phone.isNotEmpty)
                  Text(u.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: sch.onSurfaceVariant)),
              ]),
            ),
            if (!builtIn)
              isBusy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          foregroundColor: u.isAdmin ? Colors.redAccent : acColor),
                      onPressed: () => _toggleAdmin(u),
                      child: Text(u.isAdmin ? tr('Remove admin') : tr('Make admin'),
                          style: const TextStyle(fontSize: 12)),
                    ),
          ]),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(
                  tr('Admin accounts can manage the whole shop from this panel. The built-in @admin account is always Super Admin.')
                      .replaceFirst('@admin', ApiService.adminUsername),
                  style: TextStyle(fontSize: 12.5, color: sch.onSurfaceVariant)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: acColor),
              onPressed: _adding ? null : _addAdmin,
              icon: _adding
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt, size: 18),
              label: Text(tr('Add admin / staff')),
            ),
          ]),
          const SizedBox(height: 16),
          Text(tr('Super Admin'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final u in superAdmins) userRow(u, builtIn: true),
          Text(tr('Admins & Staff'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (admins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(tr('No admin users yet — promote a user with the button above.'),
                  style: TextStyle(fontSize: 12.5, color: sch.onSurfaceVariant)),
            ),
          for (final u in admins) userRow(u),
          Text(tr('Regular Users'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final u in users.where((u) => !u.isAdmin)) userRow(u),
        ]),
      );
    }

    // --------------------------------------- Roles & Permissions section
    Widget rolesTab() {
      // Every permission known across all roles, sorted — these are the
      // chips shown (and toggleable) in each row.
      final allPerms = <String>{
        for (final r in _roles) ...(r['permissions'] as List<String>),
      }.toList()
        ..sort();

      // The built-in Super Admin role is locked: it always has every
      // permission and cannot be degraded, renamed or deleted.
      bool isSuperRole(int i) =>
          (_roles[i]['name'] as String).toLowerCase() == 'super admin';

      Future<void> persist(String logEntry) async {
        await AppSettings.saveRoles(_roles);
        await AppSettings.logAdminActivity(logEntry);
        _toast(logEntry);
      }

      Future<void> togglePerm(int i, String perm) async {
        if (isSuperRole(i)) {
          final perms = _roles[i]['permissions'] as List<String>;
          if (perms.contains(perm)) {
            _toast(tr('Super Admin always has every permission.'));
            return;
          }
        }
        setState(() {
          final perms = _roles[i]['permissions'] as List<String>;
          perms.contains(perm) ? perms.remove(perm) : perms.add(perm);
        });
        await persist('Updated permissions for role "${_roles[i]['name']}"');
      }

      /// Quick "Add permission" from the row action: type a new permission
      /// name and it is added to that role (and to the chip options).
      Future<void> addPermissionDialog(int i) async {
        final c = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (dc) => AlertDialog(
            title: Text(tr('Add permission'),
                style: const TextStyle(fontSize: 16)),
            content: TextField(
              controller: c,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Permission name')),
              onSubmitted: (_) =>
                  Navigator.pop(dc, c.text.trim().isNotEmpty ? c.text.trim() : null),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dc),
                  child: Text(tr('Cancel'))),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: acColor),
                  onPressed: () =>
                      Navigator.pop(dc, c.text.trim().isNotEmpty ? c.text.trim() : null),
                  child: Text(tr('Add'))),
            ],
          ),
        );
        if (!mounted || name == null || name.isEmpty) return;
        setState(() {
          final perms = _roles[i]['permissions'] as List<String>;
          if (!perms.contains(name)) perms.add(name);
        });
        await persist('Added permission "$name" to role "${_roles[i]['name']}"');
      }

      Future<void> deleteRoleDialog(int i) async {
        if (isSuperRole(i)) {
          _toast(tr('The Super Admin role cannot be deleted.'));
          return;
        }
        final name = _roles[i]['name'] as String;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dc) => AlertDialog(
            title: Text(tr('Delete role "$name"?'),
                style: const TextStyle(fontSize: 16)),
            content: Text(
                tr('This removes the role and its permission mapping. Accounts keep their current access.'),
                style: const TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dc, false),
                  child: Text(tr('Cancel'))),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(dc).colorScheme.error),
                  onPressed: () => Navigator.pop(dc, true),
                  child: Text(tr('Delete'))),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        setState(() => _roles.removeAt(i));
        await persist('Deleted role "$name"');
      }

      Future<void> editRoleDialog([int? index]) async {
        if (index != null && isSuperRole(index)) {
          _toast(tr('The Super Admin role is fixed and cannot be edited.'));
          return;
        }
        final editing = index != null;
        final nameC = TextEditingController(
            text: editing ? _roles[index]['name'] as String : '');
        final descC = TextEditingController(
            text: editing ? _roles[index]['description'] as String : '');
        final permC = TextEditingController();
        var perms = editing
            ? List<String>.from(_roles[index]['permissions'] as List<String>)
            : <String>[];
        final options = [...allPerms];

        final ok = await showDialog<bool>(
          context: context,
          builder: (dc) => StatefulBuilder(
            builder: (dc, setD) => AlertDialog(
              title: Text(editing ? tr('Edit role') : tr('Create role'),
                  style: const TextStyle(fontSize: 16)),
              content: SizedBox(
                width: 380,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: nameC,
                    autofocus: !editing,
                    decoration:
                        InputDecoration(labelText: tr('Role name')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descC,
                    decoration:
                        InputDecoration(labelText: tr('Description')),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(tr('PERMISSIONS'),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: sch.onSurfaceVariant)),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final p in options)
                          CheckboxListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: perms.contains(p),
                            title: Text(p,
                                style: const TextStyle(fontSize: 12.5)),
                            onChanged: (v) => setD(() =>
                                v == true ? perms.add(p) : perms.remove(p)),
                          ),
                        if (options.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(tr('No permissions yet — add one below.'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: sch.onSurfaceVariant)),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: permC,
                    decoration: InputDecoration(
                      labelText: tr('Add custom permission'),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: tr('Add permission'),
                        onPressed: () => setD(() {
                          final v = permC.text.trim();
                          if (v.isEmpty || options.contains(v)) return;
                          options.add(v);
                          perms.add(v);
                          permC.clear();
                        }),
                      ),
                    ),
                    onSubmitted: (_) => setD(() {
                      final v = permC.text.trim();
                      if (v.isEmpty || options.contains(v)) return;
                      options.add(v);
                      perms.add(v);
                      permC.clear();
                    }),
                  ),
                ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dc, false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: acColor),
                    onPressed: () => Navigator.pop(dc, true),
                    child: Text(editing ? tr('Save') : tr('Create'))),
              ],
            ),
          ),
        );
        if (ok != true || !mounted) return;
        final name = nameC.text.trim();
        if (name.isEmpty) {
          _toast(tr('Role name is required.'));
          return;
        }
        final dup = _roles.asMap().entries.any((e) =>
            (e.value['name'] as String).toLowerCase() == name.toLowerCase() &&
            (!editing || e.key != index));
        if (dup) {
          _toast(tr('A role named "$name" already exists.'));
          return;
        }
        setState(() {
          final role = {
            'name': name,
            'description': descC.text.trim(),
            'permissions': perms,
          };
          if (editing) {
            _roles[index] = role;
          } else {
            _roles.add(role);
          }
        });
        await persist(editing ? 'Updated role "$name"' : 'Created role "$name"');
      }

      Widget permChip(String label, bool allowed) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: allowed
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    allowed ? Colors.green.shade700 : Colors.red.shade400,
              )),
        );
      }

      Widget roleRow(int i) {
        final r = _roles[i];
        final perms = r['permissions'] as List<String>;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: sch.surface,
              border:
                  Border(bottom: BorderSide(color: sch.outlineVariant))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name pill.
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: acColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Text((r['name'] as String).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: acColor)),
            ),
            const SizedBox(width: 16),
            // Description.
            SizedBox(
              width: 170,
              child: Text(r['description'] as String,
                  style: TextStyle(
                      fontSize: 12.5, color: sch.onSurfaceVariant)),
            ),
            const SizedBox(width: 16),
            // Permission chips — tap a chip to allow / deny it.
            Expanded(
              child: perms.isEmpty
                  ? Text(tr('No permissions — tap Edit to add some.'),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: sch.onSurfaceVariant))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in allPerms)
                          Tooltip(
                            message: tr(perms.contains(p)
                                ? 'Tap to deny: $p'
                                : 'Tap to allow: $p'),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => togglePerm(i, p),
                              child: permChip(p, perms.contains(p)),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            // Actions.
            SizedBox(
              width: isSuperRole(i) ? 40 : 128,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  tooltip: tr('Add permission'),
                  icon: const Icon(Icons.library_add_outlined, size: 17),
                  onPressed: () => addPermissionDialog(i),
                ),
                // The Super Admin role is permanent: no edit / delete.
                if (!isSuperRole(i)) ...[
                  IconButton(
                    tooltip: tr('Edit role'),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    onPressed: () => editRoleDialog(i),
                  ),
                  IconButton(
                    tooltip: tr('Delete role'),
                    icon: Icon(Icons.delete_outline,
                        size: 17, color: sch.error),
                    onPressed: () => deleteRoleDialog(i),
                  ),
                ],
              ]),
            ),
          ]),
        );
      }

      Widget tableHeader() {
        Widget label(String s, {bool right = false}) => Text(s,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: sch.onSurfaceVariant));
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: sch.surface,
              border:
                  Border(bottom: BorderSide(color: sch.outlineVariant))),
          child: Row(children: [
            SizedBox(width: 110, child: label(tr('NAME'))),
            const SizedBox(width: 16),
            SizedBox(width: 170, child: label(tr('DESCRIPTION'))),
            const SizedBox(width: 16),
            Expanded(child: label(tr('PERMISSIONS'))),
            const SizedBox(width: 8),
            SizedBox(
                width: 128,
                child: label(tr('ACTIONS'), right: true)),
          ]),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(
              tr('Configure user roles and map dynamic system-wide access permissions. Tap a permission chip to allow or deny it for that role.'),
              style: TextStyle(
                  fontSize: 12.5, color: sch.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (_rolesLoading)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
          else if (_roles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(tr('No roles yet — create the first one.'),
                    style: TextStyle(
                        fontSize: 12.5, color: sch.onSurfaceVariant)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                  color: sch.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sch.outlineVariant)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tableHeader(),
                    for (var i = 0; i < _roles.length; i++) roleRow(i),
                  ]),
            ),
          const SizedBox(height: 12),
          Text(tr('Role enforcement is applied by the backend admin checks. Accounts with is_admin = true are treated as Admin+.'),
              style: TextStyle(fontSize: 11.5, color: sch.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(tr('Super Admin is the top role: it always holds every permission and cannot be deleted or edited.'),
              style: TextStyle(fontSize: 11.5, color: sch.onSurfaceVariant)),
        ]),
      );
    }

    // ------------------------------------------------- Activity Logs section
    Widget logsTab() {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(
                  tr('Actions you take in this panel (edits, deletes, status changes, role updates) are recorded here.'),
                  style: TextStyle(fontSize: 12.5, color: sch.onSurfaceVariant)),
            ),
            TextButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(tr('Refresh'))),
            TextButton.icon(
                onPressed: _logEntries.isEmpty
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dc) => AlertDialog(
                            title: Text(tr('Clear all logs?')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dc, false),
                                  child: Text(tr('Cancel'))),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(dc).colorScheme.error),
                                  onPressed: () => Navigator.pop(dc, true),
                                  child: Text(tr('Clear'))),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await AppSettings.clearActivityLog();
                          _loadLogs();
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                label: Text(tr('Clear all'))),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _logLoading
                ? const Center(child: CircularProgressIndicator())
                : _logEntries.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 52, color: sch.outline),
                              const SizedBox(height: 10),
                              Text(tr('No activity recorded yet'),
                                  style: TextStyle(color: sch.onSurfaceVariant)),
                            ]),
                      )
                    : ListView.builder(
                        itemCount: _logEntries.length,
                        itemBuilder: (c, i) {
                          final raw = _logEntries[i];
                          final br = raw.indexOf(']');
                          final time =
                              br >= 0 ? raw.substring(0, br + 1) : '';
                          final text =
                              br >= 0 ? raw.substring(br + 1).trim() : raw;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: sch.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sch.outlineVariant)),
                            child: Row(children: [
                              Icon(Icons.history, size: 18, color: sch.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(text,
                                          style: const TextStyle(fontSize: 13)),
                                      Text(time,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: sch.onSurfaceVariant)),
                                    ]),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      );
    }

    // -------------------------------------------- System Management section
    Widget systemTab() {
      Widget infoRow(String label, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 150,
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12.5, color: sch.onSurfaceVariant))),
              Expanded(
                  child: SelectableText(value,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
          );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          sectionCard(
              context,
              tr('Database Status'),
              Column(children: [
                Row(children: [
                  Icon(_dbOnline ? Icons.cloud_done_outlined : Icons.cloud_off,
                      size: 22,
                      color: _dbOnline ? Colors.green : Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        _dbOnline ? tr('Connected to the shared cloud') : tr('Database unreachable'),
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: acColor),
                    onPressed: _checkingDb ? null : _checkDatabase,
                    icon: _checkingDb
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_outlined, size: 18),
                    label: Text(tr('Check now')),
                  ),
                ]),
                const Divider(height: 24),
                infoRow(tr('Database'), 'Supabase (PostgreSQL)'),
                infoRow(tr('Endpoint'), SupabaseService.url),
                infoRow(tr('Product catalog'), ApiService.baseUrl),
              ])),
          const SizedBox(height: 12),
          sectionCard(context, tr('Application Info'), Column(children: [
            infoRow(tr('App'), tr('Global Online Admin')),
            infoRow(tr('Version'), '1.0.0'),
            infoRow(tr('Admin account'), ApiService.adminUsername),
            infoRow(tr('Data source'), tr('Cloud + local device cache')),
            infoRow(tr('Realtime'), tr('Orders, Users & Feedback watchers active')),
          ])),
        ]),
      );
    }

    // ------------------------------------------------------------------ body
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, children: [
          for (final (icon, label, key) in _menu) tab(key, tr(label), icon),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _section == 'admins'
            ? adminsTab()
            : _section == 'roles'
                ? rolesTab()
                : _section == 'logs'
                    ? logsTab()
                    : systemTab(),
      ),
    ]);
  }
}

/// Values collected by the Add admin/staff dialog.
class _StaffDraft {
  final String username, firstName, lastName, email, phone, password;
  final bool isAdmin;
  const _StaffDraft({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.isAdmin,
  });
}

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _username = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _isAdmin = false;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? kb, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: kb,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _submit() {
    final tr = AppLocalizations.of(context).t;
    if (_username.text.trim().isEmpty) {
      _toast(tr('Username is required'));
      return;
    }
    if (_password.text.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }
    setState(() => _busy = true);
    Navigator.pop(
        context,
        _StaffDraft(
          username: _username.text.trim(),
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          isAdmin: _isAdmin,
        ));
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).t;
    return AlertDialog(
      title: Text(tr('Add admin / staff')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(_username, tr('Username'), Icons.alternate_email),
          Row(children: [
            Expanded(child: _field(_firstName, tr('First Name'), Icons.person_outline)),
            const SizedBox(width: 10),
            Expanded(child: _field(_lastName, tr('Last Name'), Icons.person_outline)),
          ]),
          _field(_email, tr('Email'), Icons.email_outlined, kb: TextInputType.emailAddress),
          _field(_phone, tr('Phone'), Icons.phone_outlined, kb: TextInputType.phone),
          _field(_password, tr('Password'), Icons.lock_outline, obscure: true),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Grant admin role?'), style: const TextStyle(fontSize: 13.5)),
            value: _isAdmin,
            activeThumbColor: acColor,
            onChanged: (v) => setState(() => _isAdmin = v),
          ),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _busy ? null : acColor),
          onPressed: _busy ? null : _submit,
          child: Text(tr('Create')),
        ),
      ],
    );
  }
}

/// Reused little status badge (Administration).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}