import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_model.dart';
import '../providers/match_history_provider.dart';
import '../providers/my_dashboard_provider.dart';
import '../providers/player_provider.dart';

class MyMatchHistoryPage extends ConsumerWidget {
  const MyMatchHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(myDashboardProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Match History')),
      body: dashboardAsync.when(
        data: (dashboard) {
          if (dashboard == null) {
            return Center(
              child: Text('No player linked to your account yet.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }
          return _HistoryList(playerId: dashboard.player.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final String playerId;
  const _HistoryList({required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(playerMatchHistoryProvider(playerId));
    final playersAsync = ref.watch(playerListProvider);
    final cs = Theme.of(context).colorScheme;

    return historyAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 48, color: cs.outline),
                const SizedBox(height: 12),
                Text('No completed matches yet',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        final playerMap = {
          for (final p in playersAsync.valueOrNull ?? const <PlayerModel>[])
            p.id: p,
        };
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: entries.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HistoryCard(
              entry: entries[i],
              playerId: playerId,
              playerMap: playerMap,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PlayerMatchEntry entry;
  final String playerId;
  final Map<String, PlayerModel> playerMap;

  const _HistoryCard({
    required this.entry,
    required this.playerId,
    required this.playerMap,
  });

  String _nameFor(String id) {
    if (id == playerId) return 'You';
    return playerMap[id]?.name.split(' ').first ?? 'Unknown';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final match = entry.match;
    final onTeamA = match.teamA.contains(playerId);
    final myTeam = onTeamA ? match.teamA : match.teamB;
    final oppTeam = onTeamA ? match.teamB : match.teamA;
    final partner = myTeam.where((id) => id != playerId).map(_nameFor).join(', ');
    final opponents = oppTeam.map(_nameFor).join(' & ');

    final won = entry.won;
    final resultColor = won == null
        ? cs.onSurfaceVariant
        : won
            ? const Color(0xFF2E7D32)
            : cs.error;
    final resultLabel = won == null ? 'No Result' : (won ? 'Win' : 'Loss');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resultColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(resultLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: resultColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.leagueName,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(_formatDate(entry.sortTime),
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              partner.isNotEmpty
                  ? 'You & $partner  vs  $opponents'
                  : 'You  vs  $opponents',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (match.scoreA != null && match.scoreB != null) ...[
              const SizedBox(height: 4),
              Text(
                onTeamA
                    ? '${match.scoreA} – ${match.scoreB}'
                    : '${match.scoreB} – ${match.scoreA}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
