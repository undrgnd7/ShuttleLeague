import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../schedule/domain/schedule_model.dart';
import '../../../schedule/presentation/providers/schedule_provider.dart';

class PlayerSessionPage extends ConsumerWidget {
  final String sessionId;
  final String leagueName;

  const PlayerSessionPage({
    super.key,
    required this.sessionId,
    required this.leagueName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(sessionMatchesProvider(sessionId));
    final playersAsync = ref.watch(playerListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leagueName),
            Text('Live Session',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text('Live',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return _buildEmpty(context);
          }
          return playersAsync.when(
            data: (players) {
              final playerMap = {for (final p in players) p.id: p};
              return _MatchList(matches: matches, playerMap: playerMap);
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

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_rounded, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text('Schedule not generated yet',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('The admin is setting up the session',
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<ScheduledMatch> matches;
  final Map<String, PlayerModel> playerMap;

  const _MatchList({required this.matches, required this.playerMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = matches.where((m) => m.isCompleted).length;
    final total = matches.length;

    // Group by round
    final roundNumbers =
        matches.map((m) => m.round).toSet().toList()..sort();

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$completed / $total matches',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: roundNumbers.length,
            itemBuilder: (ctx, roundIdx) {
              final round = roundNumbers[roundIdx];
              final roundMatches =
                  matches.where((m) => m.round == round).toList();
              final allDone =
                  roundMatches.every((m) => m.isCompleted);
              final anyActive =
                  roundMatches.any((m) => m.isInProgress);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: allDone
                                ? Colors.green.shade100
                                : anyActive
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Round $round',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: allDone
                                  ? Colors.green.shade800
                                  : anyActive
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (anyActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('Now playing',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (allDone) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded,
                              size: 13, color: Colors.green),
                        ],
                      ],
                    ),
                  ),
                  ...roundMatches.map((match) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReadOnlyMatchCard(
                          match: match,
                          playerMap: playerMap,
                        ),
                      )),
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyMatchCard extends StatelessWidget {
  final ScheduledMatch match;
  final Map<String, PlayerModel> playerMap;

  const _ReadOnlyMatchCard(
      {required this.match, required this.playerMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color borderColor;
    Color headerColor;

    switch (match.status) {
      case MatchStatus.inProgress:
        borderColor = cs.primary;
        headerColor = cs.primaryContainer;
        break;
      case MatchStatus.completed:
        borderColor = Colors.green.shade300;
        headerColor = Colors.green.shade50;
        break;
      default:
        borderColor = cs.outlineVariant;
        headerColor = cs.surfaceContainerLow;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(
            color: borderColor,
            width: match.isInProgress ? 2 : 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
                _statusLabel(cs),
              ],
            ),
          ),

          // Teams
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                    child: _TeamCol(
                  label: 'Team A',
                  playerIds: match.teamA,
                  playerMap: playerMap,
                  color: cs.primary,
                  isWinner: match.teamAWon == true,
                )),
                Text('vs',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurfaceVariant)),
                Expanded(
                    child: _TeamCol(
                  label: 'Team B',
                  playerIds: match.teamB,
                  playerMap: playerMap,
                  color: const Color(0xFF1565C0),
                  isWinner: match.teamAWon == false,
                )),
              ],
            ),
          ),

          // Result footer
          if (match.isCompleted)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    match.scoreA != null && match.scoreB != null
                        ? '${match.scoreA} – ${match.scoreB}'
                        : 'Completed',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusLabel(ColorScheme cs) {
    switch (match.status) {
      case MatchStatus.inProgress:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text('Live',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700)),
          ],
        );
      case MatchStatus.completed:
        return Text(
          match.teamAWon == true ? 'Team A Won' : 'Team B Won',
          style:
              TextStyle(fontSize: 11, color: Colors.green.shade700),
        );
      default:
        return Text('Upcoming',
            style:
                TextStyle(fontSize: 11, color: cs.onSurfaceVariant));
    }
  }
}

class _TeamCol extends StatelessWidget {
  final String label;
  final List<String> playerIds;
  final Map<String, PlayerModel> playerMap;
  final Color color;
  final bool isWinner;

  const _TeamCol({
    required this.label,
    required this.playerIds,
    required this.playerMap,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  color: isWinner ? color : color.withValues(alpha: 0.7),
                )),
          ],
        ),
        const SizedBox(height: 6),
        ...playerIds.map((id) {
          final p = playerMap[id];
          final name = p?.name ?? id.substring(0, 6);
          final initials = name.length >= 2
              ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
              : name[0].toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.avatarColor(name),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    name.split(' ').first,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isWinner
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
