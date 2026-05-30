import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import '../../services/app_state.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import 'admin_dashboard_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  final int initialIndex;
  const AdminShell({super.key, this.initialIndex = 0});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _index;
  String _listingsDeepLink = '';

  @override
  void initState() { super.initState(); _index = widget.initialIndex; }

  void navigateTo(int i, {String deepLink = ''}) =>
      setState(() { _index = i; _listingsDeepLink = deepLink; });

  @override
  Widget build(BuildContext context) {
    // Pending badge count comes from live Firestore streams — no cache reads.
    return StreamBuilder<QuerySnapshot>(
      stream: context.read<AppState>().allPlacesStream,
      builder: (context, placesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: context.read<AppState>().allServicesStream,
          builder: (context, svcsSnap) {
            final places = placesSnap.data?.docs.map(FirebaseService.placeFromDoc).toList() ?? [];
            final svcs   = svcsSnap.data?.docs.map(FirebaseService.serviceFromDoc).toList() ?? [];

            final pendingCount =
                places.where((p) => p.listingStatus == ListingStatus.pending).length +
                svcs.where((s)   => s.listingStatus == ListingStatus.pending).length +
                places.where((p) => p.pendingEdit != null && p.pendingEdit!.status == EditStatus.pending).length +
                svcs.where((s)   => s.pendingEdit != null && s.pendingEdit!.status == EditStatus.pending).length;

            return Scaffold(
              body: IndexedStack(index: _index, children: [
                AdminDashboardScreen(onNavigate: navigateTo),
                AdminListingsScreen(initialDeepLink: _listingsDeepLink),
               
                const AdminUsersScreen(),
              ]),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.divider)),
                  color: context.surface,
                ),
                child: BottomNavigationBar(
                  currentIndex: _index,
                  onTap: (i) => setState(() { _index = i; _listingsDeepLink = ''; }),
                  backgroundColor: context.surface,
                  selectedItemColor: kAccent,
                  unselectedItemColor: context.secondary,
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                  items: [
                    const BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(Icons.dashboard_rounded),
                        label: 'Dashboard'),
                    BottomNavigationBarItem(
                      icon: _badge(Icons.layers_outlined, pendingCount),
                      activeIcon: _badge(Icons.layers_rounded, pendingCount),
                      label: 'Proposals'),
                   
                    const BottomNavigationBarItem(
                        icon: Icon(Icons.people_outlined),
                        activeIcon: Icon(Icons.people_rounded),
                        label: 'Users'),
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
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(color: kDanger, shape: BoxShape.circle),
        child: Text('$count', style: const TextStyle(
            color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
      )),
    ]);
  }
}