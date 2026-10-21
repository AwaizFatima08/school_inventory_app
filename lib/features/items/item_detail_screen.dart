import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';
import 'item_form_screen.dart';

/// One item: stock, and its full movement history (ledger).
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemByIdProvider(itemId));
    final me = ref.watch(currentMemberProvider);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (me.can(Capability.manageItems))
            IconButton(
              tooltip: 'Edit item',
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ItemFormScreen(item: item)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _StockCard(item: item, canAdjust: me.can(Capability.adjustStock)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: AsyncView(
              value: ref.watch(itemLedgerProvider(itemId)),
              builder: (entries) => entries.isEmpty
                  ? const EmptyState(icon: Icons.history, message: 'No movements yet.')
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => LedgerTile(entry: entries[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item, required this.canAdjust});
  final Item item;
  final bool canAdjust;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.currentStock} ${item.unit}', style: t.headlineMedium),
                  Text(item.isOut
                      ? 'Out of stock'
                      : item.isLow
                          ? 'Low — reorder level ${item.reorderLevel}'
                          : 'Reorder level ${item.reorderLevel}'),
                ],
              ),
            ),
            if (canAdjust)
              OutlinedButton.icon(
                icon: const Icon(Icons.rule),
                label: const Text('Count'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdjustStockDialog(item: item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One stock movement.
class LedgerTile extends StatelessWidget {
  const LedgerTile({required this.entry, this.showItem = false, super.key});
  final LedgerEntry entry;
  final bool showItem;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final sign = e.delta > 0 ? '+' : '';
    final who = switch (e.type) {
      MoveType.issue => 'to ${e.staffName}',
      MoveType.receipt => '',
      MoveType.adjustment => 'count correction: ${e.reason}',
    };
    return ListTile(
      dense: true,
      leading: Icon(switch (e.type) {
        MoveType.issue => Icons.outbox,
        MoveType.receipt => Icons.move_to_inbox,
        MoveType.adjustment => Icons.rule,
      }),
      title: Text(showItem
          ? '${e.itemName} · ${who.isEmpty ? e.type.label : who}'
          : '${e.type.label} $who'.trim()),
      subtitle: Text('${formatDateTime(e.at)} · by ${e.byName}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$sign${e.delta} ${e.unit}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: e.delta < 0 ? Colors.red.shade700 : Colors.green.shade700,
              )),
          Text('bal ${e.balanceAfter}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Incharge records a physical count; the difference is logged.
class AdjustStockDialog extends ConsumerStatefulWidget {
  const AdjustStockDialog({required this.item, super.key});
  final Item item;

  @override
  ConsumerState<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<AdjustStockDialog> {
  late final _count = TextEditingController(text: '${widget.item.currentStock}');
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _count.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final counted = int.tryParse(_count.text);
    if (counted == null || _reason.text.trim().length < 3) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).adjustStock(
            item: widget.item,
            countedStock: counted,
            reason: _reason.text,
            by: ref.read(actorProvider),
          ),
      success: 'Stock corrected.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Physical count: ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('System stock: ${widget.item.currentStock} ${widget.item.unit}'),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Counted on the shelf'),
          ),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'e.g. Monthly count, damaged, expired',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
