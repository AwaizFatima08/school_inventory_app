import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../data/inventory_repository.dart';
import '../domain/models.dart';
import '../domain/roles.dart';

// ---------------- composition root seams ----------------
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

// ---------------- session ----------------
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(accountRepositoryProvider).authChanges(),
);

final orgIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(accountRepositoryProvider).watchOrgId(user.uid);
});

final orgProvider = StreamProvider<Org?>((ref) {
  final orgId = ref.watch(orgIdProvider).value;
  if (orgId == null) return Stream.value(null);
  return ref.watch(accountRepositoryProvider).watchOrg(orgId);
});

final myMemberProvider = StreamProvider<Member?>((ref) {
  final user = ref.watch(authUserProvider).value;
  final orgId = ref.watch(orgIdProvider).value;
  if (user == null || orgId == null) return Stream.value(null);
  return ref.watch(accountRepositoryProvider).watchMember(orgId, user.uid);
});

/// Where the signed-in person is in onboarding.
sealed class Session {
  const Session();
}

final class SignedOut extends Session {
  const SignedOut();
}

final class NoSchool extends Session {
  const NoSchool();
}

final class AwaitingApproval extends Session {
  const AwaitingApproval(this.orgId, this.member);
  final String orgId;
  final Member member;
}

final class AccessDisabled extends Session {
  const AccessDisabled(this.orgId);
  final String orgId;
}

final class ActiveSession extends Session {
  const ActiveSession(this.org, this.member);
  final Org org;
  final Member member;
}

final sessionProvider = Provider<AsyncValue<Session>>((ref) {
  final auth = ref.watch(authUserProvider);
  if (auth.isLoading) return const AsyncLoading();
  if (auth.value == null) return const AsyncData(SignedOut());
  final orgId = ref.watch(orgIdProvider);
  if (orgId.isLoading) return const AsyncLoading();
  if (orgId.hasError) return AsyncError(orgId.error!, orgId.stackTrace!);
  final id = orgId.value;
  if (id == null) return const AsyncData(NoSchool());
  final member = ref.watch(myMemberProvider);
  if (member.isLoading) return const AsyncLoading();
  final m = member.value;
  // Removed by admin (doc deleted) → back to create/join.
  if (m == null) return const AsyncData(NoSchool());
  return switch (m.status) {
    MemberStatus.pending => AsyncData(AwaitingApproval(id, m)),
    MemberStatus.disabled => AsyncData(AccessDisabled(id)),
    MemberStatus.active => ref.watch(orgProvider).whenData(
          (org) => org == null ? const NoSchool() : ActiveSession(org, m),
        ),
  };
});

/// The active member; only read below the active-session gate.
final currentMemberProvider = Provider<Member>((ref) {
  final s = ref.watch(sessionProvider).value;
  if (s is ActiveSession) return s.member;
  throw StateError('No active session');
});

final currentOrgProvider = Provider<Org>((ref) {
  final s = ref.watch(sessionProvider).value;
  if (s is ActiveSession) return s.org;
  throw StateError('No active session');
});

final actorProvider = Provider<Actor>((ref) {
  final m = ref.watch(currentMemberProvider);
  return (uid: m.uid, name: m.displayName);
});

// ---------------- inventory ----------------
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentOrgProvider).id,
  ),
);

final itemsProvider = StreamProvider<List<Item>>(
  (ref) => ref.watch(inventoryRepositoryProvider).watchItems(),
);

final itemByIdProvider = Provider.family<Item?, String>((ref, id) {
  final items = ref.watch(itemsProvider).value ?? const [];
  for (final i in items) {
    if (i.id == id) return i;
  }
  return null;
});

final staffProvider = StreamProvider<List<StaffMember>>(
  (ref) => ref.watch(inventoryRepositoryProvider).watchStaff(),
);

final demandsProvider = StreamProvider.family<List<Demand>, DocStatus?>(
  (ref, status) =>
      ref.watch(inventoryRepositoryProvider).watchDemands(status: status),
);

final demandProvider = StreamProvider.family<Demand?, String>(
  (ref, id) => ref.watch(inventoryRepositoryProvider).watchDemand(id),
);

final receiptsProvider = StreamProvider.family<List<Receipt>, DocStatus?>(
  (ref, status) =>
      ref.watch(inventoryRepositoryProvider).watchReceipts(status: status),
);

final receiptProvider = StreamProvider.family<Receipt?, String>(
  (ref, id) => ref.watch(inventoryRepositoryProvider).watchReceipt(id),
);

final itemLedgerProvider = StreamProvider.family<List<LedgerEntry>, String>(
  (ref, itemId) =>
      ref.watch(inventoryRepositoryProvider).watchItemLedger(itemId),
);

final staffLedgerProvider = StreamProvider.family<List<LedgerEntry>, String>(
  (ref, staffId) =>
      ref.watch(inventoryRepositoryProvider).watchStaffLedger(staffId),
);

final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref
      .watch(accountRepositoryProvider)
      .watchMembers(ref.watch(currentOrgProvider).id),
);
