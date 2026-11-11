import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_analysis_log.dart';
import '../models/machine_configuration.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_analysis_log_service.dart';
import '../services/workout_analysis_service.dart';
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
  final WorkoutAnalysisService _analysisService = WorkoutAnalysisService();
  final WorkoutAnalysisLogService _analysisLogService =
      WorkoutAnalysisLogService();
  final WorkoutService _workoutService = const WorkoutService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final content = user == null
        ? const Center(child: Text('Usuário não autenticado.'))
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
                    return const Center(
                        child: Text('Erro ao carregar histórico.'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma sessão registrada ainda.'),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(dateLabel),
                ],
              ),
              const SizedBox(height: 8),
              if (sourceUnavailable) ...[
                Text(
                  session.workoutId.trim().isEmpty
                      ? 'Origem indisponível'
                      : 'Origem excluída',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
              ],
              Text('Exercícios: $exerciseCount'),
              Text('Volume total: $totalVolume kg reps'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Analisar histórico deste treino (IA)'),
                  onPressed: () => _analyzeHistory(session),
                ),
              )
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

  Future<void> _analyzeHistory(WorkoutSession session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _showLoadingDialog();

    try {
      final query = await FirebaseFirestore.instance
          .collection('workout_history')
          .where('ownerUid', isEqualTo: user.uid)
          .where('workoutName', isEqualTo: session.workoutName)
          .orderBy('performedAt', descending: true)
          .get();

      final sessions = query.docs
          .map(
            (doc) => WorkoutSession.fromMap(
              Map<String, dynamic>.from(doc.data()),
              id: doc.id,
            ),
          )
          .toList();

      if (sessions.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Você ainda tem poucas sessões deste treino. A análise pode ficar limitada.',
              ),
            ),
          );
        }
      }

      final prompt = _buildHistoryPrompt(sessions, session.workoutName);
      final response = await _analysisService.analyzeText(prompt);

      await _saveAnalysisLog(
        type: 'history',
        session: session,
        prompt: prompt,
        response: response,
      );

      if (!mounted) return;
      await _showAnalysisResult(response);
    } catch (e, stackTrace) {
      debugPrint('Erro ao analisar histórico: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao analisar histórico. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  String _buildHistoryPrompt(
    List<WorkoutSession> sessions,
    String workoutName,
  ) {
    final buffer = StringBuffer()
      ..writeln(
          'Você é um treinador de musculação. Analise o histórico de treinos abaixo para o aluno. '
          'Considere a ordem executada, aquecimento, exercício-alvo do aquecimento, séries, repetições, cargas (kg), volume e percepção de esforço em português. '
          'Sugira, de forma objetiva, se deve trocar a ordem dos exercícios, aumentar ou diminuir peso ou séries para cada exercício, levando em conta sobrecarga progressiva, recuperação e fadiga.')
      ..writeln()
      ..writeln('Histórico do treino "$workoutName":');

    for (final session in sessions) {
      final dateLabel = _formatDate(session.performedAt ?? session.endAt);
      buffer.writeln('- Sessão em $dateLabel');
      for (final exercise in session.exercises) {
        if (exercise.isWarmup &&
            exercise.status == ExerciseExecutionStatus.skipped) {
          buffer.writeln('  • Aquecimento não realizado');
        } else if (exercise.isWarmup) {
          buffer.writeln(
              '  • Aquecimento para ${exercise.targetExerciseName ?? 'exercício não informado'} (sem percepção, volume ${formatCompactNumber(exercise.volume)} kg reps)');
        } else {
          buffer.writeln(
              '  • ${exercise.exerciseName} (${PerceivedEffort.labelFor(exercise.perceivedEffort)}, volume ${formatCompactNumber(exercise.volume)} kg reps)');
          if (_hasConfigurationSnapshot(exercise)) {
            buffer.writeln(
                '    - Configuracao esperada: ${_formatConfigurationSnapshot(exercise)}');
          }
          if ((exercise.observationSnapshot ?? '').trim().isNotEmpty) {
            buffer
                .writeln('    - OBS: ${exercise.observationSnapshot!.trim()}');
          }
          if (PerceivedEffort.isSkipped(exercise.perceivedEffort)) {
            buffer.writeln('    - Exercício não realizado.');
          }
        }
        for (final set in exercise.sets) {
          buffer.writeln(
              '    - Série ${set.setNumber}: ${set.reps} reps x ${formatKg(set.weightKg)}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Data não informada';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  bool _hasConfigurationSnapshot(ExerciseExecution exercise) {
    return exercise.configuredSets != null ||
        exercise.configuredRepetitions != null ||
        exercise.configuredWeightKg != null;
  }

  String _formatConfigurationSnapshot(ExerciseExecution exercise) {
    final sets = exercise.configuredSets == null
        ? 'Sem meta'
        : '${exercise.configuredSets}';
    final reps = exercise.configuredRepetitions == null
        ? 'sem repeticoes'
        : '${exercise.configuredRepetitions}';
    final weight = exercise.configuredWeightKg == null
        ? 'sem peso'
        : formatKg(exercise.configuredWeightKg!);
    return '$sets x $reps - $weight';
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _showAnalysisResult(String response) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Análise do treino (IA)'),
        content: SingleChildScrollView(child: Text(response)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          )
        ],
      ),
    );
  }

  Future<void> _saveAnalysisLog({
    required String type,
    required WorkoutSession session,
    required String prompt,
    required String response,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final log = WorkoutAnalysisLog(
      id: '',
      ownerUid: user.uid,
      workoutId: session.workoutId,
      workoutName: session.workoutName,
      type: type,
      prompt: prompt,
      response: response,
      createdAt: DateTime.now(),
    );

    try {
      await _analysisLogService.saveLog(log);
    } catch (e) {
      debugPrint('Erro ao salvar histórico de análise: $e');
    }
  }

  void _openAnalysisHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutAnalysisHistoryScreen(),
      ),
    );
  }
}
