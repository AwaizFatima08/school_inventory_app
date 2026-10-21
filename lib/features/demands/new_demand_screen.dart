import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/inventory_repository.dart';
import '../../domain/models.dart';
import '../common/async_view.dart';
import '../common/qty_field.dart';
import '../common/ui_helpers.dart';
import '../staff/staff_screen.dart';

/// Supervisor enters a staff member's paper demand slip.
class NewDemandScreen extends ConsumerStatefulWidget {
  const NewDemandScreen({super.key});

  @override
  ConsumerState<NewDemandScreen> createState() => _NewDemandScreenState();
}

class _NewDemandScreenState extends ConsumerState<NewDemandScreen> {
  final _slip = TextEditingController();
  final _note = TextEditingController();
  final Map<String, int> _qty = {};
  StaffMember? _staff;
  bool _busy = false;

  @override
  void dispose() {
    _slip.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<Item> items) async {
    final staff = _staff;
    if (staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the staff member who gave the slip.')),
      );
      return;
    }
    final lines = [
      for (final i in items)
        if ((_qty[i.id] ?? 0) > 0)
          DemandLine(
            itemId: i.id,
            itemName: i.name,
            unit: i.unit,
            qtyRequested: _qty[i.id]!,
          ),
    ];
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).createDemand(
            staff: staff,
            slipNo: _slip.text,
            note: _note.text,
            lines: lines,
            by: ref.read(actorProvider),
          ),
      success: 'Demand sent to the incharge for approval.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final staffList =
        (ref.watch(staffProvider).value ?? const []).where((s) => s.active).toList();
    final itemsValue = ref.watch(itemsProvider);
    final picked = _qty.values.where((q) => q > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Enter demand slip')),
      body: AsyncView(
        value: itemsValue,
        builder: (all) {
          final items = all.where((i) => i.active).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _StaffPicker(
                staff: staffList,
                selected: _staff,
                onChanged: (s) => setState(() => _staff = s),
              ),
              TextField(
                controller: _slip,
                decoration: const InputDecoration(labelText: 'Slip number (optional)'),
              ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              Text('Items requested ($picked / ${InventoryRepository.maxLinesPerDocument} max)',
                  style: Theme.of(context).textTheme.titleMedium),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('In stock: ${item.currentStock} ${item.unit}'),
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

class _StaffPicker extends StatelessWidget {
  const _StaffPicker({
    required this.staff,
    required this.selected,
    required this.onChanged,
  });
  final List<StaffMember> staff;
  final StaffMember? selected;
  final ValueChanged<StaffMember?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_add_alt),
        title: const Text('No staff members yet'),
        subtitle: const Text('Add janitorial staff first.'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: selected?.id,
      decoration: const InputDecoration(labelText: 'Staff member (on the slip)'),
      items: [
        for (final s in staff)
          DropdownMenuItem(
            value: s.id,
            child: Text(s.dutyArea.isEmpty ? s.name : '${s.name} · ${s.dutyArea}'),
          ),
      ],
      onChanged: (id) => onChanged(
        staff.where((s) => s.id == id).firstOrNull,
      ),
    );
  }
}
