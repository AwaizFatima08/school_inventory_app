import 'roles.dart';

/// A school (or any organisation) using the app. Multi-tenant root.
class Org {
  const Org({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    this.modules = const ['janitorial'],
  });

  final String id;
  final String name;

  /// Short code other people type to ask to join this school.
  final String joinCode;
  final String createdBy;

  /// V2 hook: enabled inventory modules, e.g. `['janitorial', 'stationery',
  /// 'furniture']` for full school inventory.
  final List<String> modules;
}

/// A person who signs in (incharge, supervisor, viewer) within an [Org].
class Member {
  const Member({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.status,
    this.requestedRole,
    this.locationIds = const [],
  });

  final String uid;
  final String displayName;
  final String email;
  final Role role;

  /// Admins approve new members and change roles. Kept separate from [role]
  /// so admin rights stay with one person while the incharge rotates.
  final bool isAdmin;
  final MemberStatus status;
  final Role? requestedRole;

  /// V2 hook: locations this member looks after (empty = whole school).
  final List<String> locationIds;

  bool can(Capability capability) =>
      status == MemberStatus.active &&
      Permissions.can(role: role, isAdmin: isAdmin, capability: capability);
}

/// A janitorial staff member. Does not sign in; demands are raised in their
/// name from the paper slip.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    this.employeeNo = '',
    this.phone = '',
    this.dutyArea = '',
    this.locationId,
    this.active = true,
  });

  final String id;
  final String name;
  final String employeeNo;
  final String phone;

  /// Free-text duty area for V1 (e.g. "Junior block washrooms").
  final String dutyArea;

  /// V2 hook: structured location assignment.
  final String? locationId;
  final bool active;
}

/// A stock item kept by the supervisor.
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.reorderLevel,
    this.category = 'janitorial',
    this.active = true,
  });

  final String id;
  final String name;
  final String unit;
  final int currentStock;

  /// When stock is at or below this level the item shows as "low".
  final int reorderLevel;

  /// V2 hook: inventory module this item belongs to.
  final String category;
  final bool active;

  bool get isLow => currentStock <= reorderLevel;
  bool get isOut => currentStock <= 0;
}

/// Where a document is in its approval flow.
enum DocStatus {
  pending('pending', 'Waiting for approval'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  issued('issued', 'Issued'),
  cancelled('cancelled', 'Cancelled');

  const DocStatus(this.id, this.label);
  final String id;
  final String label;

  static DocStatus fromId(String? id) => DocStatus.values
      .firstWhere((s) => s.id == id, orElse: () => DocStatus.pending);
}

/// One item line on a demand slip.
class DemandLine {
  const DemandLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.qtyRequested,
    this.qtyApproved = 0,
    this.qtyIssued = 0,
  });

  final String itemId;
  final String itemName;
  final String unit;
  final int qtyRequested;
  final int qtyApproved;
  final int qtyIssued;

  DemandLine copyWith({int? qtyApproved, int? qtyIssued}) => DemandLine(
        itemId: itemId,
        itemName: itemName,
        unit: unit,
        qtyRequested: qtyRequested,
        qtyApproved: qtyApproved ?? this.qtyApproved,
        qtyIssued: qtyIssued ?? this.qtyIssued,
      );
}

/// A demand raised by a staff member on paper and entered by the supervisor.
/// Flow: pending → approved/rejected (incharge) → issued (supervisor).
class Demand {
  const Demand({
    required this.id,
    required this.slipNo,
    required this.staffId,
    required this.staffName,
    required this.lines,
    required this.status,
    required this.createdByName,
    this.createdBy = '',
    this.createdAt,
    this.note = '',
    this.decidedByName = '',
    this.decidedAt,
    this.decisionNote = '',
    this.issuedByName = '',
    this.issuedAt,
    this.locationId,
  });

  final String id;
  final String slipNo;
  final String staffId;
  final String staffName;
  final List<DemandLine> lines;
  final DocStatus status;
  final String createdByName;

  /// uid of whoever entered it (may cancel while pending).
  final String createdBy;
  final DateTime? createdAt;
  final String note;
  final String decidedByName;
  final DateTime? decidedAt;
  final String decisionNote;
  final String issuedByName;
  final DateTime? issuedAt;

  /// V2 hook: location the demand is for.
  final String? locationId;
}

/// One item line on a stock receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.qty,
  });

  final String itemId;
  final String itemName;
  final String unit;
  final int qty;
}

/// New stock received (purchase, donation or opening balance). Recorded by
/// the supervisor; stock goes up only after the incharge approves.
class Receipt {
  const Receipt({
    required this.id,
    required this.source,
    required this.reference,
    required this.lines,
    required this.status,
    required this.createdByName,
    this.createdBy = '',
    this.createdAt,
    this.note = '',
    this.decidedByName = '',
    this.decidedAt,
    this.decisionNote = '',
  });

  final String id;

  /// Supplier name, "Opening stock", etc.
  final String source;

  /// Bill / challan / purchase order number.
  final String reference;
  final List<ReceiptLine> lines;
  final DocStatus status;
  final String createdByName;
  final String createdBy;
  final DateTime? createdAt;
  final String note;
  final String decidedByName;
  final DateTime? decidedAt;
  final String decisionNote;
}

enum MoveType {
  issue('issue', 'Issued'),
  receipt('receipt', 'Received'),
  adjustment('adjustment', 'Adjusted');

  const MoveType(this.id, this.label);
  final String id;
  final String label;

  static MoveType fromId(String? id) => MoveType.values
      .firstWhere((t) => t.id == id, orElse: () => MoveType.adjustment);
}

/// One stock movement of one item. Written together with the stock change
/// and never edited afterwards — this is the audit trail.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.delta,
    required this.balanceAfter,
    required this.type,
    required this.refId,
    required this.byName,
    this.staffId,
    this.staffName = '',
    this.reason = '',
    this.at,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String unit;
  final int delta;
  final int balanceAfter;
  final MoveType type;
  final String refId;
  final String byName;
  final String? staffId;
  final String staffName;
  final String reason;
  final DateTime? at;
}
