import 'package:cloud_firestore/cloud_firestore.dart';

class SessionCloudService {
  final FirebaseFirestore firestore;

  SessionCloudService(this.firestore);

  Stream<DocumentSnapshot> watchSession(String sessionId) {
    return firestore.collection('sessions').doc(sessionId).snapshots();
  }

  Future<void> updateQueue({
    required String sessionId,
    required List<String> queue,
  }) async {
    await firestore.collection('sessions').doc(sessionId).set({
      'queue': queue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
