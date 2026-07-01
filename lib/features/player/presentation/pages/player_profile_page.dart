import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../data/player_model.dart';
import '../../data/player_cloud_repository.dart';
import '../../../../core/firebase/firebase_provider.dart';

final _playerProfileProvider =
    FutureProvider.family<PlayerModel?, String>((ref, id) {
  final db = ref.read(firestoreProvider);
  return PlayerCloudRepository(db).getPlayer(id);
});

class PlayerProfilePage extends ConsumerWidget {
  final String playerId;
  const PlayerProfilePage({super.key, required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(_playerProfileProvider(playerId));

    return playerAsync.when(
      data: (player) {
        if (player == null) {
          return const Scaffold(
            body: Center(child: Text('Player not found')),
          );
        }
        return _ProfileView(player: player);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final PlayerModel player;
  const _ProfileView({required this.player});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = AppTheme.avatarColor(player.name);
    final initials = _initials(player.name);
    final total = player.wins + player.losses;
    final winRate = total > 0 ? player.wins / total : 0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      avatarColor,
                      avatarColor.withOpacity(0.6),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 30)),
                      ),
                      const SizedBox(height: 12),
                      Text(player.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22)),
                      const SizedBox(height: 4),
                      _SkillBadge(level: player.skillLevel),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Rating card
                _RatingHero(player: player),
                const SizedBox(height: 16),

                // Stats grid
                Row(
                  children: [
                    _StatBox(
                        label: 'Wins',
                        value: '${player.wins}',
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFF2E7D32)),
                    const SizedBox(width: 10),
                    _StatBox(
                        label: 'Losses',
                        value: '${player.losses}',
                        icon: Icons.close_rounded,
                        color: cs.error),
                    const SizedBox(width: 10),
                    _StatBox(
                        label: 'Win Rate',
                        value: total > 0
                            ? '${(winRate * 100).toStringAsFixed(0)}%'
                            : '-',
                        icon: Icons.bar_chart_rounded,
                        color: cs.primary),
                  ],
                ),
                const SizedBox(height: 16),

                // Win rate bar
                if (total > 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Win Rate',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(
                                '${player.wins} / $total matches',
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: winRate,
                              minHeight: 8,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 0.5
                                    ? const Color(0xFF2E7D32)
                                    : cs.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // About section
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Player Info',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.sports_tennis_rounded,
                          label: 'Skill Level',
                          value: _skillLabel(player.skillLevel),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Joined',
                          value: _formatDate(player.createdAt),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.tag_rounded,
                          label: 'Player ID',
                          value: player.id.substring(0, 8).toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _skillLabel(int level) {
    const labels = {
      1: 'Beginner',
      2: 'Casual',
      3: 'Intermediate',
      4: 'Advanced',
      5: 'Pro'
    };
    return labels[level] ?? 'Level $level';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _RatingHero extends StatelessWidget {
  final PlayerModel player;
  const _RatingHero({required this.player});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Points',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppTheme.ratingAmber, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      '${player.rating}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ratingAmber,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _ratingLabel(player.rating),
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.ratingAmber.withOpacity(0.7),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.ratingAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.ratingAmber, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    if (r >= 30) return 'Diamond';
    if (r >= 20) return 'Gold';
    if (r >= 10) return 'Silver';
    if (r >= 3) return 'Bronze';
    return 'Newcomer';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.outline),
        const SizedBox(width: 8),
        Text('$label: ',
            style:
                TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SkillBadge extends StatelessWidget {
  final int level;
  const _SkillBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    const labels = {
      1: 'Beginner',
      2: 'Casual',
      3: 'Intermediate',
      4: 'Advanced',
      5: 'Pro'
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        labels[level] ?? 'Level $level',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
