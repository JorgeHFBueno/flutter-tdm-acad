import 'package:firebased/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutSession', () {
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
  });
}
