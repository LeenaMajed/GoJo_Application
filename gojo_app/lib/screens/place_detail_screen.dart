

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gojo/screens/hours_display_widget.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../widgets/shared_widgets.dart';
import 'package:latlong2/latlong.dart';
import 'map_screen.dart';

const bool _kShowRatingsOnCards = true;

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  const PlaceDetailScreen({super.key, required this.place});
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailState();
}

class _PlaceDetailState extends State<PlaceDetailScreen> {
  bool   _showForm    = false;
  double _newRating   = 4.0;
  int    _photoPage   = 0;
  final  _ctrl        = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── Submit — persists to Firestore so comments survive logout ──────────────
  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write something first'),
        backgroundColor: kDanger, behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2)));
      return;
    }
    final state = context.read<AppState>();
    try {
      await FirebaseService().addReview(
        placeId:  widget.place.id,
        uid:      state.user?.id   ?? 'guest',
        userName: state.user?.name ?? 'Visitor',
        rating:   _newRating,
        comment:  text,
      );
      if (!mounted) return;
      _ctrl.clear();
      setState(() { _showForm = false; _newRating = 4.0; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Comment posted!'),
        ]),
        backgroundColor: kAccentDim,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to post: $e'),
        backgroundColor: kDanger, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p      = widget.place;
    final state  = context.watch<AppState>();
    final saved  = state.isSaved(p.id);
    final hasMap = p.lat != 0 && p.lng != 0;

    return Scaffold(
      body: CustomScrollView(slivers: [

        
        SliverAppBar(
          expandedHeight: 260, pinned: true,
          backgroundColor: context.surface,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
                onPressed: () => Navigator.pop(context)))),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: saved ? kAccent : Colors.white, size: 18),
                  onPressed: () => state.toggleSave(p.id)))),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: p.photoUrls.isNotEmpty
                ? Stack(children: [
                    PageView.builder(
                      itemCount: p.photoUrls.length,
                      onPageChanged: (i) => setState(() => _photoPage = i),
                      itemBuilder: (_, i) {
                        final url = p.photoUrls[i];
                        return _isNet(url)
                            ? Image.network(url, fit: BoxFit.cover,
                                loadingBuilder: (_, child, prog) =>
                                    prog == null ? child : const _PhotoPlaceholder(),
                                errorBuilder: (_, __, ___) => const _PhotoPlaceholder())
                            : Image.file(File(url), fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const _PhotoPlaceholder());
                      }),
                    // dot indicator
                    if (p.photoUrls.length > 1)
                      Positioned(bottom: 12, left: 0, right: 0,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(p.photoUrls.length, (i) =>
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: i == _photoPage ? 16 : 6, height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: i == _photoPage ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(3)))))),
                  ])
                : const _PhotoPlaceholder(),
          ),
        ),

        
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Badges
            Wrap(spacing: 8, runSpacing: 6, children: [
              _badge(_catLabel(p.category), kAccent),
              if (p.ownerName != null)
                _badge(p.ownerName!, kDeadSeaBlue),
            ]),
            const SizedBox(height: 10),

            // Name
            Text(p.name, style: TextStyle(
              color: context.primary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),

            // Location
            Row(children: [
              Icon(Icons.place_rounded, size: 14, color: context.secondary),
              const SizedBox(width: 4),
              Expanded(child: Text(p.location,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.secondary, fontSize: 13))),
            ]),
            const SizedBox(height: 8),

            // Rating summary (uses the same flag as comment cards)
            if (_kShowRatingsOnCards)
              Row(children: [
                StarRating(rating: p.rating, size: 16),
                const SizedBox(width: 8),
                Text(p.rating.toStringAsFixed(1),
                  style: TextStyle(color: context.primary,
                    fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
              //  Text('(${reviews.length} comment${reviews.length != 1 ? "s" : ""})',
                 // style: TextStyle(color: context.secondary, fontSize: 12)),
              ]),
            const SizedBox(height: 16),

            
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.divider)),
              child: Column(children: [
                if (p.hours != null)
                  _Hdetail(context, Icons.schedule_rounded,        'Hours',        HoursDisplay(hours: p.hours)),
                if (p.phone != null)
                  _detail(context, Icons.phone_rounded,           'Phone',        p.phone!),
                if (p.cuisine != null)
                  _detail(context, Icons.restaurant_menu_rounded, 'Cuisine',      p.cuisine!),
                if (p.pricePerNight != null)
                  _detail(context, Icons.payments_rounded,        'Price/Night',  'JD${p.pricePerNight!.toStringAsFixed(0)}'),
                if (p.eventDate != null)
                  _detail(context, Icons.event_rounded,           'Date',         p.eventDate!),
                if (hasMap)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        context.read<AppState>().recordBehavior(BehaviorEvent.openedMap);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MapScreen(
                            focusPoint: LatLng(p.lat, p.lng),
                            focusLabel: p.name)));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kDeadSeaBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kDeadSeaBlue.withOpacity(0.3))),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_rounded, color: kDeadSeaBlue, size: 16),
                            SizedBox(width: 8),
                            Text('View on Map', style: TextStyle(
                              color: kDeadSeaBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                          ])))),
              ]),
            ),
            const SizedBox(height: 16),

            // Description
            Text(p.description, style: TextStyle(
              color: context.secondary, fontSize: 14, height: 1.6)),

            // Tags
            if (p.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 6,
                children: p.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(t, style: const TextStyle(
                    color: kAccentDim, fontSize: 12)))).toList()),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

           
            Row(children: [
             /*  Text('Comments (${reviews.length})', style: TextStyle(
                color: context.primary, fontSize: 16, fontWeight: FontWeight.w700)),*/
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showForm = !_showForm),
                child: Text(_showForm ? 'Cancel' : '+ Add comment',
                  style: const TextStyle(color: kAccent, fontWeight: FontWeight.w600))),
            ]),

         
            if (_showForm) ...[
              const SizedBox(height: 10),
              _CommentForm(
                ctrl: _ctrl,
                rating: _newRating,
                onRating: (r) => setState(() => _newRating = r),
                onSubmit: _submit,
                showRating: _kShowRatingsOnCards,
              ),
              const SizedBox(height: 12),
            ],

            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseService().reviewsStream(p.id),
              builder: (ctx, snap) {
                final docs    = snap.data?.docs ?? [];
                final reviews = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final ts   = data['createdAt'] as Timestamp?;
                  return Review(
                    id:       d.id,
                    userId:   data['uid']      ?? '',
                    userName: data['userName'] ?? 'Visitor',
                    placeId:  data['placeId']  ?? p.id,
                    rating:   (data['rating']  as num?)?.toDouble() ?? 0,
                    text:     data['comment']  ?? '',
                    date:     ts?.toDate() ?? DateTime.now(),
                  );
                }).toList();

                if (snap.connectionState == ConnectionState.waiting && reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: kAccent)));
                }

                if (reviews.isEmpty && !_showForm) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 38,
                          color: context.secondary.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text('No comments yet — be the first!',
                          style: TextStyle(color: context.secondary, fontSize: 13)),
                    ])));
                }

                return Column(
                  children: reviews.map((r) =>
                      _CommentCard(review: r, showRating: _kShowRatingsOnCards)).toList());
              },
            ),

            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(color: color, fontSize: 11,
      fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis));

  Widget _detail(BuildContext ctx, IconData icon, String label, String value) =>
    Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: kAccent),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(label, style: TextStyle(
          color: ctx.secondary, fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ctx.primary, fontSize: 13))),
      ]));
Widget _Hdetail(
  BuildContext ctx,
  IconData icon,
  String label,
  Widget value,
) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kAccent),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: ctx.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
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


class _CommentForm extends StatelessWidget {
  final TextEditingController ctrl;
  final double rating;
  final void Function(double) onRating;
  final VoidCallback onSubmit;
  final bool showRating;
  const _CommentForm({
    required this.ctrl, required this.rating, required this.onRating,
    required this.onSubmit, required this.showRating,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kAccent.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Star picker — only shown when ratings are enabled
      if (showRating) ...[
        Text('Rating', style: TextStyle(
          color: context.secondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          ...List.generate(5, (i) => GestureDetector(
            onTap: () => onRating(i + 1.0),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: kWarning, size: 28)))),
          const SizedBox(width: 6),
          Text('${rating.toInt()}/5', style: TextStyle(
            color: context.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
      ],
      // Text field
      TextField(
        controller: ctrl,
        maxLines: 4,
        style: TextStyle(color: context.primary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Share your experience…',
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAccent, width: 1.5))),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity,
        child: ElevatedButton(onPressed: onSubmit,
          child: const Text('Post comment'))),
    ]),
  );
}

class _CommentCard extends StatelessWidget {
  final Review review;
  final bool   showRating;  // controlled by the top-of-file constant
  const _CommentCard({required this.review, required this.showRating});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: context.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 15, backgroundColor: kAccent.withOpacity(0.12),
          child: Text(
            review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?',
            style: const TextStyle(color: kAccent, fontSize: 13,
              fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.userName, style: TextStyle(
              color: context.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            Text(_fmtDate(review.date), style: TextStyle(
              color: context.secondary, fontSize: 11)),
          ])),
        // ── Stars: comment or uncomment by flipping _kShowRatingsOnCards ──
        if (showRating)
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) =>
            Icon(i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: kWarning, size: 13))),
      ]),
      const SizedBox(height: 8),
      Text(review.text, style: TextStyle(
        color: context.secondary, fontSize: 13, height: 1.5)),
    ]),
  );

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 2)  return 'Just now';
    if (diff.inHours  < 1)   return '${diff.inMinutes}m ago';
    if (diff.inDays   < 1)   return '${diff.inHours}h ago';
    if (diff.inDays   < 7)   return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}


class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    color: context.isDark ? const Color(0xFF222222) : const Color(0xFFE8E8E8));
}

bool _isNet(String s) => s.startsWith('http');