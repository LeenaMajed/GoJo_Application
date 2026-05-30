import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import 'business_add_listing_screen.dart';

class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});
  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user  = state.user!;
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<AppState>().businessPlacesStream(user.id),
      builder: (context, placesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().businessServicesStream(user.id),
          builder: (context, svcsSnap) {

            final myPlaces   = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
            final myServices = svcsSnap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];

            final livePlaces      = myPlaces.where((p) => p.isApproved).toList();
            final pendingPlaces   = myPlaces.where((p) => p.listingStatus == ListingStatus.pending).toList();
            final dismissedPlaces = myPlaces.where((p) => p.isDismissed).toList();

            final liveServices      = myServices.where((s) => s.isApproved).toList();
            final pendingServices   = myServices.where((s) => s.listingStatus == ListingStatus.pending).toList();
            final dismissedServices = myServices.where((s) => s.isDismissed).toList();

            final pendingEdits  = myPlaces.where((p) => p.pendingEdit != null).length
                                + myServices.where((s) => s.pendingEdit != null).length;
            final totalLive     = livePlaces.length + liveServices.length;
            final totalPending  = pendingPlaces.length + pendingServices.length;

            return Scaffold(
              backgroundColor: context.bg,
              body: SafeArea(child: Column(children: [

                Container(
                  color: context.surface,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hello, ${user.name.split(' ').first}',
                            style: TextStyle(color: context.secondary, fontSize: 13)),
                        Text('My Listings', style: TextStyle(color: context.primary,
                            fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ])),
                      _bizBadge(),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _statChip(context, '$totalLive',
                          'Live',      const Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      _statChip(context, '$totalPending',
                          'Pending',   kWarning),
                      const SizedBox(width: 8),
                      _statChip(context, '$pendingEdits',
                          'In Review', kAccent),
                      const SizedBox(width: 8),
                      _statChip(context, '${myPlaces.length + myServices.length}',
                          'Total',     context.secondary),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: context.bg, borderRadius: BorderRadius.circular(12)),
                      child: TabBar(
                        controller: _tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: context.secondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        tabs: [
                          Tab(text: 'Places (${myPlaces.length - dismissedPlaces.length})'),
                          Tab(text: 'Services (${myServices.length - dismissedServices.length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ]),
                ),

                _NotificationPanel(ownerId: user.id),

                Expanded(child: TabBarView(controller: _tab, children: [

                  // Places tab
                  _ListingList(
                    pending:   pendingPlaces.map((p) => _Item.fromPlace(p)).toList(),
                    live:      livePlaces.map((p) => _Item.fromPlace(p)).toList(),
                    dismissed: dismissedPlaces.map((p) => _Item.fromPlace(p)).toList(),
                    onEdit: (id) {
                      final place = myPlaces.firstWhere((p) => p.id == id);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => BusinessAddListingScreen(existingPlace: place)));
                    },
                    onTap: (id) {
                      final place = myPlaces.firstWhere((p) => p.id == id);
                      _showDetail(context, _Item.fromPlace(place), myPlaces, myServices, user.id);
                    },
                  ),
                  _ListingList(
                    pending:   pendingServices.map((s) => _Item.fromService(s)).toList(),
                    live:      liveServices.map((s) => _Item.fromService(s)).toList(),
                    dismissed: dismissedServices.map((s) => _Item.fromService(s)).toList(),
                    onEdit: (id) {
                      final svc = myServices.firstWhere((s) => s.id == id);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => BusinessAddListingScreen(existingService: svc)));
                    },
                    onTap: (id) {
                      final svc = myServices.firstWhere((s) => s.id == id);
                      _showDetail(context, _Item.fromService(svc), myPlaces, myServices, user.id);
                    },
                  ),

                ])),
              ])),
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, _Item item,
      List<Place> myPlaces, List<TripService> myServices, String ownerId) {
    final statusColor = item.isDismissed ? kDanger
        : item.isApproved ? const Color(0xFF22C55E) : kWarning;
    final statusLabel = item.isDismissed ? 'Not Approved'
        : item.isApproved ? 'Live on GoJo' : 'Awaiting Approval';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.78, maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(color: context.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
            Expanded(child: SingleChildScrollView(
              controller: sc,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Photo hero
                if (item.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: item.photoUrls.first.startsWith('http')
                          ? Image.network(item.photoUrls.first, fit: BoxFit.cover,
                              loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE8E8E8)),
                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8)))
                          : Image.file(File(item.photoUrls.first), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8))),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    color: context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                    child: Center(child: Icon(Icons.image_outlined,
                        size: 40, color: context.secondary.withOpacity(0.3)))),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(statusLabel, style: TextStyle(
                          color: statusColor, fontSize: 11, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 10),
                    Text(item.name, style: TextStyle(color: context.primary,
                        fontSize: 20, fontWeight: FontWeight.w800)),
                    if (item.category != null) ...[
                      const SizedBox(height: 3),
                      Text(item.category!, style: TextStyle(color: context.secondary, fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.divider)),
                      child: Column(children: [
                        _dRow(context, Icons.place_outlined,    'Location', item.location),
                        if (item.priceLabel != null)
                          _dRow(context, Icons.payments_outlined, 'Price', item.priceLabel!),
                        if (item.phone != null)
                          _dRow(context, Icons.phone_outlined,   'Phone',  item.phone!),
                        if (item.hours != null)
                          _dRow(context, Icons.schedule_outlined, 'Hours', item.hours!),
                      ]),
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(item.description!, style: TextStyle(
                          color: context.secondary, fontSize: 14, height: 1.55)),
                    ],
                    if (item.isDismissed && item.adminNote != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: kDanger.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kDanger.withOpacity(0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.admin_panel_settings_outlined, color: kDanger, size: 15),
                            SizedBox(width: 6),
                            Text("Admin's Feedback", style: TextStyle(
                                color: kDanger, fontSize: 13, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          Text(item.adminNote!, style: TextStyle(
                              color: context.secondary, fontSize: 13, height: 1.4)),
                        ]),
                      ),
                    ],
                    if (item.isApproved && !item.hasPendingEdit) ...[
                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit This Listing'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: kAccent, side: const BorderSide(color: kAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          Navigator.pop(context);
                          if (item.isPlace) {
                            final place = myPlaces.firstWhere((p) => p.id == item.id);
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => BusinessAddListingScreen(existingPlace: place)));
                          } else {
                            final svc = myServices.firstWhere((s) => s.id == item.id);
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => BusinessAddListingScreen(existingService: svc)));
                          }
                        })),
                    ],
                    const SizedBox(height: 8),
                    // Delete button — passes ownerUid for ownership enforcement
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_forever_rounded, size: 16, color: kDanger),
                      label: Text('Delete Listing', style: TextStyle(color: kDanger)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: kDanger,
                          side: BorderSide(color: kDanger.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        final st = context.read<AppState>();
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (!mounted) return;
                          
                          showDialog(
  context: context,
  barrierDismissible: false,
  builder: (dlg) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dlg.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Top Icon
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: kDanger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: kDanger,
              size: 40,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'Delete Listing?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dlg.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 10),

          // Description
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: dlg.secondary,
                fontSize: 13,
                height: 1.6,
              ),
              children: [
                const TextSpan(
                  text: 'You are about to permanently delete\n',
                ),
                TextSpan(
                  text: item.name,
                  style: TextStyle(
                    color: dlg.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: '.\nThis action cannot be undone.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Buttons
          Row(
            children: [

              // Cancel
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dlg.secondary,
                    side: BorderSide(color: dlg.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dlg),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Delete
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDanger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(dlg);

                    try {
                      await st.deleteListing(
                        item.id,
                        isPlace: item.isPlace,
                        ownerUid: ownerId,
                        name: item.name,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.name} deleted'),
                            backgroundColor: kDanger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delete failed: $e'),
                            backgroundColor: kDanger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
                        });
                      })),
                  ]),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _dRow(BuildContext ctx, IconData icon, String label, String value) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Icon(icon, size: 15, color: kAccent),
        const SizedBox(width: 10),
        SizedBox(width: 72, child: Text(label, style: TextStyle(
            color: ctx.secondary, fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ctx.primary, fontSize: 13))),
      ]));

  Widget _bizBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: kAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent.withOpacity(0.25))),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.storefront_rounded, color: kAccent, size: 13),
      SizedBox(width: 4),
      Text('Business', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700)),
    ]));

  Widget _statChip(BuildContext context, String val, String label, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.18))),
        child: Column(children: [
          Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ));
}

class _Item {
  final String id, name, location;
  final ListingStatus listingStatus;
  final bool isPlace;
  final String? priceLabel, category, photoUrl, adminNote, description, phone, hours;
  final List<String> photoUrls;
  final bool hasPendingEdit;

  bool get isApproved  => listingStatus == ListingStatus.approved;
  bool get isDismissed => listingStatus == ListingStatus.dismissed;
  bool get isPending   => listingStatus == ListingStatus.pending;

  const _Item({required this.isPlace,
    required this.id, required this.name, required this.location,
    required this.listingStatus,
    this.priceLabel, this.category, this.photoUrl, this.adminNote,
    this.description, this.phone, this.hours,
    this.photoUrls = const [],
    this.hasPendingEdit = false,
  });

  factory _Item.fromPlace(Place p) => _Item(
    isPlace: true, id: p.id, name: p.name, location: p.location,
    listingStatus: p.listingStatus,
    category: p.category.name[0].toUpperCase() + p.category.name.substring(1),
    photoUrl: p.photoUrls.isNotEmpty ? p.photoUrls.first : null,
    photoUrls: p.photoUrls, adminNote: p.adminDismissNote,
    description: p.description, phone: p.phone, hours: p.hours,
    priceLabel: p.pricePerNight != null ? 'JD${p.pricePerNight!.toStringAsFixed(0)}/night' : null,
    hasPendingEdit: p.pendingEdit != null,
  );

  factory _Item.fromService(TripService s) => _Item(
    isPlace: false, id: s.id, name: s.name, location: s.location,
    listingStatus: s.listingStatus,
    category: s.customCategory.isNotEmpty ? s.customCategory
        : s.category.name[0].toUpperCase() + s.category.name.substring(1),
    photoUrl: s.photoUrls.isNotEmpty ? s.photoUrls.first : null,
    photoUrls: s.photoUrls, adminNote: s.adminDismissNote,
    description: s.description, phone: s.phone, hours: s.hours,
    priceLabel: s.priceFrom != null ? 'From JD${s.priceFrom!.toInt()} ${s.priceUnit ?? ''}' : null,
    hasPendingEdit: s.pendingEdit != null,
  );
}

class _ListingList extends StatelessWidget {
  final List<_Item> pending, live, dismissed;
  final void Function(String id) onEdit;
  final void Function(String id) onTap;
  const _ListingList({required this.pending, required this.live,
    required this.dismissed, required this.onEdit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty && live.isEmpty && dismissed.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_business_outlined, size: 52,
            color: context.secondary.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No listings yet', style: TextStyle(color: context.primary,
            fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Tap "Add Listing" tab to get started',
            style: TextStyle(color: context.secondary, fontSize: 13)),
      ]));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionLabel(context, 'Awaiting Approval (${pending.length})', kWarning),
          const SizedBox(height: 8),
          ...pending.map((i) => _Card(item: i, onEdit: onEdit, onTap: onTap)),
          const SizedBox(height: 16),
        ],
        if (live.isNotEmpty) ...[
          _sectionLabel(context, 'Live on GoJo (${live.length})', const Color(0xFF22C55E)),
          const SizedBox(height: 8),
          ...live.map((i) => _Card(item: i, onEdit: onEdit, onTap: onTap)),
          const SizedBox(height: 16),
        ],
        if (dismissed.isNotEmpty) ...[
          _sectionLabel(context, 'Not Approved (${dismissed.length})', kDanger),
          const SizedBox(height: 8),
          ...dismissed.map((i) => _Card(item: i, onEdit: onEdit, onTap: onTap)),
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext ctx, String text, Color color) =>
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: ctx.primary,
            fontSize: 13, fontWeight: FontWeight.w700)),
      ]);
}

class _Card extends StatelessWidget {
  final _Item item;
  final void Function(String) onEdit;
  final void Function(String) onTap;
  const _Card({required this.item, required this.onEdit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = item.isDismissed ? kDanger.withOpacity(0.25)
        : item.isPending ? kWarning.withOpacity(0.25)
        : item.hasPendingEdit ? kWarning.withOpacity(0.35)
        : context.divider;
    final statusColor = item.isDismissed ? kDanger
        : item.isApproved ? const Color(0xFF22C55E) : kWarning;
    final statusLabel = item.isDismissed ? 'Dismissed'
        : item.isApproved ? 'Live' : 'Pending';

    return GestureDetector(
      onTap: () => onTap(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(height: 110, width: double.infinity,
                child: item.photoUrl!.startsWith('http')
                    ? Image.network(item.photoUrl!, fit: BoxFit.cover,
                        loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE8E8E8)),
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8)))
                    : Image.file(File(item.photoUrl!), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8))),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.photoUrl == null)
                Container(width: 44, height: 44, margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.divider)),
                  child: Icon(Icons.image_outlined, color: context.secondary.withOpacity(0.4), size: 22)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(item.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.secondary, fontSize: 12)),
                if (item.priceLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(item.priceLabel!,
                      style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
                if (item.hasPendingEdit)
                  const Text('Edit pending review',
                      style: TextStyle(color: kWarning, fontSize: 10, fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel, style: TextStyle(
                      color: statusColor, fontSize: 11, fontWeight: FontWeight.w700))),
                if (item.isApproved && !item.hasPendingEdit) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => onEdit(item.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: context.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.divider)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_outlined, size: 11, color: context.secondary),
                        const SizedBox(width: 3),
                        Text('Edit', style: TextStyle(color: context.secondary, fontSize: 10)),
                      ]))),
                ],
              ]),
            ]),
          ),
          if (item.isDismissed && item.adminNote != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kDanger.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kDanger.withOpacity(0.18))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, color: kDanger, size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text('Admin: ${item.adminNote}',
                    style: const TextStyle(color: kDanger, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ])),
        ]),
      ),
    );
  }
}
class _NotificationPanel extends StatelessWidget {
  final String ownerId;
  const _NotificationPanel({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: context.watch<AppState>().notificationsStream(ownerId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          children: docs.map((doc) {
            final d     = doc.data() as Map<String, dynamic>;
            final type  = d['type'] ?? '';
            final name  = d['listingName'] ?? '';
            final note  = d['adminNote'] as String?;
            final isPos = type == 'approved' || type == 'editApproved';
            final color = isPos ? const Color(0xFF22C55E) : kDanger;
            final icon  = isPos ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;
            final title = switch (type) {
              'approved'     => '"$name" was approved!',
              'dismissed'    => '"$name" was rejected.',
              'editApproved' => 'Edit to "$name" was approved!',
              'editRejected' => 'Edit to "$name" was rejected.',
              _              => 'Update for "$name"',
            };
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(note, style: TextStyle(color: context.secondary, fontSize: 12)),
                  ],
                ])),
                GestureDetector(
                  onTap: () => context.read<AppState>().deleteNotification(doc.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.04)),
                    child: Icon(Icons.close_rounded, size: 16, color: context.secondary))),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}