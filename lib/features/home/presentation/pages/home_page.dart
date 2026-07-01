import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../league/presentation/pages/league_list_page.dart';
import '../../../player/presentation/providers/player_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leagueListProvider);
    final playersAsync = ref.watch(playerListProvider);
    final cs = Theme.of(context).colorScheme;

    final playerCount = playersAsync.valueOrNull?.length ?? 0;
    final leagueCount = leaguesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await AuthService.signOut();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ShuttleLeague',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Badminton League Manager',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              background: _CourtBackground(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats row
                Row(
                  children: [
                    _StatCard(
                      label: 'Players',
                      value: '$playerCount',
                      icon: Icons.people_rounded,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Leagues',
                      value: '$leagueCount',
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Win = +3pts',
                      value: 'Points',
                      icon: Icons.bar_chart_rounded,
                      color: AppTheme.ratingAmber,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _ActionTile(
                      icon: Icons.person_add_rounded,
                      label: 'Add Player',
                      color: cs.primary,
                      onTap: () => context.push('/players/create'),
                    ),
                    _ActionTile(
                      icon: Icons.add_circle_rounded,
                      label: 'Create League',
                      color: const Color(0xFF1565C0),
                      onTap: () => context.push('/leagues/create'),
                    ),
                    _ActionTile(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      color: const Color(0xFF00695C),
                      onTap: () => context.go('/scan'),
                    ),
                    _ActionTile(
                      icon: Icons.leaderboard_rounded,
                      label: 'Leaderboard',
                      color: AppTheme.ratingAmber,
                      onTap: () {
                        final leagues = leaguesAsync.valueOrNull ?? [];
                        if (leagues.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('No leagues yet — create one first')),
                          );
                          return;
                        }
                        context.push(
                            '/leagues/${leagues.first.id}/leaderboard');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent leagues
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leagues',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/leagues'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                leaguesAsync.when(
                  data: (leagues) {
                    if (leagues.isEmpty) {
                      return _EmptyState(
                        icon: Icons.emoji_events_outlined,
                        message: 'No leagues yet',
                        actionLabel: 'Create League',
                        onAction: () => context.push('/leagues/create'),
                      );
                    }
                    return Column(
                      children: leagues
                          .take(3)
                          .map((l) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _LeagueRow(
                                  name: l.name,
                                  maxPlayers: l.maxPlayers,
                                  onTap: () =>
                                      context.push('/leagues/${l.id}'),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Court Background ────────────────────────────────────────────────────────

class _CourtBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CourtPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF004D38),
              Color(0xFF006A4E),
              Color(0xFF005F46),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;

    // Court is drawn in landscape orientation filling the header
    // Outer boundary (slightly inset)
    const pad = 20.0;
    final rect = Rect.fromLTRB(pad, pad, w - pad, h - pad);
    canvas.drawRect(rect, paint);

    // Net line (vertical center)
    canvas.drawLine(
      Offset(w / 2, pad),
      Offset(w / 2, h - pad),
      paint,
    );

    // Short service lines (1/4 from each end, horizontal)
    final ssl = h * 0.28;
    canvas.drawLine(Offset(pad, ssl), Offset(w - pad, ssl), paint);
    canvas.drawLine(
        Offset(pad, h - ssl), Offset(w - pad, h - ssl), paint);

    // Singles sidelines (inset ~12% from each side)
    final singleInset = w * 0.12;
    canvas.drawLine(
      Offset(pad + singleInset, pad),
      Offset(pad + singleInset, h - pad),
      paint,
    );
    canvas.drawLine(
      Offset(w - pad - singleInset, pad),
      Offset(w - pad - singleInset, h - pad),
      paint,
    );

    // Center service line (horizontal midline between ssl lines)
    canvas.drawLine(
      Offset(w / 2, ssl),
      Offset(w / 2, h - ssl),
      paint,
    );

    // Subtle shuttlecock silhouette near top-right corner
    _drawShuttlecock(canvas, Offset(w - 48, 36), 14, paint);
  }

  void _drawShuttlecock(Canvas canvas, Offset center, double r, Paint paint) {
    // Simplified: a small circle + radiating lines (feathers)
    canvas.drawCircle(center, r * 0.3, paint);
    final featherPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      canvas.drawLine(
        center + Offset(math.cos(angle) * r * 0.35, math.sin(angle) * r * 0.35),
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        featherPaint,
      );
    }
    // Skirt arc
    canvas.drawArc(
      Rect.fromCenter(center: center, width: r * 2, height: r * 2),
      0,
      2 * math.pi,
      false,
      featherPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueRow extends StatelessWidget {
  final String name;
  final int maxPlayers;
  final VoidCallback onTap;

  const _LeagueRow({
    required this.name,
    required this.maxPlayers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.emoji_events_rounded,
              color: cs.onPrimaryContainer, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Max $maxPlayers players',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

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
          Icon(icon, size: 36, color: cs.outline),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
