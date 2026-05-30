import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';

enum _Tab { pending, approved, dismissed, edits }

class AdminListingsScreen extends StatefulWidget {
  final String initialDeepLink;
  const AdminListingsScreen({super.key, this.initialDeepLink = ''});
  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _typeTab;
  late _Tab _activeTab;

  @override
  void initState() {
    super.initState();
    _typeTab   = TabController(length: 2, vsync: this);
    _activeTab = _deepLinkToTab(widget.initialDeepLink);
  }

  @override
  void didUpdateWidget(AdminListingsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialDeepLink != old.initialDeepLink)
      setState(() => _activeTab = _deepLinkToTab(widget.initialDeepLink));
  }

  _Tab _deepLinkToTab(String link) {
    switch (link) {
      case 'edits':     return _Tab.edits;
      case 'approved':  return _Tab.approved;
      case 'dismissed': return _Tab.dismissed;
      default:          return _Tab.pending;
    }
  }

  @override
  void dispose() { _typeTab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<AppState>().allPlacesStream,
      builder: (context, placesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().allServicesStream,
          builder: (context, svcsSnap) {
            final allPlaces = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
            final allSvcs   = svcsSnap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];

            final pendingPlaces   = allPlaces.where((p) => p.listingStatus == ListingStatus.pending).toList();
            final approvedPlaces  = allPlaces.where((p) => p.listingStatus == ListingStatus.approved && p.ownerId != null).toList();
            final dismissedPlaces = allPlaces.where((p) => p.listingStatus == ListingStatus.dismissed).toList();
            final editPlaces      = allPlaces.where((p) => p.pendingEdit != null && p.pendingEdit!.status == EditStatus.pending).toList();

            final pendingSvcs   = allSvcs.where((s) => s.listingStatus == ListingStatus.pending).toList();
            final approvedSvcs  = allSvcs.where((s) => s.listingStatus == ListingStatus.approved ).toList();
            final dismissedSvcs = allSvcs.where((s) => s.listingStatus == ListingStatus.dismissed).toList();
            final editSvcs      = allSvcs.where((s) => s.pendingEdit != null && s.pendingEdit!.status == EditStatus.pending).toList();

            final counts = {
              _Tab.pending:   pendingPlaces.length + pendingSvcs.length,
              _Tab.approved:  approvedPlaces.length + approvedSvcs.length,
              _Tab.dismissed: dismissedPlaces.length + dismissedSvcs.length,
              _Tab.edits:     editPlaces.length + editSvcs.length,
            };
            const labels = {
              _Tab.pending:   'Pending',
              _Tab.approved:  'Approved',
              _Tab.dismissed: 'Dismissed',
              _Tab.edits:     'Edit Requests',
            };
            const chipColors = {
              _Tab.pending:   kWarning,
              _Tab.approved:  Color(0xFF22C55E),
              _Tab.dismissed: kDanger,
              _Tab.edits:     kDeadSeaBlue,
            };

            return Scaffold(
              backgroundColor: context.bg,
              body: SafeArea(child: Column(children: [

                Container(
                  color: context.surface,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Proposals', style: TextStyle(color: context.primary,
                            fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('Review business-submitted listings',
                            style: TextStyle(color: context.secondary, fontSize: 12)),
                      ])),
                      if ((counts[_Tab.pending] ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: kWarning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${counts[_Tab.pending]} pending',
                              style: const TextStyle(color: kWarning, fontSize: 12, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 14),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _Tab.values.map((t) {
                        final sel   = _activeTab == t;
                        final col   = chipColors[t]!;
                        final count = counts[t]!;
                        return GestureDetector(
                          onTap: () => setState(() => _activeTab = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel ? col.withOpacity(0.12) : context.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? col : context.divider, width: sel ? 1.5 : 1)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(labels[t]!, style: TextStyle(
                                  color: sel ? col : context.secondary,
                                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                              if (count > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: col.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text('$count', style: TextStyle(
                                      color: col, fontSize: 10, fontWeight: FontWeight.w800))),
                              ],
                            ]),
                          ),
                        );
                      }).toList()),
                    ),
                    const SizedBox(height: 12),

                    if (_activeTab != _Tab.edits)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: context.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.divider)),
                        child: TabBar(
                          controller: _typeTab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: context.secondary,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          tabs: [
                            Tab(text: 'Places (${_activeTab == _Tab.pending ? pendingPlaces.length : _activeTab == _Tab.approved ? approvedPlaces.length : dismissedPlaces.length})'),
                            Tab(text: 'Services (${_activeTab == _Tab.pending ? pendingSvcs.length : _activeTab == _Tab.approved ? approvedSvcs.length : dismissedSvcs.length})'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ]),
                ),

                Expanded(child: _activeTab == _Tab.edits
                    ? _EditsList(places: editPlaces, services: editSvcs)
                    : TabBarView(controller: _typeTab, children: [
                        _ProposalList(
                          places: _activeTab == _Tab.pending ? pendingPlaces
                              : _activeTab == _Tab.approved ? approvedPlaces : dismissedPlaces,
                          showActions: _activeTab == _Tab.pending,
                          showDelete:  true,
                          emptyMsg: _activeTab == _Tab.pending ? 'No pending place proposals'
                              : _activeTab == _Tab.approved ? 'No approved places' : 'No dismissed places',
                        ),
                        _ServiceList(
                          services: _activeTab == _Tab.pending ? pendingSvcs
                              : _activeTab == _Tab.approved ? approvedSvcs : dismissedSvcs,
                          showActions: _activeTab == _Tab.pending,
                          showDelete:  true,
                          emptyMsg: _activeTab == _Tab.pending ? 'No pending service proposals'
                              : _activeTab == _Tab.approved ? 'No approved services' : 'No dismissed services',
                        ),
                      ])),
              ])),
            );
          },
        );
      },
    );
  }
}

class _ProposalList extends StatelessWidget {
  final List<Place> places;
  final bool showActions, showDelete;
  final String emptyMsg;
  const _ProposalList({required this.places, required this.showActions,
    this.showDelete = false, required this.emptyMsg});
  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return _emptyState(context, emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      itemBuilder: (_, i) => _PlaceCard(place: places[i], showActions: showActions, isAdmin: showDelete),
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<TripService> services;
  final bool showActions, showDelete;
  final String emptyMsg;
  const _ServiceList({required this.services, required this.showActions,
    this.showDelete = false, required this.emptyMsg});
  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return _emptyState(context, emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (_, i) => _ServiceCard(svc: services[i], showActions: showActions, isAdmin: showDelete),
    );
  }
}

class _EditsList extends StatelessWidget {
  final List<Place> places;
  final List<TripService> services;
  const _EditsList({required this.places, required this.services});
  @override
  Widget build(BuildContext context) {
    if (places.isEmpty && services.isEmpty)
      return _emptyState(context, 'No pending edit requests');
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (places.isNotEmpty) ...[
        _sectionLabel(context, 'Place Edit Requests (${places.length})', kWarning),
        const SizedBox(height: 8),
        ...places.map((p) => _PlaceEditCard(place: p)),
        const SizedBox(height: 16),
      ],
      if (services.isNotEmpty) ...[
        _sectionLabel(context, 'Service Edit Requests (${services.length})', kWarning),
        const SizedBox(height: 8),
        ...services.map((s) => _ServiceEditCard(svc: s)),
      ],
    ]);
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  final bool showActions, isAdmin;
  const _PlaceCard({required this.place, this.showActions = true, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: showActions ? kWarning.withOpacity(0.25) : context.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (place.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(height: 130, width: double.infinity,
                  child: placePhoto(place, context))),
          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pill(_catLabel(place.category), kAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(place.name, style: TextStyle(
                  color: context.primary, fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right_rounded, color: context.secondary, size: 18),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.storefront_outlined, size: 12, color: context.secondary),
              const SizedBox(width: 4),
              Expanded(child: Text(
                place.ownerName != null
                    ? '${place.ownerName}  ·  ${place.location}' : place.location,
                style: TextStyle(color: context.secondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            if (place.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(place.description, style: TextStyle(color: context.secondary, fontSize: 13, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _actionBtn(context, 'Dismiss', kDanger, () => _dismiss(context))),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn(context, 'Approve', const Color(0xFF22C55E), () async {
                  try {
                    await context.read<AppState>().approvePlace(place.id, ownerUid: place.ownerId, name: place.name);
                    if (context.mounted) _snack(context, '${place.name} approved ✓', const Color(0xFF22C55E));
                  } catch (e) { if (context.mounted) _snack(context, 'Error: $e', kDanger); }
                })),
              ]),
            ],
            if (isAdmin && !showActions) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: const Text('Delete Permanently'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    side: BorderSide(color: kDanger.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _confirmDelete(context))),
            ],
          ])),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _DetailSheet(
      name: place.name, ownerName: place.ownerName,
      photoUrls: place.photoUrls, description: place.description,
      status: place.isDismissed ? 'dismissed' : place.isApproved ? 'approved' : 'pending',
      details: {
        'Type': _catLabel(place.category), 'Location': place.location,
        if (place.phone != null) 'Phone': place.phone!,
        if (place.hours != null) 'Hours': place.hours!,
        if (place.cuisine != null) 'Cuisine': place.cuisine!,
        if (place.pricePerNight != null) 'Price/Night': 'JD${place.pricePerNight!.toStringAsFixed(0)}',
        if (place.lat != 0) 'GPS': '${place.lat.toStringAsFixed(4)}, ${place.lng.toStringAsFixed(4)}',
      },
      tags: place.tags,
      adminNote: place.adminDismissNote,
      onApprove: (!place.isApproved && !place.isDismissed) ? () async {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await context.read<AppState>().approvePlace(place.id, ownerUid: place.ownerId, name: place.name);
            if (context.mounted) _snack(context, '${place.name} approved ✓', const Color(0xFF22C55E));
          } catch (e) { if (context.mounted) _snack(context, 'Error: $e', kDanger); }
        });
      } : null,
      onDismiss: (!place.isApproved && !place.isDismissed) ? () {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) => _dismiss(context));
      } : null,
    ),
  );

  void _confirmDelete(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dlg.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: kDanger,
                  size: 36,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Delete "${place.name}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              
              Text(
                'This action permanently removes this listing. It cannot be restored.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

             
              Row(
                children: [

                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dlg.secondary,
                        side: BorderSide(color: dlg.divider),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(dlg);

                        try {
                          await context.read<AppState>().adminDeleteListing(
                            place.id,
                            isPlace: true,
                            ownerUid: place.ownerId,
                            name: place.name,
                          );

                          if (context.mounted) {
                            _snack(context, '${place.name} deleted', kDanger);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            _snack(context, 'Delete failed: $e', kDanger);
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
      );
    },
  );
}

  void _dismiss(BuildContext context) {
  final ctrl = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dlg.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
          
                // Warning Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kDanger.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: kDanger,
                    size: 36,
                  ),
                ),
          
                const SizedBox(height: 18),
          
                // Title
                Text(
                  'Dismiss "${place.name}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dlg.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
          
                const SizedBox(height: 10),
          
             
                Text(
                  'Provide a reason for dismissing this business listing. '
                  'The comment will be visible to the business owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dlg.secondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
          
                const SizedBox(height: 18),
          
                // Comment Box
                Container(
                  decoration: BoxDecoration(
                    color: dlg.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: dlg.divider),
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: 4,
                    style: TextStyle(color: dlg.primary),
                    decoration: InputDecoration(
                      hintText: 'Enter dismissal reason...',
                      hintStyle: TextStyle(color: dlg.secondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: Icon(
                          Icons.feedback_outlined,
                          color: kDanger.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
          
                const SizedBox(height: 20),
          
                // Buttons
                Row(
                  children: [
          
                    // Cancel
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dlg.secondary,
                          side: BorderSide(color: dlg.divider),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
          
                    // Dismiss
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Dismiss',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDanger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final note = ctrl.text.trim().isEmpty
                              ? null
                              : ctrl.text.trim();
          
                          Navigator.pop(dlg);
          
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            try {
                              await context.read<AppState>().rejectPlace(
                                place.id,
                                note: note,
                                ownerUid: place.ownerId,
                                name: place.name,
                              );
          
                              if (context.mounted) {
                                _snack(context, 'Place dismissed', kDanger);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _snack(context, 'Error: $e', kDanger);
                              }
                            }
                          });
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
    },
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

class _ServiceCard extends StatelessWidget {
  final TripService svc;
  final bool showActions, isAdmin;
  const _ServiceCard({required this.svc, this.showActions = true, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final catLabel = svc.customCategory.isNotEmpty ? svc.customCategory : svc.category.name;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: showActions ? kWarning.withOpacity(0.25) : context.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (svc.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(height: 130, width: double.infinity,
                  child: servicePhoto(svc, context))),
          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pill(catLabel.toUpperCase(), kDeadSeaBlue),
              const SizedBox(width: 8),
              Expanded(child: Text(svc.name, style: TextStyle(
                  color: context.primary, fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (svc.priceFrom != null) Text('JD${svc.priceFrom!.toInt()}',
                  style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, color: context.secondary, size: 18),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 12, color: context.secondary),
              const SizedBox(width: 4),
              Expanded(child: Text('${svc.ownerName}  ·  ${svc.location}',
                  style: TextStyle(color: context.secondary, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            if (svc.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(svc.description, style: TextStyle(color: context.secondary, fontSize: 13, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _actionBtn(context, 'Dismiss', kDanger, () => _dismiss(context))),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn(context, 'Approve', const Color(0xFF22C55E), () async {
                  try {
                    await context.read<AppState>().approveService(svc.id, ownerUid: svc.ownerId, name: svc.name);
                    if (context.mounted) _snack(context, '${svc.name} approved ✓', const Color(0xFF22C55E));
                  } catch (e) { if (context.mounted) _snack(context, 'Error: $e', kDanger); }
                })),
              ]),
            ],
            if (isAdmin && !showActions) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: const Text('Delete Permanently'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDanger,
                    side: BorderSide(color: kDanger.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _confirmDelete(context))),
            ],
          ])),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _DetailSheet(
      name: svc.name, ownerName: svc.ownerName,
      photoUrls: svc.photoUrls, description: svc.description,
      status: svc.isDismissed ? 'dismissed' : svc.isApproved ? 'approved' : 'pending',
      details: {
        'Category': svc.customCategory.isNotEmpty ? svc.customCategory : svc.category.name,
        'Provider': svc.ownerName, 'Location': svc.location,
        if (svc.phone != null) 'Phone': svc.phone!,
        if (svc.hours != null) 'Hours': svc.hours!,
        if (svc.priceFrom != null) 'Price': 'From JD${svc.priceFrom!.toInt()} ${svc.priceUnit ?? ''}',
        if (svc.whatsapp != null) 'WhatsApp': svc.whatsapp!,
        if (svc.lat != null) 'GPS': '${svc.lat!.toStringAsFixed(4)}, ${svc.lng!.toStringAsFixed(4)}',
      },
      tags: svc.tags,
      adminNote: svc.adminDismissNote,
      onApprove: (!svc.isApproved && !svc.isDismissed) ? () async {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await context.read<AppState>().approveService(svc.id, ownerUid: svc.ownerId, name: svc.name);
            if (context.mounted) _snack(context, '${svc.name} approved ✓', const Color(0xFF22C55E));
          } catch (e) { if (context.mounted) _snack(context, 'Error: $e', kDanger); }
        });
      } : null,
      onDismiss: (!svc.isApproved && !svc.isDismissed) ? () {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) => _dismiss(context));
      } : null,
    ),
  );
void _confirmDelete(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dlg.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: kDanger,
                  size: 36,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Delete "${svc.name}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                'This action permanently removes this listing. It cannot be restored.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              
              Row(
                children: [

                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dlg.secondary,
                        side: BorderSide(color: dlg.divider),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(dlg);

                        try {
                          await context.read<AppState>().adminDeleteListing(
                            svc.id,
                            isPlace: false,
                            ownerUid: svc.ownerId,
                            name: svc.name,
                          );

                          if (context.mounted) {
                            _snack(context, '${svc.name} deleted', kDanger);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            _snack(context, 'Delete failed: $e', kDanger);
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
      );
    },
  );
}
void _dismiss(BuildContext context) {
  final ctrl = TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dlg.card,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Warning Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: kDanger,
                  size: 36,
                ),
              ),

              const SizedBox(height: 18),

              // Title
              Text(
                'Dismiss "${svc.name}"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              Text(
                'Provide a reason for dismissing this business listing. '
                'The comment will be visible to the business owner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dlg.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 18),

              // Comment Box
              Container(
                decoration: BoxDecoration(
                  color: dlg.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dlg.divider),
                ),
                child: TextField(
                  controller: ctrl,
                  maxLines: 4,
                  style: TextStyle(color: dlg.primary),
                  decoration: InputDecoration(
                    hintText: 'Enter dismissal reason...',
                    hintStyle: TextStyle(color: dlg.secondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Icon(
                        Icons.feedback_outlined,
                        color: kDanger.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [

                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dlg.secondary,
                        side: BorderSide(color: dlg.divider),
                        padding: const EdgeInsets.symmetric(vertical: 13),
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

                
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Dismiss',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDanger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final note = ctrl.text.trim().isEmpty
                            ? null
                            : ctrl.text.trim();

                        Navigator.pop(dlg);

                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          try {
                            await context.read<AppState>().rejectPlace(
                              svc.id,
                              note: note,
                              ownerUid: svc.ownerId,
                              name: svc.name,
                            );

                            if (context.mounted) {
                              _snack(context, 'Place dismissed', kDanger);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _snack(context, 'Error: $e', kDanger);
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
}
class _DetailSheet extends StatelessWidget {
  final String name, description, status;
  final String? ownerName, adminNote;
  final List<String> photoUrls, tags;
  final Map<String, String> details;
  final VoidCallback? onApprove, onDismiss;

  const _DetailSheet({
    required this.name, required this.description, required this.status,
    this.ownerName, this.adminNote,
    required this.photoUrls, required this.tags,
    required this.details, this.onApprove, this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(color: context.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
          Expanded(child: SingleChildScrollView(
            controller: sc,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: photoUrls.first.startsWith('http')
                        ? Image.network(photoUrls.first, fit: BoxFit.cover,
                            loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE8E8E8)),
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8)))
                        : Image.file(File(photoUrls.first), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE8E8E8))),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _pill(_statusLabel(), _statusColor()),
                  const SizedBox(height: 10),
                  Text(name, style: TextStyle(color: context.primary,
                      fontSize: 20, fontWeight: FontWeight.w800)),
                  if (ownerName != null) ...[
                    const SizedBox(height: 4),
                    Text('Submitted by $ownerName',
                        style: TextStyle(color: context.secondary, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  if (description.isNotEmpty) ...[
                    Text(description, style: TextStyle(color: context.secondary, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: context.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.divider)),
                    child: Column(children: details.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 80, child: Text(e.key, style: TextStyle(
                            color: context.secondary, fontSize: 12, fontWeight: FontWeight.w600))),
                        Expanded(child: Text(e.value,
                            style: TextStyle(color: context.primary, fontSize: 13))),
                      ]),
                    )).toList()),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 6, children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: context.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.divider)),
                      child: Text(t, style: TextStyle(color: context.secondary, fontSize: 12)),
                    )).toList()),
                  ],
                  if (adminNote != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kDanger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kDanger.withOpacity(0.2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Dismiss reason:', style: TextStyle(color: kDanger, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(adminNote!, style: TextStyle(color: context.secondary, fontSize: 13)),
                      ]),
                    ),
                  ],
                  if (onApprove != null || onDismiss != null) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      if (onDismiss != null) Expanded(child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: kDanger,
                            side: const BorderSide(color: kDanger),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: onDismiss, child: const Text('Dismiss'))),
                      if (onDismiss != null && onApprove != null) const SizedBox(width: 12),
                      if (onApprove != null) Expanded(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white, elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: onApprove, child: const Text('Approve'))),
                    ]),
                  ],
                ]),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Color _statusColor() {
    switch (status) {
      case 'approved':  return const Color(0xFF22C55E);
      case 'dismissed': return kDanger;
      default:          return kWarning;
    }
  }
  String _statusLabel() {
    switch (status) {
      case 'approved':  return 'Approved';
      case 'dismissed': return 'Dismissed';
      default:          return 'Pending Review';
    }
  }
}

class _PlaceEditCard extends StatefulWidget {
  final Place place;
  const _PlaceEditCard({required this.place});
  @override
  State<_PlaceEditCard> createState() => _PlaceEditCardState();
}
class _PlaceEditCardState extends State<_PlaceEditCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final e = p.pendingEdit!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kWarning.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kWarning.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(14),
                    bottom: _expanded ? Radius.zero : const Radius.circular(14))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Edit request — tap to view changes',
                    style: TextStyle(color: kWarning, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kWarning),
            ]),
          ),
        ),
        if (_expanded) Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          _diff(context, 'Name', p.name, e.name),
          _diff(context, 'Description', p.description, e.description),
          _diff(context, 'Location', p.location, e.location),
          if ((e.phone ?? '') != (p.phone ?? '')) _diff(context, 'Phone', p.phone ?? '—', e.phone ?? '—'),
          if ((e.hours ?? '') != (p.hours ?? '')) _diff(context, 'Hours', p.hours ?? '—', e.hours ?? '—'),
          if ((e.cuisine ?? '') != (p.cuisine ?? '')) _diff(context, 'Cuisine', p.cuisine ?? '—', e.cuisine ?? '—'),
          if (e.pricePerNight != p.pricePerNight)
            _diff(context, 'Price/Night',
                p.pricePerNight != null ? 'JD${p.pricePerNight!.toStringAsFixed(0)}' : '—',
                e.pricePerNight != null ? 'JD${e.pricePerNight!.toStringAsFixed(0)}' : '—'),
          if (e.tags.join(',') != p.tags.join(','))
            _diff(context, 'Tags', p.tags.join(', '), e.tags.join(', ')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _rejectEdit(context),
              child: const Text('Reject'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final editMap = {
                  'name': e.name, 'description': e.description, 'location': e.location,
                  if (e.phone != null) 'phone': e.phone,
                  if (e.hours != null) 'hours': e.hours,
                  if (e.cuisine != null) 'cuisine': e.cuisine,
                  if (e.pricePerNight != null) 'pricePerNight': e.pricePerNight,
                  'tags': e.tags,
                  if (e.photoUrls.isNotEmpty) 'photoUrls': e.photoUrls,
                };
                await context.read<AppState>().approvePlaceEdit(p.id, editMap, ownerUid: p.ownerId, name: p.name);
                if (context.mounted) _snack(context, 'Edit approved', const Color(0xFF22C55E));
              },
              child: const Text('Approve'))),
          ]),
        ])),
      ]),
    );
  }
  void _rejectEdit(BuildContext context) {
  final ctrl = TextEditingController();
  String? error;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: SingleChildScrollView(
              child: Container(
                
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dlg.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kDanger.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_off_rounded,
                        color: kDanger,
                        size: 36,
                      ),
                    ),
              
                    const SizedBox(height: 18),
              
                    Text(
                      'Reject Edit Request?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dlg.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              
                    const SizedBox(height: 10),
              
                    Text(
                      'Provide a reason for rejecting this edit request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dlg.secondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
              
                    const SizedBox(height: 18),
              
                    Container(
                      decoration: BoxDecoration(
                        color: dlg.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: error != null ? kDanger : dlg.divider,
                        ),
                      ),
                      child: TextField(
                        controller: ctrl,
                        maxLines: 4,
                        style: TextStyle(color: dlg.primary),
                        decoration: InputDecoration(
                          hintText: 'Enter rejection reason...',
                          errorText: error,
                          hintStyle: TextStyle(color: dlg.secondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
              
                    const SizedBox(height: 20),
              
                    Row(
                      children: [
              
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dlg),
                            child: const Text('Cancel'),
                          ),
                        ),
              
                        const SizedBox(width: 12),
              
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDanger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
              
                              final note = ctrl.text.trim();
              
                              if (note.isEmpty) {
                                setStateDialog(() {
                                  error = 'Reason is required';
                                });
                                return;
                              }
              
                              Navigator.pop(dlg);
              
                              try {
              
                                await context.read<AppState>().rejectPlaceEdit(
                                  widget.place.id,
                                  ownerUid: widget.place.ownerId,
                                  name: widget.place.name,
                                  note: note,
                                );
              
                                if (context.mounted) {
                                  _snack(context, 'Edit rejected', kDanger);
                                }
              
                              } catch (e) {
              
                                if (context.mounted) {
                                  _snack(context, 'Error: $e', kDanger);
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
        },
      );
    },
  );
}
}

class _ServiceEditCard extends StatefulWidget {
  final TripService svc;
  const _ServiceEditCard({required this.svc});
  @override
  State<_ServiceEditCard> createState() => _ServiceEditCardState();
}
class _ServiceEditCardState extends State<_ServiceEditCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.svc;
    final e = s.pendingEdit!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kWarning.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kWarning.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(14),
                    bottom: _expanded ? Radius.zero : const Radius.circular(14))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: TextStyle(color: context.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Edit request — tap to view changes',
                    style: TextStyle(color: kWarning, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kWarning),
            ]),
          ),
        ),
        if (_expanded) Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          if (s.name != e.name) _diff(context, 'Name', s.name, e.name),
          if (s.description != e.description) _diff(context, 'Description', s.description, e.description),
          if (s.location != e.location) _diff(context, 'Location', s.location, e.location),
          if ((s.phone ?? '') != (e.phone ?? '')) _diff(context, 'Phone', s.phone ?? '—', e.phone ?? '—'),
          if ((s.hours ?? '') != (e.hours ?? '')) _diff(context, 'Hours', s.hours ?? '—', e.hours ?? '—'),
          if (s.priceFrom != e.priceFrom)
            _diff(context, 'Price', s.priceFrom != null ? 'JD${s.priceFrom!.toInt()}' : '—',
                e.priceFrom != null ? 'JD${e.priceFrom!.toInt()}' : '—'),
          if (s.tags.join(',') != e.tags.join(','))
            _diff(context, 'Tags', s.tags.join(', '), e.tags.join(', ')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
             onPressed: () => _rejectEdit(context),
              child: const Text('Reject'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final editMap = {
                  'name': e.name, 'description': e.description, 'location': e.location,
                  if (e.phone != null) 'phone': e.phone,
                  if (e.hours != null) 'hours': e.hours,
                  if (e.priceFrom != null) 'priceFrom': e.priceFrom,
                  'tags': e.tags,
                };
                await context.read<AppState>().approveServiceEdit(s.id, editMap, ownerUid: s.ownerId, name: s.name);
                if (context.mounted) _snack(context, 'Edit approved', const Color(0xFF22C55E));
              },
              child: const Text('Approve'))),
          ]),
        ])),
      ]),
    );
  }
  void _rejectEdit(BuildContext context) {
  final ctrl = TextEditingController();
  String? error;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dlg) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return SingleChildScrollView(
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: dlg.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kDanger.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_off_rounded,
                        color: kDanger,
                        size: 36,
                      ),
                    ),
            
                    const SizedBox(height: 18),
            
                    Text(
                      'Reject Edit Request?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dlg.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            
                    const SizedBox(height: 10),
            
                    Text(
                      'Provide a reason for rejecting this edit request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dlg.secondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
            
                    const SizedBox(height: 18),
            
                    Container(
                      decoration: BoxDecoration(
                        color: dlg.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: error != null ? kDanger : dlg.divider,
                        ),
                      ),
                      child: TextField(
                        controller: ctrl,
                        maxLines: 4,
                        style: TextStyle(color: dlg.primary),
                        decoration: InputDecoration(
                          hintText: 'Enter rejection reason...',
                          errorText: error,
                          hintStyle: TextStyle(color: dlg.secondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
            
                    const SizedBox(height: 20),
            
                    Row(
                      children: [
            
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dlg),
                            child: const Text('Cancel'),
                          ),
                        ),
            
                        const SizedBox(width: 12),
            
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDanger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
            
                              final note = ctrl.text.trim();
            
                              if (note.isEmpty) {
                                setStateDialog(() {
                                  error = 'Reason is required';
                                });
                                return;
                              }
            
                              Navigator.pop(dlg);
            
                              try {
            
                                await context.read<AppState>().rejectPlaceEdit(
                                  widget.svc.id,
                                  ownerUid: widget.svc.ownerId,
                                  name: widget.svc.name,
                                  note: note,
                                );
            
                                if (context.mounted) {
                                  _snack(context, 'Edit rejected', kDanger);
                                }
            
                              } catch (e) {
            
                                if (context.mounted) {
                                  _snack(context, 'Error: $e', kDanger);
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
        },
      );
    },
  );
}
}

Widget _pill(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
  child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)));

Widget _diff(BuildContext ctx, String field, String oldV, String newV) {
  if (oldV == newV) return const SizedBox.shrink();
  return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(field, style: TextStyle(color: ctx.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kDanger.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
        child: Text(oldV, style: const TextStyle(color: kDanger, fontSize: 12, decoration: TextDecoration.lineThrough),
            maxLines: 2, overflow: TextOverflow.ellipsis))),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 14, color: kAccent)),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: kAccent.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
        child: Text(newV, style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis))),
    ]),
  ]));
}

Widget _actionBtn(BuildContext ctx, String label, Color color, VoidCallback onTap) =>
    OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color, side: BorderSide(color: color.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      onPressed: onTap, child: Text(label));

Widget _sectionLabel(BuildContext ctx, String text, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(color: ctx.primary, fontSize: 13, fontWeight: FontWeight.w700)),
  ]));

Widget _emptyState(BuildContext ctx, String msg) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
  Icon(Icons.inbox_outlined, size: 48, color: ctx.secondary.withOpacity(0.3)),
  const SizedBox(height: 12),
  Text(msg, style: TextStyle(color: ctx.secondary, fontSize: 14)),
]));

void _snack(BuildContext ctx, String msg, Color color) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));