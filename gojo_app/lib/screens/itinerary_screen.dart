
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/firebase_service.dart';
import 'place_model.dart';

class ItineraryScreen extends StatefulWidget {
  final Map<String, List<Place>> itinerary;
  final Map<String, int> totals;
  final String category;
  final String budget;
  final int days;

  const ItineraryScreen({
    super.key,
    required this.itinerary,
    required this.totals,
    this.category = '',
    this.budget   = '',
    this.days     = 1,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  bool _saving = false;
  bool _saved  = false;

  Future<void> _saveItinerary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to save itineraries.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseService().saveAiItinerary(
        uid:       uid,
        title:     '${widget.category[0].toUpperCase()}${widget.category.substring(1)} · ${widget.days}d',
        category:  widget.category,
        budget:    widget.budget,
        days:      widget.days,
        itinerary: widget.itinerary,
      );
      if (!mounted) return;
      setState(() { _saving = false; _saved = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Itinerary saved!'),
        backgroundColor: kAccentDim));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: kDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.itinerary.keys.toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Your AI Travel Plan'),
        backgroundColor: context.surface,
        foregroundColor: context.primary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.divider),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saved
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, color: kAccentDim, size: 20),
                    const SizedBox(width: 4),
                    Text('Saved', style: TextStyle(color: kAccentDim,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  ])
                : GestureDetector(
                    onTap: _saving ? null : _saveItinerary,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccent.withOpacity(0.3))),
                      child: _saving
                          ? const SizedBox(height: 16, width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.bookmark_add_outlined, color: kAccent, size: 16),
                              SizedBox(width: 5),
                              Text('Save', style: TextStyle(color: kAccent,
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                    ),
                  ),
          ),
        ],
      ),
      body: days.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.map_outlined, size: 64, color: context.secondary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('No itinerary available.', style: TextStyle(color: context.secondary)),
            ]))
          : ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day    = days[index];
                final places = widget.itinerary[day]!;
                final totalMinutes = widget.totals[day] ?? 0;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: double.infinity,
                    color: kAccent.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800, color: context.primary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kAccent.withOpacity(0.3))),
                          child: Text(
                            '${(totalMinutes / 60).toStringAsFixed(1)} hrs total',
                            style: const TextStyle(color: kAccent,
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  if (places.isEmpty)
                    Padding(padding: const EdgeInsets.all(16),
                      child: Text("No activities scheduled for this day.",
                          style: TextStyle(color: context.secondary)))
                  else
                    ...places.asMap().entries.map((e) =>
                        _PlaceCard(place: e.value, stopNumber: e.key + 1)),
                  const SizedBox(height: 8),
                ]);
              },
            ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  final int stopNumber;
  const _PlaceCard({required this.place, required this.stopNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Image.network(place.imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null ? child :
              Container(height: 200, color: context.card,
                  child: const Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))),
            errorBuilder: (_, __, ___) => Container(height: 200, color: context.card,
              child: Center(child: Icon(Icons.image_not_supported,
                  size: 48, color: context.secondary.withOpacity(0.4))))),
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
              child: Text('Stop $stopNumber', style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(place.name, style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: context.primary))),
            if (place.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kWarning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kWarning.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star_rounded, size: 14, color: kWarning),
                  const SizedBox(width: 3),
                  Text(place.rating!.toStringAsFixed(1), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: context.primary)),
                ])),
          ])),
        if (place.description.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(place.description, style: TextStyle(color: context.secondary, fontSize: 14),
                maxLines: 3, overflow: TextOverflow.ellipsis)),
        if (place.reasonWhy != null && place.reasonWhy!.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAccent.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, size: 16, color: kAccent),
              const SizedBox(width: 6),
              Expanded(child: Text(place.reasonWhy!,
                  style: const TextStyle(color: kAccentDim, fontSize: 13))),
            ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(children: [
            Icon(Icons.schedule_outlined, size: 16, color: context.secondary),
            const SizedBox(width: 4),
            Text('${(place.durationMinutes / 60).toStringAsFixed(1)} hrs',
                style: TextStyle(color: context.secondary, fontSize: 13)),
            if (place.category != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.category_outlined, size: 16, color: context.secondary),
              const SizedBox(width: 4),
              Text(place.category!, style: TextStyle(color: context.secondary, fontSize: 13)),
            ],
            if (place.costLevel != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.attach_money, size: 16, color: context.secondary),
              Text(place.costLevel!, style: TextStyle(color: context.secondary, fontSize: 13)),
            ],
          ])),
      ]),
    );
  }
}
