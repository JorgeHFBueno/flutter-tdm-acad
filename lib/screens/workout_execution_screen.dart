import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_history_service.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutExecutionScreen({super.key, required this.workout});

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  final Map<String, ExerciseExecution> _executions = {};
  final WorkoutHistoryService _historyService = WorkoutHistoryService();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Executar treino: ${widget.workout.name}'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.workout.exercises.length + 1,
        itemBuilder: (context, index) {
          if (index == widget.workout.exercises.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishWorkout,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text('Concluir treino'),
              ),
            );
          }
          final exercise = widget.workout.exercises[index];
          final execution = _executions[exercise.name];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(exercise.name),
              subtitle: execution != null
                  ? Text(
                '${execution.sets}x${execution.reps} • ${execution.weightKg} kg',
              )
                  : Text('Peso padrão: ${exercise.defaultWeightKg} kg'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _openExecutionDialog(exercise),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openExecutionDialog(WorkoutExercise exercise) async {
    final formKey = GlobalKey<FormState>();
    final setsController = TextEditingController(
      text: _executions[exercise.name]?.sets.toString() ?? '3',
    );
    final repsController = TextEditingController(
      text: _executions[exercise.name]?.reps.toString() ?? '10',
    );
    final weightController = TextEditingController(
      text: _executions[exercise.name]?.weightKg.toString() ??
          exercise.defaultWeightKg.toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Registrar ${exercise.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Séries'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Informe um número válido';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Repetições'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Informe um número válido';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Informe um número válido';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final sets = int.parse(setsController.text);
                  final reps = int.parse(repsController.text);
                  final weight = int.parse(weightController.text);
                  setState(() {
                    _executions[exercise.name] = ExerciseExecution(
                      exerciseName: exercise.name,
                      sets: sets,
                      reps: reps,
                      weightKg: weight,
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishWorkout() async {
    if (_executions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registre pelo menos um exercício.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final session = WorkoutSession(
      workoutId: widget.workout.id ?? '',
      workoutName: widget.workout.name,
      ownerUid: user.uid,
      exercises: _executions.values.toList(),
    );

    try {
      await _historyService.saveSession(session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino salvo no histórico!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar treino. Tente novamente.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}