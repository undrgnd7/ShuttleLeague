import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../player/data/player_model.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../providers/auth_provider.dart';

class UserManagementPage extends ConsumerWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          usersAsync.when(
            data: (users) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${users.length} users',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return _empty(context);
          }
          // Sort: admins first, then alphabetically
          final sorted = List<UserRecord>.from(users)
            ..sort((a, b) {
              if (a.role == b.role) return a.name.compareTo(b.name);
              return a.role == 'admin' ? -1 : 1;
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _UserCard(
              user: sorted[i],
              isCurrentUser: sorted[i].uid == currentUid,
              onRoleChange: (newRole) =>
                  _confirmRoleChange(context, ref, sorted[i], newRole),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmRoleChange(
    BuildContext context,
    WidgetRef ref,
    UserRecord user,
    String newRole,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final isElevating = newRole == 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isElevating ? 'Grant Admin Access?' : 'Revoke Admin Access?'),
        content: Text(
          isElevating
              ? '${user.name.isNotEmpty ? user.name : user.email} will be able to manage players, leagues, and other users.'
              : '${user.name.isNotEmpty ? user.name : user.email} will be downgraded to a regular player account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isElevating
                ? null
                : FilledButton.styleFrom(backgroundColor: cs.error),
            child: Text(isElevating ? 'Grant Admin' : 'Revoke Admin'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.updateUserRole(user.uid, newRole);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isElevating
                  ? '${user.name} is now an admin'
                  : '${user.name} is now a player',
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text('No users found',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── User card ────────────────────────────────────────────────────────────────

class _UserCard extends ConsumerWidget {
  final UserRecord user;
  final bool isCurrentUser;
  final void Function(String newRole) onRoleChange;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onRoleChange,
  });

  Future<void> _pickPlayer(BuildContext context, WidgetRef ref) async {
    final players = ref.read(playerListProvider).valueOrNull ?? [];
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No players exist yet')),
      );
      return;
    }
    final selected = await showModalBottomSheet<PlayerModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlayerLinkPickerSheet(players: players),
    );
    if (selected != null) {
      await AuthService.bindPlayer(user.uid, selected.id);
    }
  }

  Future<void> _unlinkPlayer(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Player'),
        content: Text(
            'Remove the link between ${user.name.isNotEmpty ? user.name : user.email} and their player profile?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService.unbindPlayer(user.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final playersAsync = ref.watch(playerListProvider);
    PlayerModel? linkedPlayer;
    if (user.playerId != null) {
      for (final p in playersAsync.valueOrNull ?? const <PlayerModel>[]) {
        if (p.id == user.playerId) {
          linkedPlayer = p;
          break;
        }
      }
    }
    final isAdmin = user.role == 'admin';
    final initials = _initials(user.name.isNotEmpty ? user.name : user.email);
    final avatarColor = AppTheme.avatarColor(
        user.name.isNotEmpty ? user.name : user.email);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + email + role badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name.isNotEmpty ? user.name : '(no name)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('You',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _RoleBadge(role: user.role),
                ],
              ),
            ),

            // Role action button — hidden for current user
            if (!isCurrentUser) ...[
              const SizedBox(width: 8),
              _RoleActionButton(
                isCurrentlyAdmin: isAdmin,
                onTap: () => onRoleChange(isAdmin ? 'player' : 'admin'),
              ),
            ],
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.sports_tennis_rounded, size: 15, color: cs.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    linkedPlayer != null
                        ? 'Linked to ${linkedPlayer.name}'
                        : 'No player linked',
                    style: TextStyle(
                        fontSize: 12,
                        color: linkedPlayer != null
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                        fontWeight: linkedPlayer != null
                            ? FontWeight.w600
                            : FontWeight.w400),
                  ),
                ),
                TextButton(
                  onPressed: () => _pickPlayer(context, ref),
                  child: Text(linkedPlayer != null ? 'Change' : 'Link Player'),
                ),
                if (linkedPlayer != null)
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    tooltip: 'Unlink',
                    color: cs.error,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _unlinkPlayer(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String s) {
    final parts = s.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return s.isNotEmpty ? s[0].toUpperCase() : '?';
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? cs.primaryContainer : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.admin_panel_settings_rounded
                : Icons.person_rounded,
            size: 11,
            color: isAdmin ? cs.onPrimaryContainer : cs.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isAdmin ? 'Admin' : 'Player',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  isAdmin ? cs.onPrimaryContainer : cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleActionButton extends StatelessWidget {
  final bool isCurrentlyAdmin;
  final VoidCallback onTap;

  const _RoleActionButton({
    required this.isCurrentlyAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: isCurrentlyAdmin ? 'Revoke admin access' : 'Grant admin access',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrentlyAdmin
                ? cs.errorContainer
                : cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrentlyAdmin
                    ? Icons.remove_moderator_rounded
                    : Icons.shield_rounded,
                size: 14,
                color: isCurrentlyAdmin ? cs.error : cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                isCurrentlyAdmin ? 'Revoke' : 'Elevate',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCurrentlyAdmin ? cs.error : cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerLinkPickerSheet extends StatelessWidget {
  final List<PlayerModel> players;
  const _PlayerLinkPickerSheet({required this.players});

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
                Text('Link Player',
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
                  subtitle: Text('Rating ${p.rating}',
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
