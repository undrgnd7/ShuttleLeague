import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/league_provider.dart';

class CreateLeaguePage extends ConsumerStatefulWidget {
  const CreateLeaguePage({super.key});

  @override
  ConsumerState<CreateLeaguePage> createState() => _CreateLeaguePageState();
}

class _CreateLeaguePageState extends ConsumerState<CreateLeaguePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int _maxPlayers = 16;
  bool _saving = false;
  String? _nameError;

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
      await ref
          .read(leagueControllerProvider)
          .createLeague(_nameCtrl.text, maxPlayers: _maxPlayers);
      if (mounted) Navigator.pop(context);
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
      appBar: AppBar(title: const Text('New League')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.emoji_events_rounded,
                    color: cs.onPrimaryContainer, size: 36),
              ),
            ),
            const SizedBox(height: 28),

            Text('League Name',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Tuesday Doubles',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (_nameError != null) return _nameError;
                return null;
              },
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Max Players',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_maxPlayers',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _maxPlayers.toDouble(),
              min: 4,
              max: 32,
              divisions: 7,
              label: '$_maxPlayers players',
              onChanged: (v) {
                final snapped = (v / 4).round() * 4;
                setState(() => _maxPlayers = snapped.clamp(4, 32));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('4',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('32',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
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
                    : const Text('Create League'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
