import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/app_state.dart';

class HelpSupportScreen extends StatefulWidget {
  final bool isAdmin;
  final bool isBusiness;
  const HelpSupportScreen({super.key, this.isAdmin = false, this.isBusiness = false});
  @override
  State<HelpSupportScreen> createState() => _HelpState();
}

class _HelpState extends State<HelpSupportScreen> {
  final _msgCtrl  = TextEditingController();
  String? _topic;
  bool _sending   = false;
  bool _sent      = false;
  String? _sendError;

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty || _topic == null) return;
    setState(() { _sending = true; _sendError = null; });
    try {
      await context.read<AppState>().sendMessage(
        topic: _topic!,
        body:  _msgCtrl.text.trim(),
      );
      setState(() { _sent = true; _sending = false; });
    } catch (e) {
      setState(() { _sendError = 'Failed to send: $e'; _sending = false; });
    }
  }

  List<_Faq> get _faqs {
    if (widget.isAdmin) return [
      _Faq('How do I approve a listing?',
           'Open Proposals → Pending tab. Tap any card to see full details, then tap Approve. '
           'The listing goes live for tourists immediately and the business gets a notification.'),
      _Faq('What should I write in a dismiss note?',
           'Be specific and constructive. Explain what is missing or incorrect so the business '
           'can fix it and resubmit. The note is shown directly to the business owner.'),
      _Faq('How do edit requests work?',
           'When a business edits a live listing you see the request in the Edit Requests tab. '
           'Each changed field shows old versus new. Approve to apply changes or reject to keep '
           'the original.'),
      _Faq('Can I undo an approval?',
           'Yes. Go to the Approved tab, open the listing, and tap Dismiss. '
           'The listing is hidden from tourists and the business is notified.'),
    ];
    if (widget.isBusiness) return [
      _Faq('How long does approval take?',
           'Our team reviews new listings within 24–48 hours. You will see a notification '
           'in My Listings when a decision is made.'),
      _Faq('Why was my listing dismissed?',
           'Check your My Listings screen under "Not Approved" to read the admin\'s feedback. '
           'Fix the issues described and you can resubmit.'),
      _Faq('Can I edit a live listing?',
           'Yes. Tap Edit on any live listing. Your changes go to admin for review. '
           'The current version stays live until the edit is approved.'),
      _Faq('How do I add a photo?',
           'Tap Edit on your listing, then tap the photo area to pick from your camera or gallery.'),
      _Faq('What makes a listing get approved?',
           'Complete all fields, add a clear real photo, write an accurate description, '
           'and set the correct GPS pin. Incomplete or misleading submissions are dismissed.'),
    ];
    return [
      _Faq('How do I save a place?',
           'Tap the bookmark icon on any place card or detail screen. '
           'Find all saved items in the Saved tab.'),
      _Faq('How does the itinerary generator work?',
           'Go to the Home screen, pick trip length and interests, then tap Generate. '
           'GoJo builds a day-by-day plan from approved places that match your interests.'),
      _Faq('Can I use the map offline?',
           'Yes. Open the Map, tap the download icon, and save a Jordan region. '
           'Saved regions work without internet.'),
      _Faq('How do I get driving directions?',
           'Open the Map, tap any marker, then tap the Go button on the popup card. '
           'A free route appears from your current location to the destination.'),
      _Faq('Are prices up to date?',
           'Prices are set by local businesses and updated when they submit edits. '
           'Always confirm directly with the business before booking.'),
      _Faq('How do I update my interests?',
           'Go to Profile, tap Edit Profile, then toggle your interest tags. '
           'These affect recommendations throughout the app.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role  = widget.isAdmin ? 'Admin' : widget.isBusiness ? 'Business' : 'Tourist';

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: !widget.isAdmin ? _MessagesFAB(state: state) : null,
      appBar: AppBar(
        backgroundColor: context.surface,
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.primary, size: 18),
          onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                kAccent.withOpacity(0.12), kDeadSeaBlue.withOpacity(0.06)]),
              borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, color: kAccent, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GoJo Support  ·  $role',
                  style: TextStyle(color: context.secondary, fontSize: 11)),
                Text('How can we help?', style: TextStyle(
                  color: context.primary, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(widget.isAdmin
                    ? 'Priority response for admin team'
                    : widget.isBusiness
                        ? 'Business partner support line'
                        : 'We\'re here to make your Jordan trip perfect',
                  style: TextStyle(color: context.secondary, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          Text('Frequently Asked Questions', style: TextStyle(
            color: context.primary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final faq in _faqs) _FaqTile(faq: faq),
          const SizedBox(height: 24),

          Text('Send us a message', style: TextStyle(
            color: context.primary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          if (_sent) ...[
            _successCard(),
            const SizedBox(height: 10),
            Center(child: TextButton(
              onPressed: () => setState(() { _sent = false; _msgCtrl.clear(); _topic = null; }),
              child: const Text('Send another message'))),
          ] else ...[
            _buildForm(),
          ],
          const SizedBox(height: 24),
          Text('Other ways to reach us', style: TextStyle(
            color: context.primary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _channel(context, Icons.email_outlined,              'Email',    'support@gojo.jo'),
          _channel(context, Icons.chat_bubble_outline_rounded, 'WhatsApp', '+962 7 9999 0000'),
          const SizedBox(height: 8),
          Text('Hours: Sun – Thu, 8 AM – 6 PM (Jordan time)',
            style: TextStyle(color: context.secondary, fontSize: 12)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildForm() => Column(children: [
    DropdownButtonFormField<String>(
      value: _topic,
      hint: Text('Select a topic',
          style: TextStyle(color: context.secondary, fontSize: 14)),
      dropdownColor: context.card,
      style: TextStyle(color: context.primary, fontSize: 14),
      decoration: InputDecoration(
          prefixIcon: Icon(Icons.topic_outlined, color: context.secondary, size: 20)),
      items: ['App not working', 'Account issue', 'Map problem',
              'Report content', 'Billing question', 'Other']
          .map((t) => DropdownMenuItem(value: t,
              child: Text(t, style: TextStyle(color: context.primary, fontSize: 14))))
          .toList(),
      onChanged: (v) => setState(() => _topic = v)),
    const SizedBox(height: 12),
    TextField(
      controller: _msgCtrl,
      maxLines: 5,
      style: TextStyle(color: context.primary, fontSize: 14),
      decoration: const InputDecoration(hintText: 'Describe your issue or question…')),
    if (_sendError != null) ...[
      const SizedBox(height: 8),
      Text(_sendError!, style: const TextStyle(color: kDanger, fontSize: 12)),
    ],
    const SizedBox(height: 14),
    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      icon: _sending
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 16),
      label: Text(_sending ? 'Sending…' : 'Send message'),
      onPressed: (_sending || _topic == null || _msgCtrl.text.trim().isEmpty)
          ? null : _send)),
  ]);

  Widget _successCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E).withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Message sent!', style: TextStyle(
            color: context.primary, fontWeight: FontWeight.w700)),
        Text('We\'ll reply within 24 hours.',
            style: TextStyle(color: context.secondary, fontSize: 12)),
      ])),
    ]));

  Widget _channel(BuildContext ctx, IconData icon, String label, String value) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: kAccent),
        const SizedBox(width: 10),
        SizedBox(width: 72, child: Text(label, style: TextStyle(
            color: ctx.secondary, fontSize: 13, fontWeight: FontWeight.w600))),
        Text(value, style: TextStyle(color: ctx.primary, fontSize: 13)),
      ]));
}

class _MessageCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _MessageCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d        = doc.data() as Map<String, dynamic>;
    final topic    = d['topic']      ?? '';
    final body     = d['body']       ?? '';
    final reply    = d['reply']      as String?;
    final userRead = d['userRead']   ?? true;
    final hasReply = reply != null && reply.isNotEmpty;

    // Mark as read when user sees it
    if (hasReply && !userRead) {
      context.read<AppState>().markMessageUserRead(doc.id);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (!userRead && hasReply) ? kAccent : context.divider,
            width: (!userRead && hasReply) ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(topic,
                    style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700))),
              if (!userRead && hasReply) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Text('New reply',
                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 8),
            
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('You', style: TextStyle(
                      color: kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(body, style: TextStyle(color: context.primary, fontSize: 13)),
                ]))),
          ])),

       
        if (hasReply) ...[
          Divider(height: 1, color: context.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14)),
                  border: Border.all(color: context.divider)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent_rounded, color: kAccent, size: 11)),
                    const SizedBox(width: 5),
                    Text('GoJo Support', style: TextStyle(
                        color: kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  Text(reply, style: TextStyle(color: context.primary, fontSize: 13)),
                ]))))],

        if (!hasReply)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: context.secondary),
              const SizedBox(width: 5),
              Text('Awaiting reply…',
                  style: TextStyle(color: context.secondary, fontSize: 12, fontStyle: FontStyle.italic)),
            ])),
      ]),
    );
  }
}

class _Faq { final String q, a; const _Faq(this.q, this.a); }

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});
  @override State<_FaqTile> createState() => _FaqTileState();
}
class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: context.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.divider)),
    child: Column(children: [
      ListTile(
        onTap: () => setState(() => _open = !_open),
        title: Text(widget.faq.q, style: TextStyle(
            color: context.primary, fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: Icon(
            _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: context.secondary)),
      if (_open) Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(widget.faq.a, style: TextStyle(
            color: context.secondary, fontSize: 13, height: 1.55))),
    ]));
}
class _MessagesFAB extends StatelessWidget {
  final AppState state;
  const _MessagesFAB({required this.state});

  @override
  Widget build(BuildContext context) {
    final stream = state.userMessagesStream();
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final docs       = snap.data?.docs ?? [];
        final unreadCount = docs.where((doc) {
          final d        = doc.data() as Map<String, dynamic>;
          final reply    = d['reply']    as String?;
          final userRead = d['userRead'] ?? true;
          return (reply != null && reply.isNotEmpty) && !userRead;
        }).length;

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => _UserMessagesScreen(state: state))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: kAccent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.inbox_rounded, color: Colors.white, size: 20),
                if (unreadCount > 0)
                  Positioned(
                    top: -5, right: -5,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
                      child: Center(child: Text('$unreadCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))))),
              ]),
              const SizedBox(width: 8),
              const Text('My Messages',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }
}
class _UserMessagesScreen extends StatelessWidget {
  final AppState state;
  const _UserMessagesScreen({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        title: const Text('My Messages'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.primary, size: 18),
          onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<QuerySnapshot>(
        stream: state.userMessagesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccent));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_rounded, size: 52,
                  color: context.secondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('No messages yet',
                  style: TextStyle(color: context.secondary, fontSize: 15)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            // reuse the existing _MessageCard widget
            itemBuilder: (_, i) => _MessageCard(doc: docs[i]));
        },
      ),
    );
  }
}