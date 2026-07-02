import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../schedule/presentation/providers/schedule_provider.dart';
import '../../data/session_repository.dart';

class SessionDashboard extends ConsumerStatefulWidget {
  final String sessionId;
  final String leagueId;

  const SessionDashboard({
    super.key,
    required this.sessionId,
    required this.leagueId,
  });

  @override
  ConsumerState<SessionDashboard> createState() => _SessionDashboardState();
}

class _SessionDashboardState extends ConsumerState<SessionDashboard> {
  bool _ending = false;

  Future<void> _endSession() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
            'This will close the active session and remove it from the league. '
            'Match results already recorded are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _ending = true);
    try {
      await SessionRepository()
          .endSession(widget.leagueId, widget.sessionId);
      // Clear in-memory active session
      ref.read(activeSessionProvider(widget.leagueId).notifier).state = null;
      if (mounted) context.pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sessionId = widget.sessionId;
    final leagueId = widget.leagueId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session'),
            Text(
              'ID: ${sessionId.substring(0, 8)}...',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session ID card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.circle,
                          size: 10, color: Colors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Session Active',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            sessionId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Session Tools',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            _ToolButton(
              icon: Icons.calendar_month_rounded,
              label: 'Full Schedule',
              subtitle: 'View and manage the full day match schedule',
              color: const Color(0xFF00695C),
              onTap: () => context.push(
                '/leagues/$leagueId/schedule',
                extra: sessionId,
              ),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.qr_code_2_rounded,
              label: 'Session QR Code',
              subtitle: 'Show QR for players to scan and join session',
              color: cs.primary,
              onTap: () => context.push('/leagues/$leagueId/qr'),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan Player QR',
              subtitle: 'Check in players by scanning their QR code',
              color: cs.tertiary,
              onTap: () => context.push('/scan/camera'),
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              subtitle: 'View player rankings for this league',
              color: const Color(0xFFF9A825),
              onTap: () =>
                  context.push('/leagues/$leagueId/leaderboard'),
            ),

            const SizedBox(height: 28),

            // ── End session ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _ending ? null : _endSession,
                icon: _ending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.error),
                      )
                    : Icon(Icons.stop_circle_outlined, color: cs.error),
                label: Text(
                  _ending ? 'Ending…' : 'End Session',
                  style: TextStyle(color: cs.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
