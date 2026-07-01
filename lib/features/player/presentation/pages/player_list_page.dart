import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../app/theme.dart';
import '../../data/player_model.dart';
import '../providers/player_provider.dart';

class PlayerListPage extends ConsumerStatefulWidget {
  const PlayerListPage({super.key});

  @override
  ConsumerState<PlayerListPage> createState() => _PlayerListPageState();
}

class _PlayerListPageState extends ConsumerState<PlayerListPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(PlayerModel player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Player'),
        content: Text('Remove "${player.name}" from all leagues and records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(playerControllerProvider).deletePlayer(player.id);
      ref.invalidate(playerListProvider);
    }
  }

  @override
  Widget build(BuildContext context, ) {
    final playersAsync = ref.watch(playerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search players...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: playersAsync.when(
        data: (all) {
          final players = _query.isEmpty
              ? all
              : all
                  .where((p) => p.name.toLowerCase().contains(_query))
                  .toList();

          if (all.isEmpty) return _empty(context);

          if (players.isEmpty) {
            return Center(
              child: Text('No players match "$_query"',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(playerListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: players.length,
              itemBuilder: (ctx, i) {
                final player = players[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(player.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _confirmDelete(player);
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
                    child: _PlayerCard(
                      player: player,
                      onTap: () => context.push('/players/${player.id}'),
                      onDelete: () => _confirmDelete(player),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/players/create');
          ref.invalidate(playerListProvider);
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Player'),
      ),
    );
  }

  Widget _empty(BuildContext context) {
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
            child: Icon(Icons.people_outline_rounded,
                size: 40, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('No players yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Add players to get started',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/players/create'),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Add Player'),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PlayerCard({required this.player, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = AppTheme.avatarColor(player.name);
    final initials = _initials(player.name);
    final totalGames = player.wins + player.losses;
    final winRate = totalGames > 0
        ? (player.wins / totalGames * 100).toStringAsFixed(0)
        : '-';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.sports_tennis,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          'Skill ${player.skillLevel}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${player.wins}W · ${player.losses}L',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        if (totalGames > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$winRate%',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Rating badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.ratingAmberLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppTheme.ratingAmber),
                    const SizedBox(width: 3),
                    Text(
                      '${player.rating}',
                      style: const TextStyle(
                        color: AppTheme.ratingAmber,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: cs.error,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
