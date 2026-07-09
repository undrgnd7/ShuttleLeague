import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../leaderboard/presentation/providers/leaderboard_provider.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../schedule/domain/schedule_model.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../providers/session_controller.dart';
import '../widgets/player_pickers.dart';

class SessionDetailPage extends ConsumerWidget {
  final String leagueId;
  final String sessionId;
  final String leagueName;

  const SessionDetailPage({
    super.key,
    required this.leagueId,
    required this.sessionId,
    required this.leagueName,
  });

  Future<void> _confirmDeleteSession(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text(
            'This removes the session and all its matches, and reverses any points they awarded. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await ref.read(sessionControllerProvider).deleteSession(
          sessionId: sessionId,
          leagueId: leagueId,
        );
    ref.invalidate(sessionHistoryProvider(leagueId));
    ref.invalidate(leaderboardProvider(leagueId));
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addMatch(BuildContext context, WidgetRef ref) async {
    final players = ref.read(playerListProvider).valueOrNull ?? [];
    final chosen = await pickMultiplePlayers(context, players, count: 4);
    if (chosen == null || !context.mounted) return;

    final round = await _askNumber(context, 'Round number', initial: 1);
    if (round == null || !context.mounted) return;
    final court = await _askNumber(context, 'Court number', initial: 1);
    if (court == null) return;

    await ref.read(sessionControllerProvider).addMatch(
          sessionId: sessionId,
          round: round,
          courtNumber: court,
          teamA: [chosen[0].id, chosen[1].id],
          teamB: [chosen[2].id, chosen[3].id],
        );
  }

  Future<int?> _askNumber(BuildContext context, String label,
      {required int initial}) async {
    final ctrl = TextEditingController(text: '$initial');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text) ?? initial),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(sessionMatchesProvider(sessionId));
    final playersAsync = ref.watch(playerListProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session Detail'),
            Text(leagueName,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete session',
              onPressed: () => _confirmDeleteSession(context, ref),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _addMatch(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Match'),
            )
          : null,
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Text('No matches in this session',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            );
          }
          return playersAsync.when(
            data: (players) {
              final playerMap = {for (final p in players) p.id: p};
              final roundNumbers =
                  matches.map((m) => m.round).toSet().toList()..sort();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: roundNumbers.length,
                itemBuilder: (ctx, i) {
                  final round = roundNumbers[i];
                  final roundMatches =
                      matches.where((m) => m.round == round).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Round $round',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant)),
                        ),
                      ),
                      ...roundMatches.map((match) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EditableMatchCard(
                              match: match,
                              playerMap: playerMap,
                              leagueId: leagueId,
                              sessionId: sessionId,
                              isAdmin: isAdmin,
                            ),
                          )),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EditableMatchCard extends ConsumerWidget {
  final ScheduledMatch match;
  final Map<String, PlayerModel> playerMap;
  final String leagueId;
  final String sessionId;
  final bool isAdmin;

  const _EditableMatchCard({
    required this.match,
    required this.playerMap,
    required this.leagueId,
    required this.sessionId,
    required this.isAdmin,
  });

  String _teamLabel(List<String> ids) => ids
      .map((id) => playerMap[id]?.name.split(' ').first ?? id.substring(0, 6))
      .join(' & ');

  Future<void> _setWinner(BuildContext context, WidgetRef ref, bool teamAWon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Result'),
        content: Text(
            'Set "${_teamLabel(teamAWon ? match.teamA : match.teamB)}" as the winner? Points will be corrected accordingly.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(sessionControllerProvider).editMatchWinner(
          sessionId: sessionId,
          leagueId: leagueId,
          match: match,
          newTeamAWon: teamAWon,
        );
    ref.invalidate(leaderboardProvider(leagueId));
  }

  Future<void> _deleteMatch(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Match'),
        content: const Text(
            'This removes the match. If it was completed, its points will be reversed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(sessionControllerProvider).deleteMatch(
          sessionId: sessionId,
          leagueId: leagueId,
          match: match,
        );
    ref.invalidate(leaderboardProvider(leagueId));
  }

  Future<void> _swapPlayer(
      BuildContext context, WidgetRef ref, String oldPlayerId) async {
    final players = ref.read(playerListProvider).valueOrNull ?? [];
    final replacement = await pickSinglePlayer(
      context,
      players,
      excludeIds: {...match.teamA, ...match.teamB},
    );
    if (replacement == null) return;

    await ref.read(sessionControllerProvider).swapPlayer(
          sessionId: sessionId,
          match: match,
          oldPlayerId: oldPlayerId,
          newPlayerId: replacement.id,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Color borderColor;
    switch (match.status) {
      case MatchStatus.inProgress:
        borderColor = cs.primary;
        break;
      case MatchStatus.completed:
        borderColor = Colors.green.shade300;
        break;
      default:
        borderColor = cs.outlineVariant;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Court ${match.courtNumber}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSecondaryContainer)),
                ),
                const Spacer(),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: cs.error,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete match',
                    onPressed: () => _deleteMatch(context, ref),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TeamButton(
                    label: 'Team A',
                    playerIds: match.teamA,
                    playerMap: playerMap,
                    isWinner: match.teamAWon == true,
                    color: cs.primary,
                    enabled: isAdmin,
                    canSwap: isAdmin && !match.isCompleted,
                    onTap: () => _setWinner(context, ref, true),
                    onSwap: (id) => _swapPlayer(context, ref, id),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Text('vs', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: _TeamButton(
                    label: 'Team B',
                    playerIds: match.teamB,
                    playerMap: playerMap,
                    isWinner: match.teamAWon == false,
                    color: const Color(0xFF1565C0),
                    enabled: isAdmin,
                    canSwap: isAdmin && !match.isCompleted,
                    onTap: () => _setWinner(context, ref, false),
                    onSwap: (id) => _swapPlayer(context, ref, id),
                  ),
                ),
              ],
            ),
            if (match.isCompleted &&
                match.scoreA != null &&
                match.scoreB != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${match.scoreA} – ${match.scoreB}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamButton extends StatelessWidget {
  final String label;
  final List<String> playerIds;
  final Map<String, PlayerModel> playerMap;
  final bool isWinner;
  final Color color;
  final bool enabled;
  final bool canSwap;
  final VoidCallback onTap;
  final void Function(String playerId) onSwap;

  const _TeamButton({
    required this.label,
    required this.playerIds,
    required this.playerMap,
    required this.isWinner,
    required this.color,
    required this.enabled,
    required this.canSwap,
    required this.onTap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isWinner ? color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isWinner) ...[
                  const Icon(Icons.emoji_events_rounded,
                      size: 13, color: Color(0xFFFFD700)),
                  const SizedBox(width: 3),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isWinner ? color : color.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 4),
            ...playerIds.map((id) {
              final name =
                  playerMap[id]?.name.split(' ').first ?? id.substring(0, 6);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isWinner ? FontWeight.w700 : FontWeight.w400)),
                    ),
                    if (canSwap)
                      GestureDetector(
                        onTap: () => onSwap(id),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(Icons.swap_horiz_rounded,
                              size: 14, color: color.withValues(alpha: 0.7)),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
