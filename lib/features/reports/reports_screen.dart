import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/clock.dart';
import '../../core/result.dart';
import '../../domain/models.dart';
import '../../domain/stock_logic.dart';
import '../common/ui_helpers.dart';

/// Monthly consumption: issued per item and per staff member, plus a
/// shareable CSV of every movement.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _month;
  Result<List<LedgerEntry>>? _result;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _result = null);
    final r = await ref
        .read(inventoryRepositoryProvider)
        .ledgerBetween(_month, DateTime(_month.year, _month.month + 1));
    if (mounted) setState(() => _result = r);
  }

  void _shift(int months) {
    _month = DateTime(_month.year, _month.month + months);
    _load();
  }

  Future<void> _share(List<LedgerEntry> entries) async {
    final org = ref.read(currentOrgProvider);
    final csv = StringBuffer('Date,Type,Item,Unit,Quantity,Balance,Staff,By,Reason\n');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    for (final e in entries) {
      csv.writeln([
        formatDateTime(e.at), e.type.label, q(e.itemName), e.unit, e.delta,
        e.balanceAfter, q(e.staffName), q(e.byName), q(e.reason),
      ].join(','));
    }
    await SharePlus.instance.share(ShareParams(
      subject: '${org.name} — stock movements ${DateFormat('MMMM yyyy').format(_month)}',
      text: csv.toString(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (r case Ok(:final value) when value.isNotEmpty)
            IconButton(
              tooltip: 'Share as CSV',
              icon: const Icon(Icons.share),
              onPressed: () => _share(value),
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Text(DateFormat('MMMM yyyy').format(_month),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          Expanded(
            child: switch (r) {
              null => const Center(child: CircularProgressIndicator()),
              Err(:final failure) =>
                EmptyState(icon: Icons.cloud_off, message: failure.message),
              Ok(:final value) => _ReportBody(entries: value),
            },
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart, message: 'No stock movements this month.');
    }
    final byItem = StockLogic.issuedByItem(entries);
    final byStaff = StockLogic.issuedByStaff(entries);
    final received = entries.where((e) => e.type == MoveType.receipt).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${entries.length} movements · $received receipt lines'),
        const SizedBox(height: 16),
        _Section(title: 'Issued per item', rows: byItem),
        const SizedBox(height: 16),
        _Section(title: 'Issued per staff member (total units)', rows: byStaff),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final Map<String, int> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (rows.isEmpty) const Text('Nothing issued.'),
            for (final e in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(e.key)),
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
