import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../components/observation_dialog.dart';
import '../models/machine_event.dart';
import '../models/machine_configuration.dart';
import '../models/machine_history.dart';
import '../models/workout.dart';
import '../models/workout_execution_flow.dart';
import '../models/workout_machine_resolution.dart';
import '../models/workout_session.dart';
import '../services/machine_history_service.dart';
import 'machine_history_screen.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  const WorkoutExecutionScreen({
    super.key,
    required this.workout,
    this.machines,
  });

  final Workout workout;
  final List<MachineProfile>? machines;

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  final MachineService _machineService = const MachineService();
  final Map<String, MachineProfile> _machinesById = {};
  late DateTime _startAt;
  late ExerciseExecution _warmupExecution;
  List<SessionExerciseEntry> _pendingEntries = const [];
  final List<SessionExerciseEntry> _completedEntries = [];
  dynamic _sessionRef;
  WorkoutExecutionPhase _phase = WorkoutExecutionPhase.warmup;
  bool _isLoadingMachines = false;
  bool _isSaving = false;
  List<String> _missingMachineIds = const [];

  @override
  void initState() {
    super.initState();
    _startAt = DateTime.now();
    _warmupExecution = createWarmupExecution();
    if (widget.machines == null) {
      _loadMachines();
    } else {
      _applyMachines(widget.machines!);
    }
  }

  void _applyMachines(List<MachineProfile> machines) {
    _machinesById
      ..clear()
      ..addEntries(
        machines.map((machine) => MapEntry(machine.exerciseId, machine)),
      );
    _missingMachineIds = missingMachineIds(widget.workout, _machinesById);
    _pendingEntries = _missingMachineIds.isEmpty
        ? createPendingEntriesFromMachines(
            resolveWorkoutMachines(widget.workout, _machinesById),
          )
        : const [];
    if (_pendingEntries.isEmpty) {
      _phase = WorkoutExecutionPhase.remainingExercises;
    } else if (_pendingEntries.length == 1) {
      final target = _pendingEntries.single.machine;
      _warmupExecution = _warmupExecution.copyWith(
        targetExerciseId: target.exerciseId,
        targetExerciseName: target.exerciseName,
      );
    }
  }

  Future<void> _loadMachines() async {
    final user = _currentUserOrNull();
    if (user == null) return;
    setState(() => _isLoadingMachines = true);
    try {
      final machines = await _machineService.listForUser(user.uid);
      if (!mounted) return;
      setState(() {
        _applyMachines(machines);
        _isLoadingMachines = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMachines = false);
      _showSnackBar('Erro ao carregar maquinas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePending = _visiblePendingEntries();
    return Scaffold(
      appBar: AppBar(title: Text('Executar treino: ${widget.workout.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoadingMachines)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_missingMachineIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Uma ou mais maquinas deste treino nao estao disponiveis. Edite o treino antes de iniciar.',
                style: TextStyle(color: Colors.orange[800]),
              ),
            ),
          if (widget.workout.machineIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Este treino nao possui maquinas cadastradas.'),
            ),
          if (_missingMachineIds.isEmpty &&
              _phase == WorkoutExecutionPhase.warmup)
            _buildWarmupCard()
          else if (_missingMachineIds.isEmpty && _warmupExecution.completed)
            _buildWarmupSummary(),
          if (_missingMachineIds.isEmpty &&
              _phase != WorkoutExecutionPhase.warmup) ...[
            if (visiblePending.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Maquinas pendentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < visiblePending.length; index++)
                _buildExerciseCard(visiblePending[index]),
            ],
            if (_completedEntries.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Maquinas concluidas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final entry in _completedEntries)
                _buildExerciseCard(entry, completedView: true),
            ],
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finishWorkout,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Concluir treino'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupCard() {
    final targetMachines =
        uniqueMachinesByName(_pendingEntries.map((entry) => entry.machine));
    final selectedTarget = _warmupExecution.targetExerciseName;
    final targetWeight = _defaultWeightForExerciseName(selectedTarget);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aquecimento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: targetMachines.any((m) => m.exerciseName == selectedTarget)
                  ? selectedTarget
                  : null,
              decoration: const InputDecoration(
                labelText: 'Maquina utilizada no aquecimento',
              ),
              items: targetMachines
                  .map(
                    (machine) => DropdownMenuItem<String>(
                      value: machine.exerciseName,
                      child: Text(machine.exerciseName),
                    ),
                  )
                  .toList(),
              onChanged: targetMachines.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        final targetEntry = _findPendingTarget(value);
                        _warmupExecution = _warmupExecution.copyWith(
                          targetExerciseId: targetEntry?.machine.exerciseId,
                          targetExerciseName: value,
                        );
                      });
                    },
            ),
            const SizedBox(height: 8),
            _buildSetsSummary(
              _warmupExecution.sets,
              fallbackText: 'Nenhuma serie de aquecimento registrada.',
            ),
            _buildObservationText(_warmupExecution.targetExerciseId),
            Text('Volume: ${_warmupExecution.volume} kg reps'),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Adicionar serie',
                    icon: const Icon(Icons.add),
                    onPressed: selectedTarget == null
                        ? null
                        : () => _openAddSetDialog(
                              title: 'Adicionar serie - Aquecimento',
                              initialWeightKg: targetWeight,
                              defaultRepetitions: 10,
                              currentSets: _warmupExecution.sets,
                              onAdd: (sets) {
                                setState(() {
                                  _warmupExecution = _warmupExecution.copyWith(
                                    sets: sets,
                                  );
                                });
                              },
                            ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('Concluir aquecimento'),
                    onPressed: _completeWarmup,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarmupSummary() {
    final target = _warmupExecution.targetExerciseName ?? 'Nao informado';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aquecimento concluido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Maquina utilizada: $target'),
            _buildObservationText(_warmupExecution.targetExerciseId),
            _buildSetsSummary(
              _warmupExecution.sets,
              fallbackText: 'Sem series registradas.',
            ),
            Text('Volume: ${_warmupExecution.volume} kg reps'),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(
    SessionExerciseEntry entry, {
    bool completedView = false,
  }) {
    final execution = entry.execution;
    final pendingIndex = _pendingEntries.indexWhere(
      (item) => item.originalIndex == entry.originalIndex,
    );
    final canReorder = !completedView &&
        _phase == WorkoutExecutionPhase.remainingExercises &&
        pendingIndex >= 0;
    final skipped = PerceivedEffort.isSkipped(execution.perceivedEffort);
    final config = resolveExerciseConfiguration(machine: entry.machine);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: execution.completed ? Colors.grey[200] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.machine.exerciseName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: execution.completed ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                if (canReorder) ...[
                  IconButton(
                    tooltip: 'Mover para cima',
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: pendingIndex <= 0
                        ? null
                        : () => _movePending(pendingIndex, up: true),
                  ),
                  IconButton(
                    tooltip: 'Mover para baixo',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: pendingIndex >= _pendingEntries.length - 1
                        ? null
                        : () => _movePending(pendingIndex, up: false),
                  ),
                ],
                IconButton(
                  tooltip: 'Editar OBS da Maquina',
                  icon: const Icon(Icons.notes),
                  onPressed: execution.completed
                      ? null
                      : () => _editObservation(entry),
                ),
                IconButton(
                  tooltip: 'Editar configuracao atual',
                  icon: const Icon(Icons.tune),
                  onPressed: execution.completed
                      ? null
                      : () => _editCurrentConfiguration(entry),
                ),
                IconButton(
                  tooltip: 'Adicionar serie',
                  icon: const Icon(Icons.add),
                  onPressed: execution.completed
                      ? null
                      : () => _openAddSetDialog(
                            title:
                                'Adicionar serie - ${entry.machine.exerciseName}',
                            initialWeightKg: config.configuredWeightKg,
                            defaultRepetitions: config.configuredRepetitions,
                            currentSets: execution.sets,
                            onAdd: (updatedSets) {
                              _updatePendingExecution(
                                entry,
                                execution.copyWith(sets: updatedSets),
                              );
                            },
                          ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (skipped)
              Text(
                  'Nao realizado: ${PerceivedEffort.labelFor(execution.perceivedEffort)}'),
            _buildObservationText(entry.machine.exerciseId),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Meta atual: ${config.compactLabel}'),
            ),
            _buildSetsSummary(
              execution.sets,
              fallbackText:
                  'Nenhuma serie registrada. Peso atual: ${formatKg(config.configuredWeightKg)}',
            ),
            Text('Volume: ${execution.volume} kg reps'),
            if (execution.perceivedEffort != null)
              Text(
                  'Percepcao: ${PerceivedEffort.labelFor(execution.perceivedEffort)}'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.flag),
                label: Text(
                  execution.completed
                      ? 'Maquina concluida'
                      : 'Concluir maquina',
                ),
                onPressed:
                    execution.completed ? null : () => _completeExercise(entry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsSummary(
    List<ExerciseSet> sets, {
    required String fallbackText,
  }) {
    if (sets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(fallbackText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Series registradas: ${sets.length}'),
        for (final set in sets)
          Text(
            'Serie ${set.setNumber}: ${set.reps} reps, ${formatKg(set.weightKg)}',
          ),
      ],
    );
  }

  Widget _buildObservationText(String? exerciseId) {
    final id = exerciseId?.trim();
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final observation = _machinesById[id]?.observationText.trim() ?? '';
    if (observation.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('OBS: $observation'),
    );
  }

  List<SessionExerciseEntry> _visiblePendingEntries() {
    if (_phase == WorkoutExecutionPhase.warmupTargetExercise) {
      final target = _warmupExecution.targetExerciseName;
      final targetEntry = _findPendingTarget(target);
      return targetEntry == null ? const [] : [targetEntry];
    }
    if (_phase == WorkoutExecutionPhase.remainingExercises) {
      return _pendingEntries;
    }
    return const [];
  }

  SessionExerciseEntry? _findPendingTarget(String? targetName) {
    if (targetName == null) return null;
    for (final entry in _pendingEntries) {
      if (entry.machine.exerciseName == targetName) return entry;
    }
    return null;
  }

  double _defaultWeightForExerciseName(String? name) {
    final target = _findPendingTarget(name);
    return target?.machine.currentWeightKg ?? 0;
  }

  Future<void> _editObservation(SessionExerciseEntry entry) async {
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }
    final machine = entry.machine;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => ObservationDialog(
        title: 'OBS - ${machine.exerciseName}',
        initialObservation: machine.observationText,
      ),
    );
    if (result == null) return;
    try {
      await _machineService.updateObservation(
        ownerUid: user.uid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        observation: result.trim(),
      );
      if (!mounted) return;
      setState(() {
        _replaceMachine(machine.copyWith(observation: result.trim()));
      });
      _showSnackBar('OBS atualizada.');
    } catch (_) {
      _showSnackBar('Erro ao salvar OBS. Tente novamente.');
    }
  }

  Future<void> _editCurrentConfiguration(SessionExerciseEntry entry) async {
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }
    final machine = entry.machine;
    final result = await showMachineConfigurationDialog(
      context,
      machine: machine,
      exerciseName: machine.exerciseName,
      requireComplete: true,
    );
    if (result == null) return;
    try {
      await _machineService.ensureMachine(
        ownerUid: user.uid,
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
        observation: result.observation,
        currentSets: result.currentSets,
        currentRepetitions: result.currentRepetitions,
        currentWeightKg: result.currentWeightKg,
      );
      if (!mounted) return;
      setState(() {
        _replaceMachine(
          machine.copyWith(
            currentSets: result.currentSets,
            currentRepetitions: result.currentRepetitions,
            currentWeightKg: result.currentWeightKg,
            observation: result.observation,
          ),
        );
      });
      _showSnackBar('Configuracao atualizada.');
    } catch (_) {
      _showSnackBar('Erro ao salvar configuracao.');
    }
  }

  void _replaceMachine(MachineProfile machine) {
    _machinesById[machine.exerciseId] = machine;
    _pendingEntries = [
      for (final entry in _pendingEntries)
        entry.machine.exerciseId == machine.exerciseId
            ? entry.copyWith(
                machine: machine,
                execution: entry.execution.copyWith(
                  configuredSets: machine.currentSets,
                  configuredRepetitions: machine.currentRepetitions,
                  configuredWeightKg: machine.currentWeightKg,
                  observationSnapshot: machine.observationText,
                ),
              )
            : entry,
    ];
  }

  Future<void> _openAddSetDialog({
    required String title,
    required double initialWeightKg,
    required int defaultRepetitions,
    required List<ExerciseSet> currentSets,
    required ValueChanged<List<ExerciseSet>> onAdd,
  }) async {
    final lastSet = currentSets.isNotEmpty ? currentSets.last : null;
    final formKey = GlobalKey<FormState>();
    final repsController = TextEditingController(
      text: (lastSet?.reps ?? defaultRepetitions).toString(),
    );
    final weightController = TextEditingController(
      text: formatCompactNumber(lastSet?.weightKg ?? initialWeightKg),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Repeticoes'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Informe um numero valido'
                        : null;
                  },
                ),
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                  validator: (value) =>
                      parsePositiveDecimal(value ?? '') == null
                          ? 'Informe um numero valido'
                          : null,
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
                  onAdd([
                    ...currentSets,
                    ExerciseSet(
                      setNumber: currentSets.length + 1,
                      reps: int.parse(repsController.text),
                      weightKg: double.parse(
                        weightController.text.replaceAll(',', '.'),
                      ),
                    ),
                  ]);
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

  void _completeWarmup() {
    if (_warmupExecution.targetExerciseName == null) {
      _showSnackBar('Selecione a maquina do aquecimento.');
      return;
    }
    if (_warmupExecution.sets.isEmpty) {
      _showSnackBar('Registre pelo menos uma serie de aquecimento.');
      return;
    }
    if (_findPendingTarget(_warmupExecution.targetExerciseName) == null) {
      _showSnackBar('Maquina do aquecimento nao encontrada no treino.');
      return;
    }
    setState(() {
      _warmupExecution = _warmupExecution.copyWith(completed: true);
      _phase = WorkoutExecutionPhase.warmupTargetExercise;
    });
  }

  Future<void> _completeExercise(SessionExerciseEntry entry) async {
    final execution = entry.execution;
    String? selectedEffort = execution.perceivedEffort;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Percepcao de esforco'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: PerceivedEffort.options
                      .map(
                        (option) => RadioListTile<String>(
                          title: Text(option.label),
                          value: option.value,
                          groupValue: selectedEffort,
                          onChanged: (value) {
                            setDialogState(() => selectedEffort = value);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: selectedEffort == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(selectedEffort),
                  child: const Text('Concluir maquina'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    if (execution.sets.isEmpty && !PerceivedEffort.allowsEmptySets(result)) {
      _showSnackBar('Registre pelo menos uma serie para essa percepcao.');
      return;
    }

    final pendingIndex = _pendingEntries.indexWhere(
      (item) => item.originalIndex == entry.originalIndex,
    );
    if (pendingIndex < 0) return;
    setState(() {
      final moved = moveEntryToCompleted(
        _pendingEntries,
        _completedEntries,
        pendingIndex,
        execution.copyWith(perceivedEffort: result, completed: true),
      );
      _pendingEntries = moved.pending;
      _completedEntries
        ..clear()
        ..addAll(moved.completed);
      if (_phase == WorkoutExecutionPhase.warmupTargetExercise) {
        _phase = _pendingEntries.isEmpty
            ? WorkoutExecutionPhase.finished
            : WorkoutExecutionPhase.remainingExercises;
      } else if (_pendingEntries.isEmpty) {
        _phase = WorkoutExecutionPhase.finished;
      }
    });
  }

  void _movePending(int pendingIndex, {required bool up}) {
    setState(() {
      _pendingEntries = up
          ? movePendingUp(_pendingEntries, pendingIndex)
          : movePendingDown(_pendingEntries, pendingIndex);
    });
  }

  void _updatePendingExecution(
    SessionExerciseEntry entry,
    ExerciseExecution execution,
  ) {
    setState(() {
      _pendingEntries = [
        for (final current in _pendingEntries)
          current.originalIndex == entry.originalIndex
              ? current.copyWith(execution: execution)
              : current,
      ];
    });
  }

  Future<void> _finishWorkout() async {
    if (_isSaving) return;
    if (_missingMachineIds.isNotEmpty) {
      _showSnackBar('Edite o treino antes de iniciar.');
      return;
    }
    final hasRegisteredSets = _warmupExecution.sets.isNotEmpty ||
        _completedEntries.any((entry) => entry.execution.sets.isNotEmpty) ||
        _pendingEntries.any((entry) => entry.execution.sets.isNotEmpty);
    if (!hasRegisteredSets) {
      _showSnackBar('Registre pelo menos uma serie.');
      return;
    }
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }

    setState(() => _isSaving = true);
    final exercisesForSession = buildSessionExerciseOrder(
      warmup: _warmupExecution,
      completed: _completedEntries,
      pending: _pendingEntries,
    );
    final session = WorkoutSession(
      id: (_sessionRef ??= _machineService.newSessionRef()).id,
      workoutId: widget.workout.id ?? '',
      workoutName: widget.workout.name,
      ownerUid: user.uid,
      startAt: _startAt,
      endAt: DateTime.now(),
      performedAt: DateTime.now(),
      exercises: exercisesForSession,
    );
    final completions = <MachineCompletion>[];
    final completionEvents = <MachineCompletionEventInput>[];
    for (final execution in exercisesForSession) {
      final id = execution.exerciseId?.trim();
      if (id == null || id.isEmpty) continue;
      final machine = _machinesById[id];
      if (shouldCreateMachineCompletionEvent(execution) && machine != null) {
        completionEvents.add(
          MachineCompletionEventInput(
            exerciseId: id,
            exerciseName: machine.exerciseName,
            category: machine.category,
            execution: execution,
          ),
        );
      }
      if (!shouldCountMachineCompletion(execution)) continue;
      completions.add(
        MachineCompletion(
          exerciseId: id,
          exerciseName: machine?.exerciseName ?? execution.exerciseName,
          category: machine?.category ?? '',
        ),
      );
    }

    try {
      await _machineService.saveSessionAndApplyMachineCounts(
        sessionRef: _sessionRef,
        sessionData: session.toMap(),
        ownerUid: user.uid,
        completions: completions,
        completionEvents: completionEvents,
      );
      if (!mounted) return;
      _phase = WorkoutExecutionPhase.finished;
      _showSnackBar('Treino salvo no historico!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Erro ao salvar treino. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  User? _currentUserOrNull() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
