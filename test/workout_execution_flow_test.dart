import 'package:firebased/models/machine_history.dart';
import 'package:firebased/models/workout.dart';
import 'package:firebased/models/workout_execution_flow.dart';
import 'package:firebased/models/workout_machine_resolution.dart';
import 'package:firebased/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final machines = [
    _machine('supino', 'Supino reto', 'Peito', 3, 12, 40),
    _machine('remada', 'Remada baixa', 'Costas', 4, 10, 35),
    _machine('leg', 'Leg press', 'Perna', 3, 12, 80),
  ];

  Workout workout() {
    return Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino', 'remada', 'leg'],
    );
  }

  group('workout execution flow', () {
    test('calculates canonical exercise progress and protects empty workouts',
        () {
      final entries = createPendingEntriesFromMachines([
        _machine('a', 'A', 'C', 1, 1, 1),
        _machine('b', 'B', 'C', 1, 1, 1),
        _machine('c', 'C', 'C', 1, 1, 1),
        _machine('d', 'D', 'C', 1, 1, 1),
      ]);

      List<SessionExerciseEntry> withCompleted(int count) => [
            for (var index = 0; index < entries.length; index++)
              entries[index].copyWith(
                execution: entries[index].execution.copyWith(
                      completed: index < count,
                    ),
              ),
          ];

      expect(workoutExerciseProgress(const []), 0);
      expect(workoutExerciseProgress(withCompleted(0)), 0);
      expect(workoutExerciseProgress(withCompleted(1)), .25);
      expect(workoutExerciseProgress(withCompleted(3)), .75);
      expect(workoutExerciseProgress(withCompleted(4)), 1);
    });

    test('creates warmup as first session item', () {
      final warmup = createWarmupExecution(
        targetExerciseName: 'Supino reto',
        sets: [ExerciseSet(setNumber: 1, reps: 15, weightKg: 10)],
        completed: true,
      );

      expect(warmup.exerciseName, 'Aquecimento');
      expect(warmup.isWarmup, isTrue);
      expect(warmup.targetExerciseName, 'Supino reto');
      expect(warmup.perceivedEffort, isNull);
    });

    test('pending entries follow workout machineIds order and snapshot machine',
        () {
      final resolved = resolveWorkoutMachines(
        workout(),
        {for (final machine in machines) machine.exerciseId: machine},
      );
      final pending = createPendingEntriesFromMachines(resolved);

      expect(pending.map((entry) => entry.machine.exerciseName), [
        'Supino reto',
        'Remada baixa',
        'Leg press',
      ]);
      expect(pending.first.execution.exerciseId, 'supino');
      expect(pending.first.execution.configuredSets, 3);
      expect(pending.first.execution.configuredRepetitions, 12);
      expect(pending.first.execution.configuredWeightKg, 40);
      expect(pending.first.execution.observationSnapshot, 'Banco 4');
    });

    test('pending exercise moves up and down without changing workout order',
        () {
      final originalWorkout = workout();
      final pending = createPendingEntriesFromMachines(machines);

      final movedUp = movePendingUp(pending, 1);
      final movedDown = movePendingDown(movedUp, 0);

      expect(movedUp.map((entry) => entry.machine.exerciseName), [
        'Remada baixa',
        'Supino reto',
        'Leg press',
      ]);
      expect(movedDown.map((entry) => entry.machine.exerciseName), [
        'Supino reto',
        'Remada baixa',
        'Leg press',
      ]);
      expect(originalWorkout.machineIds, ['supino', 'remada', 'leg']);
    });

    test('cannot move first up, last down, or completed pending entry', () {
      final pending = createPendingEntriesFromMachines(machines);
      final completedEntry = pending[1].copyWith(
        execution: pending[1].execution.copyWith(completed: true),
      );
      final withCompleted = [pending[0], completedEntry, pending[2]];

      expect(movePendingUp(pending, 0), pending);
      expect(movePendingDown(pending, 2), pending);
      expect(movePendingUp(withCompleted, 1), withCompleted);
      expect(movePendingDown(withCompleted, 1), withCompleted);
    });

    test('completed exercises keep completion order', () {
      final pending = createPendingEntriesFromMachines(machines);
      final firstMove = moveEntryToCompleted(
        pending,
        const [],
        1,
        pending[1].execution.copyWith(completed: true),
      );
      final secondMove = moveEntryToCompleted(
        firstMove.pending,
        firstMove.completed,
        0,
        firstMove.pending[0].execution.copyWith(completed: true),
      );

      expect(secondMove.completed.map((entry) => entry.machine.exerciseName), [
        'Remada baixa',
        'Supino reto',
      ]);
    });

    test('session order is warmup, completed, then current pending order', () {
      final pending = createPendingEntriesFromMachines(machines);
      final moved = movePendingUp(pending, 2);
      final completedMove = moveEntryToCompleted(
        moved,
        const [],
        1,
        moved[1].execution.copyWith(completed: true),
      );
      final warmup = createWarmupExecution(
        targetExerciseName: 'Supino reto',
        completed: true,
      );

      final sessionOrder = buildSessionExerciseOrder(
        warmup: warmup,
        completed: completedMove.completed,
        pending: completedMove.pending,
      );

      expect(sessionOrder.map((execution) => execution.exerciseName), [
        'Aquecimento',
        'Leg press',
        'Supino reto',
        'Remada baixa',
      ]);
    });

    test('finds first pending entry and classifies incomplete executions', () {
      final entries = createPendingEntriesFromMachines(machines);
      final updated = replaceEntryExecution(
        entries,
        0,
        entries.first.execution.copyWith(
          completed: true,
          perceivedEffort: PerceivedEffort.adequate,
          status: ExerciseExecutionStatus.completed,
        ),
      );

      expect(firstPendingEntryIndex(updated), 1);
      expect(
        classifyExerciseExecution(updated.first.execution),
        SessionExerciseCompletionState.completed,
      );
      expect(
        classifyExerciseExecution(entries[1].execution.copyWith(
          sets: [ExerciseSet(setNumber: 1, reps: 5, weightKg: 10)],
        )),
        SessionExerciseCompletionState.partial,
      );
      expect(
        classifyExerciseExecution(entries[2].execution),
        SessionExerciseCompletionState.notDone,
      );
    });

    test('completion rules distinguish warmup, performed and skipped exercises',
        () {
      expect(
        completionAllowsCurrentSets(createWarmupExecution(completed: true)),
        isFalse,
      );
      expect(
        completionAllowsCurrentSets(ExerciseExecution(
          exerciseName: 'Supino',
          sets: const [],
          perceivedEffort: PerceivedEffort.adequate,
        )),
        isFalse,
      );
      expect(
        completionAllowsCurrentSets(ExerciseExecution(
          exerciseName: 'Supino',
          sets: [ExerciseSet(setNumber: 1, reps: 10, weightKg: 40)],
          perceivedEffort: PerceivedEffort.highFatigue,
        )),
        isTrue,
      );
      expect(
        completionAllowsCurrentSets(ExerciseExecution(
          exerciseName: 'Supino',
          sets: const [],
          perceivedEffort: PerceivedEffort.skippedOther,
        )),
        isTrue,
      );
    });

    test('warmup selector removes duplicate machine names', () {
      final unique = uniqueMachinesByName([
        _machine('supino-1', 'Supino reto', 'Peito', 3, 12, 40),
        _machine('supino-2', 'Supino reto', 'Peito', 3, 12, 45),
        _machine('remada', 'Remada baixa', 'Costas', 4, 10, 35),
      ]);

      expect(unique.map((machine) => machine.exerciseName), [
        'Supino reto',
        'Remada baixa',
      ]);
    });

    test('missing machine references are identified', () {
      final missing = missingMachineIds(
        workout(),
        {'supino': machines.first, 'leg': machines.last},
      );

      expect(missing, ['remada']);
    });
  });
}

MachineProfile _machine(
  String id,
  String name,
  String category,
  int sets,
  int reps,
  double weight,
) {
  return MachineProfile(
    exerciseId: id,
    exerciseName: name,
    category: category,
    ownerUid: 'user-1',
    observation: id == 'supino' ? 'Banco 4' : '',
    currentSets: sets,
    currentRepetitions: reps,
    currentWeightKg: weight,
  );
}
