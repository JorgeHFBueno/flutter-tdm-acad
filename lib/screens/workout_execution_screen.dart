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
  late Map<String, ExerciseExecution> _executions;
  final WorkoutHistoryService _historyService = WorkoutHistoryService();
  bool _isSaving = false;
  late DateTime _startAt;

  @override
  void initState() {
    super.initState();
    _startAt = DateTime.now();
    _executions = {
      for (final exercise in widget.workout.exercises)
        exercise.name: ExerciseExecution(
          exerciseName: exercise.name,
          sets: [],
          completed: false,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final exercises = [...widget.workout.exercises];
    exercises.sort((a, b) {
      final aCompleted = _executions[a.name]?.completed ?? false;
      final bCompleted = _executions[b.name]?.completed ?? false;
      if (aCompleted == bCompleted) return 0;
      return aCompleted ? 1 : -1;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Executar treino: ${widget.workout.name}'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exercises.length + 1,
        itemBuilder: (context, index) {
          if (index == exercises.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishWorkout,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Concluir treino'),
              ),
            );
          }
          final exercise = exercises[index];
          return _buildExerciseCard(exercise);
        },
      ),
    );
  }

  Widget _buildExerciseCard(WorkoutExercise exercise) {
    final execution = _executions[exercise.name];
    final sets = execution?.sets ?? [];
    final lastSet = sets.isNotEmpty ? sets.last : null;
    final completed = execution?.completed ?? false;

    final perceivedEffort = execution?.perceivedEffort;
    final effortLabel = perceivedEffort != null
        ? 'Percepção: ${_effortLabel(perceivedEffort)}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: completed ? Colors.grey[200] : null,
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
                    exercise.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: completed ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  // Uma vez concluído, não permitimos adicionar novas séries.
                  onPressed:
                      completed ? null : () => _openAddSetDialog(exercise),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (sets.isNotEmpty) ...[
              Text('Séries registradas: ${sets.length}'),
              Text('Última: ${lastSet!.reps} reps, ${lastSet.weightKg} kg'),
            ] else
              Text(
                  'Nenhuma série registrada. Peso padrão: ${exercise.defaultWeightKg} kg'),
            if (effortLabel != null) ...[
              const SizedBox(height: 4),
              Text(effortLabel),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.flag),
                label:
                    Text(completed ? 'Máquina concluída' : 'Concluir máquina'),
                onPressed: completed ? null : () => _completeExercise(exercise),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddSetDialog(WorkoutExercise exercise) async {
    final execution = _executions[exercise.name]!;
    final lastSet = execution.sets.isNotEmpty ? execution.sets.last : null;
    final formKey = GlobalKey<FormState>();
    final repsController = TextEditingController(
      text: (lastSet?.reps ?? 10).toString(),
    );
    final weightController = TextEditingController(
      text: (lastSet?.weightKg ?? exercise.defaultWeightKg).toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Adicionar série - ${exercise.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  final reps = int.parse(repsController.text);
                  final weight = int.parse(weightController.text);
                  final newSet = ExerciseSet(
                    setNumber: execution.sets.length + 1,
                    reps: reps,
                    weightKg: weight,
                  );
                  setState(() {
                    _executions[exercise.name] = execution.copyWith(
                      sets: [...execution.sets, newSet],
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeExercise(WorkoutExercise exercise) async {
    final execution = _executions[exercise.name]!;
    String? selectedEffort = execution.perceivedEffort;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Percepção de esforço'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['certo', 'leve', 'fadiga']
                    .map(
                      (option) => RadioListTile<String>(
                        title: Text(_effortLabel(option)),
                        value: option,
                        groupValue: selectedEffort,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedEffort = value;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedEffort != null) {
                      Navigator.of(dialogContext).pop(selectedEffort);
                    }
                  },
                  child: const Text('Concluir máquina'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      _executions[exercise.name] = execution.copyWith(
        perceivedEffort: result,
        completed: true,
      );
    });
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

  Future<void> _finishWorkout() async {
    final hasRegisteredSets =
        _executions.values.any((execution) => execution.sets.isNotEmpty);

    if (!hasRegisteredSets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registre pelo menos uma série.')),
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

    final exercisesForSession = widget.workout.exercises
        .map(
          (exercise) =>
              _executions[exercise.name] ??
              ExerciseExecution(exerciseName: exercise.name, sets: []),
        )
        .toList();

    final session = WorkoutSession(
      workoutId: widget.workout.id ?? '',
      workoutName: widget.workout.name,
      ownerUid: user.uid,
      startAt: _startAt,
      endAt: DateTime.now(),
      performedAt: DateTime.now(),
      exercises: exercisesForSession,
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
        const SnackBar(
            content: Text('Erro ao salvar treino. Tente novamente.')),
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
