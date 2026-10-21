import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../common/async_view.dart';
import '../common/ui_helpers.dart';
import 'new_receipt_screen.dart';

/// Stock receipts: pending ones first.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stock received'),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'All')]),
        ),
        floatingActionButton: me.can(Capability.recordReceipt)
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Receive stock'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NewReceiptScreen()),
                ),
              )
            : null,
        body: const TabBarView(children: [
          _ReceiptList(status: DocStatus.pending),
          _ReceiptList(status: null),
        ]),
      ),
    );
  }
}

class _ReceiptList extends ConsumerWidget {
  const _ReceiptList({required this.status});
  final DocStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(receiptsProvider(status)),
      builder: (list) => list.isEmpty
          ? const EmptyState(icon: Icons.move_to_inbox_outlined, message: 'Nothing here.')
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _ReceiptTile(receipt: list[i]),
            ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    return ListTile(
      title: Text(r.source + (r.reference.isEmpty ? '' : ' · ${r.reference}')),
      subtitle: Text('${formatDateTime(r.createdAt)} · ${r.createdByName}\n'
          '${r.lines.map((l) => '${l.itemName} ${l.qty}').join(', ')}'),
      isThreeLine: true,
      trailing: StatusChip(r.status),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReceiptDetailScreen(receiptId: r.id),
      )),
    );
  }
}

/// One receipt; incharge approves (stock goes up) or rejects.
class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({required this.receiptId, super.key});
  final String receiptId;

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final note = await askText(context,
        title: approve ? 'Approve receipt' : 'Reject receipt',
        label: approve ? 'Note (optional)' : 'Reason',
        required: !approve);
    if (note == null || !mounted) return;
    await _run(
      () => ref.read(inventoryRepositoryProvider).decideReceipt(
            receiptId: widget.receiptId,
            approve: approve,
            note: note,
            by: ref.read(actorProvider),
          ),
      approve ? 'Approved. Stock added.' : 'Rejected.',
    );
  }

  Future<void> _run(Future<Result<void>> Function() action, String success) async {
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentMemberProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stock receipt')),
      body: AsyncView(
        value: ref.watch(receiptProvider(widget.receiptId)),
        builder: (r) {
          if (r == null) {
            return const EmptyState(icon: Icons.search_off, message: 'Not found.');
          }
          final pending = r.status == DocStatus.pending;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: Text(r.source, style: Theme.of(context).textTheme.titleLarge)),
                StatusChip(r.status),
              ]),
              if (r.reference.isNotEmpty) Text('Bill / challan: ${r.reference}'),
              Text('Recorded by ${r.createdByName} · ${formatDateTime(r.createdAt)}'),
              if (r.note.isNotEmpty) Text('Note: ${r.note}'),
              if (r.decidedByName.isNotEmpty)
                Text('Decided by ${r.decidedByName} · ${formatDateTime(r.decidedAt)}'),
              if (r.decisionNote.isNotEmpty) Text('Incharge note: ${r.decisionNote}'),
              const Divider(height: 32),
              for (final l in r.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.itemName),
                  trailing: Text('+${l.qty} ${l.unit}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 24),
              if (pending && me.can(Capability.approveReceipt))
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _decide(false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _decide(true),
                      child: const Text('Approve & add stock'),
                    ),
                  ),
                ]),
              if (pending && r.createdBy == me.uid)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => ref
                                .read(inventoryRepositoryProvider)
                                .cancelReceipt(r.id),
                            'Receipt cancelled.',
                          ),
                  child: const Text('Cancel this receipt'),
                ),
            ],
          );
        },
      ),
    );
  }
}
