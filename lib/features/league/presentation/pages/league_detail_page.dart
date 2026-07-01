import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/league_provider.dart';

class LeagueDetailPage extends ConsumerWidget {
  final String leagueId;
  final String leagueName;

  const LeagueDetailPage({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(leagueDetailPlayersProvider(leagueId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(leagueName),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded),
            tooltip: 'Leaderboard',
            onPressed: () => context.push('/leagues/$leagueId/leaderboard'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Action chips row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.qr_code_rounded,
                    label: 'Start Session',
                    color: cs.primary,
                    onTap: () {
                      final sessionId = const Uuid().v4();
                      context.push(
                        '/leagues/$leagueId/session',
                        extra: sessionId,
                      );
                    },
                  ),
                  _ActionChip(
                    icon: Icons.sports_rounded,
                    label: 'Live Queue',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      final sessionId = const Uuid().v4();
                      context.push(
                        '/leagues/$leagueId/queue',
                        extra: sessionId,
                      );
                    },
                  ),
                  _ActionChip(
                    icon: Icons.leaderboard_rounded,
                    label: 'Leaderboard',
                    color: AppTheme.ratingAmber,
                    onTap: () =>
                        context.push('/leagues/$leagueId/leaderboard'),
                  ),
                ],
              ),
            ),
          ),

          // Players header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Players',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  playersAsync.when(
                    data: (p) => Text(
                      '${p.length} player${p.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // Players list
          playersAsync.when(
            data: (players) {
              if (players.isEmpty) {
                return SliverToBoxAdapter(child: _emptyPlayers(context));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlayerRow(player: players[i]),
                    ),
                    childCount: players.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final players =
              ref.read(playerListProvider).valueOrNull ?? [];
          if (players.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Add players first from the Players tab')),
            );
            return;
          }
          final selected = await showModalBottomSheet<PlayerModel>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _PlayerPickerSheet(players: players),
          );
          if (selected != null) {
            await ref.read(leagueRepositoryProvider).addPlayerToLeague(
              leagueId: leagueId,
              player: selected,
            );
            ref.invalidate(leagueDetailPlayersProvider(leagueId));
          }
        },
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _emptyPlayers(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: cs.outline),
          const SizedBox(height: 12),
          Text('No players in this league yet',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Tap + to add players',
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerModel player;
  const _PlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = AppTheme.avatarColor(player.name);
    final initials = _initials(player.name);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
        title: Text(player.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 3),
            Text('Skill ${player.skillLevel}',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.ratingAmberLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  size: 13, color: AppTheme.ratingAmber),
              const SizedBox(width: 3),
              Text('${player.rating}',
                  style: const TextStyle(
                    color: AppTheme.ratingAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )),
            ],
          ),
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

class _PlayerPickerSheet extends StatelessWidget {
  final List<PlayerModel> players;
  const _PlayerPickerSheet({required this.players});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Add Player',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: players.length,
              itemBuilder: (_, i) {
                final p = players[i];
                final avatarColor = AppTheme.avatarColor(p.name);
                final initials = p.name.isNotEmpty
                    ? p.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
                    : '?';
                return ListTile(
                  onTap: () => Navigator.pop(context, p),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Rating ${p.rating} · Skill ${p.skillLevel}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.add_circle_outline_rounded),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
