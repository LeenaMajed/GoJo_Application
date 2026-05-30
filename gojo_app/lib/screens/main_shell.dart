import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
import '../theme.dart';
//import '../services/app_state.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';

// Services removed from nav bar — accessible from Home quick actions only
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() { super.initState(); _index = widget.initialIndex; }

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore_rounded), label: 'Explore'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark_rounded), label: 'Saved'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
