import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../common/ui_helpers.dart';

/// Add or edit an item. Stock is never typed here — it changes only through
/// receipts, issues and adjustments.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({this.item, super.key});
  final Item? item;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  static const _units = ['pcs', 'bottle', 'packet', 'bar', 'can', 'litre', 'kg', 'roll', 'box', 'pair'];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _unit = TextEditingController(text: widget.item?.unit ?? 'pcs');
  late final _reorder =
      TextEditingController(text: '${widget.item?.reorderLevel ?? 5}');
  late bool _active = widget.item?.active ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _reorder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(inventoryRepositoryProvider).saveItem(
            id: widget.item?.id,
            name: _name.text,
            unit: _unit.text,
            reorderLevel: int.parse(_reorder.text),
            active: _active,
            by: ref.read(actorProvider),
          ),
      success: widget.item == null
          ? 'Item added. Record its opening stock with "Receive stock".'
          : 'Item saved.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'New item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit (pcs, bottle, packet…)'),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.length > 20 ? 'Required, max 20 letters' : null;
              },
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final u in _units)
                  ActionChip(label: Text(u), onPressed: () => _unit.text = u),
              ],
            ),
            TextFormField(
              controller: _reorder,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Reorder level',
                helperText: 'Shown as "low stock" at or below this quantity',
              ),
              validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
            ),
            if (editing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive items are hidden from new slips'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
