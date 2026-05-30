import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../widgets/shared_widgets.dart';
import 'place_detail_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});
  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _cuisines(List<Place> restaurants) {
    final c = restaurants.map((r) => r.cuisine ?? 'Other').toSet().toList()..sort();
    return ['All', ...c];
  }

  List<Place> _filtered(List<Place> restaurants) {
    final q = _search.toLowerCase();
    return restaurants.where((r) {
      final matchFilter = _filter == 'All' || (r.cuisine ?? '').contains(_filter);
      final matchSearch = _search.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q) ||
          (r.cuisine ?? '').toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
      return matchFilter && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: StreamBuilder<QuerySnapshot>(
        stream: context.read<AppState>().approvedPlacesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccent));
          }
          final all         = snap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
          final restaurants = all.where((p) => p.category == PlaceCategory.restaurant).toList();
          final cuisines    = _cuisines(restaurants);
          final filtered    = _filtered(restaurants);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: context.primary),
                decoration: InputDecoration(
                  hintText: 'Search restaurants…',
                  prefixIcon: Icon(Icons.search_rounded, color: context.secondary, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: context.secondary, size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: cuisines.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TagChip(
                      label: cuisines[i],
                      selected: _filter == cuisines[i],
                      onTap: () => setState(() => _filter = cuisines[i])),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('${filtered.length} restaurants',
                      style: TextStyle(color: context.secondary, fontSize: 12))),
            ),
            const SizedBox(height: 6),
            Expanded(child: filtered.isEmpty
                ? Center(child: Text('No restaurants found',
                    style: TextStyle(color: context.secondary, fontSize: 15)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _RestaurantCard(restaurant: filtered[i]),
                  )),
          ]);
        },
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Place restaurant;
  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: restaurant))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider),
          boxShadow: context.isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(width: 100, height: 90,
                child: placePhoto(restaurant, context))),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary,
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              if (restaurant.cuisine != null)
                Text(restaurant.cuisine!,
                    style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.place_outlined, size: 12, color: context.secondary),
                const SizedBox(width: 3),
                Expanded(child: Text(restaurant.location, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 12))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 3),
                Text(restaurant.rating.toStringAsFixed(1),
                    style: TextStyle(color: context.primary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}