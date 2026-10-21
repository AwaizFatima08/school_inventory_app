import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';

/// Current stock of every item, with search.
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String _query = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentMemberProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            tooltip: _showInactive ? 'Hide inactive items' : 'Show inactive items',
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: me.can(Capability.manageItems)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New item'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ItemFormScreen()),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncView(
              value: ref.watch(itemsProvider),
              builder: (all) {
                final items = all
                    .where((i) => _showInactive || i.active)
                    .where((i) => i.name.toLowerCase().contains(_query))
                    .toList();
                if (items.isEmpty) {
                  return const EmptyState(
                      icon: Icons.inventory_2_outlined, message: 'No items.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _ItemTile(item: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final color = item.isOut
        ? Colors.red.shade700
        : item.isLow
            ? Colors.orange.shade800
            : null;
    return ListTile(
      title: Text(item.name + (item.active ? '' : ' (inactive)')),
      subtitle: Text('Reorder at ${item.reorderLevel} ${item.unit}'),
      trailing: Text(
        '${item.currentStock} ${item.unit}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: item.id)),
      ),
    );
  }
}
