import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth state ───────────────────────────────────────────────────────────────

class UserRecord {
  final String uid;
  final String name;
  final String email;
  final String role;

  const UserRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRecord(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'player',
    );
  }
}

final allUsersProvider = StreamProvider<List<UserRecord>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snap) => snap.docs.map(UserRecord.fromDoc).toList());
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// ─── User role ────────────────────────────────────────────────────────────────

/// Role stored in Firestore: users/{uid} → { role: "admin" | "player", name: "..." }
final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  return doc.data()?['role'] as String?;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider).valueOrNull == 'admin';
});

// ─── Auth service ─────────────────────────────────────────────────────────────

const _adminCode = 'SHUTTLE_ADMIN';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  static Future<void> register({
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
    String? adminCode,
  }) async {
    if (isAdmin && adminCode?.trim() != _adminCode) {
      throw Exception('Invalid admin code');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);

    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': isAdmin ? 'admin' : 'player',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await cred.user!.updateDisplayName(name.trim());
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> updateProfile({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await Future.wait([
      user.updateDisplayName(name.trim()),
      _db.collection('users').doc(user.uid).update({'name': name.trim()}),
    ]);
  }

  static Future<void> sendPasswordReset() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw Exception('No email on account');
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  static Future<void> sendPasswordResetByEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> updateUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }
}
