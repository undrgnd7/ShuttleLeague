import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/league_provider.dart';

class CreateLeaguePage extends ConsumerStatefulWidget {
  const CreateLeaguePage({super.key});

  @override
  ConsumerState<CreateLeaguePage> createState() => _CreateLeaguePageState();
}

class _CreateLeaguePageState extends ConsumerState<CreateLeaguePage> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final leagueController = ref.read(leagueControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create League')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'League Name',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await leagueController.createLeague(controller.text);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            )
          ],
        ),
      ),
    );
  }
}
