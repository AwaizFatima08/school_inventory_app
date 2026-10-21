import 'models.dart';

/// Pure stock rules shared by the UI and the repositories. Total: these
/// functions never throw.
abstract final class StockLogic {
  /// Largest legal issue quantity for a line: what was approved, capped by
  /// what is on the shelf.
  static int maxIssuable({required int approved, required int inStock}) {
    if (approved <= 0 || inStock <= 0) return 0;
    return approved < inStock ? approved : inStock;
  }

  /// Returns the names of lines whose [issue] quantity is illegal
  /// (negative, above approved, or above stock). Empty means OK.
  static List<String> invalidIssueLines({
    required List<DemandLine> lines,
    required Map<String, int> issue,
    required Map<String, int> stockByItemId,
  }) {
    final bad = <String>[];
    for (final line in lines) {
      final qty = issue[line.itemId] ?? 0;
      final stock = stockByItemId[line.itemId] ?? 0;
      if (qty < 0 || qty > line.qtyApproved || qty > stock) {
        bad.add(line.itemName);
      }
    }
    return bad;
  }

  /// Approved quantities must be between 0 and requested.
  static bool validApproval(List<DemandLine> lines, Map<String, int> approved) {
    var total = 0;
    for (final line in lines) {
      final qty = approved[line.itemId] ?? 0;
      if (qty < 0 || qty > line.qtyRequested) return false;
      total += qty;
    }
    return total > 0;
  }

  /// Items at or below their reorder level, lowest stock first.
  static List<Item> lowStock(Iterable<Item> items) =>
      items.where((i) => i.active && i.isLow).toList()
        ..sort((a, b) => a.currentStock.compareTo(b.currentStock));

  /// Total quantity issued per item name over [entries].
  static Map<String, int> issuedByItem(Iterable<LedgerEntry> entries) =>
      _sum(entries, (e) => '${e.itemName} (${e.unit})');

  /// Total quantity issued per staff member over [entries].
  static Map<String, int> issuedByStaff(Iterable<LedgerEntry> entries) =>
      _sum(entries, (e) => e.staffName.isEmpty ? '—' : e.staffName);

  static Map<String, int> _sum(
    Iterable<LedgerEntry> entries,
    String Function(LedgerEntry) key,
  ) {
    final out = <String, int>{};
    for (final e in entries.where((e) => e.type == MoveType.issue)) {
      out.update(key(e), (v) => v - e.delta, ifAbsent: () => -e.delta);
    }
    return Map.fromEntries(
      out.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// A 6-character join code without look-alike characters (0/O, 1/I).
  static String joinCode(int Function(int max) nextInt) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => alphabet[nextInt(alphabet.length)]).join();
  }
}

/// The standard janitorial list a new school can start with.
const defaultJanitorialItems = <(String, String)>[
  ('Dish Washing Soap', 'bar'),
  ('Dust Bin', 'pcs'),
  ('Dry Mop', 'pcs'),
  ('Liquid Hand Wash', 'bottle'),
  ('Harpic Toilet Cleaner', 'bottle'),
  ('Mosquito Spray', 'can'),
  ('Mop Cloth', 'pcs'),
  ('Robin Bleach', 'bottle'),
  ('Sweep Toilet Cleaner', 'bottle'),
  ('Detergent Surf', 'packet'),
  ('Dish Washing Sponge', 'pcs'),
  ('Vim Powder', 'packet'),
  ('Web Cleaning Brush', 'pcs'),
  ('Toilet Cleaning Brush', 'pcs'),
  ('Wiper', 'pcs'),
];
