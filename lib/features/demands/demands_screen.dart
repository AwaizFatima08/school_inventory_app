import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';
import 'demand_detail_screen.dart';
import 'new_demand_screen.dart';

/// Demands grouped by status in tabs.
class DemandsScreen extends ConsumerWidget {
  const DemandsScreen({this.initialTab = 0, super.key});
  final int initialTab;

  static const _tabs = <(String, DocStatus?)>[
    ('Pending', DocStatus.pending),
    ('Approved', DocStatus.approved),
    ('Issued', DocStatus.issued),
    ('All', null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider);
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demands'),
          bottom: TabBar(tabs: [for (final t in _tabs) Tab(text: t.$1)]),
        ),
        floatingActionButton: me.can(Capability.recordDemand)
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Enter slip'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NewDemandScreen()),
                ),
              )
            : null,
        body: TabBarView(
          children: [for (final t in _tabs) _DemandList(status: t.$2)],
        ),
      ),
    );
  }
}

class _DemandList extends ConsumerWidget {
  const _DemandList({required this.status});
  final DocStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(demandsProvider(status)),
      builder: (demands) => demands.isEmpty
          ? const EmptyState(icon: Icons.assignment_outlined, message: 'No demands here.')
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: demands.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => DemandTile(demand: demands[i]),
            ),
    );
  }
}

/// One demand in a list.
class DemandTile extends StatelessWidget {
  const DemandTile({required this.demand, super.key});
  final Demand demand;

  @override
  Widget build(BuildContext context) {
    final items = demand.lines.map((l) => l.itemName).join(', ');
    return ListTile(
      title: Text(demand.staffName),
      subtitle: Text(
        '${demand.slipNo.isEmpty ? '' : 'Slip ${demand.slipNo} · '}'
        '${formatDateTime(demand.createdAt)}\n$items',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: StatusChip(demand.status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DemandDetailScreen(demandId: demand.id),
        ),
      ),
    );
  }
}
