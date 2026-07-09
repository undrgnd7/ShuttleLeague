import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/file_saver.dart';
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
        title: 'League Leaderboard',
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
          title: 'Overall Leaderboard',
          emptyMessage: 'No matches recorded yet.',
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }
}

// ─── Shared list ──────────────────────────────────────────────────────────────

class _LeaderboardList extends StatefulWidget {
  final List<PlayerModel> players;
  final String subtitle;
  final String title;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;

  const _LeaderboardList({
    required this.players,
    required this.subtitle,
    required this.title,
    required this.emptyMessage,
    this.onRefresh,
  });

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList> {
  bool _exporting = false;

  Future<void> _export() async {
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
              child: _ShareableLeaderboard(
                  players: widget.players, title: widget.title),
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
        'shuttleleague_leaderboard.png',
        shareText: widget.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export leaderboard: $e')),
        );
      }
    } finally {
      entry.remove();
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty) {
      return _EmptyView(message: widget.emptyMessage);
    }

    final maxRating =
        widget.players.map((p) => p.rating).reduce((a, b) => a > b ? a : b);

    final list = ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: widget.players.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                ),
              ],
            ),
          );
        }
        final p = widget.players[i - 1];
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

    if (widget.onRefresh != null) {
      return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    }
    return list;
  }
}

// ─── Shareable (offscreen, non-scrolling) render for image export ─────────────

class _ShareableLeaderboard extends StatelessWidget {
  final List<PlayerModel> players;
  final String title;
  const _ShareableLeaderboard({required this.players, required this.title});

  @override
  Widget build(BuildContext context) {
    final maxRating = players.isEmpty
        ? 0
        : players.map((p) => p.rating).reduce((a, b) => a > b ? a : b);

    // Solid, fully-opaque rectangle (no rounded corners at this outer edge)
    // painted with the app's own badminton-court gradient — guarantees
    // there's no transparent pixel anywhere for a viewer to render as black.
    return Container(
      width: 400,
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
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.ratingAmber, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
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
          for (int i = 0; i < players.length; i++) ...[
            _PlayerCard(player: players[i], rank: i + 1, maxRating: maxRating),
            if (i != players.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
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
