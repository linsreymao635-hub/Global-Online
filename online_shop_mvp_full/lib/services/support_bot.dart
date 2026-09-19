import '../l10n/app_localizations.dart';

/// One user turn (or bot answer) kept as conversation context so the bot
/// can resolve follow-ups like "and what about delivery time?" using what
/// was said before.
class SupportTurn {
  final String raw; // exactly what the user typed
  final String topic; // matched topic id, '' when unmatched
  SupportTurn({required this.raw, this.topic = ''});
}

/// One knowledge-base topic: id, translated label, English + Khmer keywords
/// to match against the user's message, a list of answer variations (cycled
/// so the bot never repeats the exact same wording), optional deeper detail
/// used when the user asks again about the same topic, and follow-up keys
/// the user can jump to next.
class _Topic {
  final String id;
  final String label;
  final List<String> en;
  final List<String> km;
  final List<String> answers;
  final String extra;
  final List<String> followUps;
  const _Topic({
    required this.id,
    required this.label,
    required this.en,
    required this.km,
    required this.answers,
    this.extra = '',
    this.followUps = const [],
  });
}

/// The chat support "brain": matches what the user asked against a small
/// knowledge base, remembers the last turns, resolves follow-ups from
/// context and varies its wording so it never answers with the same
/// sentence twice in a row. All strings go through [AppLocalizations.t] so
/// Khmer users get Khmer answers.
class SupportBot {
  SupportBot(this._l10n);

  /// Mirror of the sidebar quick-topic labels, reused when the bot says
  /// "you can also ask about …".
  static const quickTopics = <String>[
    'Track my order',
    'Shipping and delivery',
    'Returns and refunds',
    'Payment methods',
  ];

  final AppLocalizations _l10n;

  String _t(String en) => _l10n.t(en);

  // --------------------------------------------------------------- memory

  final List<SupportTurn> _history = [];
  String _lastTopic = '';
  final Set<String> _usedVariants = {}; // 'topic#variantIndex'
  int _repeats = 0; // consecutive identical-topic questions

  /// Test/debug helper: forget everything.
  void reset() {
    _history.clear();
    _lastTopic = '';
    _usedVariants.clear();
    _repeats = 0;
  }

  // ---------------------------------------------------------------- topics

  static const List<_Topic> _topics = [
    _Topic(
      id: 'order',
      label: 'Track my order',
      en: [
        'track', 'tracking', 'status', 'order', 'where is my order',
        'delivery status', 'my package', 'parcel', 'shipment status',
        'invoice', 'history', 'จัดส่ง',
      ],
      km: ['តាមដាន', 'ការបញ្ជាទិញ', 'ស្ថានភាព', 'ទីតាំង'],
      answers: [
        'You can follow your order under Profile → Order History. Every order '
            'there shows its live status — Processing, Shipped or Delivered.',
        'Open Profile → Order History and tap your order: you will see its '
            'current status, the items and the delivery address.',
        'Your order status lives in Profile → Order History. Once it ships, '
            'the status changes to Shipped and later to Delivered.',
      ],
      extra: 'You also get an invoice by email, and delivery updates arrive '
          'by SMS and Telegram.',
      followUps: ['shipping', 'cancel'],
    ),
    _Topic(
      id: 'shipping',
      label: 'Shipping and delivery',
      en: [
        'ship', 'shipping', 'deliver', 'delivery', 'long', 'how many days',
        'arrive', 'courier', 'fee', 'cost of shipping', 'free shipping',
        'when will', 'lead time',
      ],
      km: ['ដឹកជញ្ជូន', 'ការដឹកជញ្ជូន', 'ថ្ងៃ', 'ចំណាយ', 'ភ្នាក់ងារ'],
      answers: [
        'Shipping takes 2–5 working days depending on your province. You can '
            'follow the courier link from your order details.',
        'Delivery usually takes 2–5 working days. The tracking link in your '
            'order details shows where the parcel is right now.',
        'Most orders arrive within 2–5 working days; remote provinces can '
            'take one day longer.',
      ],
      extra: 'Delivery is free for orders over the minimum, and you can '
          'follow the courier link from your order details.',
      followUps: ['order', 'cancel'],
    ),
    _Topic(
      id: 'returns',
      label: 'Returns and refunds',
      en: [
        'return', 'returns', 'refund', 'refunds', 'exchange', 'money back',
        'wrong item', 'damaged', 'broken', 'send back',
      ],
      km: ['ត្រឡប់', 'សងប្រាក់', 'ប្តូរ', 'ខូច'],
      answers: [
        'Returns are accepted within 7 days with the item unused and in its '
            'original packaging. Refunds are processed 3–5 working days after '
            'we receive the item back.',
        'You have 7 days to return an unused item in its original packaging. '
            'Once we receive it, your refund is processed within 3–5 working '
            'days.',
      ],
      extra: 'Start a return from Profile → Order History → your order → '
          'Return, or send us a photo of the item here.',
      followUps: ['shipping', 'payment'],
    ),
    _Topic(
      id: 'payment',
      label: 'Payment methods',
      en: [
        'pay', 'payment', 'payments', 'card', 'credit', 'debit', 'khqr',
        'aba', 'wing', 'bank', 'banking', 'cash', 'cod', 'checkout',
        'currency',
      ],
      km: ['ទូទាត់', 'ការទូទាត់', 'ប្រាក់', 'ធនាគារ', 'កាប៉ាន់ស្សាយ'],
      answers: [
        'We accept cash on delivery, credit/debit cards, KHQR and mobile '
            'banking (ABA, Wing). You choose the method at checkout.',
        'You can pay with cash on delivery, card, KHQR or mobile banking — '
            'pick whichever is easiest at checkout.',
      ],
      extra: 'KHQR and card payments are confirmed instantly; cash is '
          'collected by the courier on delivery.',
      followUps: ['discount', 'account'],
    ),
    _Topic(
      id: 'discount',
      label: 'Discounts and promo codes',
      en: [
        'discount', 'discounts', 'promo', 'promotion', 'coupon', 'code',
        'voucher', 'sale', 'cheap', 'cheaper', 'offer', 'deal',
      ],
      km: ['បញ្ចុះតម្លៃ', 'កូដ', 'បន្ថយ', 'រំលង'],
      answers: [
        'Products on sale show a red discount badge with the percentage. The '
            'price you see at checkout already includes every discount.',
        'Discounted items carry a red percentage badge on the product card — '
            'the checkout total always reflects the reduced price.',
      ],
      extra: 'There are no separate promo codes right now; every current '
          'offer is applied automatically.',
      followUps: ['payment', 'shipping'],
    ),
    _Topic(
      id: 'account',
      label: 'Account and password',
      en: [
        'account', 'password', 'sign up', 'signup', 'register', 'login',
        'log in', 'sign in', 'change password', 'forgot password', 'delete',
        'profile', 'email', 'username',
      ],
      km: ['គណនី', 'ពាក្យសម្ងាត់', 'ចូល', 'ចុះឈ្មោះ', 'ប្រវត្តិរូប'],
      answers: [
        'You can change your password under Profile → Change Password. '
            'Forgot it? Use "Forgot Password?" on the sign-in page — it '
            'sends a reset code to your phone.',
        'Profile → Change Password updates your password anytime. If you '
            'cannot sign in, tap "Forgot Password?" on the login page to '
            'reset it with your phone number.',
      ],
      extra: 'To leave us entirely, Profile → Delete Account removes your '
          'account after you confirm with your password.',
      followUps: ['order', 'feedback'],
    ),
    _Topic(
      id: 'feedback',
      label: 'Feedback',
      en: [
        'feedback', 'rate', 'rating', 'review', 'review us', 'suggest',
        'suggestion', 'complain', 'complaint', 'comment',
      ],
      km: ['មតិយោបល់', 'វាយតម្លៃ', 'សុំទោស', 'មតិ'],
      answers: [
        'We would love to hear from you! Open Profile → Feedback, pick a '
            'star rating and write your message — it reaches our team '
            'instantly.',
        'You can leave feedback under Profile → Feedback: choose your '
            'rating, type your message and submit. It goes straight to the '
            'team that reads every comment.',
      ],
      extra: 'You can also right here in this chat — just tell us what you '
          'think and we will pass it on.',
      followUps: ['account', 'contact'],
    ),
    _Topic(
      id: 'contact',
      label: 'Contact us',
      en: [
        'contact', 'call', 'phone', 'email', 'hotline', 'talk to',
        'speak to', 'human', 'agent', 'person', 'staff', 'support team',
        'reach you',
      ],
      km: ['ទាក់ទង', 'ទូរស័ព្ទ', 'អ៊ីមែល', 'ជំនួយ'],
      answers: [
        'You can reach a real person at +855 12 345 678 or '
            'support@globalonline.com — or just keep chatting with me here.',
        'Our hotline is +855 12 345 678 and email is support@globalonline.com '
            '(both listed under Profile → Contact Us).',
      ],
      extra: 'This chat also reaches the support team — they read every '
          'message you send.',
      followUps: ['feedback', 'order'],
    ),
    _Topic(
      id: 'cancel',
      label: 'Order Cancellation',
      en: [
        'cancel', 'cancellation', 'abort my order', 'stop my order',
        'change my order',
      ],
      km: ['បោះបង់', 'លុបចោល'],
      answers: [
        'Orders can be cancelled while they are still Processing. Open '
            'Profile → Order History, tap the order and choose Cancel. Once '
            'an order is Shipped it can no longer be cancelled — but you can '
            'still return it within 7 days of delivery.',
        'You can cancel any order that has not shipped yet: Profile → Order '
            'History → your order → Cancel. Shipped orders go through the '
            'normal 7-day return flow instead.',
      ],
      extra: 'Cancelled payments are refunded within 3–5 working days.',
      followUps: ['returns', 'order'],
    ),
    _Topic(
      id: 'product',
      label: 'Products and stock',
      en: [
        'product', 'products', 'stock', 'in stock', 'available',
        'availability', 'restock', 'sold out', 'out of stock', 'size',
        'color', 'colour', 'warranty', 'genuine', 'original',
      ],
      km: ['ផលិតផល', 'ស្តុក', 'មាននៅ', 'អស់ស្តុក'],
      answers: [
        'Every product page shows live stock — if it says "Out of stock", we '
            'are restocking and it usually returns within a few days.',
        'Stock is shown on each product page. Sold-out items are restocked '
            'regularly, and all our products are genuine with full warranty.',
      ],
      extra: 'Tap the heart on a product to add it to Favorites — the app '
          'keeps it handy so you can check back when it is back in stock.',
      followUps: ['shipping', 'discount'],
    ),
    _Topic(
      id: 'app',
      label: 'Using the app',
      en: [
        'app', 'application', 'how to buy', 'how to order', 'buy', 'cart',
        'checkout', 'favorite', 'favorites', 'wishlist', 'language',
        'khmer', 'dark mode', 'theme', 'search', 'use this app', 'working',
      ],
      km: ['កម្មវិធី', 'កន្ត្រក', 'ទំនើប', 'ភាសា', 'រុករក'],
      answers: [
        'To buy something: find the product (search or browse categories), '
            'tap Add to Cart, then go to Cart → Checkout and pick your '
            'delivery address and payment method.',
        'Shopping is simple: search or browse, Add to Cart, then Cart → '
            'Checkout. You can switch language and dark mode anytime in '
            'Settings.',
      ],
      extra: 'Anything you add to Favorites is saved under the heart icon so '
          'you can find it quickly next time.',
      followUps: ['payment', 'shipping'],
    ),
  ];

  // ------------------------------------------------------------ matching

  /// Normalise a message: lowercase, strip punctuation, collapse spaces.
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u1780-\u17ff\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Score one topic against the message: keyword hits weighted by keyword
  /// length (longer = more specific = stronger signal).
  static int _scoreTopic(_Topic topic, String msg) {
    var score = 0;
    for (final k in topic.en) {
      if (msg.contains(k)) score += k.length;
    }
    for (final k in topic.km) {
      if (msg.contains(k)) score += k.length + 2; // Khmer words are dense
    }
    return score;
  }

  /// The topic the user is most likely asking about, or null when nothing
  /// matches meaningfully.
  _Topic? _matchTopic(String message) {
    final msg = _normalize(message);
    if (msg.isEmpty) return null;
    _Topic? best;
    var bestScore = 0;
    for (final t in _topics) {
      final s = _scoreTopic(t, msg);
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    // Require a meaningful signal (a real keyword, not a stray letter).
    if (best == null || bestScore < 3) return null;
    return best;
  }

  /// True when the message looks like a follow-up ("and delivery?", "what
  /// about payment?", "how about returns?", "why?", "more details") rather
  /// than a full question.
  bool _looksLikeFollowUp(String message) {
    final msg = _normalize(message);
    if (msg.isEmpty) return false;
    const cues = [
      'and ', 'what about', 'how about', 'what of', 'why', 'more',
      'detail', 'details', 'explain', 'tell me more', 'also', 'then',
      'continue', 'and?', 'that', 'this one', 'it ',
    ];
    for (final c in cues) {
      if (msg.contains(c)) return true;
    }
    // Very short replies are usually follow-ups too ("delivery?", "price?").
    if (msg.length <= 18) return true;
    return false;
  }

  // ------------------------------------------------------------- answering

  /// Pick the next answer variant for [topic] that has not been used yet;
  /// when all variants were shown, start over but the [extra] detail is
  /// appended so the text is still not identical.
  String _nextVariant(_Topic topic) {
    for (var i = 0; i < topic.answers.length; i++) {
      final key = '${topic.id}#$i';
      if (!_usedVariants.contains(key)) {
        _usedVariants.add(key);
        return topic.answers[i];
      }
    }
    // All used — recycle variant 0 plus the extra detail so it never reads
    // as the same sentence again.
    return topic.answers[_repeats % topic.answers.length] +
        (topic.extra.isEmpty ? '' : ' ${topic.extra}');
  }

  /// Answer the user's message using the conversation context. Never
  /// returns the same wording twice for the same topic.
  String reply(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return _t(defaultFallback);

    var topic = _matchTopic(trimmed);
    var followedUp = false;

    // No direct match — is it a follow-up to the previous topic?
    if (topic == null && _lastTopic.isNotEmpty && _looksLikeFollowUp(trimmed)) {
      final prev = _topics.firstWhere((t) => t.id == _lastTopic,
          orElse: () => _topics.first);
      if (prev.id == _lastTopic) {
        topic = prev;
        followedUp = true;
      }
    }

    // Small talk: greetings, thanks, bye.
    final small = _smallTalk(trimmed);
    if (small != null) {
      // Small talk does not change the current topic context.
      _remember(trimmed, '');
      return small;
    }

    if (topic == null) {
      _remember(trimmed, '');
      _lastTopic = '';
      return _t(defaultFallback);
    }

    // Same topic asked again: acknowledge and add DEPTH (the extra detail),
    // not the same sentences.
    final sameAsLast = topic.id == _lastTopic;
    String text;
    if (sameAsLast) {
      _repeats++;
      final extra = topic.extra;
      text = extra.isEmpty
          ? _nextVariant(topic)
          : (followedUp
              ? '${_t('Sure — more about that: ')}$extra'
              : extra);
      if (text.isEmpty) text = _nextVariant(topic);
    } else {
      _repeats = 0;
      text = _nextVariant(topic);
      // After a first full answer, offer the natural follow-up topics.
      if (topic.followUps.isNotEmpty && !followedUp) {
        final labels = topic.followUps
            .map((id) => _topics.firstWhere((t) => t.id == id).label)
            .map(_t)
            .join(', ');
        text = '$text\n\n${_t('Related:')} $labels';
      }
    }

    _remember(trimmed, topic.id);
    _lastTopic = topic.id;
    return text;
  }

  static const defaultFallback =
      'Sorry, I did not quite catch that. I can help with orders, '
      'shipping, returns, payments, your account and more — could you '
      'rephrase, or pick one of those topics?';

  /// Greetings / thanks / goodbye get their own short human replies so the
  /// bot feels like a chat, not a form. Only checked on SHORT messages so
  /// "hi" inside a longer question never triggers a greeting.
  String? _smallTalk(String raw) {
    final msg = _normalize(raw);
    if (msg.length > 30) return null;
    bool has(List<String> words) {
      for (final w in words) {
        if (msg == w || msg.startsWith('$w ') || msg.endsWith(' $w')) {
          return true;
        }
      }
      return false;
    }

    if (has(['hi', 'hello', 'hey', 'hello there', 'good morning',
        'good afternoon', 'good evening', 'suosdey', 'សួស្តី'])) {
      return _t('Hello! 👋 How can I help you today? You can ask about your '
          'order, shipping, returns, payments — anything.');
    }
    if (has(['thank', 'thanks', 'thank you', 'orksran', 'អរគុណ'])) {
      return _t('You are very welcome! Anything else I can help with?');
    }
    if (has(['bye', 'goodbye', 'see you', 'leahoy', 'លាហើយ'])) {
      return _t('Thanks for chatting with Global Online support. Have a '
          'great day! 👋');
    }
    if (has(['ok', 'okay', 'got it', 'alright'])) {
      return _t('Great! Let me know if you need anything else. 😊');
    }
    return null;
  }

  void _remember(String raw, String topic) {
    _history.add(SupportTurn(raw: raw, topic: topic));
    if (_history.length > 20) _history.removeAt(0);
  }

  /// Recent conversation (for debugging / future server sync).
  List<SupportTurn> get history => List.unmodifiable(_history);
}
