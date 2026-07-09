import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/file_saver.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../league/presentation/providers/league_provider.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../session/presentation/widgets/player_pickers.dart';
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
  bool _exporting = false;

  Future<void> _exportSchedule(
      List<ScheduledMatch> matches, Map<String, PlayerModel> playerMap) async {
    setState(() => _exporting = true);
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -10000,
        top: 0,
        // Force a fixed light theme for the capture, so the exported image
        // always looks the same regardless of the device's dark/light
        // setting, and MaterialType.transparency so this wrapper never
        // paints a background of its own behind the opaque content below.
        child: Theme(
          data: ThemeData.light(useMaterial3: true),
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(
              key: boundaryKey,
              child:
                  _ShareableSchedule(matches: matches, playerMap: playerMap),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await saveOrShareBytes(
        bytes,
        'shuttleleague_schedule.png',
        shareText: 'Full Schedule',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export schedule: $e')),
        );
      }
    } finally {
      entry.remove();
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _initIfNeeded(List<PlayerModel> players) {
    _selectedIds ??= {for (final p in players) p.id};
  }

  void _generate(List<PlayerModel> allPlayers) {
    final selected =
        allPlayers.where((p) => _selectedIds!.contains(p.id)).toList();
    final ratings = {for (final p in selected) p.id: p.rating};
    final genders = {for (final p in selected) p.id: p.gender.name};
    ref.read(scheduleProvider(widget.sessionId).notifier).generate(
          leagueId: widget.leagueId,
          playerIds: selected.map((p) => p.id).toList(),
          courts: _courts,
          ratings: ratings,
          genders: genders,
        );
  }

  void _reselect() {
    ref.read(scheduleProvider(widget.sessionId).notifier).reset();
    setState(() => _selectedIds = null);
  }

  Future<void> _addMatch(List<PlayerModel> players) async {
    final chosen = await pickMultiplePlayers(context, players, count: 4);
    if (chosen == null || !mounted) return;

    final round = await _askNumber('Round number', initial: 1);
    if (round == null || !mounted) return;
    final court = await _askNumber('Court number', initial: 1);
    if (court == null) return;

    ref.read(scheduleProvider(widget.sessionId).notifier).addMatch(
          round: round,
          courtNumber: court,
          teamA: [chosen[0].id, chosen[1].id],
          teamB: [chosen[2].id, chosen[3].id],
        );
  }

  Future<int?> _askNumber(String label, {required int initial}) async {
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
        final femaleCount = selected
            .where((p) => p.gender == PlayerGender.female)
            .length;
        final hasGenderError = femaleCount == 1;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Full Schedule'),
            actions: [
              if (!scheduleState.isEmpty) ...[
                IconButton(
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded),
                  tooltip: 'Share / download as image',
                  onPressed: _exporting
                      ? null
                      : () => _exportSchedule(scheduleState.matches, playerMap),
                ),
                IconButton(
                  icon: const Icon(Icons.people_alt_rounded),
                  tooltip: 'Change players / courts',
                  onPressed: _reselect,
                ),
              ],
            ],
          ),
          body: scheduleState.isEmpty
              ? _SetupView(
                  players: players,
                  selectedIds: _selectedIds!,
                  courts: _courts,
                  maxCourts: maxCourts,
                  hasGenderError: hasGenderError,
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
                  onGenerate: selected.length >= 4 && !hasGenderError
                      ? () => _generate(players)
                      : null,
                )
              : _ScheduleList(
                  state: scheduleState,
                  playerMap: playerMap,
                  sessionId: widget.sessionId,
                  isAdmin: ref.watch(isAdminProvider),
                  onStart: (matchNumber) => ref
                      .read(scheduleProvider(widget.sessionId).notifier)
                      .startMatch(matchNumber),
                  onComplete: (matchNumber, teamAWon, scoreA, scoreB) async {
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
                        .completeMatch(matchNumber,
                            teamAWon: teamAWon,
                            scoreA: scoreA,
                            scoreB: scoreB);
                    ref.invalidate(playerListProvider);
                  },
                  onEditResult: (matchNumber, newTeamAWon, scoreA, scoreB) async {
                    final match = scheduleState.matches
                        .firstWhere((m) => m.matchNumber == matchNumber);
                    // Only correct points if the winner actually changed —
                    // a pure score edit shouldn't flip anyone's result.
                    if (match.teamAWon != newTeamAWon) {
                      final oldWinners =
                          match.teamAWon == true ? match.teamA : match.teamB;
                      final oldLosers =
                          match.teamAWon == true ? match.teamB : match.teamA;
                      await ref
                          .read(playerRepositoryProvider)
                          .editMatchResult(
                            leagueId: widget.leagueId,
                            oldWinnerIds: oldWinners,
                            oldLoserIds: oldLosers,
                          );
                      ref.invalidate(playerListProvider);
                    }
                    ref
                        .read(scheduleProvider(widget.sessionId).notifier)
                        .editMatch(matchNumber,
                            teamAWon: newTeamAWon,
                            scoreA: scoreA,
                            scoreB: scoreB);
                  },
                  onRemoveMatch: (matchNumber) async {
                    final match = scheduleState.matches
                        .firstWhere((m) => m.matchNumber == matchNumber);
                    if (match.isCompleted && match.teamAWon != null) {
                      final winners =
                          match.teamAWon == true ? match.teamA : match.teamB;
                      final losers =
                          match.teamAWon == true ? match.teamB : match.teamA;
                      await ref.read(playerRepositoryProvider).revertMatchResult(
                            leagueId: widget.leagueId,
                            winnerIds: winners,
                            loserIds: losers,
                          );
                      ref.invalidate(playerListProvider);
                    }
                    ref
                        .read(scheduleProvider(widget.sessionId).notifier)
                        .removeMatch(matchNumber);
                  },
                  onSwapPlayer: (matchNumber, oldId, newId) => ref
                      .read(scheduleProvider(widget.sessionId).notifier)
                      .swapPlayer(matchNumber,
                          oldPlayerId: oldId, newPlayerId: newId),
                ),
          floatingActionButton: !scheduleState.isEmpty && ref.watch(isAdminProvider)
              ? FloatingActionButton.extended(
                  onPressed: () => _addMatch(players),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Match'),
                )
              : null,
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
  final bool hasGenderError;
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
    required this.hasGenderError,
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
          color: cs.primaryContainer.withValues(alpha: 0.5),
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
                          color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
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
              const _LegendChip(label: 'Win  +3 pts', color: Color(0xFF2E7D32)),
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
                if (hasGenderError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Sessions must have 0 or at least 2 female players.',
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
            ? cs.primaryContainer.withValues(alpha: 0.35)
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
                        : avatarColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
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
                      Row(
                        children: [
                          Icon(
                            player.gender == PlayerGender.female
                                ? Icons.female_rounded
                                : Icons.male_rounded,
                            size: 14,
                            color: player.gender == PlayerGender.female
                                ? Colors.pinkAccent
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                              '${player.rating} pts  ·  ${player.wins}W ${player.losses}L',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
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
  final bool isAdmin;
  final void Function(int matchNumber) onStart;
  final void Function(int matchNumber, bool teamAWon, int scoreA, int scoreB) onComplete;
  final void Function(int matchNumber, bool newTeamAWon, int scoreA, int scoreB) onEditResult;
  final void Function(int matchNumber) onRemoveMatch;
  final void Function(int matchNumber, String oldPlayerId, String newPlayerId)
      onSwapPlayer;

  const _ScheduleList({
    required this.state,
    required this.playerMap,
    required this.sessionId,
    required this.isAdmin,
    required this.onStart,
    required this.onComplete,
    required this.onEditResult,
    required this.onRemoveMatch,
    required this.onSwapPlayer,
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
                          const Icon(Icons.check_circle_rounded,
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
                        isAdmin: isAdmin,
                        onStart: () => onStart(match.matchNumber),
                        onComplete: (won, sA, sB) =>
                            onComplete(match.matchNumber, won, sA, sB),
                        onEdit: (won, sA, sB) => onEditResult(
                            match.matchNumber, won, sA, sB),
                        onRemove: () => onRemoveMatch(match.matchNumber),
                        onSwap: (oldId, newId) =>
                            onSwapPlayer(match.matchNumber, oldId, newId),
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

class _MatchCard extends StatefulWidget {
  final ScheduledMatch match;
  final Map<String, PlayerModel> playerMap;
  final bool isCurrent;
  final bool isAdmin;
  final VoidCallback onStart;
  final void Function(bool teamAWon, int scoreA, int scoreB) onComplete;
  final void Function(bool teamAWon, int scoreA, int scoreB) onEdit;
  final VoidCallback onRemove;
  final void Function(String oldPlayerId, String newPlayerId) onSwap;

  const _MatchCard({
    required this.match,
    required this.playerMap,
    required this.isCurrent,
    required this.isAdmin,
    required this.onStart,
    required this.onComplete,
    required this.onEdit,
    required this.onRemove,
    required this.onSwap,
  });

  List<PlayerModel> get allPlayers => playerMap.values.toList();

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  Future<void> _recordResult(bool teamAWon) async {
    final scoreACtrl = TextEditingController();
    final scoreBCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          teamAWon ? 'Team A Won' : 'Team B Won',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the final score (optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: scoreACtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Team A',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('–',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: scoreBCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Team B',
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final a = int.tryParse(scoreACtrl.text) ?? 0;
              final b = int.tryParse(scoreBCtrl.text) ?? 0;
              Navigator.pop(ctx, (a, b));
            },
            child: const Text('Save Result'),
          ),
        ],
      ),
    );

    scoreACtrl.dispose();
    scoreBCtrl.dispose();

    if (result != null && mounted) {
      widget.onComplete(teamAWon, result.$1, result.$2);
    }
  }

  Future<void> _editResult() async {
    final match = widget.match;
    bool teamAWon = match.teamAWon ?? true;
    final scoreACtrl =
        TextEditingController(text: match.scoreA?.toString() ?? '');
    final scoreBCtrl =
        TextEditingController(text: match.scoreB?.toString() ?? '');

    final result = await showDialog<(bool, int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Winner',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Team A'),
                      selected: teamAWon,
                      onSelected: (_) =>
                          setDialogState(() => teamAWon = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Team B'),
                      selected: !teamAWon,
                      onSelected: (_) =>
                          setDialogState(() => teamAWon = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Score',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: scoreACtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          labelText: 'Team A', hintText: '0'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('–',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: scoreBCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          labelText: 'Team B', hintText: '0'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(scoreACtrl.text) ?? 0;
                final b = int.tryParse(scoreBCtrl.text) ?? 0;
                Navigator.pop(ctx, (teamAWon, a, b));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    scoreACtrl.dispose();
    scoreBCtrl.dispose();

    if (result != null && mounted) {
      widget.onEdit(result.$1, result.$2, result.$3);
    }
  }

  Future<void> _swapPlayer(String oldPlayerId) async {
    final replacement = await pickSinglePlayer(
      context,
      widget.allPlayers,
      excludeIds: {...widget.match.teamA, ...widget.match.teamB},
    );
    if (replacement == null || !mounted) return;
    widget.onSwap(oldPlayerId, replacement.id);
  }

  Future<void> _confirmRemove() async {
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
    if (ok == true) widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final playerMap = widget.playerMap;
    final isCurrent = widget.isCurrent;
    final isAdmin = widget.isAdmin;
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
            isCurrent ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant;
        headerColor = isCurrent
            ? cs.primaryContainer.withValues(alpha: 0.4)
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
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _confirmRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: cs.error),
                    ),
                  ),
                ],
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
                  canSwap: isAdmin && !match.isCompleted,
                  onSwap: (id) => _swapPlayer(id),
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
                  canSwap: isAdmin && !match.isCompleted,
                  onSwap: (id) => _swapPlayer(id),
                )),
              ],
            ),
          ),

          // Actions
          if (match.isScheduled && isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Match'),
                ),
              ),
            )
          else if (match.isInProgress && !isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('In progress',
                      style: TextStyle(
                          fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (match.isInProgress && isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _recordResult(true),
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
                      onPressed: () => _recordResult(false),
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
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  if (match.scoreA != null && match.scoreB != null) ...[
                    Text(
                      '${match.scoreA} – ${match.scoreB}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700),
                    ),
                  ] else ...[
                    Text('Completed',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade700)),
                  ],
                  const Spacer(),
                  if (isAdmin)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _editResult,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_outlined,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ),
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
  final bool canSwap;
  final void Function(String playerId)? onSwap;

  const _TeamColumn({
    required this.label,
    required this.playerIds,
    required this.playerMap,
    required this.color,
    required this.isWinner,
    this.canSwap = false,
    this.onSwap,
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
          final isFemale = p?.gender == PlayerGender.female;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
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
                const SizedBox(width: 3),
                Text(
                  isFemale ? '♀' : '♂',
                  style: TextStyle(
                      fontSize: 10,
                      color: isFemale
                          ? Colors.pink.shade400
                          : Colors.blue.shade400),
                ),
                if (canSwap)
                  GestureDetector(
                    onTap: () => onSwap?.call(id),
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
    );
  }
}

// ─── Shareable (offscreen, non-scrolling) render for image export ─────────────

class _ShareableSchedule extends StatelessWidget {
  final List<ScheduledMatch> matches;
  final Map<String, PlayerModel> playerMap;
  const _ShareableSchedule({required this.matches, required this.playerMap});

  @override
  Widget build(BuildContext context) {
    final roundNumbers = matches.map((m) => m.round).toSet().toList()..sort();

    // Solid, fully-opaque rectangle (no rounded corners at this outer edge)
    // painted with the app's own badminton-court gradient — guarantees
    // there's no transparent pixel anywhere for a viewer to render as black.
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004D38), Color(0xFF006A4E), Color(0xFF005F46)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: AppTheme.ratingAmber, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Full Schedule',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('ShuttleLeague',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),
          for (final round in roundNumbers) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Round $round',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            ...matches.where((m) => m.round == round).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ShareableMatchRow(match: m, playerMap: playerMap),
                )),
          ],
        ],
      ),
    );
  }
}

class _ShareableMatchRow extends StatelessWidget {
  final ScheduledMatch match;
  final Map<String, PlayerModel> playerMap;
  const _ShareableMatchRow({required this.match, required this.playerMap});

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    switch (match.status) {
      case MatchStatus.inProgress:
        borderColor = const Color(0xFF1565C0);
        break;
      case MatchStatus.completed:
        borderColor = Colors.green.shade300;
        break;
      default:
        borderColor = Colors.grey.shade300;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Court ${match.courtNumber}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _TeamColumn(
                  label: 'Team A',
                  playerIds: match.teamA,
                  playerMap: playerMap,
                  color: const Color(0xFF00897B),
                  isWinner: match.teamAWon == true,
                ),
              ),
              const Text('vs',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Expanded(
                child: _TeamColumn(
                  label: 'Team B',
                  playerIds: match.teamB,
                  playerMap: playerMap,
                  color: const Color(0xFF1565C0),
                  isWinner: match.teamAWon == false,
                ),
              ),
            ],
          ),
          if (match.isCompleted &&
              match.scoreA != null &&
              match.scoreB != null) ...[
            const SizedBox(height: 4),
            Text('${match.scoreA} – ${match.scoreB}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700)),
          ],
        ],
      ),
    );
  }
}
