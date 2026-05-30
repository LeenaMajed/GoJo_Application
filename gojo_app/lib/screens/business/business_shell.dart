import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import 'business_home_screen.dart';
import 'business_add_listing_screen.dart';
import 'business_profile_screen.dart';

class BusinessShell extends StatefulWidget {
  final int initialIndex;
  const BusinessShell({super.key, this.initialIndex = 0});
  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  late int _index;

  @override
  void initState() { super.initState(); _index = widget.initialIndex; }

  final _screens = const [
    BusinessHomeScreen(),
    BusinessAddListingScreen(),
    BusinessProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user  = state.user;
    if (user == null) return const SizedBox.shrink();

    // Pending badge: stream both collections, count non-approved docs for this owner.
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<AppState>().businessPlacesStream(user.id),
      builder: (context, placesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().businessServicesStream(user.id),
          builder: (context, svcsSnap) {
            final myPlaces   = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
            final myServices = svcsSnap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];

            final pendingCount =
                myPlaces.where((p) => p.listingStatus == ListingStatus.pending).length +
                myServices.where((s) => s.listingStatus == ListingStatus.pending).length;

            return Scaffold(
              body: IndexedStack(index: _index, children: _screens),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.divider, width: 1)),
                  color: context.surface,
                ),
                child: BottomNavigationBar(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                  backgroundColor: context.surface,
                  selectedItemColor: kAccent,
                  unselectedItemColor: context.secondary,
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                  items: [
                    BottomNavigationBarItem(
                      icon: _badge(Icons.storefront_outlined, pendingCount),
                      activeIcon: _badge(Icons.storefront_rounded, pendingCount),
                      label: 'My Listings',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle_outline_rounded),
                      activeIcon: Icon(Icons.add_circle_rounded),
                      label: 'Add Listing',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded),
                      activeIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      Positioned(right: -5, top: -3, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: kWarning, borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
      )),
    ]);
  }
}