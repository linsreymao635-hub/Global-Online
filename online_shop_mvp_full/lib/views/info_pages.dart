import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../presenters/presenters.dart';
import '../services/app_settings.dart';

// ---------------------------------------------------------------------------
// Shared helpers for the informational pages
// ---------------------------------------------------------------------------

/// Scaffold with an icon header and a list of sections.
class _InfoPage extends StatelessWidget {
  final String title;
  final List<Widget> sections;
  const _InfoPage({
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Logo directly on the page background (no colored banner behind it).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Center(
              child: Image.asset('assets/images/image.png',
                  height: 64, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          ...sections,
        ],
      ),
    );
  }
}

Widget _sec(BuildContext c, String title, List<Widget> children) {
  final sch = Theme.of(c).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                color: sch.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

Widget _p(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: TextStyle(
            height: 1.55,
            fontSize: 14,
            color: Theme.of(c).colorScheme.onSurfaceVariant),
      ),
    );

Widget _bullet(BuildContext c, IconData icon, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(c).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// About Us
// ---------------------------------------------------------------------------
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return _InfoPage(
      title: tr('About Us'),
      sections: [
        _sec(c, tr('Who We Are'), [
          _p(c, tr(
              'Global Online is a modern online marketplace delivering quality '
              'products straight to your door in Cambodia. From electronics and '
              'fashion to home essentials and groceries, we bring thousands of '
              'curated items together in one easy app.')),
          _p(c, tr(
              'Founded with a simple idea — trustworthy shopping from your phone — '
              'we combine fair prices, honest service, and fast delivery.')),
        ]),
        _sec(c, tr('Our Mission'), [
          _p(c, tr(
              'Our mission is to make online shopping simple, safe and enjoyable '
              'for everyone. We work directly with suppliers so you get great '
              'value with every order.')),
        ]),
        _sec(c, tr('Our Values'), [
          _bullet(c, Icons.favorite_outline, tr(
              'Customer first — your happiness drives every decision we make.')),
          _bullet(c, Icons.verified_outlined, tr(
              'Honesty — clear prices, real stock and transparent policies.')),
          _bullet(c, Icons.eco_outlined, tr(
              'Sustainability — we reduce waste and support local partners.')),
          _bullet(c, Icons.rocket_launch_outlined, tr(
              'Innovation — we keep improving the app around your needs.')),
        ]),
        _sec(c, tr('Why Shop With Us'), [
          _bullet(c, Icons.local_shipping_outlined,
              tr('Fast, tracked delivery across Cambodia.')),
          _bullet(c, Icons.payments_outlined, tr(
              'Flexible payment: cash on delivery, cards, KHQR and mobile banking.')),
          _bullet(c, Icons.support_agent_outlined,
              tr('Friendly support on chat, phone and Telegram.')),
          _bullet(c, Icons.autorenew_outlined,
              tr('Easy returns within 7 days of delivery.')),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact Us
// ---------------------------------------------------------------------------
class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _callA() =>
      launchUrl(Uri(scheme: 'tel', path: '+855066778213'));
  Future<void> _callB() =>
      launchUrl(Uri(scheme: 'tel', path: '+855769778213'));
  Future<void> _email() => launchUrl(
        Uri(scheme: 'mailto', path: 'support@globalonline.com'),
      );
  Future<void> _maps() => launchUrl(
        Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=11.5564,104.9282'),
        mode: LaunchMode.externalApplication,
      );
  Future<void> _telegram() async {
    final opened = await launchUrl(
      Uri.parse('tg://resolve?domain=Lin_Sreymao'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      await launchUrl(
        Uri.parse('https://t.me/Lin_Sreymao'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _facebook() => launchUrl(
        Uri.parse('https://www.facebook.com/share/1JouuaDpP2/'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return _InfoPage(
      title: tr('Contact Us'),
      sections: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            tr('We would love to hear from you. Reach out any time — our team '
                'replies as fast as possible.'),
            style: TextStyle(
                height: 1.5, fontSize: 14, color: sch.onSurfaceVariant),
          ),
        ),
        _sec(c, tr('Get in touch'), [
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: sch.outlineVariant)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.phone_outlined, color: sch.primary),
                  title: Text(tr('Phone')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('+855 066778213'),
                      Text('+855 769778213'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr('Call'),
                        icon: const Icon(Icons.call_outlined),
                        onPressed: _callA,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: tr('Call'),
                        icon: const Icon(Icons.phone_outlined),
                        onPressed: _callB,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 58, color: sch.outlineVariant),
                ListTile(
                  leading: Icon(Icons.email_outlined, color: sch.primary),
                  title: Text(tr('Email')),
                  subtitle: const Text('support@globalonline.com'),
                  trailing: IconButton(
                    tooltip: tr('Email'),
                    icon: const Icon(Icons.send_outlined),
                    onPressed: _email,
                  ),
                ),
                Divider(height: 1, indent: 58, color: sch.outlineVariant),
                ListTile(
                  leading: Icon(Icons.location_on_outlined, color: sch.primary),
                  title: Text(tr('Address')),
                  subtitle: const Text('Phnom Penh, Cambodia'),
                  trailing: IconButton(
                    tooltip: tr('Open map'),
                    icon: const Icon(Icons.map_outlined),
                    onPressed: _maps,
                  ),
                ),
                Divider(height: 1, indent: 58, color: sch.outlineVariant),
                ListTile(
                  leading: Icon(Icons.send, color: sch.primary),
                  title: Text(tr('Telegram')),
                  subtitle: const Text('@Lin_Sreymao'),
                  trailing: IconButton(
                    tooltip: tr('Open'),
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _telegram,
                  ),
                ),
                Divider(height: 1, indent: 58, color: sch.outlineVariant),
                ListTile(
                  leading: Icon(Icons.facebook, color: sch.primary),
                  title: Text(tr('Facebook')),
                  subtitle: const Text('Global Online'),
                  trailing: IconButton(
                    tooltip: tr('Open'),
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _facebook,
                  ),
                ),
                Divider(height: 1, indent: 58, color: sch.outlineVariant),
                ListTile(
                  leading: Icon(Icons.schedule, color: sch.primary),
                  title: Text(tr('Working hours')),
                  subtitle: Text(tr('Monday – Sunday, 8:00 AM – 20:00 PM')),
                ),
              ],
            ),
          ),
        ]),
        _sec(c, tr('Faster help'), [
          _p(c, tr(
              'For order status, shipping questions and returns, check the FAQ '
              'or open Chat Support — our assistant answers instantly.')),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _email,
              icon: const Icon(Icons.mail_outline),
              label: Text(tr('Send us an email')),
              style:
                  OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _callA,
              icon: const Icon(Icons.phone_outlined),
              label: Text(tr('Call us now')),
              style:
                  OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                  content: Text(tr('Thanks! We will get back to you soon.')))),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(tr('Leave a message')),
              style:
                  OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Terms & Conditions
// ---------------------------------------------------------------------------
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return _InfoPage(
      title: tr('Terms & Conditions'),
      sections: [
        _sec(c, tr('1. Overview'), [
          _p(c, tr(
              'By using the Global Online application you agree to these terms. '
              'If you do not agree, please do not use the app. We may update '
              'these terms from time to time, and continued use means you '
              'accept the latest version.')),
        ]),
        _sec(c, tr('2. Orders & Payment'), [
          _p(c, tr(
              'All prices are shown in US dollars and include applicable taxes. '
              'An order is confirmed once you complete checkout. We accept cash '
              'on delivery, credit and debit cards, KHQR and mobile banking.')),
          _p(c, tr(
              'We reserve the right to refuse or cancel an order, for example '
              'when a product is out of stock or a price error occurred.')),
        ]),
        _sec(c, tr('3. Shipping & Delivery'), [
          _p(c, tr(
              'Orders are delivered in 2–5 working days. Delivery is free for '
              'orders over the minimum amount. After dispatch you can track '
              'your order from Profile → Order History.')),
        ]),
        _sec(c, tr('4. Returns & Refunds'), [
          _p(c, tr(
              'You may return unused items in their original packaging within '
              '7 days. Refunds are processed within 3–5 working days after we '
              'receive the returned item.')),
        ]),
        _sec(c, tr('5. Account & Using the App'), [
          _p(c, tr(
              'You are responsible for keeping your login details safe and for '
              'all activity on your account. You may not misuse the app, '
              'attempt to break its security, or resell our content.')),
        ]),
        _sec(c, tr('6. Limitation of Liability'), [
          _p(c, tr(
              'Global Online is not liable for damages caused by misuse of '
              'products or by events beyond our control, such as delays caused '
              'by third party couriers or natural disasters.')),
        ]),
        _sec(c, tr('7. Contact'), [
          _p(c, tr(
              'For any question about these terms, contact us via email at '
              'support@globalonline.com or use Chat Support in the app.')),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy Policy
// ---------------------------------------------------------------------------
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return _InfoPage(
      title: tr('Privacy Policy'),
      sections: [
        _sec(c, tr('Information We Collect'), [
          _p(c, tr(
              'We collect the information you give us when you create an '
              'account or place an order: your name, phone number, email and '
              'delivery address. We also store minimal data on this device, '
              'such as your password for local logins, your saved address and '
              'your shopping cart.')),
        ]),
        _sec(c, tr('How We Use Your Information'), [
          _bullet(c, Icons.shopping_bag_outlined,
              tr('To process and deliver your orders.')),
          _bullet(c, Icons.notifications_outlined,
              tr('To send you order updates and, if you allow it, discount alerts.')),
          _bullet(c, Icons.support_agent_outlined,
              tr('To provide customer support and answer your questions.')),
          _bullet(c, Icons.insights_outlined,
              tr('To improve our products and services.')),
        ]),
        _sec(c, tr('Cookies & Local Storage'), [
          _p(c, tr(
              'The app stores only the information needed for it to work. This '
              'data stays on your device and is never sold to third parties.')),
        ]),
        _sec(c, tr('Data Sharing'), [
          _p(c, tr(
              'We share your delivery details only with the courier that '
              'delivers your order, and with payment providers only to '
              'complete a payment you chose. We never sell your personal data.')),
        ]),
        _sec(c, tr('Data Security'), [
          _p(c, tr(
              'We take reasonable steps to protect your personal information. '
              'Local sign-in data is stored within the app on your own device.')),
        ]),
        _sec(c, tr('Your Rights'), [
          _p(c, tr(
              'You can edit your profile, change your password, or delete your '
              'account at any time from the Profile page. Deleting your account '
              'removes your saved data from this device.')),
        ]),
        _sec(c, tr('Contact Us'), [
          _p(c, tr(
              'If you have questions about this privacy policy, email '
              'support@globalonline.com or use Chat Support in the app.')),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// FAQs
// ---------------------------------------------------------------------------
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  Widget _item(BuildContext c, String q, String a) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: sch.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.help_outline, color: sch.primary),
        title: Text(tr(q),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(a),
              style: TextStyle(
                  fontSize: 13.5, height: 1.5, color: sch.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    return Scaffold(
      appBar: AppBar(title: Text(tr('FAQs'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Text(
              tr('Answers to the questions we are asked the most.'),
              style: TextStyle(
                  fontSize: 13.5,
                  color: Theme.of(c).colorScheme.onSurfaceVariant),
            ),
          ),
          _item(c, 'How do I place an order?',
              'Browse products, add them to your cart, then tap Checkout. Enter your (or pick a saved) delivery address, confirm and the order is placed.'),
          _item(c, 'What payment methods do you accept?',
              'We accept cash on delivery, credit/debit cards, KHQR and mobile banking. You choose the method at checkout.'),
          _item(c, 'How long does shipping take?',
              'Shipping takes 2–5 working days depending on your location. You receive SMS and Telegram updates along the way.'),
          _item(c, 'Is delivery free?',
              'Delivery is free for orders over the minimum order value. The exact shipping cost, if any, is shown at checkout.'),
          _item(c, 'How can I track my order?',
              'Open Profile → Order History and tap your order. You can follow the courier link from your order details.'),
          _item(c, 'What is your return and refund policy?',
              'Returns are accepted within 7 days with the item unused and in its original packaging. Refunds are processed within 3–5 working days after we receive the item.'),
          _item(c, 'Can I change or cancel my order?',
              'As soon as your order is placed it goes into processing. Contact support quickly and we will do our best to change or cancel it before dispatch.'),
          _item(c, 'How do I change my password?',
              'Open Profile → Change Password, enter your current and new password, then save. The new password is used the next time you sign in.'),
          _item(c, 'How do I delete my account?',
              'Open Profile → Delete Account. If you have pending orders, they must be settled first. After deletion your saved data is removed from this device.'),
          _item(c, 'How do I contact support?',
              'Use Chat Support in the app, call +855 12 345 678, or email support@globalonline.com.'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change Password
// ---------------------------------------------------------------------------
class ChangePasswordPage extends StatefulWidget {
  final User user;
  const ChangePasswordPage({super.key, required this.user});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showNew = false;
  bool _busy = false;

  String get _username => widget.user.username.trim().toLowerCase();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _msg(String x) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x)));

  bool get _hasLocalAccount => AppSettings.localAuth.containsKey(_username);

  Future<void> _save() async {
    final tr = AppLocalizations.of(context).t;
    // Verify the current password when a local account exists.
    if (_hasLocalAccount) {
      final local = AppSettings.localAuth[_username] ?? {};
      if (local['password'] != _current.text) {
        _msg(tr('Current password is incorrect'));
        return;
      }
    }
    // Validate the new password.
    if (_new.text.length < 6) {
      _msg(tr('Password must be at least 6 characters'));
      return;
    }
    if (_new.text != _confirm.text) {
      _msg(tr('Passwords do not match'));
      return;
    }
    if (_hasLocalAccount && _new.text == _current.text) {
      _msg(tr('New password must be different from the current one'));
      return;
    }
    setState(() => _busy = true);
    if (_hasLocalAccount) {
      await AppSettings.setLocalPassword(_username, _new.text);
    } else {
      await AppSettings.saveLocalAccount(
        username: _username,
        password: _new.text,
        firstName: widget.user.firstName,
        lastName: widget.user.lastName,
        email: widget.user.email,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            size: 40, color: Colors.green),
        title: Text(tr('Password changed successfully')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dc);
              Navigator.pop(context);
            },
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputAction action = TextInputAction.next}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        textInputAction: action,
        onSubmitted: (_) => action == TextInputAction.done ? _save() : null,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Change Password'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_hasLocalAccount)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sch.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: sch.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('No password is set for this account yet. Set a '
                          'password so you can sign in with it later.'),
                      style: TextStyle(
                          fontSize: 13, color: sch.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_hasLocalAccount)
            _field(_current, tr('Current Password'), Icons.lock_outline,
                obscure: !_showNew),
          _field(_new, tr('New Password'), Icons.lock_reset,
              obscure: !_showNew),
          _field(_confirm, tr('Confirm new password'), Icons.lock_outline,
              obscure: !_showNew, action: TextInputAction.done),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showNew = !_showNew),
              icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
              label: Text(tr(_showNew ? 'Hide passwords' : 'Show passwords')),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(tr('Save')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Account
// ---------------------------------------------------------------------------
class DeleteAccountPage extends StatefulWidget {
  final User user;
  /// The username of the signed-in session (unlike [user], it is never
  /// overwritten by profile edits) — used to remove the correct local auth.
  final String loginUsername;
  final String ownerKey;
  final OrderPresenter orders;
  final CartPresenter cart;
  final FavoritePresenter fav;
  final VoidCallback onDeleted;
  const DeleteAccountPage({
    super.key,
    required this.user,
    required this.loginUsername,
    required this.ownerKey,
    required this.orders,
    required this.cart,
    required this.fav,
    required this.onDeleted,
  });

  @override
  State<DeleteAccountPage> createState() => _DeleteAccount();
}

class _DeleteAccount extends State<DeleteAccountPage> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _password = TextEditingController();

  String get _storedPassword =>
      AppSettings.localAuth[widget.loginUsername.trim().toLowerCase()]
          ?['password']?.toString() ?? '';
  bool get _hasPassword => _storedPassword.isNotEmpty;

  @override
  void dispose() {
    _reason.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final tr = AppLocalizations.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined,
            size: 40, color: Colors.red),
        title: Text(tr('Are you sure you want to delete this account?')),
        content: Text(tr(
            'Your profile, saved address, cart, favorites and local password '
            'will be removed from this device. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dc, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    // Store the off-boarding feedback (why the user is leaving).
    await AppSettings.saveFeedback(_reason.text);
    // Clean up all locally stored account data.
    await AppSettings.removeLocalAccount(widget.loginUsername);
    await AppSettings.removeProfile(widget.ownerKey);
    await AppSettings.clearAddress();
    await AppSettings.clearSession();
    widget.cart.clear();
    widget.fav.ids.clear();
    if (!mounted) return;
    // Drop the whole pushed stack first; once the frame is done the initial
    // route rebuils itself as the login screen (logout flips `user` to null).
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.context.mounted) widget.onDeleted();
    });
  }

  @override
  Widget build(BuildContext c) {
    final tr = AppLocalizations.of(c).t;
    final sch = Theme.of(c).colorScheme;
    final pending = widget.orders.hasPending;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Delete Account'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sch.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined,
                      color: sch.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('After deleting your account, you will not be '
                              'able to use it again.'),
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: sch.onErrorContainer),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Are you sure you want to delete your account?'),
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: sch.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _sec(c, tr('Order Cancellation'), [
              const SizedBox(height: 6),
              Text(
                tr('Before deleting your account, make sure you don\'t have '
                    'any order that is in progress.'),
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: sch.onSurfaceVariant),
              ),
            ]),
            if (pending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sch.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: sch.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('You have pending (processing) orders. Please wait '
                            'until they are completed before deleting your '
                            'account.'),
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: sch.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!pending) ...[
              _sec(c, tr('Account Deletion Reason'), [
                const SizedBox(height: 6),
                Text(
                  tr('We are really sorry to hear that you decided to leave '
                      'us. However, your feedback can be useful for us to '
                      'improve our system.'),
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: sch.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: tr('Add your reason here'),
                    hintText: tr('Share your feedback...'),
                    alignLabelWithHint: true,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                if (_hasPassword)
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return tr('Password is required');
                      }
                      if (v != _storedPassword) {
                        return tr('Current password is incorrect');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: tr('Password'),
                      hintText: tr('Enter your password to confirm.'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  )
                else
                  Text(
                    tr('No password is set for this account yet.'),
                    style: TextStyle(
                        fontSize: 12, color: sch.onSurfaceVariant),
                  ),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  if (_form.currentState!.validate()) _confirmDelete();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: sch.error,
                  foregroundColor: sch.onError,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(tr('Delete my account')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(c).maybePop(),
                child: Text(tr('Keep my account')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}