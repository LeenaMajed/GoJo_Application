import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../screens/place_detail_screen.dart';


bool _isNet(String s) => s.startsWith('http');

Widget _netOrFile(String path, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
  final fb = fallback ?? const ColoredBox(color: Color(0xFFE8E8E8));
  if (_isNet(path)) {
    return Image.network(path, fit: fit,
        loadingBuilder: (_, child, prog) =>
            prog == null ? child : const ColoredBox(color: Color(0xFFE8E8E8)),
        errorBuilder: (_, __, ___) => fb);
  }
  return Image.file(File(path), fit: fit, errorBuilder: (_, __, ___) => fb);
}

// First photo from list (network or file), or a grey placeholder
Widget placePhoto(Place p, BuildContext ctx, {BoxFit fit = BoxFit.cover}) {
  if (p.photoUrls.isNotEmpty) return _netOrFile(p.photoUrls.first, fit: fit);
  return Container(color: ctx.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
      child: Center(child: Icon(Icons.image_outlined, size: 36, color: ctx.secondary.withOpacity(0.4))));
}

Widget servicePhoto(TripService s, BuildContext ctx, {BoxFit fit = BoxFit.cover}) {
  if (s.photoUrls.isNotEmpty) return _netOrFile(s.photoUrls.first, fit: fit);
  return Container(color: ctx.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
      child: Center(child: Icon(Icons.image_outlined, size: 32, color: ctx.secondary.withOpacity(0.4))));
}

Widget placeThumb(Place p, BuildContext ctx, {double size = 56, double radius = 10}) =>
    ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: placePhoto(p, ctx)));

Widget serviceThumb(TripService s, BuildContext ctx, {double size = 56, double radius = 10}) =>
    ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: servicePhoto(s, ctx)));

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title,
        style: TextStyle(color: context.primary, fontSize: 17, fontWeight: FontWeight.w700),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
    if (actionLabel != null)
      TextButton(onPressed: onAction,
          child: Text(actionLabel!, style: const TextStyle(color: kAccent, fontSize: 13))),
  ]);
}

class PlaceCard extends StatelessWidget {
  final Place place;
  const PlaceCard({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final saved = state.isSaved(place.id);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place))),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(children: [
              SizedBox(height: 120, width: double.infinity, child: placePhoto(place, context)),
              // Bookmark
              Positioned(top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => state.toggleSave(place.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: Colors.white, size: 15)))),
              // Business badge
              if (place.ownerName != null)
                Positioned(bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(place.ownerName!,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis))),
              // Price overlay for hotels
              if (place.pricePerNight != null)
                Positioned(top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
                    child: Text('JD${place.pricePerNight!.toInt()}/night',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
            ]),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.place_outlined, size: 11, color: context.secondary),
                const SizedBox(width: 2),
                Expanded(child: Text(place.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 11))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, size: 13, color: kWarning),
                const SizedBox(width: 3),
                Text(place.rating.toStringAsFixed(1),
                    style: TextStyle(color: context.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              //  Text('  (${place.reviewCount})',
                   // style: TextStyle(color: context.secondary, fontSize: 11)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PlaceListTile extends StatelessWidget {
  final Place place;
  const PlaceListTile({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final saved = state.isSaved(place.id);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: SizedBox(width: 80, height: 80,
                child: placePhoto(place, context))),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.place_outlined, size: 11, color: context.secondary),
                const SizedBox(width: 2),
                Expanded(child: Text(place.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 12))),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: kWarning),
                const SizedBox(width: 3),
                Text(place.rating.toStringAsFixed(1),
                    style: TextStyle(color: context.primary, fontSize: 12, fontWeight: FontWeight.w600)),
               // Text('  ·  ${place.reviewCount} reviews',
                  //  style: TextStyle(color: context.secondary, fontSize: 11)),
              ]),
            ]),
          )),
          IconButton(
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? kAccent : context.secondary, size: 20),
            onPressed: () => state.toggleSave(place.id)),
        ]),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Place place;
  const EventCard({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place))),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(children: [
              SizedBox(height: 150, width: double.infinity, child: placePhoto(place, context)),
              // Dark gradient bottom
              Positioned.fill(child: Container(decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6)])))),
              // Date badge
              if (place.eventDate != null)
                Positioned(top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
                    child: Text(place.eventDate!,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
              // Bookmark
              Positioned(top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => state.toggleSave(place.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: Icon(state.isSaved(place.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: Colors.white, size: 15)))),
              // Location on photo
              Positioned(bottom: 8, left: 10, right: 10,
                child: Row(children: [
                  Icon(Icons.place_outlined, size: 12, color: Colors.white70),
                  const SizedBox(width: 3),
                  Expanded(child: Text(place.location,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              if (place.hours != null)
                Row(children: [
                  Icon(Icons.schedule_outlined, size: 11, color: context.secondary),
                  const SizedBox(width: 3),
                  Text(place.hours!, style: TextStyle(color: context.secondary, fontSize: 11)),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  const StarRating({super.key, required this.rating, this.size = 20});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      if (i < rating.floor()) return Icon(Icons.star_rounded, color: kWarning, size: size);
      if (i < rating) return Icon(Icons.star_half_rounded, color: kWarning, size: size);
      return Icon(Icons.star_outline_rounded, color: Colors.grey.shade400, size: size);
    }),
  );
}

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const TagChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? kAccent : context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? kAccent : context.divider),
      ),
      child: Text(label, style: TextStyle(
        color: selected ? Colors.white : context.secondary,
        fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
    ),
  );
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: context.primary, size: 22),
      onPressed: () => context.read<AppState>().toggleTheme());
  }
}

class GojoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outline, loading;
  const GojoButton({super.key, required this.label, this.onTap, this.outline = false, this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: outline ? Colors.transparent : kAccent,
        foregroundColor: outline ? kAccent : Colors.white,
        side: outline ? const BorderSide(color: kAccent) : null,
        padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: TextStyle(
              fontWeight: FontWeight.w700, color: outline ? kAccent : Colors.white)),
    ),
  );
}
