import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_service.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _wrapContent(
        const Center(child: Text('Usuário não autenticado')),
      );
    }

    final content = StreamBuilder<List<Workout>>(
      stream: WorkoutService().getWorkoutsForUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar treinos.'));
        }

        final workouts = snapshot.data ?? [];
        if (workouts.isEmpty) {
          return const Center(
            child: Text('Você ainda não cadastrou nenhum treino.'),
          );
        }

        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            return ListTile(
              title: Text(workout.name),
              subtitle: Text(
                '${workout.exercises.length} exercício(s)' +
                    (workout.createdAt != null
                        ? ' · ${_formatDate(workout.createdAt!)}'
                        : ''),
              ),
              leading: const Icon(Icons.fitness_center),
            );
          },
        );
      },
    );

    if (!embedInScaffold) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de treinos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: content,
      ),
    );
  }

  Widget _wrapContent(Widget child) {
    if (embedInScaffold) {
      return Scaffold(body: child);
    }
    return child;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
}