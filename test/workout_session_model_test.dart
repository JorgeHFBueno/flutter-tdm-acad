import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebased/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutSession', () {
    test('skipped warmup keeps skipped status after round trip', () {
      final warmup = ExerciseExecution(
        exerciseName: 'Aquecimento',
        sets: [],
        completed: true,
        isWarmup: true,
        status: ExerciseExecutionStatus.skipped,
      );

      final restored = ExerciseExecution.fromMap(warmup.toMap());

      expect(restored.isWarmup, isTrue);
      expect(restored.completed, isTrue);
      expect(restored.status, ExerciseExecutionStatus.skipped);
    });

    test('deserializes session for missing original workout', () {
      final session = WorkoutSession.fromMap({
        'workoutId': 'deleted-workout-id',
        'workoutName': 'Treino A',
        'ownerUid': 'user-1',
        'exercises': [
          {
            'exerciseId': 'remada_baixa',
            'exerciseName': 'Remada baixa',
            'sets': [
              {'setNumber': 1, 'reps': 10, 'weightKg': 40}
            ],
            'perceivedEffort': 'certo',
            'completed': true,
          }
        ],
      });

      expect(session.workoutId, 'deleted-workout-id');
      expect(session.workoutName, 'Treino A');
      expect(session.exercises.single.exerciseName, 'Remada baixa');
      expect(session.exercises.single.exerciseId, 'remada_baixa');
      expect(session.exercises.single.sets.single.weightKg, 40);
      expect(session.exercises.single.completed, isTrue);
    });

    test('serializes new execution with exerciseId', () {
      final execution = ExerciseExecution(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        sets: const [],
      );

      final restored = ExerciseExecution.fromMap(execution.toMap());

      expect(restored.exerciseId, 'supino_simples');
      expect(restored.exerciseName, 'Supino Simples');
    });

    test('deserializes old session with empty workoutId', () {
      final session = WorkoutSession.fromMap({
        'workoutName': 'Sessão antiga',
        'ownerUid': 'user-1',
        'exercises': [],
      });

      expect(session.workoutId, '');
      expect(session.exercises, isEmpty);
    });

    test('keeps legacy flat set data accessible', () {
      final execution = ExerciseExecution.fromMap({
        'exerciseName': 'Leg 45°',
        'sets': 2,
        'reps': 12,
        'weightKg': 60.0,
        'completed': false,
      });

      expect(execution.sets.single.setNumber, 2);
      expect(execution.sets.single.reps, 12);
      expect(execution.sets.single.weightKg, 60);
    });

    test('serializes warmup with target exercise and sets', () {
      final execution = ExerciseExecution(
        exerciseName: 'Aquecimento',
        isWarmup: true,
        targetExerciseName: 'Supino reto',
        completed: true,
        sets: [
          ExerciseSet(setNumber: 1, reps: 15, weightKg: 10),
          ExerciseSet(setNumber: 2, reps: 10, weightKg: 20),
        ],
      );

      final map = execution.toMap();

      expect(map['isWarmup'], isTrue);
      expect(map['targetExerciseName'], 'Supino reto');
      expect(map['perceivedEffort'], isNull);
      expect((map['sets'] as List), hasLength(2));
    });

    test('deserializes execution without warmup fields safely', () {
      final execution = ExerciseExecution.fromMap({
        'exerciseName': 'Remada baixa',
        'sets': [],
      });

      expect(execution.isWarmup, isFalse);
      expect(execution.targetExerciseName, isNull);
      expect(execution.status, ExerciseExecutionStatus.pending);
    });

    test('serializes partial and skipped exercise statuses', () {
      final partial = ExerciseExecution(
        exerciseId: 'supino',
        exerciseName: 'Supino',
        sets: [ExerciseSet(setNumber: 1, reps: 6, weightKg: 30)],
        completed: true,
        status: ExerciseExecutionStatus.partial,
      );
      final skipped = ExerciseExecution(
        exerciseId: 'remada',
        exerciseName: 'Remada',
        sets: const [],
        completed: true,
        status: ExerciseExecutionStatus.skipped,
      );

      expect(ExerciseExecution.fromMap(partial.toMap()).status,
          ExerciseExecutionStatus.partial);
      expect(ExerciseExecution.fromMap(skipped.toMap()).sets, isEmpty);
      expect(
          ExerciseExecution.fromMap(skipped.toMap()).perceivedEffort, isNull);
      expect(ExerciseExecution.fromMap(skipped.toMap()).status,
          ExerciseExecutionStatus.skipped);
    });

    test('keeps old effort value readable without changing original value', () {
      final execution = ExerciseExecution.fromMap({
        'exerciseName': 'Supino',
        'sets': [],
        'perceivedEffort': 'certo',
      });

      expect(execution.perceivedEffort, 'certo');
      expect(PerceivedEffort.labelFor(execution.perceivedEffort), 'Adequado');
    });

    test('preserves new effort values and allows skipped exercise without sets',
        () {
      final execution = ExerciseExecution(
        exerciseName: 'Leg press',
        sets: const [],
        perceivedEffort: PerceivedEffort.skippedFatigue,
        completed: true,
      );
      final restored = ExerciseExecution.fromMap(execution.toMap());

      expect(restored.perceivedEffort, PerceivedEffort.skippedFatigue);
      expect(PerceivedEffort.labelFor(restored.perceivedEffort),
          'Não realizado por fadiga');
      expect(restored.sets, isEmpty);
      expect(PerceivedEffort.allowsEmptySets(restored.perceivedEffort), isTrue);
    });

    test('calculates warmup and total session volume', () {
      final session = WorkoutSession.fromMap({
        'workoutName': 'Treino A',
        'ownerUid': 'user-1',
        'exercises': [
          {
            'exerciseName': 'Aquecimento',
            'isWarmup': true,
            'targetExerciseName': 'Supino reto',
            'sets': [
              {'setNumber': 1, 'reps': 15, 'weightKg': 10}
            ],
            'completed': true,
          },
          {
            'exerciseName': 'Supino reto',
            'sets': [
              {'setNumber': 1, 'reps': 10, 'weightKg': 40}
            ],
            'completed': true,
            'perceivedEffort': PerceivedEffort.adequate,
          },
          {
            'exerciseName': 'Remada baixa',
            'sets': [],
            'completed': true,
            'perceivedEffort': PerceivedEffort.skippedOther,
          },
        ],
      });

      expect(session.exercises.first.volume, 150);
      expect(session.exercises[1].volume, 400);
      expect(session.exercises[2].volume, 0);
      expect(calculateSessionVolume(session), 550);
    });

    test('normalizes active and completed session status compatibly', () {
      final active = WorkoutSession.fromMap({
        'workoutId': 'workout-1',
        'workoutName': 'Treino A',
        'ownerUid': 'user-1',
        'status': WorkoutSessionStatus.inProgress,
        'executionPhase': 'executingExercise',
        'activeExerciseId': 'supino',
        'activeOriginalIndex': 0,
        'exercises': [
          {'exerciseName': 'Aquecimento', 'isWarmup': true},
          {'exerciseId': 'supino', 'exerciseName': 'Supino'},
        ],
      });

      final completedAt = Timestamp.fromDate(DateTime(2026));
      final legacyCompleted = WorkoutSession.fromMap({
        'workoutId': 'workout-1',
        'workoutName': 'Treino A',
        'ownerUid': 'user-1',
        'completedAt': completedAt,
        'exercises': const [],
      });

      expect(active.isInProgress, isTrue);
      expect(active.executionPhase, 'executingExercise');
      expect(active.activeExerciseId, 'supino');
      expect(active.activeOriginalIndex, 0);
      expect(legacyCompleted.status, WorkoutSessionStatus.completed);
    });

    test('serializes optional machine configuration snapshot', () {
      final execution = ExerciseExecution(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        sets: [ExerciseSet(setNumber: 1, reps: 12, weightKg: 42.5)],
        configuredSets: 3,
        configuredRepetitions: 12,
        configuredWeightKg: 45.5,
        observationSnapshot: 'Banco 4',
      );

      final restored = ExerciseExecution.fromMap(execution.toMap());

      expect(restored.configuredSets, 3);
      expect(restored.configuredRepetitions, 12);
      expect(restored.configuredWeightKg, 45.5);
      expect(restored.observationSnapshot, 'Banco 4');
      expect(restored.sets.single.weightKg, 42.5);
      expect(restored.volume, 510);
    });

    test('old session without configuration snapshot remains valid', () {
      final execution = ExerciseExecution.fromMap({
        'exerciseName': 'Remada baixa',
        'sets': [
          {'setNumber': 1, 'reps': 10, 'weightKg': 40}
        ],
      });

      expect(execution.configuredSets, isNull);
      expect(execution.configuredRepetitions, isNull);
      expect(execution.configuredWeightKg, isNull);
      expect(execution.observationSnapshot, isNull);
      expect(execution.volume, 400);
    });

    group('goal reached', () {
      ExerciseExecution execution({
        required List<ExerciseSet> sets,
        int? configuredSets = 3,
        int? configuredRepetitions = 12,
        double? configuredWeightKg = 40,
      }) {
        return ExerciseExecution(
          exerciseId: 'supino',
          exerciseName: 'Supino',
          sets: sets,
          configuredSets: configuredSets,
          configuredRepetitions: configuredRepetitions,
          configuredWeightKg: configuredWeightKg,
        );
      }

      test('detects below exact and above target', () {
        expect(
          execution(
            sets: [
              ExerciseSet(setNumber: 1, reps: 12, weightKg: 40),
              ExerciseSet(setNumber: 2, reps: 12, weightKg: 40),
            ],
          ).isGoalReached,
          isFalse,
        );
        expect(
          execution(
            sets: [
              ExerciseSet(setNumber: 1, reps: 12, weightKg: 40),
              ExerciseSet(setNumber: 2, reps: 12, weightKg: 40),
              ExerciseSet(setNumber: 3, reps: 12, weightKg: 40),
            ],
          ).isGoalReached,
          isTrue,
        );
        expect(
          execution(
            sets: [
              ExerciseSet(setNumber: 1, reps: 15, weightKg: 45),
              ExerciseSet(setNumber: 2, reps: 13, weightKg: 40),
              ExerciseSet(setNumber: 3, reps: 12, weightKg: 42),
              ExerciseSet(setNumber: 4, reps: 12, weightKg: 40),
            ],
          ).isGoalReached,
          isTrue,
        );
      });

      test('returns false for reduced invalid or partial data', () {
        expect(
          execution(
            sets: [
              ExerciseSet(setNumber: 1, reps: 12, weightKg: 40),
              ExerciseSet(setNumber: 2, reps: 11, weightKg: 40),
              ExerciseSet(setNumber: 3, reps: 12, weightKg: 35),
            ],
          ).isGoalReached,
          isFalse,
        );
        expect(
          execution(
            configuredSets: null,
            sets: [
              ExerciseSet(setNumber: 1, reps: 12, weightKg: 40),
            ],
          ).isGoalReached,
          isFalse,
        );
      });
    });
  });
}
