import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/machine_configuration.dart';
import '../models/workout_session.dart';

class WorkoutSessionDetailScreen extends StatefulWidget {
  const WorkoutSessionDetailScreen({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<WorkoutSessionDetailScreen> createState() =>
      _WorkoutSessionDetailScreenState();
}

class _WorkoutSessionDetailScreenState
    extends State<WorkoutSessionDetailScreen> {
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
                    'Série ${set.setNumber}: ${set.reps} reps - '
                    '${formatSetLoad(set.weightKg, perSide: exercise.loadPerSide, bodyweight: exercise.isBodyweight)}',
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
        : exercise.isBodyweight
            ? bodyweightLabel
            : formatKg(
                exercise.configuredWeightKg!,
                perSide: exercise.loadPerSide,
              );
    return '$sets x $reps - $weight';
  }
}
