import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/firebase/firebase_provider.dart';
import '../../data/player_model.dart';
import '../../data/player_cloud_repository.dart';
import '../../domain/player_repository.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  final db = ref.read(firestoreProvider);
  return PlayerCloudRepository(db);
});

// Real-time stream so all devices see changes instantly
final playerListProvider = StreamProvider<List<PlayerModel>>((ref) {
  final db = ref.read(firestoreProvider);
  return PlayerCloudRepository(db).watchPlayers();
});

final playerControllerProvider = Provider((ref) {
  return PlayerController(ref.read(playerRepositoryProvider));
});

class PlayerController {
  final PlayerRepository _repo;
  PlayerController(this._repo);

  Future<void> createPlayer(
    String name, {
    int skillLevel = 3,
    PlayerGender gender = PlayerGender.male,
  }) async {
    final player = PlayerModel(
      id: const Uuid().v4(),
      name: name.trim(),
      skillLevel: skillLevel,
      gender: gender,
      createdAt: DateTime.now(),
    );
    await _repo.addPlayer(player);
  }

  Future<void> updatePlayer(PlayerModel player) => _repo.updatePlayer(player);

  Future<void> deletePlayer(String id) => _repo.deletePlayer(id);
}
