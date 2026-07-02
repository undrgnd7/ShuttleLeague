import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../providers/leaderboard_provider.dart';
import '../../../player/data/player_model.dart';

class LeaderboardPage extends ConsumerWidget {
  /// Pass a leagueId to show both tabs (League + Overall).
  /// Pass an empty string to show only the Overall tab.
  final String leagueId;
  const LeaderboardPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final hasLeague = leagueId.isNotEmpty;

    if (!hasLeague) {
      // Overall-only view — no tab bar needed
      return Scaffold(
        appBar: AppBar(title: const Text('Overall Leaderboard')),
        body: const _OverallTab(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.emoji_events_rounded), text: 'This League'),
              Tab(icon: Icon(Icons.public_rounded), text: 'Overall'),
            ],
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
          ),
        ),
        body: TabBarView(
          children: [
            _LeagueTab(leagueId: leagueId),
            const _OverallTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Per-league tab ───────────────────────────────────────────────────────────

class _LeagueTab extends ConsumerWidget {
  final String leagueId;
  const _LeagueTab({required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(leagueId));
    return async.when(
      data: (players) => _LeaderboardList(
        players: players,
        subtitle: 'Points this league',
        emptyMessage: 'No matches played in this league yet.',
        onRefresh: () => ref.refresh(leaderboardProvider(leagueId).future),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }
}

// ─── Overall tab ──────────────────────────────────────────────────────────────

class _OverallTab extends ConsumerWidget {
  const _OverallTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(overallLeaderboardProvider);
    return async.when(
      data: (players) {
        final withGames = players.where((p) => p.wins + p.losses > 0).toList();
        return _LeaderboardList(
          players: withGames,
          subtitle: 'Lifetime points across all leagues',
          emptyMessage: 'No matches recorded yet.',
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }
}

// ─── Shared list ──────────────────────────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  final List<PlayerModel> players;
  final String subtitle;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;

  const _LeaderboardList({
    required this.players,
    required this.subtitle,
    required this.emptyMessage,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return _EmptyView(message: emptyMessage);
    }

    final maxRating =
        players.map((p) => p.rating).reduce((a, b) => a > b ? a : b);

    final list = ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: players.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final p = players[i - 1];
        final rank = i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PlayerCard(
            player: p,
            rank: rank,
            maxRating: maxRating,
          ),
        );
      },
    );

    if (onRefresh != null) {
      return RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    return list;
  }
}

// ─── Player card ──────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final PlayerModel player;
  final int rank;
  final int maxRating;

  const _PlayerCard({
    required this.player,
    required this.rank,
    required this.maxRating,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = AppTheme.avatarColor(player.name);
    final initials = _initials(player.name);
    final ratingFraction = maxRating > 0 ? player.rating / maxRating : 0.0;
    final total = player.wins + player.losses;
    final winRate = total > 0 ? (player.wins / total * 100).round() : 0;

    final isTopThree = rank <= 3;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isTopThree
            ? _podiumColor(rank).withValues(alpha: 0.07)
            : cs.surfaceContainerLow,
        border: isTopThree
            ? Border.all(color: _podiumColor(rank).withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 36,
              child: isTopThree
                  ? _MedalIcon(rank: rank)
                  : Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 10),

            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + bar + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${player.wins}W · ${player.losses}L',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratingFraction,
                      minHeight: 5,
                      backgroundColor: AppTheme.ratingAmber.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.ratingAmber),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        total > 0 ? '$winRate% win rate' : 'No matches yet',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (total > 0)
                        Text(
                          '· $total played',
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Points column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.rating}',
                  style: const TextStyle(
                    color: AppTheme.ratingAmber,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'pts',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.ratingAmber.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _podiumColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFB0B7C3),
      _ => const Color(0xFFCD7F32),
    };
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _MedalIcon extends StatelessWidget {
  final int rank;
  const _MedalIcon({required this.rank});

  @override
  Widget build(BuildContext context) {
    const emojis = {1: '🥇', 2: '🥈', 3: '🥉'};
    const colors = {
      1: Color(0xFFFFD700),
      2: Color(0xFFB0B7C3),
      3: Color(0xFFCD7F32),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: (colors[rank] ?? Colors.grey).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        emojis[rank] ?? '$rank',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Error: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
