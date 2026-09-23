import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/chat_store.dart';
import '../services/support_bot.dart';

/// One chat message. [type] is 'text', 'image', 'video' or 'voice'.
/// [text] holds the text, [path] a local file path, [url] a remote URL
/// (used by seeded bot messages with sample media), [secs] the voice
/// duration in seconds, and [thumb] an optional video thumbnail poster.
class ChatMessage {
  ChatMessage({
    required this.fromUser,
    required this.type,
    this.text = '',
    this.path,
    this.url,
    this.secs = 0,
    this.thumb,
    this.forwarded = false,
  });

  final bool fromUser;
  final String type; // 'text' | 'image' | 'video' | 'voice' | 'sticker'
  final String text;
  final String? path;
  final String? url;
  final int secs;
  final String? thumb;

  /// Reply quote: who wrote the quoted message ([replyToFromUser]) plus a
  /// one-line preview of it. Set when the message was sent as a reply.
  bool replyToFromUser = false;
  String? replyToText;

  /// Emoji reaction sticker on this message (null = no reaction).
  String? reaction;

  /// True when this message was forwarded (re-sent from another message).
  bool forwarded = false;

  /// Preferred source for playback: local file first, then network URL.
  String get mediaSource => path ?? url ?? '';

  /// Serialize for [ChatStore] persistence. Local media files (paths) are
  /// NOT saved — temp files are gone after a restart — only text content
  /// and remote URLs survive; media bubbles restore as their caption text.
  Map<String, dynamic> toJson() => {
        'fromUser': fromUser,
        'type': type,
        'text': text,
        if (url != null) 'url': url,
        if (secs > 0) 'secs': secs,
        if (forwarded) 'forwarded': true,
        if (reaction != null) 'reaction': reaction,
        if (replyToText != null)
          'replyTo': {'fromUser': replyToFromUser, 'text': replyToText},
      };

  /// Restored messages are always renderable: a media bubble whose local
  /// file is gone (paths are not persisted) becomes its caption text.
  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final type = j['type']?.toString() ?? 'text';
    final url = j['url']?.toString();
    final text = j['text']?.toString() ?? '';
    // Stickers are pure text; other media needs a surviving remote URL.
    final renderable =
        type == 'text' || type == 'sticker' || (url != null && url.isNotEmpty);
    final m = ChatMessage(
      fromUser: j['fromUser'] == true,
      type: renderable ? type : 'text',
      text: text,
      url: url,
      secs: (j['secs'] as num?)?.toInt() ?? 0,
    );
    m.reaction = j['reaction']?.toString();
    m.forwarded = j['forwarded'] == true;
    final reply = (j['replyTo'] as Map?)?.cast<String, dynamic>();
    if (reply != null) {
      m.replyToFromUser = reply['fromUser'] == true;
      m.replyToText = reply['text']?.toString() ?? '';
    }
    return m;
  }
}

/// A live bot "typing" bubble is rendered from a placeholder message whose
/// text is the sentinel [_typingSentinel].
const String _typingSentinel = '__typing__';

class ChatSupportPage extends StatefulWidget {
  const ChatSupportPage({super.key});
  @override
  State<ChatSupportPage> createState() => _ChatSupportPageState();
}

class _ChatSupportPageState extends State<ChatSupportPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<ChatMessage> _msgs = [];

  // Message currently being replied to (quoted above the input bar).
  ChatMessage? _replyTo;

  // The support "brain": understands the question, remembers the
  // conversation and varies its answers (created in initState, where the
  // localizations are available).
  SupportBot? _bot;

  // --- attachments preview state ------------------------------------------
  XFile? _pendingImage;
  XFile? _pendingVideo;

  // --- voice recording state ----------------------------------------------
  final _recorder = AudioRecorder();
  String? _recordingPath;
  Duration _recElapsed = Duration.zero;
  Timer? _recTimer;

  // --- voice playback state ------------------------------------------------
  final _player = AudioPlayer();
  String? _playingPath;
  Timer? _posTimer;
  int _playingPosMs = 0;
  int _playingDurMs = 1;
  StreamSubscription? _playerSub;

  // --- video preview (full-screen dialog) ----------------------------------
  VideoPlayerController? _videoCtl;

  bool get _hasPendingMedia => _pendingImage != null || _pendingVideo != null;
  bool get _recording => _recordingPath != null;  // --------------------------------------------------------------------------
  // Conversation start: restore a saved chat, or seed the welcome messages
  // --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bot = SupportBot(AppLocalizations.of(context));
      _startConversation();
    });
  }

  /// Restore this account's saved conversation; a fresh account gets the
  /// standard welcome + quick-topic seed (which is then saved too, so it
  /// becomes part of the restored history next time).
  Future<void> _startConversation() async {
    final u = AppSettings.restoredUser;
    final accountKey = (u == null || u.username.trim().isEmpty)
        ? 'anon'
        : AppSettings.profileKeyOf(u);
    final saved = await ChatStore.instance.load(accountKey);
    if (!mounted) return;
    if (saved.isNotEmpty) {
      // Continue exactly where the user left off.
      setState(() {
        _msgs
          ..clear()
          ..addAll(saved);
      });
      _scrollDown();
      return;
    }
    // Fresh conversation: seed the welcome messages and remember them.
    final tr = AppLocalizations.of(context).t;
    final seed = [
      ChatMessage(
          fromUser: false,
          type: 'text',
          text: tr(
              'Hello! Welcome to Global Online support. How can I help you today?')),
      ChatMessage(fromUser: true, type: 'text', text: tr('Track my order')),
      ChatMessage(
          fromUser: false,
          type: 'text',
          text: tr(
              'You can view order status in Profile → Order History. Invoices are sent to your email, and delivery updates arrive by SMS and Telegram.')),
      ChatMessage(
          fromUser: true, type: 'text', text: tr('Shipping and delivery')),
      ChatMessage(
          fromUser: false,
          type: 'text',
          text: tr(
              'Shipping takes 2–5 working days. Delivery is free for orders over the minimum and you can follow the courier link from your order details.')),
      ChatMessage(
          fromUser: true, type: 'text', text: tr('Returns and refunds')),
      ChatMessage(
          fromUser: false,
          type: 'text',
          text: tr(
              'Returns are accepted within 7 days with the item unused and its original packaging. Refunds are processed within 3–5 working days after we receive the item.')),
      ChatMessage(
          fromUser: true, type: 'text', text: tr('Payment methods')),
      ChatMessage(
          fromUser: false,
          type: 'text',
          text: tr(
              'We accept cash on delivery, credit/debit cards, KHQR, and mobile banking. Choose your payment method at checkout.')),
    ];
    setState(() => _msgs.addAll(seed));
    unawaited(ChatStore.instance.saveAll(_msgs));
    _scrollDown();
  }

  /// Persist [m] right away (fire-and-forget; the chat never waits on I/O).
  void _remember(ChatMessage m) {
    if (m.text == _typingSentinel) return;
    unawaited(ChatStore.instance.append(m));
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _posTimer?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    _recorder.dispose();
    _videoCtl?.dispose();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Clear chat (delete the saved conversation and start fresh)
  // --------------------------------------------------------------------------
  Future<void> _confirmClearChat() async {
    final tr = AppLocalizations.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(tr('Clear chat')),
        content: Text(tr(
            'This deletes the whole conversation on this device. Continue?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dc).colorScheme.error),
            onPressed: () => Navigator.pop(dc, true),
            child: Text(tr('Clear')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ChatStore.instance.clear();
    _bot?.reset();
    if (!mounted) return;
    final tr2 = AppLocalizations.of(context).t;
    setState(() {
      _msgs
        ..clear()
        ..add(ChatMessage(
            fromUser: false,
            type: 'text',
            text: tr2(
                'Hello! Welcome to Global Online support. How can I help you today?')));
    });
    unawaited(ChatStore.instance.saveAll(_msgs));
    _scrollDown();
  }

  // --------------------------------------------------------------------------
  // Scrolling
  // --------------------------------------------------------------------------
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  // --------------------------------------------------------------------------
  // Sending
  // --------------------------------------------------------------------------
  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _focus.unfocus();
    final m =
        _withReply(ChatMessage(fromUser: true, type: 'text', text: text));
    _replyTo = null;
    setState(() => _msgs.add(m));
    _remember(m);
    _scrollDown();
    _botReply(userText: text);
  }

  Future<void> _sendPendingMedia() async {
    final img = _pendingImage;
    final vid = _pendingVideo;
    if (img == null && vid == null) return;
    setState(() {
      if (img != null) {
        final m = _withReply(ChatMessage(
            fromUser: true, type: 'image', path: img.path, text: _input.text.trim()));
        _msgs.add(m);
        _remember(m);
      }
      if (vid != null) {
        final m = _withReply(ChatMessage(
            fromUser: true, type: 'video', path: vid.path, text: _input.text.trim()));
        _msgs.add(m);
        _remember(m);
      }
      _pendingImage = null;
      _pendingVideo = null;
      _replyTo = null;
      _input.clear();
    });
    _scrollDown();
    _botReply();
  }

  // --------------------------------------------------------------------------
  // Bot reply (answers the actual question + remembers the conversation)
  // --------------------------------------------------------------------------
  void _botReply({String? userText}) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _msgs.add(ChatMessage(
          fromUser: false, type: 'text', text: _typingSentinel)));
      _scrollDown();
    });
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      // Answer the user's ACTUAL message from the knowledge base — with
      // conversation memory, follow-up handling and answer variation.
      final bot = _bot;
      final answer = bot == null
          ? ''
          : bot.reply(userText ?? _lastUserText);
      final i = _msgs.indexWhere((m) => m.text == _typingSentinel && !m.fromUser);
      final bubble = ChatMessage(fromUser: false, type: 'text', text: answer);
      setState(() {
        if (i >= 0) {
          _msgs[i] = bubble;
        } else {
          _msgs.add(bubble);
        }
      });
      _remember(bubble);
      _scrollDown();
    });
  }

  /// The most recent text the user typed — used by voice/media messages so
  /// a spoken question still gets a real answer. Stickers are skipped so a
  /// sticker send does not become the "question".
  String get _lastUserText {
    for (final m in _msgs.reversed) {
      if (m.fromUser &&
          m.type != 'sticker' &&
          m.text.trim().isNotEmpty) {
        return m.text;
      }
    }
    return '';
  }

  // --------------------------------------------------------------------------
  // Reply / Forward / Reactions / Stickers
  // --------------------------------------------------------------------------
  /// One-line preview of a message, used in reply quotes and the reply bar.
  String _previewOf(ChatMessage m) {
    switch (m.type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎬 Video';
      case 'voice':
        return '🎙️ Voice message';
      case 'sticker':
        return m.text;
      default:
        final t = m.text.trim();
        return t.length > 80 ? '${t.substring(0, 80)}…' : t;
    }
  }

  /// Attach the pending reply quote to a message being sent.
  ChatMessage _withReply(ChatMessage m) {
    final r = _replyTo;
    if (r != null) {
      m.replyToFromUser = r.fromUser;
      m.replyToText = _previewOf(r);
    }
    return m;
  }

  void _startReply(ChatMessage m) {
    setState(() => _replyTo = m);
    _focus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  /// Re-send a message as a copy marked "Forwarded".
  void _forwardMessage(ChatMessage m) {
    final copy = ChatMessage(
        fromUser: true,
        type: m.type,
        text: m.text,
        path: m.path,
        url: m.url,
        secs: m.secs,
        thumb: m.thumb,
        forwarded: true);
    setState(() {
      _msgs.add(copy);
      _replyTo = null;
    });
    _remember(copy);
    _scrollDown();
    _botReply(userText: m.type == 'text' ? m.text : null);
  }

  /// Toggle an emoji reaction on [m] (same emoji removes it). The whole
  /// conversation is re-saved so the reaction survives a restart.
  void _setReaction(ChatMessage m, String emoji) {
    setState(() => m.reaction = m.reaction == emoji ? null : emoji);
    unawaited(ChatStore.instance.saveAll(_msgs));
  }

  /// Long-press sheet: reaction stickers + Reply + Forward.
  Future<void> _showMessageActions(ChatMessage m) async {
    const reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🎉'];
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bc) {
        final tr = AppLocalizations.of(bc).t;
        final sch = Theme.of(bc).colorScheme;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: sch.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            // Reaction sticker row — tap to react, tap the same emoji again
            // (or "Remove reaction") to take it back.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final e in reactions)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(bc);
                      _setReaction(m, e);
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(e,
                            style: const TextStyle(fontSize: 28))),
                  ),
              ],
            ),
            const Divider(height: 16),
            if (m.reaction != null)
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(tr('Remove reaction')),
                onTap: () {
                  Navigator.pop(bc);
                  _setReaction(m, m.reaction!);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(tr('Reply')),
              onTap: () {
                Navigator.pop(bc);
                _startReply(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shortcut_outlined),
              title: Text(tr('Forward')),
              onTap: () {
                Navigator.pop(bc);
                _forwardMessage(m);
              },
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  /// Sticker picker: tap a sticker to send it as its own big message.
  void _showStickerSheet() {
    const stickers = [
      '😀', '😂', '🥰', '😍', '😎', '🤔', '😴', '😭',
      '😡', '🤗', '🥳', '😇', '👍', '👎', '🙏', '👏',
      '💪', '🤝', '✌️', '❤️', '💔', '✨', '🔥', '🎉',
      '🎁', '🛒', '📦', '💳', '🚚', '⭐', '🤩', '🙌',
    ];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bc) => SafeArea(
        child: SizedBox(
          height: 280,
          child: GridView.count(
            crossAxisCount: 8,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final s in stickers)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(bc);
                    _sendSticker(s);
                  },
                  child: Center(
                      child: Text(s, style: const TextStyle(fontSize: 30))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendSticker(String emoji) {
    final m = _withReply(
        ChatMessage(fromUser: true, type: 'sticker', text: emoji));
    _replyTo = null;
    setState(() => _msgs.add(m));
    _remember(m);
    _scrollDown();
    _botReply(userText: emoji);
  }

  // --------------------------------------------------------------------------
  // Attachments
  // --------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _pendingImage = x;
      _pendingVideo = null;
    });
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker()
        .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 1));
    if (x == null) return;
    setState(() {
      _pendingVideo = x;
      _pendingImage = null;
    });
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      _pendingImage = x;
      _pendingVideo = null;
    });
  }

  // --------------------------------------------------------------------------
  // Voice recording
  // --------------------------------------------------------------------------
  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context).t('Microphone permission needed'))));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _recordingPath = path;
        _recElapsed = Duration.zero;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recElapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context).t('Could not start recording'))));
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    final path = _recordingPath;
    final secs = _recElapsed.inSeconds;
    _recTimer?.cancel();
    setState(() => _recordingPath = null);
    if (path == null) return;
    try {
      final p = await _recorder.stop();
      if (!send) {
        // user cancelled — try to remove the temp file
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        return;
      }
      if (p == null) return;
      final m = ChatMessage(
          fromUser: true, type: 'voice', path: p, secs: secs < 1 ? 1 : secs);
      setState(() => _msgs.add(m));
      _remember(m);
      _scrollDown();
      _botReply();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).t('Could not send recording'))));
    }
  }

  // --------------------------------------------------------------------------
  // Voice playback
  // --------------------------------------------------------------------------
  Future<void> _togglePlay(ChatMessage m) async {
    final src = m.mediaSource;
    if (src.isEmpty) return;
    if (_playingPath == src) {
      // stop
      await _player.stop();
      _posTimer?.cancel();
      setState(() {
        _playingPath = null;
        _playingPosMs = 0;
      });
      return;
    }
    _posTimer?.cancel();
    await _player.stop();
    try {
      final isLocal = m.path != null;
      await _player.play(DeviceFileSource(src),
          mode: isLocal ? PlayerMode.mediaPlayer : PlayerMode.mediaPlayer);
    } catch (_) {
      try {
        await _player.play(UrlSource(src));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).t('Could not play audio'))));
        return;
      }
    }
    _playerSub?.cancel();
    _playerSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      _posTimer?.cancel();
      setState(() {
        _playingPath = null;
        _playingPosMs = 0;
      });
    });
    _playingDurMs = (m.secs > 0 ? m.secs * 1000 : 1000);
    _playingPosMs = 0;
    setState(() => _playingPath = src);
    _posTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final pos = await _player.getDuration(); // Duration?
      final cur = await _player.getCurrentPosition(); // Duration?
      if (!mounted) return;
      setState(() {
        if (pos != null && pos > Duration.zero) {
          _playingDurMs = pos.inMilliseconds;
        }
        _playingPosMs = cur?.inMilliseconds ?? 0;
      });
    });
  }

  // --------------------------------------------------------------------------
  // Video dialog
  // --------------------------------------------------------------------------
  Future<void> _openVideo(ChatMessage m) async {
    final src = m.mediaSource;
    if (src.isEmpty) return;
    final ctl = m.path != null
        ? VideoPlayerController.file(File(src))
        : VideoPlayerController.networkUrl(Uri.parse(src));
    try {
      await ctl.initialize();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).t('Could not play video'))));
      return;
    }
    if (!mounted) return;
    _videoCtl = ctl;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dc) => _VideoDialog(ctl: ctl),
    ).whenComplete(() {
      ctl.pause();
    });
  }

  // --------------------------------------------------------------------------
  // UI helpers
  // --------------------------------------------------------------------------
  String _fmtSecs(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '$m:${ss.toString().padLeft(2, '0')}';
  }

  String _fmtMs(int ms) {
    final s = (ms / 1000).round();
    return _fmtSecs(s);
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext c) {
    final l10n = AppLocalizations.of(c);
    final tr = l10n.t;
    final sch = Theme.of(c).colorScheme;
    return PopScope(
      canPop: !_recording,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _stopRecording(send: false);
      },
      child: Scaffold(        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: tr('Clear chat'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClearChat,
            ),
          ],
          title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sch.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.support_agent, color: sch.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Chat Support'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(tr('Online'),
                          style: TextStyle(
                              fontSize: 12, color: sch.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _msgs.length,
                itemBuilder: (_, i) {
                  final m = _msgs[i];
                  if (!m.fromUser && m.text == _typingSentinel) {
                    return _typingBubble(sch);
                  }
                  return _bubble(m, sch, tr);
                },
              ),
            ),
            if (_replyTo != null) _replyPreview(sch, tr),
            if (_pendingImage != null || _pendingVideo != null)
              _pendingPreview(sch, tr),
            if (_recording) _recordingBar(sch, tr),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendText(),
                        decoration: InputDecoration(
                          hintText: tr('Type your message…'),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stickers
                    IconButton(
                      tooltip: tr('Stickers'),
                      onPressed: _showStickerSheet,
                      icon: const Icon(Icons.mood_outlined),
                    ),
                    // Attach (image / video / camera)
                    IconButton(
                      tooltip: tr('Attach'),
                      onPressed: _showAttachSheet,
                      icon: const Icon(Icons.attach_file),
                    ),
                    // Mic / Send
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (_, v, __) {
                        final hasText = v.text.trim().isNotEmpty;
                        final hasMedia = _hasPendingMedia;
                        if (hasText || hasMedia) {
                          return IconButton.filled(
                            tooltip: tr('Send'),
                            onPressed: () {
                              if (_hasPendingMedia) {
                                _sendPendingMedia();
                              } else {
                                _sendText();
                              }
                            },
                            icon: const Icon(Icons.send),
                          );
                        }
                        return IconButton.filled(
                          tooltip: tr('Hold to record'),
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Attachment sheet
  // --------------------------------------------------------------------------
  void _showAttachSheet() {
    final tr = AppLocalizations.of(context).t;
    final sch = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bc) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: sch.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(tr('Photo from gallery')),
              onTap: () {
                Navigator.pop(bc);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(tr('Video from gallery')),
              onTap: () {
                Navigator.pop(bc);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Take a photo')),
              onTap: () {
                Navigator.pop(bc);
                _takePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Reply preview strip (quoted message above the input bar)
  // --------------------------------------------------------------------------
  Widget _replyPreview(ColorScheme sch, String Function(String) tr) {
    final r = _replyTo!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: sch.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: sch.primary, width: 3),
          top: BorderSide(color: sch.outlineVariant),
          right: BorderSide(color: sch.outlineVariant),
          bottom: BorderSide(color: sch.outlineVariant),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.fromUser ? tr('You') : tr('Support'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sch.primary)),
                Text(_previewOf(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ]),
        ),
        IconButton(
          tooltip: tr('Cancel'),
          onPressed: _cancelReply,
          icon: const Icon(Icons.close, size: 18),
        ),
      ]),
    );
  }

  // --------------------------------------------------------------------------
  // Pending attachment preview strip
  // --------------------------------------------------------------------------
  Widget _pendingPreview(ColorScheme sch, String Function(String) tr) {
    final f = _pendingImage ?? _pendingVideo;
    final isVideo = _pendingVideo != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: sch.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sch.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 46,
              height: 46,
              child: isVideo
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.videocam, size: 24))
                  : Image.file(File(f!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isVideo ? tr('Video attached') : tr('Photo attached'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: tr('Remove'),
            onPressed: () => setState(() {
              _pendingImage = null;
              _pendingVideo = null;
            }),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Recording bar
  // --------------------------------------------------------------------------
  Widget _recordingBar(ColorScheme sch, String Function(String) tr) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: sch.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: sch.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Text(_fmtSecs(_recElapsed.inSeconds),
              style: TextStyle(
                  color: sch.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr('Recording… tap send to stop and send'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sch.onErrorContainer, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => _stopRecording(send: false),
            child: Text(tr('Cancel'),
                style: TextStyle(color: sch.onErrorContainer)),
          ),
          IconButton.filled(
            tooltip: tr('Send'),
            onPressed: () => _stopRecording(send: true),
            icon: const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Typing indicator
  // --------------------------------------------------------------------------
  Widget _typingBubble(ColorScheme sch) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sch.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: _TypingDots(color: sch.onSurfaceVariant),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Message bubble
  // --------------------------------------------------------------------------
  Widget _bubble(
      ChatMessage m, ColorScheme sch, String Function(String) tr) {
    final isUser = m.fromUser;
    final bg = isUser ? sch.primary : sch.surfaceContainerHighest;
    final fg = isUser ? sch.onPrimary : sch.onSurface;

    // Sticker messages render big, without the colored bubble.
    if (m.type == 'sticker') {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageActions(m),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(2),
                child: Text(m.text, style: const TextStyle(fontSize: 46)),
              ),
              if (m.reaction != null) _reactionBadge(m, sch),
            ],
          ),
        ),
      );
    }

    // Quoted message this one replies to.
    Widget? quote;
    if (m.replyToText != null && m.replyToText!.isNotEmpty) {
      quote = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.white.withValues(alpha: .18)
              : sch.surface.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 3,
                decoration: BoxDecoration(
                    color: isUser ? sch.onPrimary : sch.primary,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.replyToFromUser ? tr('You') : tr('Support'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUser ? sch.onPrimary : sch.primary)),
                    Text(m.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: fg.withValues(alpha: .85))),
                  ]),
            ),
          ]),
        ),
      );
    }

    Widget content;
    switch (m.type) {
      case 'image':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => _openImage(m),
            child: m.path != null
                ? Image.file(File(m.path!),
                    width: 220, height: 220, fit: BoxFit.cover)
                : Image.network(m.url!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox(
                        width: 220,
                        height: 220,
                        child: Icon(Icons.broken_image, color: fg))),
          ),
        );
        break;
      case 'video':
        content = GestureDetector(
          onTap: () => _openVideo(m),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  height: 150,
                  child: m.thumb != null
                      ? Image.network(m.thumb!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: Colors.black26,
                          child: Icon(Icons.videocam_off_outlined,
                              color: fg, size: 40)),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        );
        break;
      case 'voice':
        final playing = _playingPath == m.mediaSource;
        final pos = playing ? _playingPosMs : 0;
        final dur =
            playing ? _playingDurMs : (m.secs > 0 ? m.secs * 1000 : 1000);
        content = SizedBox(
          width: 200,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _togglePlay(m),
                child: Icon(
                  playing ? Icons.stop_circle_outlined : Icons.play_circle_fill,
                  color: isUser ? sch.onPrimary : sch.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isUser ? sch.onPrimary : sch.primary)
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor:
                          (pos / (dur == 0 ? 1 : dur)).clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isUser ? sch.onPrimary : sch.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                playing ? _fmtMs(dur - pos) : _fmtSecs(m.secs),
                style: TextStyle(
                    fontSize: 11,
                    color: isUser ? sch.onPrimary : sch.onSurfaceVariant),
              ),
            ],
          ),
        );
        break;
      default:
        content = Text(m.text,
            style: TextStyle(fontSize: 14, height: 1.35, color: fg));
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Long-press any message for reactions / Reply / Forward.
        onLongPress: () => _showMessageActions(m),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.symmetric(
                  horizontal: m.type == 'text' ? 14 : 6,
                  vertical: m.type == 'text' ? 10 : 6),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.forwarded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shortcut,
                            size: 12, color: fg.withValues(alpha: .8)),
                        const SizedBox(width: 4),
                        Text(tr('Forwarded'),
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: fg.withValues(alpha: .8))),
                      ]),
                    ),
                  if (quote != null) quote,
                  content,
                ],
              ),
            ),
            if (m.reaction != null) _reactionBadge(m, sch),
          ],
        ),
      ),
    );
  }

  /// Small tappable pill under a bubble showing its emoji reaction
  /// (tap it to remove the reaction).
  Widget _reactionBadge(ChatMessage m, ColorScheme sch) {
    return GestureDetector(
      onTap: () => _setReaction(m, m.reaction!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: sch.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sch.outlineVariant)),
        child: Text(m.reaction!, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Image full-screen viewer
  // --------------------------------------------------------------------------
  Future<void> _openImage(ChatMessage m) async {
    final src = m.mediaSource;
    if (src.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dc) => GestureDetector(
        onTap: () => Navigator.pop(dc),
        child: InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: m.path != null
                ? Image.file(File(src))
                : Image.network(src, errorBuilder: (_, __, ___) {
                    return const Icon(Icons.broken_image,
                        color: Colors.white, size: 60);
                  }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing dots
// ---------------------------------------------------------------------------
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        Widget dot(int i) {
          final t = ((_ctl.value * 3 - i).clamp(0.0, 1.0));
          final scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs());
          return Container(
            width: 7 * scale,
            height: 7 * scale,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration:
                BoxDecoration(color: widget.color, shape: BoxShape.circle),
          );
        }

        return Row(mainAxisSize: MainAxisSize.min, children: [dot(0), dot(1), dot(2)]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Video dialog
// ---------------------------------------------------------------------------
class _VideoDialog extends StatefulWidget {
  final VideoPlayerController ctl;
  const _VideoDialog({required this.ctl});
  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  @override
  void initState() {
    super.initState();
    widget.ctl.play();
  }

  @override
  Widget build(BuildContext c) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: widget.ctl.value.aspectRatio == 0
                ? 16 / 9
                : widget.ctl.value.aspectRatio,
            child: VideoPlayer(widget.ctl),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.ctl,
              builder: (_, v, __) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          v.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white),
                      onPressed: () {
                        setState(() {
                          v.isPlaying
                              ? widget.ctl.pause()
                              : widget.ctl.play();
                        });
                      },
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        widget.ctl,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                            playedColor: Colors.lightBlueAccent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {
                          widget.ctl.setVolume(v.volume > 0 ? 0 : 1);
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
