import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../domain/roles.dart';
import '../domain/stock_logic.dart';
import 'mappers.dart';

/// Sign-in, the user's profile, creating/joining a school, and managing
/// members. The single write path for everything account-related.
class AccountRepository {
  AccountRepository(this._auth, this._db, {Random? random})
      : _random = random ?? Random.secure();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final Random _random;

  Stream<User?> authChanges() => _auth.authStateChanges();

  DocumentReference<Json> _userDoc(String uid) => _db.doc('users/$uid');
  DocumentReference<Json> _orgDoc(String orgId) => _db.doc('orgs/$orgId');
  CollectionReference<Json> _members(String orgId) =>
      _db.collection('orgs/$orgId/members');

  /// The org id this user belongs to, or null before create/join.
  Stream<String?> watchOrgId(String uid) => _userDoc(uid)
      .snapshots()
      .map((d) => d.data()?['orgId'] as String?);

  Stream<Org?> watchOrg(String orgId) => _orgDoc(orgId)
      .snapshots()
      .map((d) => d.exists ? orgFrom(d) : null);

  Stream<Member?> watchMember(String orgId, String uid) => _members(orgId)
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? memberFrom(d) : null);

  Stream<List<Member>> watchMembers(String orgId) =>
      _members(orgId).snapshots().map(
            (q) => q.docs.map(memberFrom).toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName)),
          );

  Future<Result<void>> signIn(String email, String password) =>
      _authGuard(() => _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ));

  Future<Result<void>> register({
    required String name,
    required String email,
    required String password,
  }) =>
      _authGuard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user!.updateDisplayName(name.trim());
        await _userDoc(cred.user!.uid).set({
          'displayName': name.trim(),
          'email': email.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<Result<void>> sendPasswordReset(String email) =>
      _authGuard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  /// Creates a new school. The founder becomes incharge + admin. Optionally
  /// seeds the standard janitorial item list.
  Future<Result<String>> createSchool({
    required String schoolName,
    required bool seedDefaultItems,
  }) =>
      guard(() async {
        final user = _requireUser();
        final orgRef = _db.collection('orgs').doc();
        final code = StockLogic.joinCode(_random.nextInt);
        final name = _nameOf(user);
        final batch = _db.batch()
          ..set(orgRef, {
            'name': schoolName.trim(),
            'joinCode': code,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'modules': ['janitorial'],
            'schemaVersion': 1,
          })
          ..set(_members(orgRef.id).doc(user.uid), {
            'uid': user.uid,
            'displayName': name,
            'email': user.email ?? '',
            'role': Role.incharge.id,
            'isAdmin': true,
            'status': MemberStatus.active.id,
            'locationIds': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(_db.doc('joinCodes/$code'),
              {'orgId': orgRef.id, 'orgName': schoolName.trim()});
        await batch.commit();
        await _setUserOrg(user, orgRef.id);
        if (seedDefaultItems) await _seedItems(orgRef.id, user.uid);
        return orgRef.id;
      });

  Future<void> _seedItems(String orgId, String uid) async {
    final batch = _db.batch();
    for (final (name, unit) in defaultJanitorialItems) {
      batch.set(_db.collection('orgs/$orgId/items').doc(), {
        'name': name,
        'unit': unit,
        'category': 'janitorial',
        'reorderLevel': 5,
        'currentStock': 0,
        'active': true,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Files a pending request to join the school with [joinCode].
  Future<Result<void>> requestToJoin({
    required String joinCode,
    required Role requestedRole,
  }) =>
      guard(() async {
        final user = _requireUser();
        final code = joinCode.trim().toUpperCase();
        final lookup = await _db.doc('joinCodes/$code').get();
        final orgId = lookup.data()?['orgId'] as String?;
        if (orgId == null) {
          throw const AppFailure(FailureCode.notFound,
              'No school found with that code. Check it with your admin.');
        }
        await _members(orgId).doc(user.uid).set({
          'uid': user.uid,
          'displayName': _nameOf(user),
          'email': user.email ?? '',
          'role': Role.viewer.id,
          'isAdmin': false,
          'status': MemberStatus.pending.id,
          'requestedRole': requestedRole.id,
          'locationIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _setUserOrg(user, orgId);
      });

  /// Withdraws a pending request (or leaves after being removed).
  Future<Result<void>> leaveSchool(String orgId, {required bool isPending}) =>
      guard(() async {
        final user = _requireUser();
        if (isPending) await _members(orgId).doc(user.uid).delete();
        await _userDoc(user.uid).set(
          {'orgId': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      });

  /// Admin: approve / change role / grant admin / disable.
  Future<Result<void>> updateMember({
    required String orgId,
    required String memberUid,
    required Role role,
    required bool isAdmin,
    required MemberStatus status,
  }) =>
      guard(() => _members(orgId).doc(memberUid).update({
            'role': role.id,
            'isAdmin': isAdmin,
            'status': status.id,
            'approvedBy': _requireUser().uid,
            'approvedAt': FieldValue.serverTimestamp(),
          }));

  /// Admin: delete a join request.
  Future<Result<void>> removeMember(String orgId, String memberUid) =>
      guard(() => _members(orgId).doc(memberUid).delete());

  Future<Result<void>> renameSchool(String orgId, String name) =>
      guard(() => _orgDoc(orgId).update({'name': name.trim()}));

  Future<void> _setUserOrg(User user, String orgId) =>
      _userDoc(user.uid).set({
        'displayName': _nameOf(user),
        'email': user.email ?? '',
        'orgId': orgId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  User _requireUser() {
    final u = _auth.currentUser;
    if (u == null) {
      throw const AppFailure(FailureCode.auth, 'Please sign in again.');
    }
    return u;
  }

  String _nameOf(User u) {
    final n = u.displayName?.trim() ?? '';
    return n.isNotEmpty ? n : (u.email ?? 'User').split('@').first;
  }

  Future<Result<void>> _authGuard(Future<void> Function() body) async {
    try {
      await body();
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(AppFailure(FailureCode.auth, _authMessage(e.code)));
    } on Object catch (e) {
      return Err(failureFrom(e));
    }
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' =>
          'An account with this email already exists. Sign in instead.',
        'weak-password' => 'Password must be at least 6 characters.',
        'network-request-failed' => 'No connection. Please try again.',
        'too-many-requests' => 'Too many attempts. Wait a minute and retry.',
        _ => 'Sign-in failed ($code).',
      };
}
