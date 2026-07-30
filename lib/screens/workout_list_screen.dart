import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/machine_history.dart';
import '../models/workout.dart';
import '../models/workout_machine_resolution.dart';
import '../screens/workout_execution_screen.dart';
import '../services/machine_history_service.dart';
import '../services/workout_service.dart';
import 'workout_edit_screen.dart';

class WorkoutListScreen extends StatefulWidget {
  const WorkoutListScreen({super.key, this.embedInScaffold = true});

  final bool embedInScaffold;

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  final WorkoutService _workoutService = const WorkoutService();
  final MachineService _machineService = const MachineService();
  late final String? _uid;
  late final Stream<List<Workout>>? _workoutsStream;
  late final Stream<List<MachineProfile>>? _machinesStream;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _workoutsStream =
        _uid == null ? null : _workoutService.getWorkoutsForUser(_uid);
    _machinesStream = _uid == null ? null : _machineService.watchForUser(_uid);
  }

  @override
  Widget build(BuildContext context) {
    final content = _uid == null
        ? const Center(child: Text('Usuario nao autenticado'))
        : _buildStreams();

    if (!widget.embedInScaffold) {
      return Padding(padding: const EdgeInsets.all(8), child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de treinos')),
      body: Padding(padding: const EdgeInsets.all(8), child: content),
    );
  }

  Widget _buildStreams() {
    return StreamBuilder<List<Workout>>(
      stream: _workoutsStream,
      builder: (context, workoutSnapshot) {
        if (workoutSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (workoutSnapshot.hasError) {
          return const Center(child: Text('Erro ao carregar treinos.'));
        }
        return StreamBuilder<List<MachineProfile>>(
          stream: _machinesStream,
          builder: (context, machineSnapshot) {
            if (machineSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (machineSnapshot.hasError) {
              return const Center(child: Text('Erro ao carregar maquinas.'));
            }
            final workouts = workoutSnapshot.data ?? const <Workout>[];
            final machinesById = {
              for (final machine
                  in machineSnapshot.data ?? const <MachineProfile>[])
                machine.exerciseId: machine,
            };
            if (workouts.isEmpty) {
              return const Center(
                child: Text(
                  'Voce ainda nao cadastrou nenhum treino novo. Crie um treino selecionando Maquinas cadastradas.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _WorkoutTile(
                  workout: workout,
                  machinesById: machinesById,
                  onTap: () => _showActions(context, workout, machinesById),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showActions(
    BuildContext context,
    Workout workout,
    Map<String, MachineProfile> machinesById,
  ) {
    final missingIds = missingMachineIds(workout, machinesById);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Comecar'),
                enabled: missingIds.isEmpty,
                subtitle: missingIds.isEmpty
                    ? null
                    : const Text(
                        'Uma ou mais maquinas deste treino nao estao disponiveis. Edite o treino antes de iniciar.',
                      ),
                onTap: missingIds.isEmpty
                    ? () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkoutExecutionScreen(
                              workout: workout,
                              machines: resolveWorkoutMachines(
                                workout,
                                machinesById,
                              ),
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutEditScreen(workout: workout),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Excluir'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, workout);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Workout workout) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir treino'),
        content: const Text('Tem certeza que deseja excluir este treino?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && workout.id != null) {
      await _workoutService.deleteWorkout(workout.ownerUid, workout.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino excluido com sucesso')),
      );
    }
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.workout,
    required this.machinesById,
    required this.onTap,
  });

  final Workout workout;
  final Map<String, MachineProfile> machinesById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = missingMachineIds(workout, machinesById);
    final machines = resolveWorkoutMachines(workout, machinesById);
    final names = machines.map((machine) => machine.exerciseName).take(3);
    final subtitle = <String>[
      '${workout.machineIds.length} maquina(s)',
      if (names.isNotEmpty) names.join(', '),
      if (missing.isNotEmpty) 'Referencia ausente',
      if (workout.createdAt != null) _formatDate(workout.createdAt!),
    ].join(' - ');
    return ListTile(
      title: Text(workout.name),
      subtitle: Text(subtitle),
      leading: Icon(
        missing.isEmpty ? Icons.fitness_center : Icons.error_outline,
        color: missing.isEmpty ? null : Colors.orange[800],
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
