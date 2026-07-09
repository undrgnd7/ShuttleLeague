import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/league_model.dart';
import '../../data/league_cloud_repository.dart';
import '../providers/league_provider.dart';

// Real-time stream so league list updates on all devices instantly
final leagueListProvider = StreamProvider<List<LeagueModel>>((ref) {
  final db = ref.read(firestoreProvider);
  return LeagueCloudRepository(db).watchLeagues();
});

class LeagueListPage extends ConsumerWidget {
  const LeagueListPage({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, LeagueModel league) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete League'),
        content: Text(
            'Delete "${league.name}"? All player memberships will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(leagueControllerProvider).deleteLeague(league.id);
      ref.invalidate(leagueListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leagueListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leagues')),
      body: leaguesAsync.when(
        data: (leagues) {
          if (leagues.isEmpty) return _empty(context, isAdmin);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leagueListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: leagues.length,
              itemBuilder: (ctx, i) {
                final league = leagues[i];
                final card = _LeagueCard(
                  league: league,
                  isAdmin: isAdmin,
                  onDelete: () => _confirmDelete(context, ref, league),
                );
                if (!isAdmin) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey(league.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _confirmDelete(context, ref, league);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_rounded,
                          color: Colors.red, size: 24),
                    ),
                    child: card,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/leagues/create');
                ref.invalidate(leagueListProvider);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New League'),
            )
          : null,
    );
  }

  Widget _empty(BuildContext context, bool isAdmin) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_outlined,
                size: 40, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('No leagues yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            isAdmin
                ? 'Create your first league to start playing'
                : 'No leagues have been created yet',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/leagues/create'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create League'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  final LeagueModel league;
  final VoidCallback onDelete;
  final bool isAdmin;
  const _LeagueCard({
    required this.league,
    required this.onDelete,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () => context.push('/leagues/${league.id}', extra: league),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.emoji_events_rounded,
                    color: cs.onPrimaryContainer, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.group_rounded,
                          label: 'Max ${league.maxPlayers}',
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: Icons.calendar_today_rounded,
                          label: _formatDate(league.createdAt),
                          color: cs.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: cs.error,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                ),
              Icon(Icons.chevron_right_rounded, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
