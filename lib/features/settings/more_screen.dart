import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/roles.dart';
import '../members/members_screen.dart';
import '../receipts/receipts_screen.dart';
import '../reports/reports_screen.dart';
import '../staff/staff_screen.dart';

/// Secondary destinations and account actions.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider);
    final org = ref.watch(currentOrgProvider);
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.move_to_inbox_outlined),
            title: const Text('Stock received'),
            subtitle: const Text('Purchases, store issues, opening stock'),
            onTap: () => open(const ReceiptsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Janitorial staff'),
            subtitle: const Text('People who bring demand slips'),
            onTap: () => open(const StaffScreen()),
          ),
          if (me.can(Capability.viewReports))
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reports'),
              subtitle: const Text('Monthly consumption, CSV export'),
              onTap: () => open(const ReportsScreen()),
            ),
          if (me.can(Capability.manageMembers))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Users & roles'),
              subtitle: Text('Approve requests · school code ${org.joinCode}'),
              onTap: () => open(const MembersScreen()),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(me.displayName),
            subtitle: Text('${me.email}\n${me.role.label}${me.isAdmin ? ' · Admin' : ''}'),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(accountRepositoryProvider).signOut(),
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'School Inventory',
            applicationVersion: '1.0.0',
            applicationLegalese: '© HomiLabs',
          ),
        ],
      ),
    );
  }
}
