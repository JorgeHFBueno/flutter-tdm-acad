import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_service.dart';
import 'workout_creation_screen.dart';
import 'workout_list_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;
  final WorkoutService _workoutService = WorkoutService();

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
          Expanded(
            child: StreamBuilder<List<Workout>>(
              stream: _workoutService.getWorkoutsForUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Erro ao carregar treinos: ${snapshot.error}');
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
}