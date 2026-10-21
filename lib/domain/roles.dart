/// Roles of people who sign in to the app.
///
/// Janitorial staff do NOT sign in (they are not allowed phones); they are
/// kept as [StaffMember] records and their paper slips are entered by the
/// supervisor. V2 hook: add roles such as `storeKeeper` or `locationLead`
/// here and in `firestore.rules` (`validRoles`).
enum Role {
  incharge('incharge', 'Janitorial Incharge'),
  supervisor('supervisor', 'Janitorial Supervisor'),
  viewer('viewer', 'Viewer (read only)');

  const Role(this.id, this.label);
  final String id;
  final String label;

  static Role fromId(String? id) =>
      Role.values.firstWhere((r) => r.id == id, orElse: () => Role.viewer);
}

enum MemberStatus {
  pending('pending'),
  active('active'),
  disabled('disabled');

  const MemberStatus(this.id);
  final String id;

  static MemberStatus fromId(String? id) => MemberStatus.values
      .firstWhere((s) => s.id == id, orElse: () => MemberStatus.pending);
}

/// Everything a signed-in member may try to do. The UI asks [Permissions];
/// Firestore rules enforce the same table on the server.
enum Capability {
  manageItems,
  manageStaff,
  recordDemand,
  approveDemand,
  issueDemand,
  recordReceipt,
  approveReceipt,
  adjustStock,
  viewReports,
  manageMembers,
}

/// Pure permission table.
abstract final class Permissions {
  static bool can({
    required Role role,
    required bool isAdmin,
    required Capability capability,
  }) {
    if (capability == Capability.manageMembers) return isAdmin;
    return switch (role) {
      Role.supervisor => const {
          Capability.manageItems,
          Capability.manageStaff,
          Capability.recordDemand,
          Capability.issueDemand,
          Capability.recordReceipt,
          Capability.viewReports,
        }.contains(capability),
      Role.incharge => const {
          Capability.manageItems,
          Capability.manageStaff,
          Capability.recordDemand,
          Capability.approveDemand,
          Capability.approveReceipt,
          Capability.adjustStock,
          Capability.viewReports,
        }.contains(capability),
      Role.viewer => capability == Capability.viewReports,
    };
  }
}
