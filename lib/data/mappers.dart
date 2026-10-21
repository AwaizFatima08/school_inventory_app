import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../domain/roles.dart';

typedef Json = Map<String, dynamic>;

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
String _s(Object? v) => v is String ? v : '';
int _i(Object? v) => v is num ? v.toInt() : 0;
Json _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Org orgFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  return Org(
    id: d.id,
    name: _s(j['name']),
    joinCode: _s(j['joinCode']),
    createdBy: _s(j['createdBy']),
    modules: (j['modules'] as List?)?.whereType<String>().toList() ??
        const ['janitorial'],
  );
}

Member memberFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  final requested = j['requestedRole'];
  return Member(
    uid: d.id,
    displayName: _s(j['displayName']),
    email: _s(j['email']),
    role: Role.fromId(j['role'] as String?),
    isAdmin: j['isAdmin'] == true,
    status: MemberStatus.fromId(j['status'] as String?),
    requestedRole: requested is String ? Role.fromId(requested) : null,
    locationIds:
        (j['locationIds'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

StaffMember staffFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  return StaffMember(
    id: d.id,
    name: _s(j['name']),
    employeeNo: _s(j['employeeNo']),
    phone: _s(j['phone']),
    dutyArea: _s(j['dutyArea']),
    locationId: j['locationId'] as String?,
    active: j['active'] != false,
  );
}

Item itemFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  return Item(
    id: d.id,
    name: _s(j['name']),
    unit: _s(j['unit']),
    currentStock: _i(j['currentStock']),
    reorderLevel: _i(j['reorderLevel']),
    category: _s(j['category']).isEmpty ? 'janitorial' : _s(j['category']),
    active: j['active'] != false,
  );
}

List<DemandLine> _demandLines(Object? raw) {
  final lines = _m(raw).entries.map((e) {
    final l = _m(e.value);
    return DemandLine(
      itemId: e.key,
      itemName: _s(l['itemName']),
      unit: _s(l['unit']),
      qtyRequested: _i(l['qtyRequested']),
      qtyApproved: _i(l['qtyApproved']),
      qtyIssued: _i(l['qtyIssued']),
    );
  }).toList()
    ..sort((a, b) => a.itemName.compareTo(b.itemName));
  return lines;
}

Json demandLinesToJson(List<DemandLine> lines) => {
      for (final l in lines)
        l.itemId: {
          'itemName': l.itemName,
          'unit': l.unit,
          'qtyRequested': l.qtyRequested,
          'qtyApproved': l.qtyApproved,
          'qtyIssued': l.qtyIssued,
        },
    };

Demand demandFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  return Demand(
    id: d.id,
    slipNo: _s(j['slipNo']),
    staffId: _s(j['staffId']),
    staffName: _s(j['staffName']),
    lines: _demandLines(j['lines']),
    status: DocStatus.fromId(j['status'] as String?),
    createdByName: _s(j['createdByName']),
    createdBy: _s(j['createdBy']),
    createdAt: _date(j['createdAt']),
    note: _s(j['note']),
    decidedByName: _s(j['decidedByName']),
    decidedAt: _date(j['decidedAt']),
    decisionNote: _s(j['decisionNote']),
    issuedByName: _s(j['issuedByName']),
    issuedAt: _date(j['issuedAt']),
    locationId: j['locationId'] as String?,
  );
}

Receipt receiptFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  final lines = _m(j['lines']).entries.map((e) {
    final l = _m(e.value);
    return ReceiptLine(
      itemId: e.key,
      itemName: _s(l['itemName']),
      unit: _s(l['unit']),
      qty: _i(l['qty']),
    );
  }).toList()
    ..sort((a, b) => a.itemName.compareTo(b.itemName));
  return Receipt(
    id: d.id,
    source: _s(j['source']),
    reference: _s(j['reference']),
    lines: lines,
    status: DocStatus.fromId(j['status'] as String?),
    createdByName: _s(j['createdByName']),
    createdBy: _s(j['createdBy']),
    createdAt: _date(j['createdAt']),
    note: _s(j['note']),
    decidedByName: _s(j['decidedByName']),
    decidedAt: _date(j['decidedAt']),
    decisionNote: _s(j['decisionNote']),
  );
}

LedgerEntry ledgerFrom(DocumentSnapshot<Json> d) {
  final j = d.data() ?? const {};
  return LedgerEntry(
    id: d.id,
    itemId: _s(j['itemId']),
    itemName: _s(j['itemName']),
    unit: _s(j['unit']),
    delta: _i(j['delta']),
    balanceAfter: _i(j['balanceAfter']),
    type: MoveType.fromId(j['type'] as String?),
    refId: _s(j['refId']),
    byName: _s(j['byName']),
    staffId: j['staffId'] as String?,
    staffName: _s(j['staffName']),
    reason: _s(j['reason']),
    at: _date(j['at']),
  );
}

/// Maps any thrown error to a typed failure with a readable message.
AppFailure failureFrom(Object error) {
  if (error is AppFailure) return error;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const AppFailure(FailureCode.permissionDenied,
          'You are not allowed to do this, or the record changed. Refresh and try again.'),
      'not-found' =>
        const AppFailure(FailureCode.notFound, 'Record not found.'),
      'unavailable' || 'deadline-exceeded' => const AppFailure(
          FailureCode.network, 'No connection. Please try again.'),
      'aborted' || 'failed-precondition' => const AppFailure(
          FailureCode.invalidState, 'Someone else changed this. Try again.'),
      _ => AppFailure(FailureCode.unknown, error.message ?? error.code),
    };
  }
  return AppFailure(FailureCode.unknown, error.toString());
}

/// Runs [body] and converts any error to [Err].
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Object catch (e) {
    return Err(failureFrom(e));
  }
}
