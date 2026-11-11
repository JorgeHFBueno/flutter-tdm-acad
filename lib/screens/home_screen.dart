import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        const Center(child: Text('Usuário não autenticado')),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bem-vindo, ${user.displayName ?? user.email ?? 'usuário'}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<WorkoutSession?>(
            stream: _machineService.watchActiveSession(user.uid),
            builder: (context, snapshot) {
              final session = snapshot.data;
              if (session == null || !session.isInProgress) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildContinueWorkout(context, session),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Workout>>(
              stream: _workoutService.getWorkoutsForUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Erro ao carregar treinos: ${snapshot.error}');
                  return const Center(child: Text('Erro ao carregar treinos.'));
                }

                final workouts = snapshot.data ?? [];
                if (workouts.isEmpty) {
                  return _buildEmptyState(context);
                }

                final suggestedWorkout = workouts.first;
                return _buildSuggestedWorkout(context, suggestedWorkout);
              },
            ),
          ),
        ],
      ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Você ainda não possui treinos cadastrados.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WorkoutCreationScreen(),
                ),
              );
            },
            child: const Text('Criar treino agora'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedWorkout(BuildContext context, Workout workout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu treino sugerido para hoje:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  workout.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${workout.machineIds.length} maquina(s)'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkoutListScreen(),
                      ),
                    );
                  },
                  child: const Text('Ver treino'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWorkout(BuildContext context, WorkoutSession session) {
    final completed = session.exercises
        .where((exercise) => !exercise.isWarmup && exercise.completed)
        .length;
    final total =
        session.exercises.where((exercise) => !exercise.isWarmup).length;
    final started = session.startAt;
    final dateLabel = started == null
        ? null
        : '${started.day.toString().padLeft(2, '0')}/'
            '${started.month.toString().padLeft(2, '0')} '
            '${started.hour.toString().padLeft(2, '0')}:'
            '${started.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text('Continuar treino'),
        subtitle: Text(
          [
            session.workoutName,
            if (dateLabel != null) dateLabel,
            '$completed de $total exercicios',
          ].join(' - '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
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
        },
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
