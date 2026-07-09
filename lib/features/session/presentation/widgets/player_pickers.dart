import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../player/data/player_model.dart';

String _initials(String name) {
  if (name.isEmpty) return '?';
  return name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
}

/// Shows a bottom sheet to pick a single replacement player.
Future<PlayerModel?> pickSinglePlayer(
  BuildContext context,
  List<PlayerModel> players, {
  Set<String> excludeIds = const {},
}) {
  final options = players.where((p) => !excludeIds.contains(p.id)).toList();
  return showModalBottomSheet<PlayerModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SinglePickerSheet(players: options),
  );
}

/// Shows a bottom sheet requiring exactly [count] players to be selected.
Future<List<PlayerModel>?> pickMultiplePlayers(
  BuildContext context,
  List<PlayerModel> players, {
  required int count,
  Set<String> excludeIds = const {},
}) {
  final options = players.where((p) => !excludeIds.contains(p.id)).toList();
  return showModalBottomSheet<List<PlayerModel>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MultiPickerSheet(players: options, count: count),
  );
}

class _SinglePickerSheet extends StatelessWidget {
  final List<PlayerModel> players;
  const _SinglePickerSheet({required this.players});

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
                Text('Choose Player',
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
            child: players.isEmpty
                ? Center(
                    child: Text('No eligible players',
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: players.length,
                    itemBuilder: (_, i) {
                      final p = players[i];
                      return ListTile(
                        onTap: () => Navigator.pop(context, p),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.avatarColor(p.name),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(_initials(p.name),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Rating ${p.rating}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MultiPickerSheet extends StatefulWidget {
  final List<PlayerModel> players;
  final int count;
  const _MultiPickerSheet({required this.players, required this.count});

  @override
  State<_MultiPickerSheet> createState() => _MultiPickerSheetState();
}

class _MultiPickerSheetState extends State<_MultiPickerSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Choose ${widget.count} Players',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_selected.length}/${widget.count}',
                    style: TextStyle(
                        color: _selected.length == widget.count
                            ? cs.primary
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.players.isEmpty
                ? Center(
                    child: Text('No eligible players',
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: widget.players.length,
                    itemBuilder: (_, i) {
                      final p = widget.players[i];
                      final isSelected = _selected.contains(p.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              if (_selected.length < widget.count) {
                                _selected.add(p.id);
                              }
                            } else {
                              _selected.remove(p.id);
                            }
                          });
                        },
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.avatarColor(p.name),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(_initials(p.name),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Rating ${p.rating}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.length == widget.count
                      ? () {
                          final chosen = widget.players
                              .where((p) => _selected.contains(p.id))
                              .toList();
                          Navigator.pop(context, chosen);
                        }
                      : null,
                  child: const Text('Add Match'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
