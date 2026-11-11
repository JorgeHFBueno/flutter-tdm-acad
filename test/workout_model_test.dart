import 'package:firebased/data/exercise_catalog.dart';
import 'package:firebased/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Workout', () {
    test('serializes new schema with ordered machine ids only', () {
      final workout = Workout(
        id: 'workout-1',
        name: 'Treino A',
        ownerUid: 'user-1',
        machineIds: const ['supino', 'remada', 'supino', 'leg'],
      );

      final map = workout.toMap();

      expect(workout.machineIds, ['supino', 'remada', 'leg']);
      expect(map['name'], 'Treino A');
      expect(map['ownerUid'], 'user-1');
      expect(map['machineIds'], ['supino', 'remada', 'leg']);
      expect(map['schemaVersion'], workoutSchemaVersion);
      expect(map.containsKey('exercises'), isFalse);
      expect(map.containsKey('defaultWeightKg'), isFalse);
      expect(map.containsKey('observation'), isFalse);
    });

    test('deserializes preserving order and optional timestamps', () {
      final workout = Workout.fromMap(
        {
          'name': 'Treino B',
          'ownerUid': 'user-1',
          'machineIds': ['leg', 'supino'],
          'schemaVersion': 2,
        },
        id: 'workout-2',
      );

      expect(workout.id, 'workout-2');
      expect(workout.name, 'Treino B');
      expect(workout.ownerUid, 'user-1');
      expect(workout.machineIds, ['leg', 'supino']);
      expect(workout.schemaVersion, 2);
      expect(workout.createdAt, isNull);
      expect(workout.updatedAt, isNull);
    });

    test('filters legacy synthetic warmup id from active workout refs', () {
      final workout = Workout.fromMap(
        {
          'name': 'Treino antigo',
          'ownerUid': 'user-1',
          'machineIds': ['aquecimento', 'supino', 'aquecimento', 'remada'],
          'schemaVersion': 2,
        },
        id: 'workout-warmup',
      );

      expect(workout.machineIds, ['supino', 'remada']);
      expect(workout.toMap()['machineIds'], ['supino', 'remada']);
    });

    test('validation rejects empty name, owner, or machine list', () {
      expect(
        () => validateWorkoutFields(
          name: '',
          ownerUid: 'user-1',
          machineIds: const ['supino'],
        ),
        throwsArgumentError,
      );
      expect(
        () => validateWorkoutFields(
          name: 'Treino',
          ownerUid: '',
          machineIds: const ['supino'],
        ),
        throwsArgumentError,
      );
      expect(
        () => validateWorkoutFields(
          name: 'Treino',
          ownerUid: 'user-1',
          machineIds: const [],
        ),
        throwsArgumentError,
      );
    });

    test('ignores legacy exercises payload in active workout model', () {
      final workout = Workout.fromMap(
        {
          'name': 'Treino antigo ignorado',
          'ownerUid': 'user-1',
          'exercises': [
            {'name': 'Supino Simples', 'defaultWeightKg': 35},
          ],
          'schemaVersion': 1,
        },
        id: 'legacy-workout',
      );

      expect(workout.machineIds, isEmpty);
      expect(workout.schemaVersion, 1);
    });
  });

  group('category resolution', () {
    test('preserves saved category before catalog lookup', () {
      expect(
        resolveExerciseCategory('Exercicio antigo', savedCategory: 'Legado'),
        'Legado',
      );
    });

    test('keeps deterministic id for exercise outside catalog', () {
      final legacyId = resolveExerciseId(
        name: 'Exercicio antigo',
        category: resolveExerciseCategory('Exercicio antigo'),
      );

      expect(legacyId, startsWith('legacy__'));
    });
  });
}
