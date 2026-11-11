import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/appearance/retro/retro_colors.dart';
import '../app/appearance/retro/retro_metrics.dart';
import '../components/observation_dialog.dart';
import '../models/machine_event.dart';
import '../models/machine_configuration.dart';
import '../models/machine_history.dart';
import '../models/machine_catalog_item.dart';
import '../models/machine_catalog_view.dart';
import '../models/workout.dart';
import '../models/workout_execution_flow.dart';
import '../models/workout_machine_resolution.dart';
import '../models/workout_session.dart';
import '../services/machine_history_service.dart';
import '../services/machine_catalog_service.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  const WorkoutExecutionScreen({
    super.key,
    required this.workout,
    this.machines,
    this.initialSession,
  });

  final Workout workout;
  final List<MachineProfile>? machines;
  final WorkoutSession? initialSession;

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen>
    with WidgetsBindingObserver {
  final MachineService _machineService = const MachineService();
  final MachineCatalogService _catalogService = MachineCatalogService();
  final Map<String, MachineProfile> _machinesById = {};
  final Map<String, List<MachineEvent>> _eventsByExerciseId = {};
  final List<StreamSubscription<List<MachineEvent>>> _eventSubscriptions = [];
  late DateTime _startAt;
  late ExerciseExecution _warmupExecution;
  List<SessionExerciseEntry> _sessionEntries = const [];
  int? _activeOriginalIndex;
  dynamic _sessionRef;
  WorkoutExecutionPhase _phase = WorkoutExecutionPhase.warmup;
  bool _isLoadingMachines = false;
  bool _isSaving = false;
  bool _isCompletingExercise = false;
  bool _isAddingExercise = false;
  bool _hasPendingAutosave = false;
  bool _isAutosaving = false;
  Object? _autosaveError;
  Timer? _autosaveDebounce;
  List<String> _missingMachineIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAt = widget.initialSession?.startAt ?? DateTime.now();
    _warmupExecution = createWarmupExecution();
    if (widget.machines == null) {
      _loadMachines();
    } else {
      _applyMachines(widget.machines!);
    }
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    for (final subscription in _eventSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_flushAutosave());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_flushAutosave());
    }
  }

  void _applyMachines(List<MachineProfile> machines) {
    _machinesById
      ..clear()
      ..addEntries(
        machines.map((machine) => MapEntry(machine.exerciseId, machine)),
      );
    _missingMachineIds = missingMachineIds(widget.workout, _machinesById);
    _sessionEntries = _missingMachineIds.isEmpty
        ? createPendingEntriesFromMachines(
            resolveWorkoutMachines(widget.workout, _machinesById),
          )
        : const [];
    _restoreInitialSessionIfAvailable();
    _watchMachineEvents(machines);
    if (_sessionEntries.isEmpty) {
      _phase = WorkoutExecutionPhase.choosingNextExercise;
    } else if (_sessionEntries.length == 1) {
      final target = _sessionEntries.single.machine;
      _warmupExecution = _warmupExecution.copyWith(
        targetExerciseId: target.exerciseId,
        targetExerciseName: target.exerciseName,
      );
    }
    _scheduleAutosave(immediate: true);
  }

  void _watchMachineEvents(List<MachineProfile> machines) {
    final user = _currentUserOrNull();
    if (user == null || _eventSubscriptions.isNotEmpty) return;
    for (final machine in machines) {
      _watchEventsFor(user.uid, machine);
    }
  }

  void _watchEventsFor(String ownerUid, MachineProfile machine) {
    _eventSubscriptions.add(
      _machineService
          .watchEvents(
        ownerUid: ownerUid,
        exerciseId: machine.exerciseId,
      )
          .listen(
        (events) {
          if (!mounted) return;
          setState(() => _eventsByExerciseId[machine.exerciseId] = events);
        },
        onError: (_) {},
      ),
    );
  }

  void _restoreInitialSessionIfAvailable() {
    final session = widget.initialSession;
    if (session == null || !session.isInProgress || session.exercises.isEmpty) {
      return;
    }
    if (session.id != null) {
      _sessionRef ??= _machineService.newSessionRef().parent.doc(session.id);
    }
    final restoredWarmup = session.exercises.firstWhere(
      (execution) => execution.isWarmup,
      orElse: () => createWarmupExecution(),
    );
    _warmupExecution = restoredWarmup;
    final executionsById = {
      for (final execution in session.exercises)
        if (!execution.isWarmup && (execution.exerciseId ?? '').isNotEmpty)
          execution.exerciseId!: execution,
    };
    _sessionEntries = [
      for (final entry in _sessionEntries)
        entry.copyWith(
          execution:
              executionsById[entry.machine.exerciseId] ?? entry.execution,
        ),
    ];
    _phase = _phaseFromStoredValue(session.executionPhase);
    _activeOriginalIndex = session.activeOriginalIndex ??
        _originalIndexForExerciseId(session.activeExerciseId);
  }

  Future<void> _loadMachines() async {
    final user = _currentUserOrNull();
    if (user == null) return;
    setState(() => _isLoadingMachines = true);
    try {
      await _catalogService.importLocalCatalogOnce(user.uid);
      final results = await Future.wait([
        _machineService.listForUser(user.uid),
        _catalogService.listCatalog(),
      ]);
      final machines = resolveProfilesFromCatalog(
        results[0] as List<MachineProfile>,
        indexMachineCatalog(results[1] as dynamic),
        preserveIds: widget.workout.machineIds.toSet(),
      );
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
    final visibleEntries = _visibleEntries();
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_flushAutosave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Executar treino: ${widget.workout.name}'),
          actions: [
            IconButton(
              tooltip: 'Adicionar exercicio',
              icon: const Icon(Icons.playlist_add),
              onPressed: _missingMachineIds.isNotEmpty ||
                      _isSaving ||
                      _isAddingExercise
                  ? null
                  : _addExercise,
            ),
            IconButton(
              tooltip: 'Descartar treino',
              icon: const Icon(Icons.delete_outline),
              onPressed: _abandonWorkout,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoadingMachines)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_autosaveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: const Text('Falha ao salvar progresso.'),
                  actions: [
                    TextButton(
                      onPressed: () => _scheduleAutosave(immediate: true),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
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
            else if (_warmupExecution.completed && _missingMachineIds.isEmpty)
              _WorkoutProgressPanel(
                progress: workoutExerciseProgress(_sessionEntries),
              ),
            if (_missingMachineIds.isEmpty &&
                _phase != WorkoutExecutionPhase.warmup) ...[
              if (_phase == WorkoutExecutionPhase.choosingNextExercise) ...[
                const SizedBox(height: 12),
                const Text(
                  'Escolha o proximo exercicio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (visibleEntries.isEmpty)
                  const Text('Nao ha exercicios validos neste treino.')
                else
                  for (final entry in visibleEntries) _buildExerciseCard(entry),
              ] else if (_phase == WorkoutExecutionPhase.executingExercise) ...[
                const SizedBox(height: 12),
                for (final entry in visibleEntries)
                  _buildExerciseCard(entry, focusedView: true),
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
      ),
    );
  }

  Widget _buildWarmupCard() {
    final targetMachines =
        uniqueMachinesByName(_sessionEntries.map((entry) => entry.machine));
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
              isExpanded: true,
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
                      child: Text(
                        machine.exerciseName,
                        softWrap: true,
                      ),
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
                      _scheduleAutosave();
                    },
            ),
            const SizedBox(height: 8),
            _buildSetsSummary(
              _warmupExecution.sets,
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
                                _scheduleAutosave();
                              },
                            ),
                  ),
                  TextButton(
                    onPressed: _skipWarmup,
                    child: const Text('Pular aquecimento'),
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

  Widget _buildExerciseCard(
    SessionExerciseEntry entry, {
    bool focusedView = false,
  }) {
    final execution = entry.execution;
    final completed = execution.completed;
    final canStart =
        _phase == WorkoutExecutionPhase.choosingNextExercise && !completed;
    final skipped = PerceivedEffort.isSkipped(execution.perceivedEffort);
    final config = resolveExerciseConfiguration(machine: entry.machine);
    final goalReached = execution.isGoalReached;
    final theme = Theme.of(context);
    final isRetro = _isRetroTheme(theme);
    final cardColor = completed
        ? (isRetro
            ? RetroColors.surfaceAlternative
            : theme.colorScheme.surfaceContainerHighest)
        : goalReached
            ? (isRetro
                ? RetroColors.surfaceAlternative
                : theme.colorScheme.primaryContainer)
            : null;
    final borderColor = completed || goalReached
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final cardRadius = isRetro ? RetroMetrics.radius : 8.0;
    final exerciseNameStyle = theme.textTheme.titleMedium?.copyWith(
          color: isRetro ? RetroColors.amberLight : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ) ??
        TextStyle(
          color: isRetro ? RetroColors.amberLight : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        );
    final completedLabelStyle = theme.textTheme.labelLarge?.copyWith(
          color: isRetro ? RetroColors.amberLight : theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ) ??
        TextStyle(
          color: isRetro ? RetroColors.amberLight : theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        );
    final completedContentStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isRetro ? RetroColors.text : theme.colorScheme.onSurface,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: cardColor,
      shape: completed || goalReached
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius),
              side: BorderSide(color: borderColor, width: goalReached ? 2 : 1),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle.merge(
          style: completedContentStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (completed) ...[
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: isRetro
                          ? RetroColors.amberLight
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'STATUS // CONCLUIDO',
                        style: completedLabelStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.machine.exerciseName,
                      style: exerciseNameStyle,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (skipped)
                Text(
                    'Nao realizado: ${PerceivedEffort.labelFor(execution.perceivedEffort)}'),
              _buildObservationText(entry.machine.exerciseId),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Meta atual: ${config.compactLabel}'),
              ),
              _buildLatestIncreaseText(entry.machine),
              if (goalReached && !completed) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: isRetro
                          ? RetroColors.amberLight
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'META ALCANCADA',
                        style: completedLabelStyle,
                      ),
                    ),
                  ],
                ),
              ],
              _buildSetsSummary(execution.sets),
              if (execution.perceivedEffort != null)
                Text(
                    'Percepcao: ${PerceivedEffort.labelFor(execution.perceivedEffort)}'),
              if (execution.status == ExerciseExecutionStatus.partial)
                const Text('Status: parcial'),
              if (execution.status == ExerciseExecutionStatus.skipped)
                const Text('Status: nao feito'),
              Align(
                alignment: Alignment.centerRight,
                child: focusedView
                    ? _buildFocusedControls(entry, config)
                    : ElevatedButton.icon(
                        icon: Icon(completed ? Icons.check : Icons.play_arrow),
                        label: Text(
                          completed
                              ? 'Exercicio concluido'
                              : 'Iniciar exercicio',
                        ),
                        onPressed:
                            canStart ? () => _startExercise(entry) : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRetroTheme(ThemeData theme) {
    return theme.colorScheme.surface == RetroColors.surface &&
        theme.colorScheme.primary == RetroColors.amber;
  }

  Widget _buildFocusedControls(
    SessionExerciseEntry entry,
    ResolvedExerciseConfiguration config,
  ) {
    final execution = entry.execution;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Adicionar serie'),
          onPressed: execution.completed
              ? null
              : () => _openAddSetDialog(
                    title: 'Adicionar serie - ${entry.machine.exerciseName}',
                    initialWeightKg: config.configuredWeightKg,
                    defaultRepetitions: config.configuredRepetitions,
                    currentSets: execution.sets,
                    onAdd: (updatedSets) {
                      _updateEntryExecution(
                        entry,
                        execution.copyWith(sets: updatedSets),
                      );
                    },
                  ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.notes),
              label: const Text('OBS'),
              onPressed:
                  execution.completed ? null : () => _editObservation(entry),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(56, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.flag),
          label: const Text('Concluir exercicio'),
          onPressed: execution.completed || _isCompletingExercise
              ? null
              : () => _completeExercise(entry),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
    );
  }

  Widget _buildSetsSummary(
    List<ExerciseSet> sets,
  ) {
    if (sets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final set in sets)
          Text(
            'Serie ${set.setNumber}: ${set.reps} reps, ${formatKg(set.weightKg)}',
          ),
      ],
    );
  }

  Widget _buildLatestIncreaseText(MachineProfile machine) {
    final events = _eventsByExerciseId[machine.exerciseId];
    final text = formatLatestMachineModification(
      latestMachineModification(events ?? const []),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, softWrap: true),
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

  List<SessionExerciseEntry> _visibleEntries() {
    if (_phase == WorkoutExecutionPhase.executingExercise) {
      final activeIndex = _activeOriginalIndex;
      if (activeIndex == null) return const [];
      final active = _entryByOriginalIndex(activeIndex);
      return active == null ? const [] : [active];
    }
    if (_phase == WorkoutExecutionPhase.choosingNextExercise ||
        _phase == WorkoutExecutionPhase.completed) {
      return _sessionEntries;
    }
    return const [];
  }

  SessionExerciseEntry? _findPendingTarget(String? targetName) {
    if (targetName == null) return null;
    for (final entry in _sessionEntries) {
      if (!entry.execution.completed &&
          entry.machine.exerciseName == targetName) {
        return entry;
      }
    }
    return null;
  }

  SessionExerciseEntry? _entryByOriginalIndex(int originalIndex) {
    for (final entry in _sessionEntries) {
      if (entry.originalIndex == originalIndex) return entry;
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
      _scheduleAutosave();
      _showSnackBar('OBS atualizada.');
    } catch (_) {
      _showSnackBar('Erro ao salvar OBS. Tente novamente.');
    }
  }

  void _replaceMachine(MachineProfile machine) {
    _machinesById[machine.exerciseId] = machine;
    _sessionEntries = [
      for (final entry in _sessionEntries)
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

  Future<void> _addExercise() async {
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }
    final choice = await showDialog<_AddExerciseChoice>(
      context: context,
      builder: (_) => _AddExerciseDialog(
        catalog: _catalogService.listCatalog(),
        excludedIds: {
          for (final entry in _sessionEntries) entry.machine.exerciseId,
        },
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _isAddingExercise = true);
    try {
      final catalogItem = choice.existing ??
          await _catalogService.add(
            uid: user.uid,
            popularName: choice.newName!,
            scientificName: choice.newName!,
            category: choice.newCategory!,
            type: MachineCatalogType.outro,
            origin: machineCatalogOriginQuickAdd,
            scientificNamePending: true,
          );
      var profile =
          await _machineService.getByExerciseId(user.uid, catalogItem.id);
      if (profile == null) {
        await _machineService.ensureMachine(
          ownerUid: user.uid,
          exerciseId: catalogItem.id,
          exerciseName: catalogItem.popularName,
          category: catalogItem.category,
        );
        profile =
            await _machineService.getByExerciseId(user.uid, catalogItem.id);
      }
      if (profile == null) throw StateError('Perfil nao criado');
      final machine = resolveProfilesFromCatalog(
        [profile],
        {catalogItem.id: catalogItem},
        preserveIds: {catalogItem.id},
      ).single;
      if (!mounted) return;
      setState(() {
        _machinesById[machine.exerciseId] = machine;
        _sessionEntries = appendPendingEntry(_sessionEntries, machine);
        if (_phase == WorkoutExecutionPhase.completed) {
          _phase = WorkoutExecutionPhase.choosingNextExercise;
        }
      });
      _watchEventsFor(user.uid, machine);
      _scheduleAutosave(immediate: true);
      _showSnackBar('${machine.exerciseName} adicionado ao treino.');
    } on MachineCatalogDuplicateException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Erro ao adicionar exercicio. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isAddingExercise = false);
    }
  }

  Future<void> _openAddSetDialog({
    required String title,
    required double initialWeightKg,
    required int defaultRepetitions,
    required List<ExerciseSet> currentSets,
    required ValueChanged<List<ExerciseSet>> onAdd,
  }) async {
    final lastSet = currentSets.isNotEmpty ? currentSets.last : null;
    var reps = lastSet?.reps ?? defaultRepetitions;
    var weightKg = lastSet?.weightKg ?? initialWeightKg;
    if (reps < 0) reps = 0;
    if (weightKg < 0) weightKg = 0;
    var isRegistering = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void updateWeight(double delta) {
              if (!Navigator.of(dialogContext).mounted) return;
              setDialogState(() {
                weightKg = (weightKg + delta).clamp(0, double.maxFinite);
              });
            }

            void updateReps(int delta) {
              if (!Navigator.of(dialogContext).mounted) return;
              setDialogState(() {
                reps = (reps + delta).clamp(0, 9999);
              });
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SetStepper(
                    label: 'Peso',
                    value: '${formatCompactNumber(weightKg)} kg',
                    decrementTooltip: 'Diminuir peso',
                    incrementTooltip: 'Aumentar peso',
                    onDecrement: weightKg <= 0 ? null : () => updateWeight(-1),
                    onIncrement: () => updateWeight(1),
                  ),
                  const SizedBox(height: 16),
                  _SetStepper(
                    label: 'Repeticoes',
                    value: reps.toString(),
                    decrementTooltip: 'Diminuir repeticoes',
                    incrementTooltip: 'Aumentar repeticoes',
                    onDecrement: reps <= 0 ? null : () => updateReps(-1),
                    onIncrement: () => updateReps(1),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isRegistering
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isRegistering || reps <= 0
                      ? null
                      : () {
                          setDialogState(() => isRegistering = true);
                          onAdd([
                            ...currentSets,
                            ExerciseSet(
                              setNumber: currentSets.length + 1,
                              reps: reps,
                              weightKg: weightKg,
                            ),
                          ]);
                          Navigator.of(dialogContext).pop();
                        },
                  child: isRegistering
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Adicionar'),
                ),
              ],
            );
          },
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
      final firstPendingIndex = firstPendingEntryIndex(_sessionEntries);
      if (firstPendingIndex < 0) {
        _phase = WorkoutExecutionPhase.choosingNextExercise;
        _activeOriginalIndex = null;
      } else {
        _activeOriginalIndex = _sessionEntries[firstPendingIndex].originalIndex;
        _phase = WorkoutExecutionPhase.executingExercise;
      }
    });
    _scheduleAutosave(immediate: true);
  }

  void _skipWarmup() {
    setState(() {
      _warmupExecution = createWarmupExecution(completed: true).copyWith(
        status: ExerciseExecutionStatus.skipped,
      );
      _activeOriginalIndex = null;
      _phase = WorkoutExecutionPhase.choosingNextExercise;
    });
    _scheduleAutosave(immediate: true);
  }

  Future<void> _completeExercise(SessionExerciseEntry entry) async {
    if (_isCompletingExercise || entry.execution.completed) return;
    setState(() => _isCompletingExercise = true);
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
    if (!mounted) return;
    setState(() => _isCompletingExercise = false);
    if (result == null) return;
    if (execution.sets.isEmpty && !PerceivedEffort.allowsEmptySets(result)) {
      _showSnackBar('Registre pelo menos uma serie para essa percepcao.');
      return;
    }

    if (_entryByOriginalIndex(entry.originalIndex)?.execution.completed ??
        true) {
      return;
    }
    setState(() {
      _sessionEntries = replaceEntryExecution(
        _sessionEntries,
        entry.originalIndex,
        execution.copyWith(
          perceivedEffort: result,
          completed: true,
          status: ExerciseExecutionStatus.completed,
        ),
      );
      _activeOriginalIndex = null;
      _phase = firstPendingEntryIndex(_sessionEntries) < 0
          ? WorkoutExecutionPhase.completed
          : WorkoutExecutionPhase.choosingNextExercise;
    });
    _scheduleAutosave(immediate: true);
  }

  void _startExercise(SessionExerciseEntry entry) {
    if (entry.execution.completed) return;
    setState(() {
      _activeOriginalIndex = entry.originalIndex;
      _phase = WorkoutExecutionPhase.executingExercise;
    });
    _scheduleAutosave(immediate: true);
  }

  void _updateEntryExecution(
    SessionExerciseEntry entry,
    ExerciseExecution execution,
  ) {
    setState(() {
      _sessionEntries = [
        for (final current in _sessionEntries)
          current.originalIndex == entry.originalIndex
              ? current.copyWith(execution: execution)
              : current,
      ];
    });
    _scheduleAutosave();
  }

  Future<void> _finishWorkout() async {
    if (_isSaving) return;
    if (_missingMachineIds.isNotEmpty) {
      _showSnackBar('Edite o treino antes de iniciar.');
      return;
    }
    if (!_warmupExecution.completed) {
      _showSnackBar('Conclua o aquecimento antes de encerrar.');
      return;
    }
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }
    final entriesForSave = await _entriesForWorkoutFinish();
    if (entriesForSave == null) return;

    setState(() {
      _isSaving = true;
      _phase = WorkoutExecutionPhase.finishingWorkout;
    });
    final exercisesForSession = buildSessionExerciseOrder(
      warmup: _warmupExecution,
      entries: entriesForSave,
    );
    _autosaveDebounce?.cancel();
    _hasPendingAutosave = false;
    final finishedAt = DateTime.now();
    final session = _buildSessionSnapshot(
      ownerUid: user.uid,
      status: WorkoutSessionStatus.completed,
      endAt: finishedAt,
      performedAt: finishedAt,
      completedAt: finishedAt,
    );
    final sessionData = {
      ...session.toMap(),
      'exercises': exercisesForSession.map((e) => e.toMap()).toList(),
      'executionPhase': 'completed',
      'status': WorkoutSessionStatus.completed,
      'completedAt': Timestamp.fromDate(finishedAt),
      'performedAt': Timestamp.fromDate(finishedAt),
      'endAt': Timestamp.fromDate(finishedAt),
    };
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
        sessionData: sessionData,
        ownerUid: user.uid,
        completions: completions,
        completionEvents: completionEvents,
      );
      if (!mounted) return;
      _phase = WorkoutExecutionPhase.completed;
      _showSnackBar('Treino salvo no historico!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = firstPendingEntryIndex(_sessionEntries) < 0
            ? WorkoutExecutionPhase.completed
            : WorkoutExecutionPhase.choosingNextExercise;
      });
      _showSnackBar('Erro ao salvar treino. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<SessionExerciseEntry>?> _entriesForWorkoutFinish() async {
    final incomplete = _sessionEntries.where((entry) {
      return classifyExerciseExecution(entry.execution) !=
          SessionExerciseCompletionState.completed;
    }).toList(growable: false);
    if (incomplete.isNotEmpty) {
      final shouldFinish = await _confirmFinishIncomplete(incomplete);
      if (shouldFinish != true) return null;
    }
    final entries = [
      for (final entry in _sessionEntries)
        entry.copyWith(execution: _executionForForcedFinish(entry.execution)),
    ];
    setState(() {
      _sessionEntries = entries;
      _activeOriginalIndex = null;
    });
    _scheduleAutosave(immediate: true);
    return entries;
  }

  ExerciseExecution _executionForForcedFinish(ExerciseExecution execution) {
    if (classifyExerciseExecution(execution) ==
        SessionExerciseCompletionState.completed) {
      return execution;
    }
    if (execution.sets.isEmpty) {
      return execution.copyWith(
        completed: true,
        status: ExerciseExecutionStatus.skipped,
      );
    }
    return execution.copyWith(
      completed: true,
      status: ExerciseExecutionStatus.partial,
    );
  }

  Future<bool?> _confirmFinishIncomplete(
    List<SessionExerciseEntry> incomplete,
  ) {
    final partial = incomplete
        .where((entry) =>
            classifyExerciseExecution(entry.execution) ==
            SessionExerciseCompletionState.partial)
        .toList(growable: false);
    final notDone = incomplete
        .where((entry) =>
            classifyExerciseExecution(entry.execution) ==
            SessionExerciseCompletionState.notDone)
        .toList(growable: false);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exercicios incompletos'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Existem exercicios incompletos neste treino.'),
              if (partial.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Parciais (${partial.length})'),
                for (final entry in partial.take(4))
                  Text('- ${entry.machine.exerciseName}'),
              ],
              if (notDone.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Nao feitos (${notDone.length})'),
                for (final entry in notDone.take(4))
                  Text('- ${entry.machine.exerciseName}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar ao treino'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : () => Navigator.of(ctx).pop(true),
            child: const Text('Encerrar treino mesmo assim'),
          ),
        ],
      ),
    );
  }

  Future<void> _abandonWorkout() async {
    final user = _currentUserOrNull();
    if (user == null) {
      _showSnackBar('Usuario nao autenticado.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar treino?'),
        content:
            const Text('O treino em andamento sera marcado como abandonado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      _autosaveDebounce?.cancel();
      _hasPendingAutosave = false;
      final ref = _sessionRef ??= _machineService.newSessionRef();
      await _machineService.saveInProgressSession(
        sessionRef: ref,
        session: _buildSessionSnapshot(ownerUid: user.uid),
      );
      await _machineService.abandonSession(
        sessionId: ref.id,
        ownerUid: user.uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showSnackBar('Erro ao descartar treino.');
    }
  }

  WorkoutExecutionPhase _phaseFromStoredValue(String value) {
    switch (value) {
      case 'executingExercise':
        return WorkoutExecutionPhase.executingExercise;
      case 'choosingNextExercise':
        return WorkoutExecutionPhase.choosingNextExercise;
      case 'finishingWorkout':
        return WorkoutExecutionPhase.choosingNextExercise;
      case 'completed':
        return WorkoutExecutionPhase.completed;
      case 'warmup':
      default:
        return WorkoutExecutionPhase.warmup;
    }
  }

  String _phaseToStoredValue() {
    switch (_phase) {
      case WorkoutExecutionPhase.warmup:
        return 'warmup';
      case WorkoutExecutionPhase.executingExercise:
        return 'executingExercise';
      case WorkoutExecutionPhase.choosingNextExercise:
        return 'choosingNextExercise';
      case WorkoutExecutionPhase.finishingWorkout:
        return 'finishingWorkout';
      case WorkoutExecutionPhase.completed:
        return 'completed';
    }
  }

  int? _originalIndexForExerciseId(String? exerciseId) {
    if (exerciseId == null || exerciseId.trim().isEmpty) return null;
    for (final entry in _sessionEntries) {
      if (entry.machine.exerciseId == exerciseId) return entry.originalIndex;
    }
    return null;
  }

  String? _activeExerciseId() {
    final active = _activeOriginalIndex;
    if (active == null) return null;
    return _entryByOriginalIndex(active)?.machine.exerciseId;
  }

  WorkoutSession _buildSessionSnapshot({
    required String ownerUid,
    String status = WorkoutSessionStatus.inProgress,
    DateTime? endAt,
    DateTime? performedAt,
    DateTime? completedAt,
  }) {
    return WorkoutSession(
      id: (_sessionRef ??= _machineService.newSessionRef()).id,
      workoutId: widget.workout.id ?? '',
      workoutName: widget.workout.name,
      ownerUid: ownerUid,
      startAt: _startAt,
      endAt: endAt,
      performedAt: performedAt,
      completedAt: completedAt,
      exercises: buildSessionExerciseOrder(
        warmup: _warmupExecution,
        entries: _sessionEntries,
      ),
      status: status,
      executionPhase: _phaseToStoredValue(),
      activeExerciseId: _activeExerciseId(),
      activeOriginalIndex: _activeOriginalIndex,
    );
  }

  void _scheduleAutosave({bool immediate = false}) {
    if (_missingMachineIds.isNotEmpty ||
        _phase == WorkoutExecutionPhase.completed ||
        _phase == WorkoutExecutionPhase.finishingWorkout) {
      return;
    }
    final user = _currentUserOrNull();
    if (user == null) return;
    _hasPendingAutosave = true;
    _autosaveDebounce?.cancel();
    if (immediate) {
      unawaited(_flushAutosave());
      return;
    }
    _autosaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_flushAutosave());
    });
  }

  Future<void> _flushAutosave() async {
    if (!_hasPendingAutosave || _isAutosaving) return;
    final user = _currentUserOrNull();
    if (user == null) return;
    _autosaveDebounce?.cancel();
    _hasPendingAutosave = false;
    _isAutosaving = true;
    try {
      await _machineService.saveInProgressSession(
        sessionRef: _sessionRef ??= _machineService.newSessionRef(),
        session: _buildSessionSnapshot(ownerUid: user.uid),
      );
      if (!mounted) return;
      setState(() => _autosaveError = null);
    } catch (error) {
      _hasPendingAutosave = true;
      if (!mounted) return;
      setState(() => _autosaveError = error);
    } finally {
      _isAutosaving = false;
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

class _AddExerciseChoice {
  const _AddExerciseChoice.existing(MachineCatalogItem this.existing)
      : newName = null,
        newCategory = null;

  const _AddExerciseChoice.create(String this.newName, String this.newCategory)
      : existing = null;

  final MachineCatalogItem? existing;
  final String? newName;
  final String? newCategory;
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog({
    required this.catalog,
    required this.excludedIds,
  });

  final Future<List<MachineCatalogItem>> catalog;
  final Set<String> excludedIds;

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  String _query = '';
  String? _newCategory;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar exercicio'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<MachineCatalogItem>>(
          future: widget.catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Erro ao carregar catalogo.');
            }
            final catalog = snapshot.data;
            if (catalog == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildContent(catalog);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildContent(List<MachineCatalogItem> catalog) {
    final name = _query.trim();
    final normalizedName = normalizeCatalogText(name);
    final matches = filterAndSortMachineCatalog(
      combineMachineCatalog(catalog, const []),
      query: name,
      status: MachineCatalogStatus.active,
    ).where((item) => !widget.excludedIds.contains(item.catalog.id)).take(20);
    final nameExists = catalog.any((item) =>
        normalizeCatalogText(item.popularName) == normalizedName ||
        normalizeCatalogText(item.scientificName) == normalizedName);
    final canCreate = validateCatalogName(name) == null && !nameExists;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Buscar ou digitar nome',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in matches)
                ListTile(
                  title: Text(item.popularName),
                  subtitle: Text(MachineCatalogCategory.label(item.category)),
                  onTap: () => Navigator.of(context)
                      .pop(_AddExerciseChoice.existing(item.catalog)),
                ),
            ],
          ),
        ),
        if (canCreate) ...[
          const Divider(),
          Text('Novo exercicio: "$name"'),
          DropdownButtonFormField<String>(
            value: _newCategory,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final category in MachineCatalogCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(MachineCatalogCategory.label(category)),
                ),
            ],
            onChanged: (value) => setState(() => _newCategory = value),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Criar e adicionar'),
            onPressed: _newCategory == null
                ? null
                : () => Navigator.of(context)
                    .pop(_AddExerciseChoice.create(name, _newCategory!)),
          ),
        ],
      ],
    );
  }
}

class _SetStepper extends StatelessWidget {
  const _SetStepper({
    required this.label,
    required this.value,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final String decrementTooltip;
  final String incrementTooltip;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepperButton(
              label: '-',
              tooltip: decrementTooltip,
              onPressed: onDecrement,
            ),
            Expanded(
              child: Center(
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            _StepperButton(
              label: '+',
              tooltip: incrementTooltip,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutProgressPanel extends StatelessWidget {
  const _WorkoutProgressPanel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = progress.clamp(0, 1).toDouble();
    final percentage = (value * 100).round();
    final borderColor = theme.colorScheme.outline;
    final fillColor = theme.colorScheme.primary;

    return Card(
      key: const Key('workout-progress-panel'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROGRESSO DO TREINO',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const segmentCount = 10;
                      return Row(
                        children: [
                          for (var index = 0;
                              index < segmentCount;
                              index++) ...[
                            if (index > 0) const SizedBox(width: 2),
                            Expanded(
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (value * segmentCount - index)
                                      .clamp(0, 1)
                                      .toDouble(),
                                  heightFactor: 1,
                                  child: ColoredBox(color: fillColor),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '$percentage%',
                    key: const Key('workout-progress-percentage'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fillColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 52,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
