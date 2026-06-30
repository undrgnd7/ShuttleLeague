import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/match_repository_impl.dart';
import '../../domain/match_repository.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  final db = ref.read(databaseProvider);
  return MatchRepositoryImpl(db);
});
