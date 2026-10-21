import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../../domain/stock_logic.dart';
import '../demands/demand_detail_screen.dart';
import '../demands/demands_screen.dart';
import '../demands/new_demand_screen.dart';
import '../items/item_detail_screen.dart';
import '../receipts/new_receipt_screen.dart';
import '../receipts/receipts_screen.dart';

/// Home: what needs my attention now, plus low stock.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(currentOrgProvider);
    final me = ref.watch(currentMemberProvider);
    final pendingDemands =
        ref.watch(demandsProvider(DocStatus.pending)).value ?? const [];
    final approvedDemands =
        ref.watch(demandsProvider(DocStatus.approved)).value ?? const [];
    final pendingReceipts =
        ref.watch(receiptsProvider(DocStatus.pending)).value ?? const [];
    final low = StockLogic.lowStock(ref.watch(itemsProvider).value ?? const []);

    return Scaffold(
      appBar: AppBar(title: Text(org.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Assalam o Alaikum, ${me.displayName}',
              style: Theme.of(context).textTheme.titleLarge),
          Text(me.role.label + (me.isAdmin ? ' · Admin' : '')),
          const SizedBox(height: 16),
          if (me.can(Capability.approveDemand))
            _TaskTile(
              icon: Icons.fact_check_outlined,
              label: 'Demands to approve',
              count: pendingDemands.length,
              onTap: () => _open(context, const DemandsScreen(initialTab: 0)),
            ),
          if (me.can(Capability.issueDemand))
            _TaskTile(
              icon: Icons.outbox_outlined,
              label: 'Approved demands to issue',
              count: approvedDemands.length,
              onTap: () => _open(context, const DemandsScreen(initialTab: 1)),
            ),
          if (me.can(Capability.recordDemand) && !me.can(Capability.approveDemand))
            _TaskTile(
              icon: Icons.hourglass_top,
              label: 'Demands waiting for incharge',
              count: pendingDemands.length,
              onTap: () => _open(context, const DemandsScreen(initialTab: 0)),
            ),
          _TaskTile(
            icon: Icons.move_to_inbox_outlined,
            label: me.can(Capability.approveReceipt)
                ? 'Stock receipts to approve'
                : 'Stock receipts waiting for incharge',
            count: pendingReceipts.length,
            onTap: () => _open(context, const ReceiptsScreen()),
          ),
          const SizedBox(height: 8),
          _QuickActions(me: me),
          const SizedBox(height: 16),
          Text('Low stock (${low.length})',
              style: Theme.of(context).textTheme.titleMedium),
          if (low.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('All items are above their reorder level.'),
            ),
          for (final item in low) _LowStockTile(item: item),
          if (pendingDemands.isNotEmpty && me.can(Capability.approveDemand)) ...[
            const SizedBox(height: 16),
            Text('Latest demands', style: Theme.of(context).textTheme.titleMedium),
            for (final d in pendingDemands.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(d.staffName),
                subtitle: Text('${d.lines.length} item(s) · slip ${d.slipNo}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, DemandDetailScreen(demandId: d.id)),
              ),
          ],
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.me});
  final Member me;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (me.can(Capability.recordDemand))
          FilledButton.icon(
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Enter demand slip'),
            onPressed: () =>
                DashboardScreen._open(context, const NewDemandScreen()),
          ),
        if (me.can(Capability.recordReceipt))
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Receive stock'),
            onPressed: () =>
                DashboardScreen._open(context, const NewReceiptScreen()),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: c.primary),
        title: Text(label),
        trailing: CircleAvatar(
          radius: 16,
          backgroundColor: count > 0 ? c.primary : c.surfaceContainerHighest,
          child: Text('$count',
              style: TextStyle(color: count > 0 ? c.onPrimary : c.onSurface)),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.isOut ? Icons.error : Icons.warning_amber,
        color: item.isOut ? Colors.red.shade700 : Colors.orange.shade800,
      ),
      title: Text(item.name),
      subtitle: Text('Reorder at ${item.reorderLevel} ${item.unit}'),
      trailing: Text('${item.currentStock} ${item.unit}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => DashboardScreen._open(context, ItemDetailScreen(itemId: item.id)),
    );
  }
}
