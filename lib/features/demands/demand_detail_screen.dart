import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result.dart';
import '../../domain/models.dart';
import '../../domain/roles.dart';
import '../../domain/stock_logic.dart';
import '../common/async_view.dart';
import '../common/qty_field.dart';
import '../common/ui_helpers.dart';

/// What the viewer can do with a demand right now.
enum _Mode { view, approve, issue }

/// Shows a demand and lets the incharge approve/reject it or the supervisor
/// issue it.
class DemandDetailScreen extends ConsumerWidget {
  const DemandDetailScreen({required this.demandId, super.key});
  final String demandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demand')),
      body: AsyncView(
        value: ref.watch(demandProvider(demandId)),
        builder: (d) => d == null
            ? const EmptyState(icon: Icons.search_off, message: 'Demand not found.')
            : _DemandBody(demand: d),
      ),
    );
  }
}

class _DemandBody extends ConsumerStatefulWidget {
  const _DemandBody({required this.demand});
  final Demand demand;

  @override
  ConsumerState<_DemandBody> createState() => _DemandBodyState();
}

class _DemandBodyState extends ConsumerState<_DemandBody> {
  final Map<String, int> _qty = {};
  DocStatus? _seededFor;
  bool _busy = false;

  _Mode get _mode {
    final me = ref.read(currentMemberProvider);
    final s = widget.demand.status;
    if (s == DocStatus.pending && me.can(Capability.approveDemand)) return _Mode.approve;
    if (s == DocStatus.approved && me.can(Capability.issueDemand)) return _Mode.issue;
    return _Mode.view;
  }

  /// Pre-fills quantities once per status: approve → requested,
  /// issue → what can actually be given.
  void _seed(Map<String, int> stock) {
    if (_seededFor == widget.demand.status) return;
    _seededFor = widget.demand.status;
    _qty.clear();
    for (final l in widget.demand.lines) {
      _qty[l.itemId] = switch (_mode) {
        _Mode.approve => l.qtyRequested,
        _Mode.issue => StockLogic.maxIssuable(
            approved: l.qtyApproved, inStock: stock[l.itemId] ?? 0),
        _Mode.view => 0,
      };
    }
  }

  Future<void> _decide({required bool approve}) async {
    final note = await askText(
      context,
      title: approve ? 'Approve demand' : 'Reject demand',
      label: approve ? 'Note (optional)' : 'Reason',
      required: !approve,
    );
    if (note == null || !mounted) return;
    await _run(
      () => ref.read(inventoryRepositoryProvider).decideDemand(
            demand: widget.demand,
            approve: approve,
            approvedQty: _qty,
            note: note,
            by: ref.read(actorProvider),
          ),
      approve ? 'Approved. The supervisor can now issue it.' : 'Rejected.',
    );
  }

  Future<void> _issue() async {
    final ok = await confirm(context, 'Issue items?',
        'Hand over the items now. Stock will be reduced.');
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(inventoryRepositoryProvider).issueDemand(
            demandId: widget.demand.id,
            issueQty: _qty,
            by: ref.read(actorProvider),
          ),
      'Issued. Stock updated.',
    );
  }

  Future<void> _cancel() async {
    final ok = await confirm(context, 'Cancel demand?', 'This cannot be undone.');
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(inventoryRepositoryProvider).cancelDemand(widget.demand.id),
      'Demand cancelled.',
    );
  }

  Future<void> _run(Future<Result<void>> Function() action, String success) async {
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demand;
    final me = ref.watch(currentMemberProvider);
    final items = ref.watch(itemsProvider).value ?? const [];
    final stock = {for (final i in items) i.id: i.currentStock};
    _seed(stock);
    final mode = _mode;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(demand: d),
        const Divider(height: 32),
        Text(switch (mode) {
          _Mode.approve => 'Set approved quantity',
          _Mode.issue => 'Quantity to hand over',
          _Mode.view => 'Items',
        }, style: Theme.of(context).textTheme.titleMedium),
        for (final l in d.lines)
          _LineTile(
            line: l,
            mode: mode,
            inStock: stock[l.itemId] ?? 0,
            qty: _qty[l.itemId] ?? 0,
            onChanged: (v) => setState(() => _qty[l.itemId] = v),
          ),
        const SizedBox(height: 24),
        if (mode == _Mode.approve)
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _decide(approve: false),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _decide(approve: true),
                child: const Text('Approve'),
              ),
            ),
          ]),
        if (mode == _Mode.issue)
          FilledButton.icon(
            icon: const Icon(Icons.outbox),
            label: const Text('Issue items'),
            onPressed: _busy || _qty.values.every((q) => q == 0) ? null : _issue,
          ),
        if (d.status == DocStatus.pending && d.createdBy == me.uid)
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('Cancel this demand'),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.demand});
  final Demand demand;

  @override
  Widget build(BuildContext context) {
    final d = demand;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(d.staffName, style: t.titleLarge)),
          StatusChip(d.status),
        ]),
        if (d.slipNo.isNotEmpty) Text('Slip no. ${d.slipNo}'),
        Text('Entered by ${d.createdByName} · ${formatDateTime(d.createdAt)}'),
        if (d.note.isNotEmpty) Text('Note: ${d.note}'),
        if (d.decidedByName.isNotEmpty)
          Text('${d.status == DocStatus.rejected ? 'Rejected' : 'Approved'} by '
              '${d.decidedByName} · ${formatDateTime(d.decidedAt)}'),
        if (d.decisionNote.isNotEmpty) Text('Incharge note: ${d.decisionNote}'),
        if (d.issuedByName.isNotEmpty)
          Text('Issued by ${d.issuedByName} · ${formatDateTime(d.issuedAt)}'),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.mode,
    required this.inStock,
    required this.qty,
    required this.onChanged,
  });
  final DemandLine line;
  final _Mode mode;
  final int inStock;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = line.unit;
    final facts = [
      'Asked ${line.qtyRequested} $u',
      if (mode != _Mode.approve && line.qtyApproved > 0) 'approved ${line.qtyApproved}',
      if (line.qtyIssued > 0) 'issued ${line.qtyIssued}',
      if (mode != _Mode.view) 'in stock $inStock',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(line.itemName),
      subtitle: Text(facts.join(' · ')),
      trailing: switch (mode) {
        _Mode.approve => QtyField(value: qty, max: line.qtyRequested, onChanged: onChanged),
        _Mode.issue => QtyField(
            value: qty,
            max: StockLogic.maxIssuable(approved: line.qtyApproved, inStock: inStock),
            onChanged: onChanged,
          ),
        _Mode.view => null,
      },
    );
  }
}
