import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart' as sb;

import '../models/models.dart';

/// Shared cloud backend for the whole app (shoppers AND admin).
///
/// All devices point at the same Supabase project, so every product the
/// admin adds, every order a shopper places and every account that signs up
/// is visible to everyone — instead of being trapped in one device's
/// SharedPreferences (the previous dummyjson/local behaviour, which is kept
/// as an offline/read-only fallback).
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const url = 'https://sezqflhpmkwyncrjigvw.supabase.co';
  static const publishableKey =
      'sb_publishable_DXlv4KdpR1PvJy_A3ZJLLQ_1s-L59Xg';

  sb.SupabaseClient? _client;
  bool _failed = false;

  /// True when cloud calls are short-circuited for `flutter test` (no real
  /// network there). Also read by the repositories/presenters so they skip
  /// their cloud paths too and use the local data sources instead.
  static bool get testMode => _inFlutterTest;

  /// True inside `flutter test`: there is no real network there (HTTP calls
  /// return 400 and the supabase client leaves pending timers that fail the
  /// widget tests), so every cloud call short-circuits and the app falls
  /// back to its local data sources.
  static bool get _inFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  sb.SupabaseClient get client {
    _client ??= sb.SupabaseClient(url, publishableKey);
    return _client!;
  }

  /// True once a request has failed (offline / project unreachable / tables
  /// not installed). Lets the app fall back to local data silently instead
  /// of showing error screens everywhere.
  bool get unavailable => _failed;

  Future<List<Map<String, dynamic>>> _select(
    String table, {
    String? eqColumn,
    Object? eqValue,
    int? limit,
    String? orderBy,
    bool ascending = true,
  }) async {
    if (_inFlutterTest) return const [];
    try {
      // .order()/.limit() return a transform builder, so the chain is built
      // dynamically and awaited once at the end.
      dynamic q = client.from(table).select();
      if (eqColumn != null) {
        q = q.eq(eqColumn, eqValue as Object);
      }
      if (orderBy != null) {
        q = q.order(orderBy, ascending: ascending);
      }
      if (limit != null) q = q.limit(limit);
      final rows = await q as List;
      _failed = false;
      return rows
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      _failed = true;
      return const [];
    }
  }

  Future<bool> _insert(String table, Map<String, dynamic> row) async {
    if (_inFlutterTest) return false;
    try {
      await client.from(table).insert(row);
      _failed = false;
      return true;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  Future<bool> _update(String table, Map<String, dynamic> row,
      String pk, Object? pkValue) async {
    if (_inFlutterTest) return false;
    try {
      // `.select()` makes PostgREST return the rows that were actually
      // written, so an update that matches NO row (the row only exists on
      // this device — e.g. the cloud table is empty) reports false and the
      // caller falls back to the local store instead of losing the edit.
      final res =
          await client.from(table).update(row).eq(pk, pkValue as Object).select();
      _failed = false;
      return (res as List).isNotEmpty;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  Future<bool> _delete(String table, String pk, Object? pkValue) async {
    if (_inFlutterTest) return false;
    try {
      // `.select()` counts the rows really deleted, so deleting a row that
      // was never in the cloud reports false (the caller handles its local
      // copy instead).
      final res =
          await client.from(table).delete().eq(pk, pkValue as Object).select();
      _failed = false;
      return (res as List).isNotEmpty;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  // ------------------------------------------------------------------ users

  static String hashPassword(String password) =>
      crypto.sha256.convert(utf8.encode('global-online:$password')).toString();

  Future<sb.AuthResponse?> loginAuth(String email, String password) async {
    if (_inFlutterTest) return null;
    try {
      final res = await client.auth
          .signInWithPassword(email: email, password: password);
      _failed = false;
      return res;
    } catch (_) {
      _failed = true;
      return null;
    }
  }

  /// Look up a shop account by username (case-insensitive).
  Future<Map<String, dynamic>?> userByUsername(String username) async {
    final rows = await _select('app_users',
        eqColumn: 'username', eqValue: username.trim().toLowerCase());
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> userByEmail(String email) async {
    final rows = await _select('app_users',
        eqColumn: 'email', eqValue: email.trim().toLowerCase());
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> allUsers() =>
      _select('app_users', orderBy: 'username');

  /// True when the account [username] still exists in the cloud directory,
  /// false when it was deleted (e.g. by the admin), and null when the answer
  /// is unknown (offline / running tests). The null case lets callers avoid
  /// logging a user out just because the network is down.
  Future<bool?> userExists(String username) async {
    if (_inFlutterTest) return null;
    final rows = await _select('app_users',
        eqColumn: 'username',
        eqValue: username.trim().toLowerCase(),
        limit: 1);
    if (_failed) return null; // could not reach the cloud — answer unknown
    return rows.isNotEmpty;
  }

  /// Insert (or ignore if the username already exists) a shop account.
  /// Returns false when the cloud could not be reached.
  Future<bool> upsertUser(Map<String, dynamic> row) async {
    final existing = await userByUsername(row['username'] as String? ?? '');
    if (existing != null) return true; // already registered — treat as OK
    return _insert('app_users', row);
  }

  Future<bool> deleteUser(String username) =>
      _delete('app_users', 'username', username.trim().toLowerCase());

  /// Promote/demote an account's role in the shared cloud directory
  /// (is_admin toggle used by the Administration page). Returns true when
  /// the cloud accepted the change.
  Future<bool> updateUserRole(String username, bool isAdmin) =>
      _update('app_users', {'is_admin': isAdmin}, 'username',
          username.trim().toLowerCase());

  // --------------------------------------------------------------- products

  Future<List<Product>> products() async {
    // Newest first — items the admin just added always land on top.
    final rows = await _select('products',
        orderBy: 'created_at', ascending: false);
    return rows.map(Product.fromSupabase).toList();
  }

  /// Adds the row including the `verified` column. If the connected
  /// database has not been migrated yet (older schema without `verified`),
  /// retries once without that column so the save still succeeds.
  /// Returns the stored row (with its real cloud id) so the caller can
  /// replace a temporary device-local copy — or null when offline.
  Future<Map<String, dynamic>?> addProductRow(Product p) async {
    var row = await _insertReturning(
        'products', productRow(p, newLocalId: true, withVerified: true));
    row ??=
        await _insertReturning('products', productRow(p, newLocalId: true));
    return row;
  }

  /// Insert that gives back the stored row (PostgREST return=representation
  /// via `.select()`), or null when offline / the table is missing.
  Future<Map<String, dynamic>?> _insertReturning(
      String table, Map<String, dynamic> row) async {
    if (_inFlutterTest) return null;
    try {
      final res = await client.from(table).insert(row).select();
      _failed = false;
      final list = res as List;
      return list.isEmpty
          ? null
          : (list.first as Map).cast<String, dynamic>();
    } catch (_) {
      _failed = true;
      return null;
    }
  }

  /// Update akin to [addProduct]: preferred path with `verified`, fallback
  /// retry without it for databases that lack the column.
  Future<bool> updateProduct(Product p) async {
    final ok = await _update(
        'products', productRow(p, withVerified: true), 'id', p.id);
    if (ok) return true;
    return _update('products', productRow(p), 'id', p.id);
  }

  Future<bool> deleteProduct(int id) => _delete('products', 'id', id);

  static Map<String, dynamic> productRow(Product p,
      {bool newLocalId = false, bool withVerified = true}) {
    String imgList(List<String> l) => jsonEncode(l);
    final row = <String, dynamic>{
      'title': p.title,
      'brand': p.brand,
      'category': p.category,
      'description': p.description,
      'price': p.price,
      'discount_percentage': p.discountPercentage,
      'rating': p.rating,
      'stock': p.stock,
      'thumbnail': p.thumbnail,
      'images': imgList(p.images),
      'status': p.status,
      if (withVerified) 'verified': p.verified,
    };
    if (!newLocalId) row['id'] = p.id;
    return row;
  }

  // ------------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    // Newest first — freshly added categories appear before older ones.
    final rows = await _select('categories',
        orderBy: 'created_at', ascending: false);
    return rows.map(Category.fromSupabase).toList();
  }

  Future<bool> addCategory(String name,
      {String slug = '',
      String description = '',
      String image = ''}) async {
    final label = name.trim();
    if (label.isEmpty) return false;
    final custom = slug.trim().toLowerCase();
    var safeSlug = custom.isNotEmpty
        ? custom
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '')
        : label
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
    if (safeSlug.isEmpty) safeSlug = 'custom';
    return _insert('categories', {
      'slug': safeSlug,
      'name': label,
      'url': '$url/products/category/$safeSlug',
      'description': description.trim(),
      'image': image.trim(),
    });
  }

  /// Edit a category in the cloud. Returns true only when a row with the
  /// given [slug] actually existed and was updated — an update that matches
  /// no rows (e.g. a read-only catalog category that was never added to the
  /// `categories` table) reports false so the caller can fall back to a
  /// device-local override.
  Future<bool> updateCategory(String slug,
      {required String name,
      required String newSlug,
      String description = '',
      String image = ''}) async {
    if (_inFlutterTest) return false;
    String cleanSlug(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final safeNew = cleanSlug(newSlug.trim()).isEmpty
        ? cleanSlug(name)
        : cleanSlug(newSlug.trim());
    try {
      // `.select()` makes PostgREST return the rows that were actually
      // updated, so we can tell a real match from a no-op update.
      final res = await client
          .from('categories')
          .update({
            'slug': safeNew.isEmpty ? 'custom' : safeNew,
            'name': name.trim(),
            'url':
                '$url/products/category/${safeNew.isEmpty ? 'custom' : safeNew}',
            'description': description.trim(),
            'image': image.trim(),
          })
          .eq('slug', slug)
          .select();
      _failed = false;
      return (res as List).isNotEmpty;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  Future<bool> deleteCategory(String slug) =>
      _delete('categories', 'slug', slug);

  // ----------------------------------------------------------------- orders

  /// Cloud orders, newest first.
  ///
  /// [owner] filters to a single account's orders (used by the shopper's
  /// Order History so each user only ever sees their own — changing one
  /// user's order in the admin panel can never touch another user's).
  /// Empty/null returns every order (admin panel).
  Future<List<Order>> orders({String? owner}) async {
    final rows = await _select('orders',
        eqColumn:
            (owner != null && owner.isNotEmpty) ? 'owner' : null,
        eqValue: owner,
        orderBy: 'created_at',
        ascending: false);
    return rows.map(Order.fromSupabase).toList();
  }

  Future<bool> saveOrder(Order o) => _insert('orders', {
        'id': o.id,
        'owner': o.owner,
        'status': o.status,
        'total': o.total,
        'address': o.deliveryAddress,
        'items': jsonEncode(o.items
            .map((it) => {
                  'quantity': it.quantity,
                  'product': {
                    'id': it.product.id,
                    'title': it.product.title,
                    'price': it.product.price,
                    'discountPercentage': it.product.discountPercentage,
                    'rating': it.product.rating,
                    'stock': it.product.stock,
                    'brand': it.product.brand,
                    'category': it.product.category,
                    'description': it.product.description,
                    'thumbnail': it.product.thumbnail,
                    'images': it.product.images,
                  }
                })
            .toList()),
      });

  Future<bool> updateOrderStatus(String id, String status) =>
      _update('orders', {'status': status}, 'id', id);

  // ------------------------------------------------------------- feedback

  /// Local queue of feedback written while the cloud was unreachable.
  /// Saved with negative ids so they can never collide with cloud rows.
  static const _pendingFeedbackKey = 'pending_feedback_v1';

  List<FeedbackItem> _pendingFeedback(SharedPreferences p) {
    final raw = p.getStringList(_pendingFeedbackKey) ?? const [];
    try {
      return raw
          .map((e) => FeedbackItem.fromJsonLocal(
              (jsonDecode(e) as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _queueFeedback(FeedbackItem f) async {
    final p = await SharedPreferences.getInstance();
    final list = _pendingFeedback(p);
    // Give the queued item a fresh unique negative id (cloud rows use
    // positive ids from the identity column).
    final lowest = list
        .map((x) => x.id)
        .fold(0, (a, b) => b < a ? b : a);
    final queued = FeedbackItem(
        id: lowest - 1,
        owner: f.owner,
        name: f.name,
        message: f.message,
        rating: f.rating,
        date: f.date);
    list.add(queued);
    await p.setStringList(
        _pendingFeedbackKey, list.map(jsonEncodeFeedback).toList());
  }

  String jsonEncodeFeedback(FeedbackItem f) => jsonEncode({
        'id': f.id,
        'owner': f.owner,
        'name': f.name,
        'message': f.message,
        'rating': f.rating,
        'created_at': f.date.toIso8601String(),
      });

  /// Try to flush the offline queue to the cloud. Returns the (negative)
  /// ids that made it up, so the caller can drop them from the queue.
  /// Public so the app can retry on startup — feedback queued while the
  /// cloud was down uploads as soon as the cloud works.
  Future<List<int>> flushPendingFeedback() async {
    if (_inFlutterTest) return const [];
    final p = await SharedPreferences.getInstance();
    final pending = _pendingFeedback(p);
    if (pending.isEmpty) return const [];
    final uploaded = <int>[];
    for (final f in pending) {
      final ok = await _insert('feedback', {
        'owner': f.owner,
        'name': f.name,
        'message': f.message,
        'rating': f.rating,
      });
      if (!ok) break; // still offline — stop trying, keep the rest queued
      uploaded.add(f.id);
    }
    if (uploaded.isEmpty) return const [];
    final remaining =
        pending.where((x) => !uploaded.contains(x.id)).toList();
    await p.setStringList(
        _pendingFeedbackKey, remaining.map(jsonEncodeFeedback).toList());
    return uploaded;
    }

  /// Save feedback to the cloud. If the cloud is unreachable (e.g. the
  /// `feedback` table has not been created yet), the item is queued
  /// locally and reported as SUCCESS so the shopper sees "Thanks for your
  /// feedback!" — it uploads automatically once the cloud works.
  Future<bool> addFeedback(FeedbackItem f) async {
    final ok = await _insert('feedback', {
      'owner': f.owner,
      'name': f.name,
      'message': f.message,
      'rating': f.rating,
    });
    if (ok) {
      // A previous offline message may still be queued — flush it now.
      unawaited(flushPendingFeedback());
      return true;
    }
    try {
      await _queueFeedback(f);
    } catch (_) {
      // Even the local queue failed (extremely rare): report failure so
      // the shopper can retry.
      return false;
    }
    return true; // saved locally — report success to the shopper
  }

  /// Cloud + locally queued feedback, newest first. Pending items keep
  /// their negative ids so admin delete still works on them.
  Future<List<FeedbackItem>> feedbacks() async {
    final p = await SharedPreferences.getInstance();
    // Retry any queued offline messages first — if the cloud is back,
    // they upload and this same call picks them up from the cloud.
    await flushPendingFeedback();
    final rows = await _select('feedback',
        orderBy: 'created_at', ascending: false);
    final pending = _pendingFeedback(p);
    if (rows.isEmpty && pending.isEmpty) return const [];
    final cloud = rows.map(FeedbackItem.fromSupabase).toList();
    final seen = cloud.map((x) => '${x.owner}|${x.message}').toSet();
    final merged = [
      ...pending.where((x) => !seen.contains('${x.owner}|${x.message}')),
      ...cloud,
    ]
      ..sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  Future<bool> deleteFeedback(int id) async {
    if (id < 0) {
      // A queued offline item: remove it from the local queue.
      final p = await SharedPreferences.getInstance();
      final remaining =
          _pendingFeedback(p).where((x) => x.id != id).toList();
      await p.setStringList(
          _pendingFeedbackKey, remaining.map(jsonEncodeFeedback).toList());
      return true;
    }
    return _delete('feedback', 'id', id);
  }

  Future<bool> deleteOrder(String id) => _delete('orders', 'id', id);

  // ------------------------------------------------ realtime (live updates)

  sb.RealtimeChannel? _feedbackChannel;

  /// Listen for NEW feedback rows in the cloud and call [onChanged] the
  /// moment one arrives — so the admin panel can show it without any
  /// refresh. Needs the `feedback` table added to the `supabase_realtime`
  /// publication (see supabase_schema.sql); if realtime is not enabled the
  /// caller's polling fallback still keeps the list fresh.
  void watchFeedback(void Function() onChanged) {
    if (_inFlutterTest) return;
    try {
      cancelFeedbackWatch();
      _feedbackChannel = client
          .channel('feedback-live')
          .onPostgresChanges(
            event: sb.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'feedback',
            callback: (_) => onChanged(),
          )
          .subscribe();
    } catch (_) {
      // Realtime unavailable (offline / not enabled) — the polling
      // fallback in the admin panel covers it.
      _feedbackChannel = null;
    }
  }

  /// Stop listening for live feedback (called when the admin panel closes).
  void cancelFeedbackWatch() {
    final ch = _feedbackChannel;
    _feedbackChannel = null;
    if (ch == null) return;
    try {
      client.removeChannel(ch);
    } catch (_) {}
  }

  sb.RealtimeChannel? _usersChannel;

  /// Listen for live changes to the shop account directory (`app_users`).
  ///
  /// [onInsert] fires the moment a new account row appears (a signup or a
  /// first sign-in), so the admin's Users page updates without any refresh.
  ///
  /// [onDelete] fires with the deleted username the moment an account is
  /// removed (admin delete), so the signed-in shopper can be logged out
  /// immediately.
  ///
  /// Needs the `app_users` table added to the `supabase_realtime`
  /// publication (see supabase_schema.sql); if realtime is not enabled the
  /// callers' polling fallbacks still keep everything fresh.
  void watchUsers({
    void Function()? onInsert,
    void Function(String username)? onDelete,
  }) {
    if (_inFlutterTest) return;
    try {
      cancelUsersWatch();
      var ch = client.channel('users-live');
      if (onInsert != null) {
        ch = ch.onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_users',
          callback: (_) => onInsert(),
        );
      }
      if (onDelete != null) {
        ch = ch.onPostgresChanges(
          event: sb.PostgresChangeEvent.delete,
          schema: 'public',
          table: 'app_users',
          // `username` is the primary key, so it is always part of the
          // old record the realtime service broadcasts for a delete.
          callback: (payload) {
            final uname = payload.oldRecord['username']?.toString() ?? '';
            if (uname.isNotEmpty) onDelete(uname);
          },
        );
      }
      _usersChannel = ch.subscribe();
    } catch (_) {
      // Realtime unavailable (offline / not enabled) — the polling fallbacks
      // in the admin panel and the app root cover it.
      _usersChannel = null;
    }
  }

  /// Stop listening for live users (called when the admin panel closes).
  void cancelUsersWatch() {
    final ch = _usersChannel;
    _usersChannel = null;
    if (ch == null) return;
    try {
      client.removeChannel(ch);
    } catch (_) {}
  }

  sb.RealtimeChannel? _ordersChannel;

  /// Listen for live changes to the `orders` table.
  ///
  /// [onInsert] fires the moment a NEW order row appears (a shopper just
  /// checked out), so the admin's Orders page can show it without any
  /// refresh.
  ///
  /// [onChanged] fires when an existing order is updated (the admin changes
  /// the status to Processing / Shipped / Delivered / Cancelled), so the
  /// shopper's Order History reflects it the moment it happens — no
  /// pull-to-refresh, no re-login.
  ///
  /// Needs the `orders` table added to the `supabase_realtime` publication
  /// (see supabase_schema.sql); if realtime is not enabled the polling
  /// fallbacks in the Order History page and the admin panel still keep
  /// everything fresh.
  void watchOrders({void Function()? onInsert, void Function()? onChanged}) {
    if (_inFlutterTest) return;
    try {
      cancelOrdersWatch();
      var ch = client.channel('orders-live');
      if (onInsert != null) {
        ch = ch.onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (_) => onInsert(),
        );
      }
      if (onChanged != null) {
        ch = ch.onPostgresChanges(
          event: sb.PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (_) => onChanged(),
        );
      }
      _ordersChannel = ch.subscribe();
    } catch (_) {
      // Realtime unavailable (offline / not enabled) — the polling
      // fallbacks in the Order History page and the admin panel cover it.
      _ordersChannel = null;
    }
  }

  /// Stop listening for live order changes.
  void cancelOrdersWatch() {
    final ch = _ordersChannel;
    _ordersChannel = null;
    if (ch == null) return;
    try {
      client.removeChannel(ch);
    } catch (_) {}
  }
}
