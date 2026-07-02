import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../providers/auth_provider.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _nameCtrl = TextEditingController();
  final _nameForm = GlobalKey<FormState>();
  bool _savingName = false;
  bool _sendingReset = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_nameForm.currentState!.validate()) return;
    setState(() => _savingName = true);
    try {
      await AuthService.updateProfile(name: _nameCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _sendReset() async {
    setState(() => _sendingReset = true);
    try {
      await AuthService.sendPasswordReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Password reset email sent to ${FirebaseAuth.instance.currentUser?.email ?? ''}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This will permanently delete your account and all associated data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await AuthService.deleteAccount();
      // Auth state change will redirect to login automatically.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
          _showError(
              'For security, please sign out and sign in again before deleting your account.');
        } else {
          _showError(e.message ?? e.code);
        }
      }
    } on Exception catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.valueOrNull ?? 'player';
    final name = user?.displayName ?? '';
    final email = user?.email ?? '';
    final initials = _initials(name);
    final avatarColor = AppTheme.avatarColor(name.isNotEmpty ? name : email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Avatar header ─────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.isNotEmpty ? name : 'No name set',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: role == 'admin'
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role == 'admin' ? 'Admin' : 'Player',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: role == 'admin'
                          ? cs.onPrimaryContainer
                          : cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Edit Profile ──────────────────────────────────────────────
          const _SectionHeader(label: 'Edit Profile', icon: Icons.person_outline_rounded),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _nameForm,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Name must be at least 2 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _savingName ? null : _saveProfile,
                        child: _savingName
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Security ──────────────────────────────────────────────────
          const _SectionHeader(label: 'Security', icon: Icons.lock_outline_rounded),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.email_outlined, color: cs.primary, size: 20),
              ),
              title: const Text('Reset Password',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Send a reset link to your email address',
                  style: TextStyle(fontSize: 12)),
              trailing: _sendingReset
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              onTap: _sendingReset ? null : _sendReset,
            ),
          ),

          const SizedBox(height: 20),

          // ── Account ───────────────────────────────────────────────────
          const _SectionHeader(label: 'Account', icon: Icons.manage_accounts_outlined),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded,
                    color: cs.onSecondaryContainer, size: 20),
              ),
              title: const Text('Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await AuthService.signOut();
                if (context.mounted) context.go('/splash');
              },
            ),
          ),

          const SizedBox(height: 28),

          // ── Danger zone ───────────────────────────────────────────────
          _SectionHeader(
            label: 'Danger Zone',
            icon: Icons.warning_amber_rounded,
            color: cs.error,
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_forever_rounded,
                    color: cs.error, size: 20),
              ),
              title: Text('Delete Account',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.error)),
              subtitle: const Text(
                  'Permanently remove your account and data',
                  style: TextStyle(fontSize: 12)),
              trailing: _deleting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.error),
                    )
                  : Icon(Icons.chevron_right_rounded, color: cs.error),
              onTap: _deleting ? null : _deleteAccount,
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
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _SectionHeader({
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
