import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../domain/stock_logic.dart';
import 'mappers.dart';

/// Who is acting — stamped on every document for the audit trail.
typedef Actor = ({String uid, String name});

/// Items, staff, demands, receipts, adjustments and the ledger of one
/// school. The single write path for stock: every stock change goes through
/// a transaction that also writes the source document and a ledger entry
/// (Firestore rules reject anything else).
class InventoryRepository {
  InventoryRepository(this._db, this.orgId);

  final FirebaseFirestore _db;
  final String orgId;

  static const maxLinesPerDocument = 10;

  CollectionReference<Json> _c(String name) =>
      _db.collection('orgs/$orgId/$name');

  // ---------------- reads ----------------
  Stream<List<Item>> watchItems() => _c('items').snapshots().map(
        (q) => q.docs.map(itemFrom).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  Stream<List<StaffMember>> watchStaff() => _c('staff').snapshots().map(
        (q) => q.docs.map(staffFrom).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  Stream<List<Demand>> watchDemands({DocStatus? status, int limit = 100}) {
    Query<Json> q = _c('demands');
    if (status != null) q = q.where('status', isEqualTo: status.id);
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(demandFrom).toList());
  }

  Stream<Demand?> watchDemand(String id) => _c('demands')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? demandFrom(d) : null);

  Stream<List<Receipt>> watchReceipts({DocStatus? status, int limit = 100}) {
    Query<Json> q = _c('receipts');
    if (status != null) q = q.where('status', isEqualTo: status.id);
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(receiptFrom).toList());
  }

  Stream<Receipt?> watchReceipt(String id) => _c('receipts')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? receiptFrom(d) : null);

  Stream<List<LedgerEntry>> watchItemLedger(String itemId) => _c('ledger')
      .where('itemId', isEqualTo: itemId)
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(ledgerFrom).toList());

  Stream<List<LedgerEntry>> watchStaffLedger(String staffId) => _c('ledger')
      .where('staffId', isEqualTo: staffId)
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(ledgerFrom).toList());

  /// All movements in [from, to) for reports.
  Future<Result<List<LedgerEntry>>> ledgerBetween(DateTime from, DateTime to) =>
      guard(() async {
        final q = await _c('ledger')
            .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('at', isLessThan: Timestamp.fromDate(to))
            .orderBy('at')
            .get();
        return q.docs.map(ledgerFrom).toList();
      });

  // ---------------- items & staff ----------------
  Future<Result<void>> saveItem({
    String? id,
    required String name,
    required String unit,
    required int reorderLevel,
    required bool active,
    required Actor by,
  }) =>
      guard(() async {
        final data = <String, Object?>{
          'name': name.trim(),
          'unit': unit.trim(),
          'category': 'janitorial',
          'reorderLevel': reorderLevel,
          'active': active,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (id == null) {
          await _c('items').add({
            ...data,
            'currentStock': 0,
            'createdBy': by.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _c('items').doc(id).update(data);
        }
      });

  Future<Result<void>> saveStaff({
    String? id,
    required String name,
    required String employeeNo,
    required String phone,
    required String dutyArea,
    required bool active,
    required Actor by,
  }) =>
      guard(() async {
        final data = <String, Object?>{
          'name': name.trim(),
          'employeeNo': employeeNo.trim(),
          'phone': phone.trim(),
          'dutyArea': dutyArea.trim(),
          'active': active,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (id == null) {
          await _c('staff').add({
            ...data,
            'createdBy': by.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _c('staff').doc(id).update(data);
        }
      });

  // ---------------- demands ----------------
  /// Supervisor enters a staff member's paper slip.
  Future<Result<void>> createDemand({
    required StaffMember staff,
    required String slipNo,
    required String note,
    required List<DemandLine> lines,
    required Actor by,
  }) =>
      guard(() async {
        _checkLines(lines.length);
        await _c('demands').add({
          'slipNo': slipNo.trim(),
          'staffId': staff.id,
          'staffName': staff.name,
          'locationId': staff.locationId,
          'lines': demandLinesToJson(lines),
          'note': note.trim(),
          'status': DocStatus.pending.id,
          'createdBy': by.uid,
          'createdByName': by.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  /// Incharge approves (with possibly reduced quantities) or rejects.
  Future<Result<void>> decideDemand({
    required Demand demand,
    required bool approve,
    required Map<String, int> approvedQty,
    required String note,
    required Actor by,
  }) =>
      guard(() async {
        if (approve && !StockLogic.validApproval(demand.lines, approvedQty)) {
          throw const AppFailure(FailureCode.invalidInput,
              'Approved quantities must be between 0 and the requested amount, and not all zero.');
        }
        final lines = [
          for (final l in demand.lines)
            l.copyWith(qtyApproved: approve ? approvedQty[l.itemId] ?? 0 : 0),
        ];
        await _db.runTransaction((tx) async {
          final ref = _c('demands').doc(demand.id);
          final snap = await tx.get(ref);
          if (snap.data()?['status'] != DocStatus.pending.id) {
            throw const AppFailure(
                FailureCode.invalidState, 'This demand was already decided.');
          }
          tx.update(ref, {
            'status': (approve ? DocStatus.approved : DocStatus.rejected).id,
            'lines': demandLinesToJson(lines),
            'decidedBy': by.uid,
            'decidedByName': by.name,
            'decidedAt': FieldValue.serverTimestamp(),
            'decisionNote': note.trim(),
          });
        });
      });

  /// Supervisor hands over the items. Stock goes down by [issueQty].
  Future<Result<void>> issueDemand({
    required String demandId,
    required Map<String, int> issueQty,
    required Actor by,
  }) =>
      guard(() => _db.runTransaction((tx) async {
            final ref = _c('demands').doc(demandId);
            final demand = demandFrom(await tx.get(ref));
            if (demand.status != DocStatus.approved) {
              throw const AppFailure(FailureCode.invalidState,
                  'Only approved demands can be issued.');
            }
            final moving = demand.lines
                .where((l) => (issueQty[l.itemId] ?? 0) > 0)
                .toList();
            if (moving.isEmpty) {
              throw const AppFailure(
                  FailureCode.invalidInput, 'Enter at least one quantity.');
            }
            final stock = await _readStock(tx, moving.map((l) => l.itemId));
            final bad = StockLogic.invalidIssueLines(
              lines: moving,
              issue: issueQty,
              stockByItemId: stock,
            );
            if (bad.isNotEmpty) {
              throw AppFailure(FailureCode.insufficientStock,
                  'Not enough stock or above approved: ${bad.join(', ')}');
            }
            tx.update(ref, {
              'status': DocStatus.issued.id,
              'issuedBy': by.uid,
              'issuedByName': by.name,
              'issuedAt': FieldValue.serverTimestamp(),
              'lines': demandLinesToJson([
                for (final l in demand.lines)
                  l.copyWith(qtyIssued: issueQty[l.itemId] ?? 0),
              ]),
            });
            for (final l in moving) {
              final qty = issueQty[l.itemId]!;
              _move(tx,
                  itemId: l.itemId,
                  itemName: l.itemName,
                  unit: l.unit,
                  delta: -qty,
                  balanceAfter: stock[l.itemId]! - qty,
                  refType: 'demand',
                  refId: demandId,
                  by: by,
                  staffId: demand.staffId,
                  staffName: demand.staffName);
            }
          }));

  Future<Result<void>> cancelDemand(String demandId) => guard(() =>
      _c('demands').doc(demandId).update({'status': DocStatus.cancelled.id}));

  // ---------------- receipts ----------------
  Future<Result<void>> createReceipt({
    required String source,
    required String reference,
    required String note,
    required List<ReceiptLine> lines,
    required Actor by,
  }) =>
      guard(() async {
        _checkLines(lines.length);
        await _c('receipts').add({
          'source': source.trim(),
          'reference': reference.trim(),
          'note': note.trim(),
          'lines': {
            for (final l in lines)
              l.itemId: {'itemName': l.itemName, 'unit': l.unit, 'qty': l.qty},
          },
          'status': DocStatus.pending.id,
          'createdBy': by.uid,
          'createdByName': by.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  /// Incharge approves (stock goes up) or rejects a receipt.
  Future<Result<void>> decideReceipt({
    required String receiptId,
    required bool approve,
    required String note,
    required Actor by,
  }) =>
      guard(() => _db.runTransaction((tx) async {
            final ref = _c('receipts').doc(receiptId);
            final receipt = receiptFrom(await tx.get(ref));
            if (receipt.status != DocStatus.pending) {
              throw const AppFailure(
                  FailureCode.invalidState, 'This receipt was already decided.');
            }
            final stock = approve
                ? await _readStock(tx, receipt.lines.map((l) => l.itemId))
                : const <String, int>{};
            tx.update(ref, {
              'status': (approve ? DocStatus.approved : DocStatus.rejected).id,
              'decidedBy': by.uid,
              'decidedByName': by.name,
              'decidedAt': FieldValue.serverTimestamp(),
              'decisionNote': note.trim(),
            });
            if (!approve) return;
            for (final l in receipt.lines) {
              _move(tx,
                  itemId: l.itemId,
                  itemName: l.itemName,
                  unit: l.unit,
                  delta: l.qty,
                  balanceAfter: stock[l.itemId]! + l.qty,
                  refType: 'receipt',
                  refId: receiptId,
                  by: by);
            }
          }));

  Future<Result<void>> cancelReceipt(String receiptId) => guard(() =>
      _c('receipts').doc(receiptId).update({'status': DocStatus.cancelled.id}));

  // ---------------- adjustments ----------------
  /// Incharge corrects stock after a physical count: sets [item] to
  /// [countedStock].
  Future<Result<void>> adjustStock({
    required Item item,
    required int countedStock,
    required String reason,
    required Actor by,
  }) =>
      guard(() => _db.runTransaction((tx) async {
            if (countedStock < 0) {
              throw const AppFailure(
                  FailureCode.invalidInput, 'Stock cannot be negative.');
            }
            final stock = await _readStock(tx, [item.id]);
            final delta = countedStock - stock[item.id]!;
            if (delta == 0) {
              throw const AppFailure(FailureCode.invalidInput,
                  'Counted stock is the same as the system stock.');
            }
            final ref = _c('adjustments').doc();
            tx.set(ref, {
              'lines': {
                item.id: {
                  'itemName': item.name,
                  'unit': item.unit,
                  'delta': delta,
                },
              },
              'reason': reason.trim(),
              'createdBy': by.uid,
              'createdByName': by.name,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _move(tx,
                itemId: item.id,
                itemName: item.name,
                unit: item.unit,
                delta: delta,
                balanceAfter: countedStock,
                refType: 'adjustment',
                refId: ref.id,
                by: by,
                reason: reason.trim());
          }));

  // ---------------- internals ----------------
  Future<Map<String, int>> _readStock(
      Transaction tx, Iterable<String> itemIds) async {
    final out = <String, int>{};
    for (final id in itemIds) {
      final snap = await tx.get(_c('items').doc(id));
      if (!snap.exists) {
        throw const AppFailure(FailureCode.notFound, 'An item no longer exists.');
      }
      out[id] = itemFrom(snap).currentStock;
    }
    return out;
  }

  /// Writes the stock change and its ledger entry together.
  void _move(
    Transaction tx, {
    required String itemId,
    required String itemName,
    required String unit,
    required int delta,
    required int balanceAfter,
    required String refType,
    required String refId,
    required Actor by,
    String? staffId,
    String staffName = '',
    String reason = '',
  }) {
    tx.update(_c('items').doc(itemId), {
      'currentStock': balanceAfter,
      'lastRef': {'type': refType, 'id': refId},
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(_c('ledger').doc('${refId}_$itemId'), {
      'itemId': itemId,
      'itemName': itemName,
      'unit': unit,
      'delta': delta,
      'balanceAfter': balanceAfter,
      'type': switch (refType) {
        'demand' => 'issue',
        'receipt' => 'receipt',
        _ => 'adjustment',
      },
      'refType': refType,
      'refId': refId,
      'staffId': staffId,
      'staffName': staffName,
      'reason': reason,
      'by': by.uid,
      'byName': by.name,
      'at': FieldValue.serverTimestamp(),
    });
  }

  void _checkLines(int count) {
    if (count == 0) {
      throw const AppFailure(FailureCode.invalidInput, 'Add at least one item.');
    }
    if (count > maxLinesPerDocument) {
      throw const AppFailure(FailureCode.invalidInput,
          'At most $maxLinesPerDocument items per slip. Make a second slip for the rest.');
    }
  }
}
