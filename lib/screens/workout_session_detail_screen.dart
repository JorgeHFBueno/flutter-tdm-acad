import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/machine_configuration.dart';
import '../models/workout_session.dart';
import '../services/workout_analysis_service.dart';
import '../models/workout_analysis_log.dart';
import '../services/workout_analysis_log_service.dart';

class WorkoutSessionDetailScreen extends StatefulWidget {
  const WorkoutSessionDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<WorkoutSessionDetailScreen> createState() =>
      _WorkoutSessionDetailScreenState();
}

class _WorkoutSessionDetailScreenState
    extends State<WorkoutSessionDetailScreen> {
  final WorkoutAnalysisService _analysisService = WorkoutAnalysisService();
  final WorkoutAnalysisLogService _analysisLogService =
      WorkoutAnalysisLogService();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final startAt = session.startAt;
    final endAt = session.endAt;
    final performedAt = session.performedAt ?? endAt ?? startAt;

    final dateLabel = performedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(performedAt)
        : 'Sem data registrada';
    final startLabel = _formatDateTime(startAt);
    final endLabel = _formatDateTime(endAt);
    final durationLabel = _calculateDuration(startAt, endAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do treino'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.workoutName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Realizado em: $dateLabel'),
              Text('Início: $startLabel'),
              Text('Fim: $endLabel'),
              Text('Duração: $durationLabel'),
              Text(
                'Volume total: ${formatCompactNumber(calculateSessionVolume(session))} kg reps',
              ),
              const SizedBox(height: 16),
              const Text(
                'Exercícios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...session.exercises.map(_buildExerciseCard),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Analisar este treino (IA)'),
                  onPressed: _analyzeCurrentSession,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseExecution exercise) {
    final title = exercise.isWarmup ? 'Aquecimento' : exercise.exerciseName;
    final skipped = PerceivedEffort.isSkipped(exercise.perceivedEffort);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!exercise.isWarmup && exercise.perceivedEffort != null)
                  Chip(
                    label: Text(
                      PerceivedEffort.labelFor(exercise.perceivedEffort),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (exercise.isWarmup &&
                exercise.status == ExerciseExecutionStatus.skipped)
              const Text('Aquecimento não realizado')
            else if (exercise.isWarmup)
              Text(
                'Exercício utilizado: ${exercise.targetExerciseName ?? 'Não informado'}',
              ),
            if (skipped)
              Text(
                'Não realizado: ${PerceivedEffort.labelFor(exercise.perceivedEffort)}',
              ),
            if (!exercise.isWarmup && _hasConfigurationSnapshot(exercise))
              Text(
                'Configuração da máquina: ${_formatConfigurationSnapshot(exercise)}',
              ),
            if ((exercise.observationSnapshot ?? '').trim().isNotEmpty)
              Text('OBS: ${exercise.observationSnapshot!.trim()}'),
            if (exercise.sets.isEmpty)
              const Text('Nenhuma série registrada.')
            else
              ...exercise.sets.map(
                (set) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    'Série ${set.setNumber}: ${set.reps} reps - ${formatKg(set.weightKg)}',
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text('Volume: ${formatCompactNumber(exercise.volume)} kg reps'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _calculateDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Não informado';
    final duration = end.difference(start);
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = duration.inHours;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
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

  Future<void> _analyzeCurrentSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
      }
      return;
    }
    _showLoadingDialog();
    try {
      final prompt = _buildSessionPrompt(widget.session);
      final response = await _analysisService.analyzeText(prompt);

      await _saveAnalysisLog(
        userUid: user.uid,
        prompt: prompt,
        response: response,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _showAnalysisResult(response);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao analisar treino: $e')),
      );
    }
  }

  Future<void> _saveAnalysisLog({
    required String userUid,
    required String prompt,
    required String response,
  }) async {
    final log = WorkoutAnalysisLog(
      id: '',
      ownerUid: userUid,
      workoutId: widget.session.workoutId,
      workoutName: widget.session.workoutName,
      type: 'session',
      prompt: prompt,
      response: response,
      createdAt: DateTime.now(),
    );

    try {
      await _analysisLogService.saveLog(log);
    } catch (e) {
      debugPrint('Erro ao salvar histórico de análise de sessão: $e');
    }
  }

  String _buildSessionPrompt(WorkoutSession session) {
    final buffer = StringBuffer()
      ..writeln(
          'Você é um treinador de musculação. Analise APENAS este treino realizado, considerando a ordem executada, aquecimento, exercício-alvo do aquecimento, carga (kg), séries, repetições, volume e percepção de esforço em português. Sugira ajustes práticos: trocar a ordem de equipamentos, aumentar ou diminuir peso ou número de séries, e comente se o treino parece adequado para objetivo de força/hipertrofia, levando em conta sinais de fadiga.')
      ..writeln()
      ..writeln('Treino: ${session.workoutName}')
      ..writeln(
          'Data: ${_formatDateTime(session.performedAt ?? session.endAt)}');

    for (final exercise in session.exercises) {
      if (exercise.isWarmup &&
          exercise.status == ExerciseExecutionStatus.skipped) {
        buffer.writeln('• Aquecimento não realizado');
      } else if (exercise.isWarmup) {
        buffer.writeln(
            '• Aquecimento para ${exercise.targetExerciseName ?? 'exercício não informado'} (sem percepção, volume ${formatCompactNumber(exercise.volume)} kg reps)');
      } else {
        buffer.writeln(
            '• ${exercise.exerciseName} (${PerceivedEffort.labelFor(exercise.perceivedEffort)}, volume ${formatCompactNumber(exercise.volume)} kg reps)');
        if (_hasConfigurationSnapshot(exercise)) {
          buffer.writeln(
              '  - Configuração esperada: ${_formatConfigurationSnapshot(exercise)}');
        }
        if ((exercise.observationSnapshot ?? '').trim().isNotEmpty) {
          buffer.writeln('  - OBS: ${exercise.observationSnapshot!.trim()}');
        }
        if (PerceivedEffort.isSkipped(exercise.perceivedEffort)) {
          buffer.writeln('  - Exercício não realizado.');
        }
      }
      for (final set in exercise.sets) {
        buffer.writeln(
            '  - Série ${set.setNumber}: ${set.reps} reps x ${formatKg(set.weightKg)}');
      }
    }

    return buffer.toString();
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
}
