import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../views/chat_support_page.dart' show ChatMessage;

/// Persists the Chat Support conversation per account so the user's
/// questions and the bot's answers survive closing the page and restarting
/// the app.
///
/// Everything is stored in SharedPreferences under
/// `chat_history_<accountKey>` as a JSON list — the same per-account
/// pattern [AppSettings] uses for profiles and addresses.
class ChatStore {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  static const _prefix = 'chat_history_';

  String? _key; // current account key ('anon' for guests)
  List<ChatMessage>? _cache;

  /// The storage key for the given account.
  static String _storageKey(String accountKey) =>
      '$_prefix${accountKey.trim().toLowerCase()}';

  /// Switch to the conversation of [accountKey] and load its messages.
  /// Called once when the chat page opens. Returns the saved messages
  /// (oldest first) — an empty list when this account has no history yet.
  Future<List<ChatMessage>> load(String accountKey) async {
    final key = _storageKey(accountKey);
    if (key != _key) {
      _key = key;
      _cache = null;
    }
    final cached = _cache;
    if (cached != null) return List.of(cached);
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      final msgs = list
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .where((m) => m.text != '__typing__') // never restore a ghost bubble
          .toList();
      _cache = msgs;
      return List.of(msgs);
    } catch (_) {
      return const [];
    }
  }

  /// Append [message] to the current conversation and persist immediately.
  Future<void> append(ChatMessage message) async {
    final key = _key;
    if (key == null) return; // load() was never called
    final msgs = _cache ??= [];
    msgs.add(message);
    await _persist(key, msgs);
  }

  /// Replace the stored conversation with [messages] and persist.
  Future<void> saveAll(List<ChatMessage> messages) async {
    final key = _key;
    if (key == null) return;
    _cache = List.of(messages);
    await _persist(key, _cache!);
  }

  /// Delete the current conversation (Clear chat).
  Future<void> clear() async {
    final key = _key;
    if (key == null) return;
    _cache = [];
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(key);
    } catch (_) {}
  }

  Future<void> _persist(String key, List<ChatMessage> msgs) async {
    try {
      final p = await SharedPreferences.getInstance();
      // Keep the last 200 messages so the JSON never grows unbounded.
      final trimmed = msgs.length > 200 ? msgs.sublist(msgs.length - 200) : msgs;
      await p.setString(
          key, jsonEncode(trimmed.map((m) => m.toJson()).toList()));
    } catch (_) {
      // Storage unavailable — the chat still works, it just won't persist.
    }
  }
}
