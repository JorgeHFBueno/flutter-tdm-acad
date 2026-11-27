import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../components/ui/status_tag.dart';

import '../components/ui/app_state_message.dart';
import 'package:intl/intl.dart';

import '../models/machine_configuration.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_service.dart';
import 'workout_analysis_history_screen.dart';
import 'workout_session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final WorkoutService _workoutService = const WorkoutService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final content = user == null
        ? AppStateMessage.error('Usuário não autenticado.')
        : StreamBuilder<List<Workout>>(
            stream: _workoutService.getWorkoutsForUser(user.uid),
            builder: (context, workoutsSnapshot) {
              if (workoutsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              Set<String>? activeWorkoutIds;
              if (workoutsSnapshot.hasError) {
                debugPrint(
                  'Erro ao carregar treinos ativos: ${workoutsSnapshot.error}',
                );
              } else {
                activeWorkoutIds = workoutsSnapshot.data
                        ?.map((workout) => workout.id)
                        .whereType<String>()
                        .toSet() ??
                    <String>{};
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('workout_history')
                    .where('ownerUid', isEqualTo: user.uid)
                    .orderBy('performedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'Erro ao carregar histórico: ${snapshot.error}',
                    );
                    return AppStateMessage.error('Erro ao carregar histórico.');
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const AppStateMessage.empty(
                      'Nenhuma sessão registrada ainda.',
                    );
                  }

                  final sessions = docs
                      .map(
                        (doc) => WorkoutSession.fromMap(
                          Map<String, dynamic>.from(
                              doc.data() as Map<String, dynamic>),
                          id: doc.id,
                        ),
                      )
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _buildSessionCard(session, activeWorkoutIds);
                    },
                  );
                },
              );
            },
          );

    if (!widget.embedInScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_outlined),
            tooltip: 'Histórico de análises',
            onPressed: _openAnalysisHistory,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildSessionCard(
    WorkoutSession session,
    Set<String>? activeWorkoutIds,
  ) {
    final performedAt = session.performedAt ?? session.endAt ?? session.startAt;
    final dateLabel = performedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(performedAt)
        : 'Sem data';

    final exerciseCount = session.exercises.length;
    final totalVolume = formatCompactNumber(calculateSessionVolume(session));
    final sourceUnavailable = _isSourceUnavailable(session, activeWorkoutIds);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutSessionDetailScreen(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sourceUnavailable
                          ? 'Treino excluído - ${session.workoutName}'
                          : session.workoutName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(dateLabel),
                ],
              ),
              const SizedBox(height: 8),
              if (sourceUnavailable) ...[
                StatusTag(
                  session.workoutId.trim().isEmpty
                      ? 'Origem indisponível'
                      : 'Origem excluída',
                  tone: StatusTone.warning,
                ),
                const SizedBox(height: 4),
              ],
              Text('Exercícios: $exerciseCount'),
              Text('Volume total: $totalVolume kg reps'),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSourceUnavailable(
    WorkoutSession session,
    Set<String>? activeWorkoutIds,
  ) {
    final workoutId = session.workoutId.trim();
    if (workoutId.isEmpty) return true;
    if (activeWorkoutIds == null) return false;
    return !activeWorkoutIds.contains(workoutId);
  }

  void _openAnalysisHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutAnalysisHistoryScreen(),
      ),
    );
  }
}
