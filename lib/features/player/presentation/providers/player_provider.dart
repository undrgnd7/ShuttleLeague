import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/player_repository_impl.dart';
import '../../domain/player_repository.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  final db = ref.read(databaseProvider);
  return PlayerRepositoryImpl(db);
});

final playerListProvider = FutureProvider((ref) async {
  final repo = ref.read(playerRepositoryProvider);
  return repo.getPlayers();
});
