import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/live_session_state.dart';
import '../controllers/queue_controller.dart';

final queueControllerProvider =
    StateNotifierProvider.family<QueueController, LiveSessionState, String>(
  (ref, sessionId) {
    return QueueController(sessionId);
  },
);
