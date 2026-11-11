import 'machine_history.dart';
import 'workout_session.dart';

enum WorkoutExecutionPhase {
  warmup,
  executingExercise,
  choosingNextExercise,
  finishingWorkout,
  completed,
}

enum SessionExerciseCompletionState {
  completed,
  partial,
  notDone,
}

class SessionExerciseEntry {
  final int originalIndex;
  final MachineProfile machine;
  final ExerciseExecution execution;

  const SessionExerciseEntry({
    required this.originalIndex,
    required this.machine,
    required this.execution,
  });

  SessionExerciseEntry copyWith({
    MachineProfile? machine,
    ExerciseExecution? execution,
  }) {
    return SessionExerciseEntry(
      originalIndex: originalIndex,
      machine: machine ?? this.machine,
      execution: execution ?? this.execution,
    );
  }
}

double workoutExerciseProgress(Iterable<SessionExerciseEntry> entries) {
  final canonicalEntries = entries.toList();
  if (canonicalEntries.isEmpty) return 0;
  final completed =
      canonicalEntries.where((entry) => entry.execution.completed).length;
  return (completed / canonicalEntries.length).clamp(0, 1).toDouble();
}

ExerciseExecution createWarmupExecution({
  String? targetExerciseId,
  String? targetExerciseName,
  List<ExerciseSet> sets = const [],
  bool completed = false,
}) {
  return ExerciseExecution(
    exerciseName: 'Aquecimento',
    sets: sets,
    completed: completed,
    isWarmup: true,
    targetExerciseId: targetExerciseId,
    targetExerciseName: targetExerciseName,
  );
}

List<SessionExerciseEntry> createPendingEntriesFromMachines(
  Iterable<MachineProfile> machines,
) {
  final orderedMachines = machines.toList();
  return [
    for (var index = 0; index < orderedMachines.length; index++)
      SessionExerciseEntry(
        originalIndex: index,
        machine: orderedMachines[index],
        execution: ExerciseExecution(
          exerciseId: orderedMachines[index].exerciseId,
          exerciseName: orderedMachines[index].exerciseName,
          scientificName: orderedMachines[index].catalogScientificName,
          category: orderedMachines[index].category,
          type: orderedMachines[index].catalogType,
          sets: const [],
          configuredSets: orderedMachines[index].currentSets,
          configuredRepetitions: orderedMachines[index].currentRepetitions,
          configuredWeightKg: orderedMachines[index].currentWeightKg,
          observationSnapshot: orderedMachines[index].observationText,
        ),
      ),
  ];
}

bool shouldCountMachineCompletion(ExerciseExecution execution) {
  if (execution.isWarmup || !execution.completed) return false;
  if (execution.status != ExerciseExecutionStatus.completed) return false;
  if ((execution.exerciseId ?? '').trim().isEmpty) return false;
  final normalizedEffort = PerceivedEffort.normalize(execution.perceivedEffort);
  return normalizedEffort == PerceivedEffort.light ||
      normalizedEffort == PerceivedEffort.adequate ||
      normalizedEffort == PerceivedEffort.highFatigue;
}

Set<String> eligibleMachineCompletionExerciseIds(
  Iterable<ExerciseExecution> executions,
) {
  final ids = <String>{};
  for (final execution in executions) {
    if (shouldCountMachineCompletion(execution)) {
      ids.add(execution.exerciseId!.trim());
    }
  }
  return ids;
}

List<MachineProfile> uniqueMachinesByName(Iterable<MachineProfile> machines) {
  final unique = <MachineProfile>[];
  final seen = <String>{};
  for (final machine in machines) {
    final name = machine.exerciseName.trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    unique.add(machine);
  }
  return unique;
}

List<SessionExerciseEntry> movePendingUp(
  List<SessionExerciseEntry> pending,
  int index,
) {
  if (index <= 0 || index >= pending.length) return List.of(pending);
  if (pending[index].execution.completed) return List.of(pending);
  final updated = List<SessionExerciseEntry>.of(pending);
  final item = updated.removeAt(index);
  updated.insert(index - 1, item);
  return updated;
}

List<SessionExerciseEntry> movePendingDown(
  List<SessionExerciseEntry> pending,
  int index,
) {
  if (index < 0 || index >= pending.length - 1) return List.of(pending);
  if (pending[index].execution.completed) return List.of(pending);
  final updated = List<SessionExerciseEntry>.of(pending);
  final item = updated.removeAt(index);
  updated.insert(index + 1, item);
  return updated;
}

int firstPendingEntryIndex(List<SessionExerciseEntry> entries) {
  return entries.indexWhere((entry) => !entry.execution.completed);
}

SessionExerciseCompletionState classifyExerciseExecution(
  ExerciseExecution execution,
) {
  if (execution.completed &&
      execution.status == ExerciseExecutionStatus.completed) {
    return SessionExerciseCompletionState.completed;
  }
  if (execution.hasRegisteredWork) {
    return SessionExerciseCompletionState.partial;
  }
  if (execution.completed &&
      execution.status == ExerciseExecutionStatus.partial) {
    return SessionExerciseCompletionState.partial;
  }
  return SessionExerciseCompletionState.notDone;
}

List<SessionExerciseEntry> replaceEntryExecution(
  List<SessionExerciseEntry> entries,
  int originalIndex,
  ExerciseExecution execution,
) {
  return [
    for (final entry in entries)
      entry.originalIndex == originalIndex
          ? entry.copyWith(execution: execution)
          : entry,
  ];
}

class CompletedExerciseLists {
  final List<SessionExerciseEntry> pending;
  final List<SessionExerciseEntry> completed;

  const CompletedExerciseLists({
    required this.pending,
    required this.completed,
  });
}

CompletedExerciseLists moveEntryToCompleted(
  List<SessionExerciseEntry> pending,
  List<SessionExerciseEntry> completed,
  int index,
  ExerciseExecution execution,
) {
  if (index < 0 || index >= pending.length) {
    return CompletedExerciseLists(
      pending: List.of(pending),
      completed: List.of(completed),
    );
  }
  final updatedPending = List<SessionExerciseEntry>.of(pending);
  final entry = updatedPending.removeAt(index).copyWith(execution: execution);
  return CompletedExerciseLists(
    pending: updatedPending,
    completed: [...completed, entry],
  );
}

bool completionAllowsCurrentSets(ExerciseExecution execution) {
  if (execution.isWarmup) return execution.sets.isNotEmpty;
  if (PerceivedEffort.allowsEmptySets(execution.perceivedEffort)) return true;
  return execution.sets.isNotEmpty;
}

List<ExerciseExecution> buildSessionExerciseOrder({
  required ExerciseExecution warmup,
  List<SessionExerciseEntry> completed = const [],
  List<SessionExerciseEntry> pending = const [],
  List<SessionExerciseEntry>? entries,
}) {
  return [
    warmup,
    ...(entries ?? [...completed, ...pending]).map((entry) => entry.execution),
  ];
}
