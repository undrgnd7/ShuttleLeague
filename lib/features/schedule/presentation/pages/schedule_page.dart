import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../league/presentation/providers/league_provider.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/schedule_model.dart';
import '../providers/schedule_provider.dart';

class SchedulePage extends ConsumerStatefulWidget {
  final String sessionId;
  final String leagueId;

  const SchedulePage({
    super.key,
    required this.sessionId,
    required this.leagueId,
  });

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  Set<String>? _selectedIds;
  int _courts = 1;

  void _initIfNeeded(List<PlayerModel> players) {
    if (_selectedIds == null) {
      _selectedIds = {for (final p in players) p.id};
    }
  }

  void _generate(List<PlayerModel> allPlayers) {
    final selected =
        allPlayers.where((p) => _selectedIds!.contains(p.id)).toList();
    final ratings = {for (final p in selected) p.id: p.rating};
    ref.read(scheduleProvider(widget.sessionId).notifier).generate(
          playerIds: selected.map((p) => p.id).toList(),
          courts: _courts,
          ratings: ratings,
        );
  }

  void _reselect() {
    ref.read(scheduleProvider(widget.sessionId).notifier).reset();
    setState(() => _selectedIds = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider(widget.sessionId));
    final leaguePlayers =
        ref.watch(leagueDetailPlayersProvider(widget.leagueId));

    return leaguePlayers.when(
      data: (players) {
        _initIfNeeded(players);

        final playerMap = {for (final p in players) p.id: p};
        final selected =
            players.where((p) => _selectedIds!.contains(p.id)).toList();
        final maxCourts = (selected.length ~/ 4).clamp(1, 8);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Full Schedule'),
            actions: [
              if (!scheduleState.isEmpty)
                IconButton(
                  icon: const Icon(Icons.people_alt_rounded),
                  tooltip: 'Change players / courts',
                  onPressed: _reselect,
                ),
            ],
          ),
          body: scheduleState.isEmpty
              ? _SetupView(
                  players: players,
                  selectedIds: _selectedIds!,
                  courts: _courts,
                  maxCourts: maxCourts,
                  onTogglePlayer: (id) => setState(() {
                    if (_selectedIds!.contains(id)) {
                      _selectedIds!.remove(id);
                    } else {
                      _selectedIds!.add(id);
                    }
                    // Clamp courts to new max
                    final newMax = (_selectedIds!.length ~/ 4).clamp(1, 8);
                    if (_courts > newMax) _courts = newMax;
                  }),
                  onSelectAll: () => setState(
                      () => _selectedIds = {for (final p in players) p.id}),
                  onDeselectAll: () => setState(() => _selectedIds = {}),
                  onCourtsChanged: (v) => setState(() => _courts = v),
                  onGenerate: selected.length >= 4
                      ? () => _generate(players)
                      : null,
                )
              : _ScheduleList(
                  state: scheduleState,
                  playerMap: playerMap,
                  sessionId: widget.sessionId,
                  onStart: (matchNumber) => ref
                      .read(scheduleProvider(widget.sessionId).notifier)
                      .startMatch(matchNumber),
                  onComplete: (matchNumber, teamAWon) async {
                    final match = scheduleState.matches
                        .firstWhere((m) => m.matchNumber == matchNumber);
                    final winners = teamAWon ? match.teamA : match.teamB;
                    final losers = teamAWon ? match.teamB : match.teamA;
                    await ref
                        .read(playerRepositoryProvider)
                        .recordMatchResult(
                          leagueId: widget.leagueId,
                          winnerIds: winners,
                          loserIds: losers,
                        );
                    ref
                        .read(scheduleProvider(widget.sessionId).notifier)
                        .completeMatch(matchNumber, teamAWon: teamAWon);
                    ref.invalidate(playerListProvider);
                  },
                ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// ─── Setup: players + courts ──────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  final List<PlayerModel> players;
  final Set<String> selectedIds;
  final int courts;
  final int maxCourts;
  final void Function(String id) onTogglePlayer;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final void Function(int) onCourtsChanged;
  final VoidCallback? onGenerate;

  const _SetupView({
    required this.players,
    required this.selectedIds,
    required this.courts,
    required this.maxCourts,
    required this.onTogglePlayer,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onCourtsChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = selectedIds.length;
    final activeCourts = courts.clamp(1, (n ~/ 4).clamp(1, 8));
    final activePerRound = activeCourts * 4;
    final rounds = n >= 4
        ? ((n * (n - 1)) / activePerRound).ceil().clamp(3, 30)
        : 0;
    final totalMatches = rounds * activeCourts;
    final allSelected = n == players.length;

    return Column(
      children: [
        // ── Player selection header ───────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          color: cs.primaryContainer.withOpacity(0.5),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Who is playing today?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: cs.onPrimaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      '$n of ${players.length} players selected',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimaryContainer.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: allSelected ? onDeselectAll : onSelectAll,
                child: Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // ── Courts selector ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.sports_tennis_rounded,
                  size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Text('Courts',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: cs.onSurface)),
              const SizedBox(width: 6),
              Text('(max $maxCourts for $n players)',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Spacer(),
              // Minus button
              _CourtsBtn(
                icon: Icons.remove_rounded,
                enabled: courts > 1,
                onTap: () => onCourtsChanged((courts - 1).clamp(1, maxCourts)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$activeCourts',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.primary)),
              ),
              // Plus button
              _CourtsBtn(
                icon: Icons.add_rounded,
                enabled: courts < maxCourts,
                onTap: () => onCourtsChanged((courts + 1).clamp(1, maxCourts)),
              ),
            ],
          ),
        ),

        // ── Session preview ───────────────────────────────────────
        if (n >= 4)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.surfaceContainerLowest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PreviewStat(
                    label: 'Rounds',
                    value: '$rounds',
                    color: cs.primary),
                _Divider(),
                _PreviewStat(
                    label: 'Per round',
                    value: '$activeCourts match${activeCourts > 1 ? "es" : ""}',
                    color: cs.secondary),
                _Divider(),
                _PreviewStat(
                    label: 'Total matches',
                    value: '$totalMatches',
                    color: const Color(0xFF2E7D32)),
                _Divider(),
                _PreviewStat(
                    label: 'Rest',
                    value: n > activePerRound
                        ? '${n - activePerRound}/round'
                        : 'None',
                    color: cs.outline),
              ],
            ),
          ),

        // ── Points legend ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          color: cs.surfaceContainerLow,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendChip(label: 'Win  +3 pts', color: const Color(0xFF2E7D32)),
              const SizedBox(width: 14),
              _LegendChip(label: 'Loss  +1 pt', color: cs.secondary),
              const SizedBox(width: 14),
              _LegendChip(label: 'Rest  0 pts', color: cs.outline),
            ],
          ),
        ),

        // ── Player list ───────────────────────────────────────────
        Expanded(
          child: players.isEmpty
              ? Center(
                  child: Text('No players in this league.',
                      style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: players.length,
                  itemBuilder: (ctx, i) {
                    final p = players[i];
                    final isSelected = selectedIds.contains(p.id);
                    return _PlayerCheckTile(
                      player: p,
                      isSelected: isSelected,
                      onTap: () => onTogglePlayer(p.id),
                    );
                  },
                ),
        ),

        // ── Generate button ───────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                if (n < 4 && n > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Select at least 4 players to continue.',
                      style: TextStyle(fontSize: 12, color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(n >= 4
                        ? 'Generate  ·  $totalMatches matches'
                        : 'Generate Schedule'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CourtsBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CourtsBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? cs.onPrimaryContainer : cs.outline),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PreviewStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant);
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PlayerCheckTile extends StatelessWidget {
  final PlayerModel player;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerCheckTile({
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = AppTheme.avatarColor(player.name);
    final initial =
        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? cs.primaryContainer.withOpacity(0.35)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? avatarColor
                        : avatarColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant)),
                      Text(
                          '${player.rating} pts  ·  ${player.wins}W ${player.losses}L',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? cs.primary : cs.outline,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Schedule list (grouped by round) ────────────────────────────────────────

class _ScheduleList extends StatelessWidget {
  final ScheduleState state;
  final Map<String, PlayerModel> playerMap;
  final String sessionId;
  final void Function(int matchNumber) onStart;
  final void Function(int matchNumber, bool teamAWon) onComplete;

  const _ScheduleList({
    required this.state,
    required this.playerMap,
    required this.sessionId,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = state.completed.length;
    final total = state.matches.length;

    // Group matches by round
    final roundNumbers =
        state.matches.map((m) => m.round).toSet().toList()..sort();

    return Column(
      children: [
        // Progress header
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
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
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
              final roundMatches = state.matches
                  .where((m) => m.round == round)
                  .toList();
              final allDone =
                  roundMatches.every((m) => m.isCompleted);
              final anyActive =
                  roundMatches.any((m) => m.isInProgress);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Round header
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
                        const SizedBox(width: 8),
                        Text(
                          '${roundMatches.length} court${roundMatches.length > 1 ? "s" : ""} simultaneous',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                        if (allDone) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded,
                              size: 13, color: Colors.green),
                        ],
                      ],
                    ),
                  ),

                  // Matches in this round
                  ...roundMatches.map((match) {
                    final isCurrent = match.isInProgress ||
                        (match.isScheduled &&
                            state.currentIndex ==
                                state.matches.indexOf(match));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MatchCard(
                        match: match,
                        playerMap: playerMap,
                        isCurrent: isCurrent,
                        onStart: () => onStart(match.matchNumber),
                        onComplete: (won) =>
                            onComplete(match.matchNumber, won),
                      ),
                    );
                  }),
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

class _MatchCard extends StatelessWidget {
  final ScheduledMatch match;
  final Map<String, PlayerModel> playerMap;
  final bool isCurrent;
  final VoidCallback onStart;
  final void Function(bool teamAWon) onComplete;

  const _MatchCard({
    required this.match,
    required this.playerMap,
    required this.isCurrent,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color borderColor;
    Color headerColor;
    String statusLabel;
    IconData statusIcon;

    switch (match.status) {
      case MatchStatus.inProgress:
        borderColor = cs.primary;
        headerColor = cs.primaryContainer;
        statusLabel = 'In Progress';
        statusIcon = Icons.sports_rounded;
        break;
      case MatchStatus.completed:
        borderColor = Colors.green.shade300;
        headerColor = Colors.green.shade50;
        statusLabel = match.teamAWon == true ? 'Team A Won' : 'Team B Won';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        borderColor =
            isCurrent ? cs.primary.withOpacity(0.5) : cs.outlineVariant;
        headerColor = isCurrent
            ? cs.primaryContainer.withOpacity(0.4)
            : cs.surfaceContainerLow;
        statusLabel = 'Upcoming';
        statusIcon = Icons.schedule_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
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
                Icon(statusIcon, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),

          // Teams
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                    child: _TeamColumn(
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
                    child: _TeamColumn(
                  label: 'Team B',
                  playerIds: match.teamB,
                  playerMap: playerMap,
                  color: const Color(0xFF1565C0),
                  isWinner: match.teamAWon == false,
                )),
              ],
            ),
          ),

          // Actions
          if (match.isScheduled && isCurrent)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Match'),
                ),
              ),
            )
          else if (match.isInProgress)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onComplete(true),
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
                      onPressed: () => onComplete(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                      ),
                      child: const Text('Team B Won'),
                    ),
                  ),
                ],
              ),
            )
          else if (match.isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Completed',
                      style: TextStyle(
                          fontSize: 12, color: Colors.green.shade700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String label;
  final List<String> playerIds;
  final Map<String, PlayerModel> playerMap;
  final Color color;
  final bool isWinner;

  const _TeamColumn({
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
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            if (isWinner) ...[
              const SizedBox(width: 4),
              const Icon(Icons.emoji_events_rounded,
                  size: 13, color: AppTheme.ratingAmber),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...playerIds.map((id) {
          final p = playerMap[id];
          final name = p?.name ?? id.substring(0, 6);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  name.split(' ').first,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
