import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_session.dart';
import '../services/workout_analysis_service.dart';

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
              const SizedBox(height: 16),
              const Text(
                'Exercícios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...session.exercises.map((exercise) => Card(
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
                              exercise.exerciseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (exercise.perceivedEffort != null)
                            Chip(
                              label: Text(
                                _effortLabel(exercise.perceivedEffort!),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...exercise.sets.map(
                            (set) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            'Série ${set.setNumber}: ${set.reps} reps – ${set.weightKg} kg',
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              )),
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

  String _effortLabel(String effort) {
    switch (effort) {
      case 'certo':
        return 'Certo';
      case 'leve':
        return 'Leve';
      case 'fadiga':
        return 'Fadiga';
      default:
        return effort;
    }
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

  Future<void> _analyzeCurrentSession() async {
    _showLoadingDialog();
    try {
      final prompt = _buildSessionPrompt(widget.session);
      final response = await _analysisService.analyzeText(prompt);
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

  String _buildSessionPrompt(WorkoutSession session) {
    final buffer = StringBuffer()
      ..writeln(
          'Você é um treinador de musculação. Analise APENAS este treino realizado, considerando ordem dos exercícios, carga (kg), séries e repetições, além da percepção de esforço ("certo", "leve", "fadiga"). Sugira ajustes práticos: trocar a ordem de equipamentos, aumentar ou diminuir peso ou número de séries, e comente se o treino parece adequado para objetivo de força/hipertrofia, levando em conta sinais de fadiga.')
      ..writeln()
      ..writeln('Treino: ${session.workoutName}')
      ..writeln('Data: ${_formatDateTime(session.performedAt ?? session.endAt)}');

    for (final exercise in session.exercises) {
      buffer.writeln('• ${exercise.exerciseName} (${exercise.perceivedEffort ?? 'sem percepção'})');
      for (final set in exercise.sets) {
        buffer.writeln('  - Série ${set.setNumber}: ${set.reps} reps x ${set.weightKg} kg');
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