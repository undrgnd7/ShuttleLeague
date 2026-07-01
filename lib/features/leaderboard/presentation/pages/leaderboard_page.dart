import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardPage extends ConsumerWidget {
  final String leagueId;
  const LeaderboardPage({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider(leagueId));

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: leaderboard.when(
        data: (players) {
          if (players.isEmpty) {
            return _empty(context);
          }

          final maxRating =
              players.map((p) => p.rating).reduce((a, b) => a > b ? a : b);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: players.length,
            itemBuilder: (ctx, i) {
              final p = players[i];
              final rank = i + 1;
              final avatarColor = AppTheme.avatarColor(p.name);
              final initials = _initials(p.name);
              final ratingFraction =
                  maxRating > 0 ? p.rating / maxRating : 0.0;
              final total = p.wins + p.losses;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Rank
                        SizedBox(
                          width: 36,
                          child: rank <= 3
                              ? _MedalIcon(rank: rank)
                              : Text(
                                  '$rank',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                        const SizedBox(width: 12),

                        // Name + rating bar
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${p.wins}W · ${p.losses}L',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratingFraction,
                                  minHeight: 5,
                                  backgroundColor: AppTheme.ratingAmber
                                      .withOpacity(0.15),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.ratingAmber),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Points
                        Column(
                          children: [
                            Text('pts',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.ratingAmber,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '${p.rating}',
                              style: const TextStyle(
                                color: AppTheme.ratingAmber,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text('No rankings yet',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _MedalIcon extends StatelessWidget {
  final int rank;
  const _MedalIcon({required this.rank});

  @override
  Widget build(BuildContext context) {
    const colors = {
      1: Color(0xFFFFD700),
      2: Color(0xFFB0B7C3),
      3: Color(0xFFCD7F32),
    };
    const icons = {
      1: '🥇',
      2: '🥈',
      3: '🥉',
    };
    final color = colors[rank] ?? Colors.grey;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        icons[rank] ?? '$rank',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
