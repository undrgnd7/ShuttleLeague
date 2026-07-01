import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth state ───────────────────────────────────────────────────────────────

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
}
