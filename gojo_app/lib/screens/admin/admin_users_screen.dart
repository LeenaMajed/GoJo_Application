import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String    _search     = '';
  UserRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return StreamBuilder<QuerySnapshot>(
      stream: state.unreadMessagesStream,
      builder: (context, unreadSnap) {
        final unreadCount = unreadSnap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: state.allUsersStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kAccent));
            }

            final allUsers = snap.data?.docs
                .map(FirebaseService.userFromDoc)
                .toList() ?? [];

            final users = allUsers.where((u) =>
                (_search.isEmpty ||
                  u.name.toLowerCase().contains(_search.toLowerCase()) ||
                  u.email.toLowerCase().contains(_search.toLowerCase())) &&
                (_filterRole == null || u.role == _filterRole)
            ).toList();

            final tourists   = allUsers.where((u) => u.role == UserRole.tourist).length;
            final businesses = allUsers.where((u) => u.role == UserRole.localBusiness).length;
            final admins     = allUsers.where((u) => u.role == UserRole.admin).length;

            return Scaffold(
              backgroundColor: context.bg,
              floatingActionButton: _MessagesFAB(unreadCount: unreadCount),
              body: SafeArea(child: Column(children: [
                Container(
                  color: context.surface,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Users', style: TextStyle(color: context.primary,
                        fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('${allUsers.length} registered accounts',
                        style: TextStyle(color: context.secondary, fontSize: 12)),
                    const SizedBox(height: 14),

                    Row(children: [
                      _stat(context, '$tourists',   'Tourists',   kAccent),
                      const SizedBox(width: 8),
                      _stat(context, '$businesses', 'Businesses', kDeadSeaBlue),
                      const SizedBox(width: 8),
                      _stat(context, '$admins',     'Admins',     kDanger),
                    ]),
                    const SizedBox(height: 12),

                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(color: context.primary),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email…',
                        prefixIcon: Icon(Icons.search_rounded,
                            color: context.secondary, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _search = ''))
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12))),
                    const SizedBox(height: 10),

                    // Role filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _chip('All',      null),
                        const SizedBox(width: 8),
                        _chip('Tourist',  UserRole.tourist),
                        const SizedBox(width: 8),
                        _chip('Business', UserRole.localBusiness),
                        const SizedBox(width: 8),
                        _chip('Admin',    UserRole.admin),
                      ])),
                  ]),
                ),

                Expanded(
                  child: users.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline_rounded, size: 48,
                              color: context.secondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No users found',
                              style: TextStyle(color: context.secondary, fontSize: 15)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: users.length,
                          itemBuilder: (_, i) => _UserCard(user: users[i]))),
              ])),
            );
          },
        );
      },
    );
  }

  Widget _stat(BuildContext ctx, String val, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(children: [
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ])));

  Widget _chip(String label, UserRole? role) {
    final sel = _filterRole == role;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? kAccent : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? kAccent : context.divider)),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : context.secondary,
          fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400))));
  }
}

class _MessagesFAB extends StatelessWidget {
  final int unreadCount;
  const _MessagesFAB({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AdminMessagesScreen())),
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
          const Text('Messages',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class AdminMessagesScreen extends StatelessWidget {
  const AdminMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        title: const Text('Messages'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.primary, size: 18),
          onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<QuerySnapshot>(
        stream: context.read<AppState>().allMessagesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccent));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_rounded, size: 52, color: context.secondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('No messages yet',
                  style: TextStyle(color: context.secondary, fontSize: 15)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) => _AdminMessageCard(doc: docs[i]));
        },
      ),
    );
  }
}

class _AdminMessageCard extends StatefulWidget {
  final DocumentSnapshot doc;
  const _AdminMessageCard({required this.doc});
  @override
  State<_AdminMessageCard> createState() => _AdminMessageCardState();
}

class _AdminMessageCardState extends State<_AdminMessageCard> {
  bool _replyOpen = false;
  final _replyCtrl = TextEditingController();
  bool _sending    = false;

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d          = widget.doc.data() as Map<String, dynamic>;
    final senderName = d['senderName']  ?? 'Unknown';
    final senderRole = d['senderRole']  ?? 'tourist';
    final topic      = d['topic']       ?? '';
    final body       = d['body']        ?? '';
    final reply      = d['reply']       as String?;
    final adminRead  = d['adminRead']   ?? false;
    final hasReply   = reply != null && reply.isNotEmpty;

    if (!adminRead) {
      context.read<AppState>().markMessageAdminRead(widget.doc.id);
    }

    final roleColor = senderRole == 'localBusiness' ? kDeadSeaBlue : kAccent;
    final roleLabel = senderRole == 'localBusiness' ? 'Business' : 'Tourist';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: !adminRead ? kWarning.withOpacity(0.5) : context.divider,
            width: !adminRead ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: TextStyle(color: roleColor, fontSize: 16, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(senderName, style: TextStyle(
                  color: context.primary, fontSize: 14, fontWeight: FontWeight.w700)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(roleLabel, style: TextStyle(
                      color: roleColor, fontSize: 10, fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: context.surface, borderRadius: BorderRadius.circular(6)),
                  child: Text(topic,
                      style: TextStyle(color: context.secondary, fontSize: 10))),
              ]),
            ])),
            if (!adminRead)
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: kWarning, shape: BoxShape.circle)),
          ])),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.divider)),
            child: Text(body,
                style: TextStyle(color: context.primary, fontSize: 13, height: 1.5)))),

        if (hasReply) ...[
          Divider(height: 1, color: context.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.reply_rounded, size: 14, color: kAccent),
                const SizedBox(width: 5),
                Text('Your reply', style: TextStyle(
                    color: kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kAccent.withOpacity(0.2))),
                child: Text(reply, style: TextStyle(color: context.primary, fontSize: 13))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _replyOpen = !_replyOpen;
                  _replyCtrl.text = reply;
                }),
                child: Text('Edit reply', style: TextStyle(
                    color: kAccent, fontSize: 12, fontWeight: FontWeight.w600))),
            ])),
        ],

        if (!hasReply || _replyOpen) ...[
          if (!hasReply) Divider(height: 1, color: context.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(children: [
              TextField(
                controller: _replyCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: context.primary, fontSize: 13),
                decoration: InputDecoration(
                    hintText: 'Write a reply…',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 10),
              Row(children: [
                if (_replyOpen) ...[
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() {
                      _replyOpen = false; _replyCtrl.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.secondary,
                      side: BorderSide(color: context.divider),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                ],
                Expanded(child: ElevatedButton.icon(
                  icon: _sending
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Send Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent, foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  onPressed: (_sending || _replyCtrl.text.trim().isEmpty)
                      ? null
                      : () async {
                          setState(() => _sending = true);
                          await context.read<AppState>().replyToMessage(
                              widget.doc.id, _replyCtrl.text.trim());
                          setState(() { _sending = false; _replyOpen = false; });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Reply sent'),
                              backgroundColor: kAccentDim,
                              behavior: SnackBarBehavior.floating));
                          }
                        })),
              ]),
            ])),
        ],
      ]),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    final roleLabel = _roleLabel(user.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
                color: roleColor, fontSize: 18, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.secondary, fontSize: 12)),
          if (user.interests.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(user.interests.take(3).join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.secondary.withOpacity(0.6), fontSize: 10)),
          ],
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(roleLabel, style: TextStyle(
                color: roleColor, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(height: 6),
          PopupMenuButton<String>(
            onSelected: (val) { if (val == 'remove') _showRemoveDialog(context); },
            color: context.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'remove', child: Row(children: [
                Icon(Icons.delete_outline_rounded, color: kDanger, size: 18),
                SizedBox(width: 8),
                Text('Remove User', style: TextStyle(color: kDanger)),
              ])),
            ],
            child: Icon(Icons.more_vert_rounded, size: 18, color: context.secondary)),
        ]),
      ]),
    );
  }

  void _showRemoveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: context.card, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(
                  Icons.delete_outline_rounded, color: kDanger, size: 36)),
            const SizedBox(height: 18),
            Text('Remove User?', style: TextStyle(
                color: context.primary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Are you sure you want to remove ${user.name}?\nThis cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(
                    color: context.secondary, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDanger, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await context.read<AppState>().removeUser(user.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${user.name} removed'),
                        backgroundColor: kDanger,
                        behavior: SnackBarBehavior.floating));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: kDanger,
                        behavior: SnackBarBehavior.floating));
                    }
                  }
                },
                child: const Text('Remove',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:         return kDanger;
      case UserRole.localBusiness: return kDeadSeaBlue;
      default:                     return kAccent;
    }
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.admin:         return 'Admin';
      case UserRole.localBusiness: return 'Business';
      default:                     return 'Tourist';
    }
  }
}