
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import 'services_screen.dart';
import 'place_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(child: Column(children: [

       
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Text('Saved', style: TextStyle(color: context.primary,
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const Spacer(),
          ]),
        ),

       
        Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.divider)),
          child: TabBar(
            controller: _tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: context.secondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(text: 'Places'),
              Tab(text: 'Services'),
              Tab(text: 'AI Plans'),
            ],
          ),
        ),

        
        Expanded(child: TabBarView(controller: _tab, children: [

        
          StreamBuilder<QuerySnapshot>(
            stream: context.read<AppState>().approvedPlacesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kAccent));
              }
              final all         = snap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
              final savedPlaces = all.where((p) => state.isSaved(p.id)).toList();

              if (savedPlaces.isEmpty) return _empty(context, 'No saved places yet',
                  'Bookmark any hotel, restaurant, or attraction');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: savedPlaces.length,
                itemBuilder: (_, i) => _SavedPlaceTile(
                    place: savedPlaces[i],
                    onUnsave: () => state.toggleSave(savedPlaces[i].id)));
            },
          ),

         
          StreamBuilder<QuerySnapshot>(
            stream: context.read<AppState>().approvedServicesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kAccent));
              }
              final all           = snap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];
              final savedServices = all.where((s) => state.isServiceSaved(s.id)).toList();

              if (savedServices.isEmpty) return _empty(context, 'No saved services',
                  'Bookmark local services to access them quickly');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: savedServices.length,
                itemBuilder: (_, i) => _SavedServiceTile(
                    svc: savedServices[i],
                    onUnsave: () => state.toggleServiceSave(savedServices[i].id)));
            },
          ),

          const _SavedItinerariesTab(),

        ])),
      ])),
    );
  }

  Widget _empty(BuildContext ctx, String title, String sub) =>
      Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_border_rounded, size: 52,
              color: ctx.secondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: ctx.primary,
              fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: ctx.secondary,
              fontSize: 13, height: 1.4), textAlign: TextAlign.center),
        ]),
      ));
}


class _SavedItinerariesTab extends StatelessWidget {
  const _SavedItinerariesTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 52,
              color: context.secondary.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('Sign in to view saved plans',
              style: TextStyle(color: context.secondary),
              textAlign: TextAlign.center),
        ]),
      ));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService().itineraryStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_outlined, size: 52,
                  color: context.secondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('No saved AI plans yet',
                  style: TextStyle(color: context.primary,
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Generate a trip plan and tap Save.',
                  style: TextStyle(color: context.secondary, fontSize: 13)),
            ]),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ItineraryCard(docId: doc.id, uid: uid, data: data);
          },
        );
      },
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final String docId, uid;
  final Map<String, dynamic> data;
  const _ItineraryCard({required this.docId, required this.uid, required this.data});

  @override
  Widget build(BuildContext context) {
    final title    = data['title']    ?? 'Itinerary';
    final category = data['category'] ?? '';
    final budget   = data['budget']   ?? '';
    final days     = data['days']     ?? 1;
    final stops    = List<Map<String, dynamic>>.from(data['stops'] ?? []);

    final dayGroups = <String, List<Map<String, dynamic>>>{};
    for (final s in stops) {
      final d = s['day'] as String? ?? 'Day 1';
      dayGroups.putIfAbsent(d, () => []).add(s);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            gradient: LinearGradient(colors: [
              kAccent.withOpacity(0.1), kAccent.withOpacity(0.03)])),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: context.primary,
                  fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Wrap(spacing: 6, children: [
                _badge(category, kAccent),
                _badge('$days day${days > 1 ? "s" : ""}', kAccentDim),
                _badge(budget, kWarning),
              ]),
            ])),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: kDanger.withOpacity(0.7), size: 20),
              onPressed: () => _confirmDelete(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: dayGroups.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: TextStyle(color: context.primary,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...entry.value.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    Container(width: 5, height: 5,
                        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s['name'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.secondary, fontSize: 12))),
                    if (s['durationMinutes'] != null)
                      Text('${((s['durationMinutes'] as num) / 60).toStringAsFixed(1)}h',
                          style: TextStyle(color: context.secondary.withOpacity(0.6), fontSize: 11)),
                  ]),
                )),
                if (entry.value.length > 3)
                  Padding(padding: const EdgeInsets.only(left: 13, bottom: 4),
                    child: Text('+${entry.value.length - 3} more',
                        style: const TextStyle(color: kAccent,
                            fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(height: 6),
              ],
            )).toList()),
        ),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w700)));

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.surface,
      title: Text('Delete plan?', style: TextStyle(
          color: context.primary, fontWeight: FontWeight.w700)),
      content: Text('This cannot be undone.',
          style: TextStyle(color: context.secondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.secondary))),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            FirebaseService().deleteItinerary(uid, docId);
          },
          child: const Text('Delete', style: TextStyle(color: kDanger))),
      ],
    ));
  }
}

class _SavedPlaceTile extends StatelessWidget {
  final Place place;
  final VoidCallback onUnsave;
  const _SavedPlaceTile({required this.place, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(width: 80, height: 76,
                child: placePhoto(place, context))),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_catLabel(place.category),
                    style: const TextStyle(color: kAccent,
                        fontSize: 9, fontWeight: FontWeight.w700))),
              Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary,
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.place_outlined, size: 11, color: context.secondary),
                const SizedBox(width: 2),
                Expanded(child: Text(place.location, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 12))),
              ]),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.bookmark_rounded, color: kAccent, size: 22),
              onPressed: onUnsave)),
        ]),
      ),
    );
  }

  String _catLabel(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.attraction: return 'ATTRACTION';
      case PlaceCategory.hotel:      return 'HOTEL';
      case PlaceCategory.restaurant: return 'RESTAURANT';
      case PlaceCategory.event:      return 'EVENT';
    }
  }
}

class _SavedServiceTile extends StatelessWidget {
  final TripService svc;
  final VoidCallback onUnsave;
  const _SavedServiceTile({required this.svc, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      
      onTap: () => showServiceDetail(
        context,
        svc,
        context.read<AppState>(),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(width: 80, height: 76,
                child: servicePhoto(svc, context))),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(svc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary,
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text('${svc.ownerName}  ·  ${svc.location}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.secondary, fontSize: 12)),
              if (svc.priceFrom != null) ...[
                const SizedBox(height: 4),
                Text('From JD${svc.priceFrom!.toInt()} ${svc.priceUnit ?? ""}',
                    style: const TextStyle(color: kAccent,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          )),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.bookmark_rounded, color: kAccent, size: 22),
              onPressed: onUnsave)),
        ]),
      ),
    );
  }
}