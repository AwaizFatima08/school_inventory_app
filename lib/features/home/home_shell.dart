import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_screen.dart';
import '../demands/demands_screen.dart';
import '../items/items_screen.dart';
import '../settings/more_screen.dart';

/// Window width from which the desktop layout (side rail) is used.
const wideLayoutWidth = 800.0;

/// Main navigation for an active member: a bottom bar on phones and a side
/// rail on desktop-width windows.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    DemandsScreen(),
    ItemsScreen(),
    MoreScreen(),
  ];

  static const _labels = <(IconData, String)>[
    (Icons.dashboard_outlined, 'Home'),
    (Icons.assignment_outlined, 'Demands'),
    (Icons.inventory_2_outlined, 'Stock'),
    (Icons.menu, 'More'),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(index: _index, children: _pages);
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 200,
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final (icon, label) in _labels)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final (icon, label) in _labels)
            NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }
}
