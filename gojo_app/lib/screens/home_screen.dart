import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import 'hotels_screen.dart';
import 'restaurants_screen.dart';
//import 'itinerary_screen.dart';
import 'ai_itinerary_screen.dart';
import 'map_screen.dart';
//import 'place_detail_screen.dart';
import 'services_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state     = context.watch<AppState>();
    final firstName = (state.user?.name ?? 'Traveller').split(' ').first;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().approvedPlacesStream,
          builder: (context, placesSnap) {
            final approved    = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
            final attractions = approved.where((p) => p.category == PlaceCategory.attraction).toList();
            final events      = approved.where((p) => p.category == PlaceCategory.event).toList();
            final restaurants = approved.where((p) => p.category == PlaceCategory.restaurant).toList();

            return StreamBuilder<QuerySnapshot>(
              stream: context.read<AppState>().approvedServicesStream,
              builder: (context, svcSnap) {
                return CustomScrollView(slivers: [
                  //Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Good day, $firstName',
                              style: TextStyle(color: context.secondary, fontSize: 13, fontWeight: FontWeight.w400)),
                          const SizedBox(height: 2),
                          Text('Explore Jordan',
                              style: TextStyle(color: context.primary, fontSize: 24, fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                        ])),
                        const ThemeToggleButton(),
                      ]),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AiItineraryScreen())),
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: const DecorationImage(
                              image: NetworkImage('https://images.unsplash.com/photo-1579606032821-4e6161c81bd3?q=80&w=1200&auto=format&fit=crop'),
                              fit: BoxFit.cover),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                                begin: Alignment.bottomLeft, end: Alignment.topRight)),
                            padding: const EdgeInsets.all(20),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end, children: [
                              const Text('Plan your perfect Jordan trip',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                    color: kAccent, borderRadius: BorderRadius.circular(20)),
                                child: const Text('Generate Itinerary',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(children: [
                        _action(context, Icons.hotel_outlined, 'Hotels',
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HotelsScreen()))),
                        const SizedBox(width: 10),
                        _action(context, Icons.restaurant_outlined, 'Dine',
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantsScreen()))),
                        const SizedBox(width: 10),
                        _action(context, Icons.map_outlined, 'Map',
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
                        const SizedBox(width: 10),
                        _action(context, Icons.build_outlined, 'Services',
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen()))),
                        const SizedBox(width: 10),
                        _action(context, Icons.event_outlined, 'Events',
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => _ListScreen(title: 'Events', places: events)))),
                      ]),
                    ),
                  ),

                  
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: SectionHeader(title: 'Top Attractions', actionLabel: 'See all',
                        onAction: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _ListScreen(title: 'Top Attractions', places: attractions)))),
                  )),
                  SliverToBoxAdapter(child: SizedBox(height: 230, child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: attractions.length,
                    itemBuilder: (_, i) => PlaceCard(place: attractions[i]),
                  ))),

                  
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: SectionHeader(title: 'Upcoming Events', actionLabel: 'See all',
                        onAction: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _ListScreen(title: 'Events', places: events)))),
                  )),
                  SliverToBoxAdapter(child: SizedBox(height: 230, child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: events.length,
                    itemBuilder: (_, i) => EventCard(place: events[i]),
                  ))),

                  
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: SectionHeader(title: 'Popular Restaurants', actionLabel: 'See all',
                        onAction: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RestaurantsScreen()))),
                  )),
                  SliverToBoxAdapter(child: SizedBox(height: 230, child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: restaurants.length,
                    itemBuilder: (_, i) => PlaceCard(place: restaurants[i]),
                  ))),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _action(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      Expanded(child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ctx.card, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(children: [
            Icon(icon, size: 22, color: kAccent),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: ctx.secondary, fontSize: 10,
                fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ));
}


class _ListScreen extends StatefulWidget {
  final String title;
  final List<Place> places;
  const _ListScreen({required this.title, required this.places});

  @override
  State<_ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<_ListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _chip = 'All';


  List<String> get _chipOptions {
    final freq = <String, int>{};
    for (final p in widget.places) {
      for (final t in p.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Place> get _filtered {
    final q = _search.toLowerCase();
    return widget.places.where((p) {
      final matchSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      final matchChip = _chip == 'All' ||
          p.tags.any((t) => t.toLowerCase() == _chip.toLowerCase());
      return matchSearch && matchChip;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final chips = _chipOptions;
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: context.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (Navigator.canPop(context))
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.primary))),
              Expanded(child: Text(widget.title,
                  style: TextStyle(color: context.primary, fontSize: 20, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${filtered.length} found',
                    style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: context.primary),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}…',
                prefixIcon: Icon(Icons.search_rounded, color: context.secondary, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: context.secondary, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip2('All'),
                  ...chips.map(_chip2),
                ]),
              ),
            ],
          ]),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 52,
                      color: context.secondary.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No results found',
                      style: TextStyle(color: context.secondary, fontSize: 15)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => PlaceListTile(place: filtered[i]),
                ),
        ),
      ])),
    );
  }

  Widget _chip2(String label) {
    final sel = _chip == label;
    return GestureDetector(
      onTap: () => setState(() => _chip = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? kAccent : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? kAccent : context.divider)),
        child: Text(label, style: TextStyle(
            color: sel ? Colors.white : context.secondary,
            fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}
/*
// ── Service card (home horizontal scroll) ────────────────────────────────────
class _SvcCard extends StatelessWidget {
  final TripService svc;
  final AppState state;
  const _SvcCard({required this.svc, required this.state});

  @override
  Widget build(BuildContext context) {
    final saved = state.isServiceSaved(svc.id);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ServicesScreen(
              highlightTags: state.user?.interests ?? [], initialService: svc))),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(children: [
              SizedBox(height: 100, width: double.infinity,
                  child: servicePhoto(svc, context)),
              Positioned(top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => state.toggleServiceSave(svc.id),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: Colors.white, size: 13)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(svc.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text(svc.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.secondary, fontSize: 10)),
              if (svc.priceFrom != null) ...[
                const SizedBox(height: 4),
                Text('From JD${svc.priceFrom!.toInt()}',
                    style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}


 */