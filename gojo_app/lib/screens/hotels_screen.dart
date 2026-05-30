import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../widgets/shared_widgets.dart';
import 'place_detail_screen.dart';

class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});
  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> {
  String _sort     = 'rating';
  double _maxPrice = 300;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Place> _filter(List<Place> all) {
    final q = _search.toLowerCase();
    var list = all
        .where((h) => h.category == PlaceCategory.hotel && (h.pricePerNight ?? 0) <= _maxPrice)
        .where((h) => _search.isEmpty ||
            h.name.toLowerCase().contains(q) ||
            h.location.toLowerCase().contains(q) ||
            h.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
    if (_sort == 'rating')      list.sort((a, b) => b.rating.compareTo(a.rating));
    else if (_sort == 'price_asc')  list.sort((a, b) => (a.pricePerNight ?? 0).compareTo(b.pricePerNight ?? 0));
    else                        list.sort((a, b) => (b.pricePerNight ?? 0).compareTo(a.pricePerNight ?? 0));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotels'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: context.primary),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rating',     child: Text('Top Rated',        style: TextStyle(color: context.primary))),
              PopupMenuItem(value: 'price_asc',  child: Text('Price: Low → High', style: TextStyle(color: context.primary))),
              PopupMenuItem(value: 'price_desc', child: Text('Price: High → Low', style: TextStyle(color: context.primary))),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: context.read<AppState>().approvedPlacesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kAccent));
          }
          final all    = snap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
          final hotels = _filter(all);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: context.primary),
                decoration: InputDecoration(
                  hintText: 'Search hotels…',
                  prefixIcon: Icon(Icons.search_rounded, color: context.secondary, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: context.secondary, size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Text('Max price/night:', style: TextStyle(color: context.secondary, fontSize: 12)),
                const SizedBox(width: 8),
                Text('JD ${_maxPrice.toInt()}',
                    style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
                Expanded(child: Slider(
                  value: _maxPrice, min: 50, max: 300, divisions: 25,
                  onChanged: (v) => setState(() => _maxPrice = v),
                )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('${hotels.length} hotels found',
                      style: TextStyle(color: context.secondary, fontSize: 12))),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: hotels.isEmpty
                  ? Center(child: Text('No hotels found',
                      style: TextStyle(color: context.secondary, fontSize: 15)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: hotels.length,
                      itemBuilder: (_, i) => _HotelCard(hotel: hotels[i]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  final Place hotel;
  const _HotelCard({required this.hotel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: hotel))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider),
          boxShadow: context.isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(width: 100, height: 90,
                child: placePhoto(hotel, context))),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hotel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary,
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.place_outlined, size: 12, color: context.secondary),
                const SizedBox(width: 3),
                Expanded(child: Text(hotel.location, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 12))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 3),
                Text(hotel.rating.toStringAsFixed(1),
                    style: TextStyle(color: context.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (hotel.pricePerNight != null)
                  Text('JD${hotel.pricePerNight!.toInt()}/night',
                      style: const TextStyle(color: kAccent,
                          fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}