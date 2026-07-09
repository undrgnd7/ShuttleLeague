import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_provider.dart';

final leagueStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, leagueId) {
    final firestore = ref.read(firestoreProvider);

    return firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('players')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => d.data()).toList();
    });
  },
);
