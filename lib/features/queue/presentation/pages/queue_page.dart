import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../league/presentation/providers/league_provider.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/live_session_state.dart';
import '../providers/queue_provider.dart';

class QueuePage extends ConsumerStatefulWidget {
  final String sessionId;
  final String leagueId;

  const QueuePage({
    super.key,
    required this.sessionId,
    required this.leagueId,
  });

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(queueControllerProvider(widget.sessionId));
    final controller =
        ref.read(queueControllerProvider(widget.sessionId).notifier);
    final leaguePlayers =
        ref.watch(leagueDetailPlayersProvider(widget.leagueId));
    final cs = Theme.of(context).colorScheme;

    return leaguePlayers.when(
      data: (players) {
        if (!_initialized && state.waitingQueue.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.initWithPlayers(players.map((p) => p.id).toList());
            setState(() => _initialized = true);
          });
        }

        final playerMap = {for (final p in players) p.id: p};
        final ratings = {for (final p in players) p.id: p.rating};

        return Scaffold(
          appBar: AppBar(
            title: const Text('Live Queue'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.people_rounded, size: 16),
                  label: Text(
                      '${state.waitingQueue.length} waiting'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Start Match button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.waitingQueue.length >= 4
                        ? () => controller.startNextMatch(ratings: ratings)
                        : null,
                    icon: const Icon(Icons.sports_rounded),
                    label: Text(state.waitingQueue.length < 4
                        ? 'Need ${4 - state.waitingQueue.length} more players'
                        : 'Start Match (Court ${state.activeMatches.length + 1})'),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // Active courts
                    if (state.activeMatches.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.sports_rounded,
                        label: 'Active Courts',
                        color: cs.primary,
                        count: state.activeMatches.length,
                      ),
                      const SizedBox(height: 8),
                      ...state.activeMatches.map((match) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MatchCard(
                              match: match,
                              playerMap: playerMap,
                              onTeamWon: (teamAWon) async {
                                final winners = teamAWon
                                    ? match.teamA
                                    : match.teamB;
                                final losers = teamAWon
                                    ? match.teamB
                                    : match.teamA;
                                await ref
                                    .read(playerRepositoryProvider)
                                    .recordMatchResult(
                                  leagueId: widget.leagueId,
                                  winnerIds: winners,
                                  loserIds: losers,
                                );
                                controller.endMatch(
                                  matchId: match.matchId,
                                  teamAWon: teamAWon,
                                );
                                ref.invalidate(playerListProvider);
                              },
                            ),
                          )),
                      const SizedBox(height: 8),
                    ],

                    // Waiting queue
                    _SectionHeader(
                      icon: Icons.queue_rounded,
                      label: 'Waiting Queue',
                      color: cs.secondary,
                      count: state.waitingQueue.length,
                    ),
                    const SizedBox(height: 8),
                    if (state.waitingQueue.isEmpty)
                      _EmptyQueue(
                        onAddAll: players.isEmpty
                            ? null
                            : () => controller
                                .initWithPlayers(players.map((p) => p.id).toList()),
                      )
                    else
                      ...state.waitingQueue.asMap().entries.map((entry) {
                        final i = entry.key;
                        final id = entry.value;
                        final player = playerMap[id];
                        if (player == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _QueueRow(
                            position: i + 1,
                            player: player,
                            onRemove: () => controller.removeFromQueue(id),
                          ),
                        );
                      }),

                    // Players not in queue
                    if (players
                        .where((p) =>
                            !state.waitingQueue.contains(p.id) &&
                            !state.activeMatches.any((m) =>
                                m.teamA.contains(p.id) ||
                                m.teamB.contains(p.id)))
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(
                        icon: Icons.person_off_rounded,
                        label: 'Sitting Out',
                        color: cs.outline,
                        count: players
                            .where((p) =>
                                !state.waitingQueue.contains(p.id) &&
                                !state.activeMatches.any((m) =>
                                    m.teamA.contains(p.id) ||
                                    m.teamB.contains(p.id)))
                            .length,
                      ),
                      const SizedBox(height: 8),
                      ...players
                          .where((p) =>
                              !state.waitingQueue.contains(p.id) &&
                              !state.activeMatches.any((m) =>
                                  m.teamA.contains(p.id) ||
                                  m.teamB.contains(p.id)))
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _SittingOutRow(
                                  player: p,
                                  onJoin: () => controller.joinQueue(p.id),
                                ),
                              )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final ActiveMatch match;
  final Map<String, PlayerModel> playerMap;
  final void Function(bool teamAWon) onTeamWon;

  const _MatchCard({
    required this.match,
    required this.playerMap,
    required this.onTeamWon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Court ${match.courtNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer)),
                ),
                const Spacer(),
                const Icon(Icons.sports_score_rounded, size: 16),
                const SizedBox(width: 4),
                Text('In progress',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _TeamColumn(
                  label: 'Team A',
                  playerIds: match.teamA,
                  playerMap: playerMap,
                  color: cs.primary,
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('VS',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: cs.onSurfaceVariant)),
                ),
                Expanded(
                    child: _TeamColumn(
                  label: 'Team B',
                  playerIds: match.teamB,
                  playerMap: playerMap,
                  color: const Color(0xFF1565C0),
                )),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onTeamWon(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                    ),
                    child: const Text('Team A Won'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onTeamWon(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                    ),
                    child: const Text('Team B Won'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String label;
  final List<String> playerIds;
  final Map<String, PlayerModel> playerMap;
  final Color color;

  const _TeamColumn({
    required this.label,
    required this.playerIds,
    required this.playerMap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 8),
        ...playerIds.map((id) {
          final p = playerMap[id];
          final name = p?.name ?? id.substring(0, 6);
          final initials = _initials(name);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const SizedBox(width: 6),
                Text(name.split(' ').first,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _QueueRow extends StatelessWidget {
  final int position;
  final PlayerModel player;
  final VoidCallback onRemove;

  const _QueueRow({
    required this.position,
    required this.player,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppTheme.avatarColor(player.name);

    return Card(
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              child: Text('$position',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(_initials(player.name),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ],
        ),
        title: Text(player.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Row(
          children: [
            const Icon(Icons.star_rounded, size: 12, color: AppTheme.ratingAmber),
            const SizedBox(width: 3),
            Text('${player.rating}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.ratingAmber,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${player.wins}W · ${player.losses}L',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
          color: cs.error,
          onPressed: onRemove,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _SittingOutRow extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onJoin;

  const _SittingOutRow({required this.player, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppTheme.avatarColor(player.name);

    return Card(
      color: cs.surfaceContainerLow,
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        title: Text(player.name,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: cs.onSurfaceVariant)),
        trailing: FilledButton.tonal(
          onPressed: onJoin,
          style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12)),
          child: const Text('Join', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final VoidCallback? onAddAll;
  const _EmptyQueue({this.onAddAll});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.queue_rounded, size: 36, color: cs.outline),
          const SizedBox(height: 8),
          Text('Queue is empty',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          if (onAddAll != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddAll,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Add All League Players'),
            ),
          ],
        ],
      ),
    );
  }
}
