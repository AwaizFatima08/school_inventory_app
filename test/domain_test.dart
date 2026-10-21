import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_inventory/domain/models.dart';
import 'package:school_inventory/domain/roles.dart';
import 'package:school_inventory/domain/stock_logic.dart';

DemandLine line(String id, {int req = 5, int appr = 0}) => DemandLine(
      itemId: id,
      itemName: id,
      unit: 'pcs',
      qtyRequested: req,
      qtyApproved: appr,
    );

void main() {
  group('Permissions', () {
    bool can(Role r, Capability c, {bool admin = false}) =>
        Permissions.can(role: r, isAdmin: admin, capability: c);

    test('separation of duties: incharge approves, supervisor issues', () {
      expect(can(Role.incharge, Capability.approveDemand), isTrue);
      expect(can(Role.incharge, Capability.issueDemand), isFalse);
      expect(can(Role.supervisor, Capability.issueDemand), isTrue);
      expect(can(Role.supervisor, Capability.approveDemand), isFalse);
      expect(can(Role.supervisor, Capability.approveReceipt), isFalse);
      expect(can(Role.supervisor, Capability.adjustStock), isFalse);
    });

    test('only admins manage members, whatever their role', () {
      expect(can(Role.incharge, Capability.manageMembers), isFalse);
      expect(can(Role.supervisor, Capability.manageMembers, admin: true), isTrue);
    });

    test('viewer only sees reports', () {
      for (final c in Capability.values) {
        expect(can(Role.viewer, c), c == Capability.viewReports, reason: c.name);
      }
    });

    test('inactive member can do nothing', () {
      const m = Member(
        uid: 'u', displayName: 'U', email: '', role: Role.incharge,
        isAdmin: true, status: MemberStatus.pending,
      );
      expect(Capability.values.any(m.can), isFalse);
    });
  });

  group('StockLogic', () {
    test('maxIssuable is min(approved, stock) and never negative', () {
      expect(StockLogic.maxIssuable(approved: 5, inStock: 3), 3);
      expect(StockLogic.maxIssuable(approved: 2, inStock: 9), 2);
      expect(StockLogic.maxIssuable(approved: 4, inStock: -1), 0);
    });

    test('invalidIssueLines flags over-approved and over-stock lines', () {
      final lines = [line('a', appr: 3), line('b', appr: 3), line('c', appr: 3)];
      final bad = StockLogic.invalidIssueLines(
        lines: lines,
        issue: {'a': 3, 'b': 4, 'c': 2},
        stockByItemId: {'a': 10, 'b': 10, 'c': 1},
      );
      expect(bad, ['b', 'c']);
    });

    test('validApproval: within requested and not all zero', () {
      final lines = [line('a', req: 4), line('b', req: 2)];
      expect(StockLogic.validApproval(lines, {'a': 4, 'b': 0}), isTrue);
      expect(StockLogic.validApproval(lines, {'a': 5}), isFalse);
      expect(StockLogic.validApproval(lines, {'a': 0, 'b': 0}), isFalse);
    });

    test('lowStock lists active items at/below reorder level, lowest first', () {
      const items = [
        Item(id: '1', name: 'A', unit: 'pcs', currentStock: 4, reorderLevel: 5),
        Item(id: '2', name: 'B', unit: 'pcs', currentStock: 9, reorderLevel: 5),
        Item(id: '3', name: 'C', unit: 'pcs', currentStock: 0, reorderLevel: 2),
        Item(id: '4', name: 'D', unit: 'pcs', currentStock: 0, reorderLevel: 2, active: false),
      ];
      expect(StockLogic.lowStock(items).map((i) => i.id), ['3', '1']);
    });

    test('issued totals count only issues, as positive numbers', () {
      LedgerEntry e(String item, String staff, int delta, MoveType t) => LedgerEntry(
            id: '$item$delta', itemId: item, itemName: item, unit: 'pcs',
            delta: delta, balanceAfter: 0, type: t, refId: 'r', byName: 'x',
            staffName: staff,
          );
      final entries = [
        e('Soap', 'Aslam', -2, MoveType.issue),
        e('Soap', 'Bashir', -3, MoveType.issue),
        e('Soap', '', 24, MoveType.receipt),
        e('Mop', 'Aslam', -1, MoveType.issue),
      ];
      expect(StockLogic.issuedByItem(entries), {'Soap (pcs)': 5, 'Mop (pcs)': 1});
      expect(StockLogic.issuedByStaff(entries), {'Aslam': 3, 'Bashir': 3});
    });

    test('joinCode is 6 chars with no look-alike characters', () {
      final rnd = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = StockLogic.joinCode(rnd.nextInt);
        expect(code, hasLength(6));
        expect(code, isNot(contains(RegExp('[01OI]'))));
      }
    });

    test('default item list matches the school list', () {
      expect(defaultJanitorialItems, hasLength(15));
      expect(defaultJanitorialItems.map((e) => e.$1), contains('Harpic Toilet Cleaner'));
    });
  });
}
