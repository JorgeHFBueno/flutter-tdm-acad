import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/workout_session.dart';
import '../services/workout_analysis_service.dart';
import 'workout_session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final WorkoutAnalysisService _analysisService = WorkoutAnalysisService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final content = user == null
        ? const Center(child: Text('Usuário não autenticado.'))
        : StreamBuilder<QuerySnapshot>(
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
                print('Erro ao carregar histórico: ${snapshot.error}');
                return const Center(child: Text('Erro ao carregar histórico.'));
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
                  return _buildSessionCard(session);
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
      ),
      body: content,
    );
  }

  Widget _buildSessionCard(WorkoutSession session) {
    final performedAt = session.performedAt ?? session.endAt ?? session.startAt;
    final dateLabel = performedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(performedAt)
        : 'Sem data';

    final exerciseCount = session.exercises.length;
    final totalVolume = _calculateVolume(session).toStringAsFixed(0);

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
                      session.workoutName,
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

  double _calculateVolume(WorkoutSession session) {
    double total = 0;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        total += set.reps * set.weightKg;
      }
    }
    return total;
  }

  Future<void> _analyzeHistory(WorkoutSession session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _showLoadingDialog(); // abre o loading

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
          Map<String, dynamic>.from(doc.data() as Map<String, dynamic>),
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

      if (!mounted) return;
      await _showAnalysisResult(response);
    } catch (e, stackTrace) {
      print('Erro ao analisar histórico: $e');
      print(stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao analisar histórico. Tente novamente.'),
          ),
        );
      }
    } finally {
      // FECHAR O LOADING SEMPRE
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }


  String _buildHistoryPrompt(
      List<WorkoutSession> sessions, String workoutName) {
    final buffer = StringBuffer()
      ..writeln(
          'Você é um treinador de musculação. Analise o histórico de treinos abaixo para o aluno. Considere os exercícios, número de séries, repetições, cargas (kg) e o estado subjetivo final ("certo", "leve", "fadiga") em cada sessão. Sugira, de forma objetiva, se deve trocar a ordem dos exercícios, aumentar ou diminuir peso ou séries para cada exercício, levando em conta sobrecarga progressiva, recuperação e fadiga.')
      ..writeln()
      ..writeln('Histórico do treino "$workoutName":');

    for (final session in sessions) {
      final dateLabel = _formatDate(session.performedAt ?? session.endAt);
      buffer.writeln('- Sessão em $dateLabel');
      for (final exercise in session.exercises) {
        buffer.writeln(
            '  • ${exercise.exerciseName} (${exercise.perceivedEffort ?? 'sem percepção'})');
        for (final set in exercise.sets) {
          buffer.writeln(
              '    - Série ${set.setNumber}: ${set.reps} reps x ${set.weightKg} kg');
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
