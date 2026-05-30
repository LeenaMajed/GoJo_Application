import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../sign_in_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final void Function(int, {String deepLink}) onNavigate;
  const AdminDashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // Three parallel streams — each resolves independently.
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<AppState>().allPlacesStream,
      builder: (context, placesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().allServicesStream,
          builder: (context, svcsSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: context.read<AppState>().allUsersStream,
              builder: (context, usersSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: context.read<AppState>().pendingRegistrationsStream,
                  builder: (context, regsSnap) {

                    final places   = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
                    final svcs     = svcsSnap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];
                    final users    = usersSnap.data?.docs ?? [];

                    final pendingPlaces = places.where((p) => p.listingStatus == ListingStatus.pending).length;
                    final pendingSvcs   = svcs.where((s)   => s.listingStatus == ListingStatus.pending).length;
                    final pendingEdits  = places.where((p) => p.pendingEdit != null && p.pendingEdit!.status == EditStatus.pending).length
                                       + svcs.where((s)   => s.pendingEdit != null && s.pendingEdit!.status == EditStatus.pending).length;
                    final approvedPlaces = places.where((p) => p.listingStatus == ListingStatus.approved && p.ownerId != null).length;
                    final approvedSvcs   = svcs.where((s)   => s.listingStatus == ListingStatus.approved ).length;
                    //final approvedSvcs   = svcs.where((s)   => s.listingStatus == ListingStatus.approved && s.ownerId != null).length;
                    final totalPending   = pendingPlaces + pendingSvcs + pendingEdits;
                    final totalUsers     = users.length;

                    final recentPending = [
                      ...places.where((p) => p.listingStatus == ListingStatus.pending),
                      ...svcs.where((s)   => s.listingStatus == ListingStatus.pending),
                    ].take(5).toList();

                    return Scaffold(
                      backgroundColor: context.bg,
                      body: SafeArea(child: CustomScrollView(slivers: [

                        SliverToBoxAdapter(child: Container(
                          color: context.surface,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('GoJo Admin', style: TextStyle(color: context.secondary, fontSize: 13)),
                              Text('Dashboard', style: TextStyle(color: context.primary,
                                  fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            ])),
                            GestureDetector(
                              onTap: () => context.read<AppState>().toggleTheme(),
                              child: _iconBtn(context, context.isDark
                                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                            ),
                            const SizedBox(width: 8),
                           // _adminBadge(),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                context.read<AppState>().signOut();
                                await Future.delayed(const Duration(milliseconds: 50));
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
                                }
                              },
                              child: _iconBtn(context, Icons.logout_rounded),
                            ),
                          ]),
                        )),

                        if (totalPending > 0)
                          SliverToBoxAdapter(child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kWarning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: kWarning.withOpacity(0.3))),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: kWarning.withOpacity(0.15), shape: BoxShape.circle),
                                  child: const Icon(Icons.notifications_active_outlined, color: kWarning, size: 18)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$totalPending item${totalPending > 1 ? "s" : ""} need your review',
                                    style: const TextStyle(color: kWarning, fontSize: 14, fontWeight: FontWeight.w700)),
                                Text(
                                  [if (pendingPlaces + pendingSvcs > 0)
                                      '${pendingPlaces + pendingSvcs} new listing${pendingPlaces + pendingSvcs > 1 ? "s" : ""}',
                                   if (pendingEdits > 0)
                                      '$pendingEdits edit request${pendingEdits > 1 ? "s" : ""}',
                                  ].join(' · '),
                                  style: TextStyle(color: context.secondary, fontSize: 12),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              ])),
                              GestureDetector(
                                onTap: () => onNavigate(1, deepLink: 'pending'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: kWarning, borderRadius: BorderRadius.circular(20)),
                                  child: const Text('Review', style: TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
                            ]),
                          )),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Overview', style: TextStyle(color: context.primary,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _statCard(context, 'Pending\nProposals',
                                  pendingPlaces + pendingSvcs, Icons.pending_actions_outlined, kWarning,
                                  (pendingPlaces + pendingSvcs) > 0)),
                              const SizedBox(width: 10),
                              Expanded(child: _statCard(context, 'Edit\nRequests',
                                  pendingEdits, Icons.edit_note_outlined, kDeadSeaBlue, pendingEdits > 0)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _statCard(context, 'Live\nListings',
                                  approvedPlaces + approvedSvcs, Icons.check_circle_outline_rounded,
                                  const Color(0xFF22C55E), false)),
                              const SizedBox(width: 10),
                              Expanded(child: _statCard(context, 'Total\nUsers',
                                  totalUsers, Icons.people_outline_rounded, kAccent, false)),
                            ]),
                          ])),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Quick Actions', style: TextStyle(color: context.primary,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _actionCard(context,
                                  Icons.layers_outlined, 'Review\nListings',
                                  pendingPlaces + pendingSvcs, kWarning,
                                  () => onNavigate(1, deepLink: 'pending'))),
                              const SizedBox(width: 10),
                              Expanded(child: _actionCard(context,
                                  Icons.edit_document, 'Edit\nRequests',
                                  pendingEdits, kDeadSeaBlue,
                                  () => onNavigate(1, deepLink: 'edits'))),
                              const SizedBox(width: 10),
                              Expanded(child: _actionCard(context,
                                  Icons.people_outlined, 'Manage\nUsers',
                                  0, kAccent, () => onNavigate(2, deepLink: ''))),
                            ]),
                          ])),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          sliver: SliverToBoxAdapter(child: Row(children: [
                            Text('Recent Proposals', style: TextStyle(color: context.primary,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            TextButton(onPressed: () => onNavigate(1, deepLink: 'pending'),
                                child: const Text('View all', style: TextStyle(color: kAccent, fontSize: 12))),
                          ])),
                        ),

                        if (recentPending.isEmpty)
                          SliverToBoxAdapter(child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: context.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: context.divider)),
                              child: Column(children: [
                                Icon(Icons.check_circle_outline_rounded, size: 36,
                                    color: const Color(0xFF22C55E).withOpacity(0.6)),
                                const SizedBox(height: 8),
                                Text('All caught up!', style: TextStyle(color: context.primary,
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('No pending proposals at the moment',
                                    style: TextStyle(color: context.secondary, fontSize: 12)),
                              ]),
                            ),
                          ))
                        else
                          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
                            if (i >= recentPending.length) return null;
                            final item = recentPending[i];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: item is Place
                                  ? _PlaceTile(place: item)
                                  : _ServiceTile(svc: item as TripService),
                            );
                          }, childCount: recentPending.length)),

                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ])),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: context.card,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: context.divider)),
    child: Icon(icon, size: 18, color: context.secondary));

  Widget _statCard(BuildContext context, String label, int val, IconData icon,
      Color color, bool alert) =>
      GestureDetector(
        onTap: alert ? () => onNavigate(1) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: alert ? color.withOpacity(0.25) : context.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, color: color, size: 16)),
              const Spacer(),
              if (alert) Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 10),
            Text('$val', style: TextStyle(
                color: color, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
                color: context.secondary, fontSize: 11, height: 1.3)),
          ]),
        ),
      );

  Widget _actionCard(BuildContext context, IconData icon, String label,
      int badge, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: badge > 0 ? color.withOpacity(0.25) : context.divider)),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20)),
              if (badge > 0) Positioned(right: -4, top: -4, child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
                  child: Text('$badge', style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
            ]),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(
                color: context.primary, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3)),
          ]),
        ),
      );
}

class _PlaceTile extends StatelessWidget {
  final Place place;
  const _PlaceTile({required this.place});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWarning.withOpacity(0.2))),
    child: Row(children: [
     Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: kDeadSeaBlue.withOpacity(0.10),
    borderRadius: BorderRadius.circular(10),
  ),
  child: const Icon(
    Icons.business_center_outlined,
    color: kDeadSeaBlue,
    size: 22,
  ),
),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        Text('${_catLabel(place.category)}  ·  ${place.location}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.secondary, fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: const Text('Pending', style: TextStyle(
            color: kWarning, fontSize: 10, fontWeight: FontWeight.w700))),
    ]),
  );

  String _catLabel(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.attraction: return 'Attraction';
      case PlaceCategory.hotel:      return 'Hotel';
      case PlaceCategory.restaurant: return 'Restaurant';
      case PlaceCategory.event:      return 'Event';
    }
  }
}

class _ServiceTile extends StatelessWidget {
  final TripService svc;
  const _ServiceTile({required this.svc});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWarning.withOpacity(0.2))),
    child: Row(children: [
      Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: kDeadSeaBlue.withOpacity(0.10),
    borderRadius: BorderRadius.circular(10),
  ),
  child: const Icon(
    Icons.business_center_outlined,
    color: kDeadSeaBlue,
    size: 22,
  ),
),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(svc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        Text('${svc.customCategory.isNotEmpty ? svc.customCategory : svc.category.name}  ·  ${svc.ownerName}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.secondary, fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: const Text('Pending', style: TextStyle(
            color: kWarning, fontSize: 10, fontWeight: FontWeight.w700))),
    ]),
  );
}