
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import 'map_screen.dart';
import 'package:url_launcher/url_launcher.dart';

void showServiceDetail(BuildContext context, TripService svc, AppState state) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ServiceDetailSheet(svc: svc),
  );
}

class _ServiceDetailSheet extends StatelessWidget {
  final TripService svc;
  const _ServiceDetailSheet({required this.svc});

  @override
  Widget build(BuildContext context) {
    final state   = context.watch<AppState>();
    final isSaved = state.isServiceSaved(svc.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.72, maxChildSize: 0.95,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
            color: context.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: context.divider, borderRadius: BorderRadius.circular(2))),
          Expanded(child: SingleChildScrollView(
            controller: sc,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Hero photo
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(height: 200, width: double.infinity,
                    child: servicePhoto(svc, context))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: kDeadSeaBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          (svc.customCategory.isNotEmpty
                              ? svc.customCategory : _catStr(svc.category)).toUpperCase(),
                          style: const TextStyle(color: kDeadSeaBlue,
                              fontSize: 9, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 8),
                      Text(svc.name, style: TextStyle(color: context.primary,
                          fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('by ${svc.ownerName}',
                          style: TextStyle(color: context.secondary, fontSize: 13)),
                    ])),
                    // Bookmark button — reacts to AppState via context.watch above
                    GestureDetector(
                      onTap: () => state.toggleServiceSave(svc.id),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSaved ? kAccent.withOpacity(0.1) : context.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSaved ? kAccent : context.divider)),
                        child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved ? kAccent : context.secondary, size: 20)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(svc.description,
                      style: TextStyle(color: context.secondary, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 16),
                  // Details grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: context.bg, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.divider)),
                    child: Column(children: [
                      _dRow(context, Icons.place_outlined, 'Location', svc.location),
                      if (svc.priceFrom != null)
                        _dRow(context, Icons.payments_outlined, 'Price',
                            'From JD${svc.priceFrom!.toInt()} ${svc.priceUnit ?? ""}'),
                      if (svc.hours != null)
                        _dRow(context, Icons.schedule_outlined, 'Hours', svc.hours!),
                      if (svc.phone != null)
                        _dRow(context, Icons.phone_outlined, 'Phone', svc.phone!),
                      if (svc.rating > 0)
                        _dRow(context, Icons.star_outline_rounded, 'Rating',
                            '${svc.rating} out of 5 (${svc.reviewCount} reviews)'),
                      if (svc.lat != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MapScreen(
                                  focusPoint: LatLng(svc.lat!, svc.lng!),
                                  focusLabel: svc.name))),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: kDeadSeaBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kDeadSeaBlue.withOpacity(0.3))),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.map_outlined, color: kDeadSeaBlue, size: 16),
                              SizedBox(width: 8),
                              Text('View on Map', style: TextStyle(
                                  color: kDeadSeaBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                            ]))),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (svc.tags.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 6, children: svc.tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: context.bg, borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.divider)),
                      child: Text(t, style: TextStyle(color: context.secondary, fontSize: 12)),
                    )).toList()),
                  const SizedBox(height: 20),
                  if (svc.phone != null || svc.whatsapp != null)
                    Row(children: [
                      if (svc.whatsapp != null) Expanded(child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white),
                        onPressed: () => _openWhatsApp(svc.whatsapp!))),
                      if (svc.phone != null && svc.whatsapp != null) const SizedBox(width: 12),
                      if (svc.phone != null) Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_outlined, size: 16),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: kDeadSeaBlue,
                            side: const BorderSide(color: kDeadSeaBlue)),
                        onPressed: () => _callPhone(svc.phone!))),
                    ]),
                ]),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

String _catStr(ServiceCategory c) {
  switch (c) {
    case ServiceCategory.equipment:     return 'Equipment';
    case ServiceCategory.guide:         return 'Tour Guide';
    case ServiceCategory.transport:     return 'Transport';
    case ServiceCategory.experience:    return 'Experience';
    case ServiceCategory.wellness:      return 'Wellness';
    case ServiceCategory.photography:   return 'Photography';
    case ServiceCategory.food:          return 'Food & Catering';
    case ServiceCategory.accommodation: return 'Accommodation';
    case ServiceCategory.retail:        return 'Retail';
    default:                            return 'Service';
  }
}

Widget _dRow(BuildContext ctx, IconData icon, String label, String value) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Icon(icon, size: 15, color: kAccent),
      const SizedBox(width: 10),
      SizedBox(width: 70, child: Text(label,
          style: TextStyle(color: ctx.secondary, fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ctx.primary, fontSize: 13))),
    ]));

Future<void> _callPhone(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openWhatsApp(String phone) async {
  String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (!cleaned.startsWith('962') && cleaned.startsWith('0')) {
    cleaned = '962${cleaned.substring(1)}';
  }
  final message = Uri.encodeComponent("Hello 👋");
  final appUri = Uri.parse("whatsapp://send?phone=$cleaned&text=$message");
  final webUri = Uri.parse("https://wa.me/$cleaned?text=$message");
  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri, mode: LaunchMode.externalApplication);
  } else {
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}


class ServicesScreen extends StatefulWidget {
  final List<String> highlightTags;
  final TripService? initialService;
  const ServicesScreen({super.key, this.highlightTags = const [], this.initialService});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  ServiceCategory? _filter;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TripService> _apply(List<TripService> all) {
    var services = all.where((s) {
      final q = _search.toLowerCase();
      final matchSearch = _search.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.location.toLowerCase().contains(q) ||
          s.customCategory.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q));
      final matchFilter = _filter == null || s.category == _filter;
      return matchSearch && matchFilter;
    }).toList();

    if (widget.highlightTags.isNotEmpty) {
      services.sort((a, b) {
        final aM = a.tags.any((t) => widget.highlightTags.contains(t)) ? 0 : 1;
        final bM = b.tags.any((t) => widget.highlightTags.contains(t)) ? 0 : 1;
        return aM.compareTo(bM);
      });
    }
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(child: StreamBuilder<QuerySnapshot>(
        stream: context.read<AppState>().approvedServicesStream,
        builder: (context, snap) {
          final all      = snap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];
          final services = _apply(all);

          return Column(children: [
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
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: context.primary))),
                  Expanded(child: Text('Local Services',
                      style: TextStyle(color: context.primary,
                          fontSize: 20, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${services.length} available',
                        style: const TextStyle(color: kAccent,
                            fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: context.primary),
                  decoration: InputDecoration(
                    hintText: 'Search guides, transport, gear…',
                    prefixIcon: Icon(Icons.search_rounded, color: context.secondary, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: context.secondary, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip(null, 'All'),
                    _chip(ServiceCategory.guide, 'Guides'),
                    _chip(ServiceCategory.transport, 'Transport'),
                    _chip(ServiceCategory.equipment, 'Gear'),
                    _chip(ServiceCategory.experience, 'Experiences'),
                    _chip(ServiceCategory.wellness, 'Wellness'),
                    _chip(ServiceCategory.photography, 'Photography'),
                    _chip(ServiceCategory.food, 'Food'),
                  ]),
                ),
              ]),
            ),

            Expanded(
              child: snap.connectionState == ConnectionState.waiting && all.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: kAccent))
                  : services.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off_rounded, size: 52,
                              color: context.secondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No services found',
                              style: TextStyle(color: context.secondary, fontSize: 15)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: services.length,
                          itemBuilder: (_, i) => _SvcCard(
                              svc: services[i],
                              highlight: widget.highlightTags)),
            ),
          ]);
        },
      )),
    );
  }

  Widget _chip(ServiceCategory? cat, String label) {
    final sel = _filter == cat;
    return GestureDetector(
      onTap: () => setState(() => _filter = cat),
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

class _SvcCard extends StatelessWidget {
  final TripService svc;
  final List<String> highlight;
  const _SvcCard({required this.svc, this.highlight = const []});

  @override
  Widget build(BuildContext context) {
    final state    = context.watch<AppState>();
    final saved    = state.isServiceSaved(svc.id);
    final relevant = svc.tags.any((t) => highlight.contains(t));
    final catLabel = svc.customCategory.isNotEmpty ? svc.customCategory : _catStr(svc.category);

    return GestureDetector(
      onTap: () => showServiceDetail(context, svc, state),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: relevant ? kAccent.withOpacity(0.35) : context.divider,
              width: relevant ? 1.5 : 1),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 160, width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                servicePhoto(svc, context),
                Container(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight, end: Alignment.bottomLeft,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.3)]))),
                if (svc.priceFrom != null)
                  Positioned(top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
                      child: Text('From JD${svc.priceFrom!.toInt()}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
                Positioned(top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () => state.toggleServiceSave(svc.id),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                      child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: Colors.white, size: 16)))),
                if (relevant)
                  Positioned(bottom: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Matches your interests',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))),
              ]),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: kDeadSeaBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(catLabel.toUpperCase(),
                      style: const TextStyle(color: kDeadSeaBlue, fontSize: 9, fontWeight: FontWeight.w700))),
                const Spacer(),
                if (svc.rating > 0) Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: kWarning),
                  const SizedBox(width: 3),
                  Text(svc.rating.toStringAsFixed(1),
                      style: TextStyle(color: context.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('  (${svc.reviewCount})',
                      style: TextStyle(color: context.secondary, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 8),
              Text(svc.name,
                  style: TextStyle(color: context.primary, fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.storefront_outlined, size: 13, color: context.secondary),
                const SizedBox(width: 4),
                Expanded(child: Text('${svc.ownerName}  ·  ${svc.location}',
                    style: TextStyle(color: context.secondary, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 8),
              Text(svc.description,
                  style: TextStyle(color: context.secondary, fontSize: 13, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (svc.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 4,
                  children: svc.tags.take(4).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: highlight.contains(t) ? kAccent.withOpacity(0.1) : context.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: highlight.contains(t) ? kAccent.withOpacity(0.4) : context.divider)),
                    child: Text(t, style: TextStyle(
                        color: highlight.contains(t) ? kAccent : context.secondary,
                        fontSize: 11)),
                  )).toList()),
              ],
              const SizedBox(height: 12),
              Row(children: [
                if (svc.hours != null) Expanded(child: Row(children: [
                  Icon(Icons.schedule_outlined, size: 13, color: context.secondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(svc.hours!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.secondary, fontSize: 12))),
                ])),
                Row(children: [
                  if (svc.whatsapp != null) ...[
                    _contactBtn(Icons.chat_outlined, const Color(0xFF25D366)),
                    const SizedBox(width: 8),
                  ],
                  if (svc.phone != null) _contactBtn(Icons.phone_outlined, kDeadSeaBlue),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _contactBtn(IconData icon, Color c) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.3))),
    child: Icon(icon, color: c, size: 18));
}