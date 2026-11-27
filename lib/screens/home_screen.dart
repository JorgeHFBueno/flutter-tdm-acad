import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../components/ui/app_panel.dart';
import '../components/ui/app_state_message.dart';
import '../components/ui/stat_value.dart';
import '../components/ui/status_tag.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/machine_history_service.dart';
import '../services/workout_service.dart';
import 'workout_creation_screen.dart';
import 'workout_execution_screen.dart';
import 'workout_list_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;
  final WorkoutService _workoutService = WorkoutService();
  final MachineService _machineService = const MachineService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _wrapContent(
        AppStateMessage.error('Usuário não autenticado.'),
      );
    }

    final theme = Theme.of(context);
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bem-vindo, ${user.displayName ?? user.email ?? 'usuário'}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(_todayLabel(), style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        StreamBuilder<WorkoutSession?>(
          stream: _machineService.watchActiveSession(user.uid),
          builder: (context, snapshot) {
            final session = snapshot.data;
            if (session == null || !session.isInProgress) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildContinueWorkout(context, session),
            );
          },
        ),
        StreamBuilder<List<Workout>>(
          stream: _workoutService.getWorkoutsForUser(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              debugPrint('Erro ao carregar treinos: ${snapshot.error}');
              return AppStateMessage.error('Erro ao carregar treinos.');
            }

            final workouts = snapshot.data ?? [];
            if (workouts.isEmpty) {
              return _buildEmptyState(context);
            }

            final suggestedWorkout = workouts.first;
            return _buildSuggestedWorkout(context, suggestedWorkout);
          },
        ),
      ],
    );

    if (!embedInScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
      ),
      body: content,
    );
  }

  Widget _wrapContent(Widget child) {
    if (embedInScaffold) {
      return Scaffold(body: child);
    }
    return child;
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${_two(now.day)}/${_two(now.month)}/${now.year}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  Widget _buildEmptyState(BuildContext context) {
    return AppStateMessage.empty(
      'Você ainda não possui treinos cadastrados.',
      action: ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const WorkoutCreationScreen(),
            ),
          );
        },
        child: const Text('Criar treino agora'),
      ),
    );
  }

  Widget _buildSuggestedWorkout(BuildContext context, Workout workout) {
    final theme = Theme.of(context);
    return AppPanel(
      title: 'TREINO SUGERIDO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${workout.machineIds.length} máquina(s)',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Ver treinos'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkoutListScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueWorkout(BuildContext context, WorkoutSession session) {
    final theme = Theme.of(context);
    final completed = session.exercises
        .where((exercise) => !exercise.isWarmup && exercise.completed)
        .length;
    final total =
        session.exercises.where((exercise) => !exercise.isWarmup).length;
    final started = session.startAt;

    return AppPanel(
      title: 'SESSÃO ATIVA',
      trailing: const StatusTag('Em andamento', tone: StatusTone.active),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.workoutName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              StatValue(label: 'Exercícios', value: '$completed/$total'),
              if (started != null)
                StatValue(
                  label: 'Início',
                  value: '${_two(started.hour)}:${_two(started.minute)}',
                  unit: '${_two(started.day)}/${_two(started.month)}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continuar treino'),
              onPressed: () => _openActiveSession(context, session),
            ),
          ),
        ],
      ),
    );
  }

  void _openActiveSession(BuildContext context, WorkoutSession session) {
    final machineIds = _machineIdsFromSession(session);
    if (machineIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessao em andamento sem exercicios validos.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutExecutionScreen(
          workout: _workoutFromSession(session, machineIds),
          initialSession: session,
        ),
      ),
    );
  }

  List<String> _machineIdsFromSession(WorkoutSession session) {
    return [
      for (final exercise in session.exercises)
        if (!exercise.isWarmup && (exercise.exerciseId ?? '').trim().isNotEmpty)
          exercise.exerciseId!.trim(),
    ];
  }

  Workout _workoutFromSession(WorkoutSession session, List<String> machineIds) {
    return Workout(
      id: session.workoutId,
      name: session.workoutName,
      ownerUid: session.ownerUid,
      machineIds: machineIds,
    );
  }
}
