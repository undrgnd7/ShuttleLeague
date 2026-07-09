import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_model.dart';
import '../providers/player_provider.dart';

class CreatePlayerPage extends ConsumerStatefulWidget {
  /// Null = create mode. Non-null = edit mode.
  final PlayerModel? player;
  const CreatePlayerPage({super.key, this.player});

  @override
  ConsumerState<CreatePlayerPage> createState() => _CreatePlayerPageState();
}

class _CreatePlayerPageState extends ConsumerState<CreatePlayerPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int _skillLevel = 3;
  PlayerGender _gender = PlayerGender.male;
  bool _isJoker = false;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.player != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.player!.name;
      _skillLevel = widget.player!.skillLevel;
      _gender = widget.player!.gender;
      _isJoker = widget.player!.isJoker;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _nameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = PlayerModel(
          id: widget.player!.id,
          name: _nameCtrl.text.trim(),
          skillLevel: _skillLevel,
          gender: _gender,
          isJoker: _isJoker,
          rating: widget.player!.rating,
          wins: widget.player!.wins,
          losses: widget.player!.losses,
          createdAt: widget.player!.createdAt,
        );
        await ref.read(playerControllerProvider).updatePlayer(updated);
      } else {
        await ref.read(playerControllerProvider).createPlayer(
              _nameCtrl.text,
              skillLevel: _skillLevel,
              gender: _gender,
              isJoker: _isJoker,
            );
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      if (mounted) {
        setState(() =>
            _nameError = e.toString().replaceFirst('Exception: ', ''));
        _formKey.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Player' : 'New Player')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar preview
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            Text('Player Name',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Ali Hassan',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 2) return 'Name too short';
                if (_nameError != null) return _nameError;
                return null;
              },
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Skill Level',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                _SkillBadge(level: _skillLevel),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _skillLevel.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: _skillLabel(_skillLevel),
              onChanged: (v) => setState(() => _skillLevel = v.round()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Beginner',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('Pro',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('Gender',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<PlayerGender>(
              segments: const [
                ButtonSegment(
                  value: PlayerGender.male,
                  label: Text('Male'),
                  icon: Icon(Icons.male_rounded),
                ),
                ButtonSegment(
                  value: PlayerGender.female,
                  label: Text('Female'),
                  icon: Icon(Icons.female_rounded),
                ),
              ],
              selected: {_gender},
              onSelectionChanged: (v) =>
                  setState(() => _gender = v.first),
            ),
            const SizedBox(height: 28),

            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                value: _isJoker,
                onChanged: (v) => setState(() => _isJoker = v),
                secondary: Icon(Icons.theater_comedy_rounded,
                    color: _isJoker ? cs.primary : cs.outline),
                title: const Text('Joker',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'A stand-in for no-shows — can join any league, but never earns or loses points.'),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Add Player'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _skillLabel(int level) {
    const labels = {
      1: 'Beginner',
      2: 'Casual',
      3: 'Intermediate',
      4: 'Advanced',
      5: 'Pro',
    };
    return labels[level] ?? '$level';
  }
}

class _SkillBadge extends StatelessWidget {
  final int level;
  const _SkillBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    const colors = {
      1: Color(0xFF78909C),
      2: Color(0xFF26A69A),
      3: Color(0xFF1E88E5),
      4: Color(0xFF8E24AA),
      5: Color(0xFFF57F17),
    };
    const labels = {
      1: 'Beginner',
      2: 'Casual',
      3: 'Inter.',
      4: 'Advanced',
      5: 'Pro',
    };
    final color = colors[level] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labels[level] ?? 'Level $level',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
