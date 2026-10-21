import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/inventory_repository.dart';
import '../../domain/models.dart';
import '../common/async_view.dart';
import '../common/qty_field.dart';
import '../common/ui_helpers.dart';

/// Supervisor records stock that arrived (or the opening stock).
/// Stock goes up only after the incharge approves.
class NewReceiptScreen extends ConsumerStatefulWidget {
  const NewReceiptScreen({super.key});

  @override
  ConsumerState<NewReceiptScreen> createState() => _NewReceiptScreenState();
}

class _NewReceiptScreenState extends ConsumerState<NewReceiptScreen> {
  final _source = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final Map<String, int> _qty = {};
  bool _busy = false;

  @override
  void dispose() {
    _source.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<Item> items) async {
    if (_source.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter where the stock came from (or "Opening stock").'),
      ));
      return;
    }
    final lines = [
      for (final i in items)
        if ((_qty[i.id] ?? 0) > 0)
          ReceiptLine(itemId: i.id, itemName: i.name, unit: i.unit, qty: _qty[i.id]!),
    ];
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).createReceipt(
            source: _source.text,
            reference: _reference.text,
            note: _note.text,
            lines: lines,
            by: ref.read(actorProvider),
          ),
      success: 'Sent to the incharge for approval.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final itemsValue = ref.watch(itemsProvider);
    final picked = _qty.values.where((q) => q > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Receive stock')),
      body: AsyncView(
        value: itemsValue,
        builder: (all) {
          final items = all.where((i) => i.active).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              TextField(
                controller: _source,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Received from',
                  hintText: 'Supplier / store / "Opening stock"',
                ),
              ),
              Wrap(spacing: 6, children: [
                for (final s in const ['Opening stock', 'Main store', 'Local purchase'])
                  ActionChip(label: Text(s), onPressed: () => _source.text = s),
              ]),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(labelText: 'Bill / challan no. (optional)'),
              ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              Text('Quantities received ($picked / ${InventoryRepository.maxLinesPerDocument} max)',
                  style: Theme.of(context).textTheme.titleMedium),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('Now: ${item.currentStock} ${item.unit}'),
                  trailing: QtyField(
                    value: _qty[item.id] ?? 0,
                    onChanged: (v) => setState(() => _qty[item.id] = v),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: Text('Send for approval ($picked items)'),
            onPressed: _busy || picked == 0
                ? null
                : () => _save(itemsValue.value ?? const []),
          ),
        ),
      ),
    );
  }
}
