import 'package:firebased/data/exercise_catalog.dart';
import 'package:firebased/models/machine_configuration.dart';
import 'package:firebased/models/machine_event.dart';
import 'package:firebased/models/machine_history.dart';
import 'package:firebased/models/workout.dart';
import 'package:firebased/models/workout_execution_flow.dart';
import 'package:firebased/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MachineProfile', () {
    test('deserializes complete profile', () {
      final profile = MachineProfile.fromMap({
        'exerciseId': 'supino_simples',
        'exerciseName': 'Supino Simples',
        'category': 'Peito',
        'ownerUid': 'user-1',
        'completionCount': 7,
        'observation': 'Banco 3',
        'currentSets': 3,
        'currentRepetitions': 12,
        'currentWeightKg': 45,
        'schemaVersion': 1,
      });

      expect(profile.exerciseId, 'supino_simples');
      expect(profile.completionCount, 7);
      expect(profile.observation, 'Banco 3');
      expect(profile.currentSets, 3);
      expect(profile.currentRepetitions, 12);
      expect(profile.currentWeightKg, 45);
      expect(profile.schemaVersion, 1);
    });

    test('deserializes missing optional fields safely', () {
      final profile = MachineProfile.fromMap({
        'exerciseId': 'supino_simples',
        'exerciseName': 'Supino Simples',
        'ownerUid': 'user-1',
      });

      expect(profile.completionCount, 0);
      expect(profile.schemaVersion, 1);
      expect(profile.observation, isNull);
      expect(profile.observationText, '');
      expect(profile.lastIncrease, isNull);
      expect(profile.previousIncrease, isNull);
      expect(profile.currentSets, isNull);
      expect(profile.currentRepetitions, isNull);
      expect(profile.currentWeightKg, isNull);
    });

    test('uses canonical catalog category while preserving legacy profile data',
        () {
      final profile = MachineProfile.fromMap({
        'exerciseId': 'triceps_barra',
        'exerciseName': 'Triceps Barra',
        'category': 'Peito',
        'ownerUid': 'user-1',
        'completionCount': 7,
        'observation': 'Corda curta',
        'currentSets': 3,
        'currentRepetitions': 12,
        'currentWeightKg': 25.5,
      });

      expect(profile.category, armExerciseCategory);
      expect(profile.completionCount, 7);
      expect(profile.observation, 'Corda curta');
      expect(profile.currentWeightKg, 25.5);
    });

    test('deserializes numeric int and double values', () {
      final intIncrease = MachineIncrease.fromMap({
        'type': MachineIncreaseType.weight,
        'value': 40,
      });
      final doubleIncrease = MachineIncrease.fromMap({
        'type': MachineIncreaseType.weight,
        'value': 42.5,
      });
      final intWeight = MachineProfile.fromMap({'currentWeightKg': 45});
      final doubleWeight = MachineProfile.fromMap({'currentWeightKg': 45.5});

      expect(intIncrease.value, 40);
      expect(doubleIncrease.value, 42.5);
      expect(intWeight.currentWeightKg, 45);
      expect(doubleWeight.currentWeightKg, 45.5);
    });

    test('serializes preserving prepared machine fields', () {
      final increase = MachineIncrease(
        type: MachineIncreaseType.weight,
        value: 45,
        date: DateTime(2026, 7, 28),
      );
      final map = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        completionCount: 3,
        observation: 'Banco 3',
        lastIncrease: increase,
        currentSets: 3,
        currentRepetitions: 12,
        currentWeightKg: 45.5,
      ).toMap();

      expect(map['exerciseId'], 'supino_simples');
      expect(map['completionCount'], 3);
      expect(map['schemaVersion'], 1);
      expect(map['observation'], 'Banco 3');
      expect(map['lastIncrease'], isA<Map<String, dynamic>>());
      expect(map['currentSets'], 3);
      expect(map['currentRepetitions'], 12);
      expect(map['currentWeightKg'], 45.5);
    });

    test('new increase shifts last to previous', () {
      final base = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
      );
      final first = MachineIncrease(
        type: MachineIncreaseType.weight,
        value: 40,
        date: DateTime(2026, 7, 1),
      );
      final second = MachineIncrease(
        type: MachineIncreaseType.repetitions,
        value: 15,
        date: DateTime(2026, 7, 15),
      );

      final withFirst = applyNewIncrease(base, first);
      final withSecond = applyNewIncrease(withFirst, second);

      expect(withFirst.lastIncrease, first);
      expect(withFirst.previousIncrease, isNull);
      expect(withSecond.lastIncrease, second);
      expect(withSecond.previousIncrease, first);
    });

    test('validates increase value rules', () {
      expect(
        MachineIncrease(
          type: MachineIncreaseType.weight,
          value: 42.5,
          date: DateTime(2026),
        ).isValid,
        isTrue,
      );
      expect(
        MachineIncrease(
          type: MachineIncreaseType.sets,
          value: 4.5,
          date: DateTime(2026),
        ).isValid,
        isFalse,
      );
      expect(
        MachineIncrease(
          type: MachineIncreaseType.repetitions,
          value: 0,
          date: DateTime(2026),
        ).isValid,
        isFalse,
      );
    });

    test('formats increases', () {
      expect(
        formatMachineIncrease(
          MachineIncrease(
            type: MachineIncreaseType.weight,
            value: 42.5,
            date: DateTime(2026, 7, 28),
          ),
        ),
        '28/07 - Aumentou para 42,5 kg',
      );
      expect(
        formatIncreaseValue(
          MachineIncrease(
            type: MachineIncreaseType.sets,
            value: 1,
            date: DateTime(2026),
          ),
        ),
        '1 serie',
      );
      expect(
        formatIncreaseValue(
          MachineIncrease(
            type: MachineIncreaseType.repetitions,
            value: 15,
            date: DateTime(2026),
          ),
        ),
        '15 repeticoes',
      );
    });

    test('formats latest valid increase for workout card', () {
      final profile = MachineProfile(
        exerciseId: 'supino',
        exerciseName: 'Supino',
        category: 'Peito',
        ownerUid: 'user-1',
        lastIncrease: MachineIncrease(
          type: MachineIncreaseType.weight,
          value: 45.5,
          date: DateTime(2026, 7, 28),
        ),
        previousIncrease: MachineIncrease(
          type: MachineIncreaseType.repetitions,
          value: 12,
          date: DateTime(2026, 7, 20),
        ),
      );

      final latest = latestValidMachineIncrease(profile);

      expect(latest?.value, 45.5);
      expect(
        formatLatestMachineIncrease(latest),
        'Ul_Mod: peso | +45,5 | 28/07',
      );
      expect(
        formatLatestMachineIncrease(
          latestValidMachineIncrease(
            profile.copyWith(
              clearLastIncrease: true,
              clearPreviousIncrease: true,
            ),
          ),
        ),
        'Ul_Mod: --',
      );
    });

    test('builds completion marks', () {
      expect(buildCompletionMarks(0), '');
      expect(buildCompletionMarks(1), '|');
      expect(buildCompletionMarks(5), '|||||');
      expect(buildCompletionMarks(6), '||||| |');
      expect(buildCompletionMarks(13), '||||| ||||| |||');
    });

    test('serializes event tracking fields defensively', () {
      final profile = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        completionCount: 8,
        eventTrackingBaselineCount: 8,
        eventTrackingStartedAt: DateTime(2026, 7, 29),
        increaseEventsInitializedAt: DateTime(2026, 7, 29),
        eventSchemaVersion: 1,
      );

      final map = profile.toMap();
      final restored = MachineProfile.fromMap(map);

      expect(restored.eventTrackingBaselineCount, 8);
      expect(restored.eventTrackingStartedAt, DateTime(2026, 7, 29));
      expect(restored.increaseEventsInitializedAt, DateTime(2026, 7, 29));
      expect(restored.eventSchemaVersion, 1);
    });

    test('builds structured history line without double counting', () {
      expect(buildMachineEventHistoryLine(0, const []), '');
      expect(buildMachineEventHistoryLine(1, const []), '|');
      expect(buildMachineEventHistoryLine(5, const []), '|||||');
      expect(buildMachineEventHistoryLine(6, const []), '||||| |');
      expect(
        buildMachineEventHistoryLine(8, const ['|', '!', '¡', 'i']),
        '||||| ||| | ! ¡ i',
      );
    });
  });

  group('MachineEvent', () {
    test('serializes completion summary preserving decimal volume', () {
      final event = MachineEvent(
        id: 'completion_session-1',
        exerciseId: 'supino_simples',
        ownerUid: 'user-1',
        type: MachineEventType.completion,
        sessionId: 'session-1',
        workoutId: 'workout-1',
        workoutName: 'Peito',
        perception: PerceivedEffort.adequate,
        configuredSets: 3,
        configuredRepetitions: 12,
        configuredWeightKg: 42.5,
        performedSetCount: 3,
        performedTotalRepetitions: 36,
        performedVolume: 1530,
        completed: true,
        source: MachineEventSource.session,
      );

      final map = event.toMap();
      final restored = MachineEvent.fromMap(map, id: event.id);

      expect(restored.id, event.id);
      expect(restored.type, MachineEventType.completion);
      expect(restored.perception, PerceivedEffort.adequate);
      expect(restored.configuredWeightKg, 42.5);
      expect(restored.performedVolume, 1530);
      expect(restored.completionSymbol, '|');
    });

    test('serializes increase and observation events', () {
      final increase = MachineEvent(
        id: 'increase-1',
        exerciseId: 'supino_simples',
        ownerUid: 'user-1',
        type: MachineEventType.weightIncreased,
        increaseType: MachineIncreaseType.weight,
        previousValue: 40,
        newValue: 42.5,
      );
      final observation = MachineEvent(
        id: 'obs-1',
        exerciseId: 'supino_simples',
        ownerUid: 'user-1',
        type: MachineEventType.observationChanged,
        previousObservation: 'Banco 3',
        newObservation: '',
      );

      expect(MachineEvent.fromMap(increase.toMap()).newValue, 42.5);
      expect(
        MachineEvent.fromMap(observation.toMap()).previousObservation,
        'Banco 3',
      );
      expect(MachineEvent.fromMap(observation.toMap()).newObservation, '');
    });

    test('deserializes incomplete and unknown documents safely', () {
      final event = MachineEvent.fromMap({
        'type': 'novo_tipo',
        'performedVolume': 12,
        'newValue': 45.5,
      }, id: 'doc-1');

      expect(event.id, 'doc-1');
      expect(event.type, MachineEventType.unknown);
      expect(event.performedVolume, 12);
      expect(event.newValue, 45.5);
      expect(event.completionSymbol, '?');
    });

    test('maps perception symbols and counter eligibility centrally', () {
      expect(symbolForMachinePerception(PerceivedEffort.light), '|');
      expect(symbolForMachinePerception(PerceivedEffort.adequate), '|');
      expect(symbolForMachinePerception(PerceivedEffort.highFatigue), '|');
      expect(symbolForMachinePerception(PerceivedEffort.reducedReps), '!');
      expect(symbolForMachinePerception(PerceivedEffort.reducedWeight), '¡');
      expect(symbolForMachinePerception(PerceivedEffort.skippedFatigue), 'i');
      expect(symbolForMachinePerception(PerceivedEffort.skippedOther), 'i');
      expect(symbolForMachinePerception('desconhecido'), '?');
      expect(
        shouldIncrementMachineCompletionCount(PerceivedEffort.highFatigue),
        isTrue,
      );
      expect(
        shouldIncrementMachineCompletionCount(PerceivedEffort.reducedReps),
        isFalse,
      );
    });

    test('calculates completion summaries from performed sets', () {
      final execution = ExerciseExecution(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        sets: [
          ExerciseSet(setNumber: 1, reps: 10, weightKg: 42.5),
          ExerciseSet(setNumber: 2, reps: 8, weightKg: 40),
        ],
        perceivedEffort: PerceivedEffort.reducedReps,
        completed: true,
      );
      final skipped = execution.copyWith(
        sets: const [],
        perceivedEffort: PerceivedEffort.skippedFatigue,
      );

      expect(performedSetCount(execution), 2);
      expect(performedTotalRepetitions(execution), 18);
      expect(performedVolume(execution), 745);
      expect(performedSetCount(skipped), 0);
      expect(performedTotalRepetitions(skipped), 0);
      expect(performedVolume(skipped), 0);
    });

    test('filters completion event eligibility', () {
      final normal = ExerciseExecution(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        sets: const [],
        perceivedEffort: PerceivedEffort.skippedOther,
        completed: true,
      );
      final warmup = normal.copyWith(isWarmup: true);
      final pending = normal.copyWith(completed: false);
      final partial = normal.copyWith(status: ExerciseExecutionStatus.partial);
      final unknown = normal.copyWith(perceivedEffort: 'desconhecido');

      expect(shouldCreateMachineCompletionEvent(normal), isTrue);
      expect(shouldCreateMachineCompletionEvent(warmup), isFalse);
      expect(shouldCreateMachineCompletionEvent(pending), isFalse);
      expect(shouldCreateMachineCompletionEvent(partial), isFalse);
      expect(shouldCountMachineCompletion(partial), isFalse);
      expect(shouldCreateMachineCompletionEvent(unknown), isFalse);
    });

    test('generates deterministic increase ids without hashCode', () {
      final increase = MachineIncrease(
        type: MachineIncreaseType.weight,
        value: 42.5,
        date: DateTime(2026, 7, 29),
      );

      final first = deterministicIncreaseEventId(
        'supino_simples',
        increase,
        prefix: 'legacy_increase',
      );
      final second = deterministicIncreaseEventId(
        'supino_simples',
        increase,
        prefix: 'legacy_increase',
      );

      expect(first, second);
      expect(first, startsWith('legacy_increase_'));
      expect(first, isNot(contains('Instance of')));
    });

    test('orders events deterministically and excludes deleted events', () {
      final sameOccurred = DateTime(2026, 7, 30, 10);
      final events = [
        MachineEvent(
          id: 'a',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.completion,
          occurredAt: sameOccurred,
          createdAt: DateTime(2026, 7, 30, 10, 1),
        ),
        MachineEvent(
          id: 'c',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.weightIncreased,
          occurredAt: sameOccurred,
          createdAt: DateTime(2026, 7, 30, 10, 1),
        ),
        MachineEvent(
          id: 'b',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.observationChanged,
          occurredAt: sameOccurred,
          createdAt: DateTime(2026, 7, 30, 10, 2),
          isDeleted: true,
        ),
      ];

      final active = activeMachineEventsInHistoryOrder(events);

      expect(active.map((event) => event.id), ['c', 'a']);
    });

    test('audits completion baseline without mutating data', () {
      final machine = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        completionCount: 5,
        eventTrackingBaselineCount: 3,
      );
      final events = [
        MachineEvent(
          id: 'completion_1',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.completion,
          perception: PerceivedEffort.light,
        ),
        MachineEvent(
          id: 'completion_2',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.completion,
          perception: PerceivedEffort.reducedWeight,
        ),
        MachineEvent(
          id: 'completion_3',
          exerciseId: 'supino_simples',
          ownerUid: 'user-1',
          type: MachineEventType.completion,
          perception: PerceivedEffort.highFatigue,
        ),
      ];

      expect(
        hasConsistentCompletionBaseline(machine: machine, events: events),
        isTrue,
      );
      expect(
        hasConsistentCompletionBaseline(
          machine: machine.copyWith(completionCount: 6),
          events: events,
        ),
        isFalse,
      );
    });
  });

  group('canonical machine profile', () {
    test('document becomes MachineProfile', () {
      final machine = MachineProfile.fromMap({
        'exerciseId': 'remada_baixa',
        'exerciseName': 'Remada baixa',
        'category': 'Costas',
        'ownerUid': 'user-1',
        'completionCount': 4,
        'observation': 'Ajuste 5',
      }, id: 'remada_baixa');

      expect(machine.exerciseId, 'remada_baixa');
      expect(machine.completionCount, 4);
      expect(machine.observation, 'Ajuste 5');
    });

    test('same machine id can be referenced by multiple workouts', () {
      const machineId = 'supino_simples';
      final workoutA = Workout(
        name: 'Treino A',
        ownerUid: 'user-1',
        machineIds: const [machineId, 'remada_baixa'],
      );
      final workoutB = Workout(
        name: 'Treino B',
        ownerUid: 'user-1',
        machineIds: const ['leg_45', machineId],
      );
      final machine = MachineProfile(
        exerciseId: machineId,
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        currentWeightKg: 42.5,
      );

      expect(workoutA.machineIds, contains(machine.exerciseId));
      expect(workoutB.machineIds, contains(machine.exerciseId));
      expect(workoutA.toMap()['machineIds'], [machineId, 'remada_baixa']);
    });
  });

  group('partial update helpers', () {
    test('updating observation does not alter counter or increases', () {
      final increase = MachineIncrease(
        type: MachineIncreaseType.weight,
        value: 40,
        date: DateTime(2026),
      ).toMap();
      final updated = applyObservationPatch(
        {
          'completionCount': 3,
          'lastIncrease': increase,
          'currentSets': 3,
        },
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        observation: '',
      );

      expect(updated['observation'], '');
      expect(updated['completionCount'], 3);
      expect(updated['lastIncrease'], increase);
      expect(updated['currentSets'], 3);
    });

    test('updating current config does not alter observation or counter', () {
      final updated = applyCurrentConfigPatch(
        {'completionCount': 5, 'observation': 'Banco 3'},
        currentSets: 3,
        currentRepetitions: 12,
        currentWeightKg: 45.5,
      );

      expect(updated['completionCount'], 5);
      expect(updated['observation'], 'Banco 3');
      expect(updated['currentSets'], 3);
      expect(updated['currentRepetitions'], 12);
      expect(updated['currentWeightKg'], 45.5);
    });

    test('registering increase does not alter counter', () {
      final updated = applyIncreasePatch(
        {'completionCount': 5, 'observation': 'Banco 3'},
        MachineIncrease(
          type: MachineIncreaseType.weight,
          value: 45,
          date: DateTime(2026),
        ),
      );

      expect(updated['completionCount'], 5);
      expect(updated['observation'], 'Banco 3');
      expect(updated['lastIncrease'], isA<Map<String, dynamic>>());
    });

    test('incrementing counter does not alter observation', () {
      final updated = applyCompletionIncrementPatch(
        {'completionCount': 5, 'observation': 'Banco 3'},
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
      );

      expect(updated['completionCount'], 6);
      expect(updated['observation'], 'Banco 3');
    });

    test('automatic creation starts correctly', () {
      final updated = applyCompletionIncrementPatch(
        const {},
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
      );

      expect(updated['exerciseId'], 'supino_simples');
      expect(updated['completionCount'], 1);
      expect(updated['schemaVersion'], 1);
    });
  });

  group('machine completion counter rules', () {
    ExerciseExecution execution(String? effort,
        {String? id = 'supino_simples'}) {
      return ExerciseExecution(
        exerciseId: id,
        exerciseName: 'Supino Simples',
        sets: [ExerciseSet(setNumber: 1, reps: 10, weightKg: 40)],
        perceivedEffort: effort,
        completed: true,
      );
    }

    test('counts only valid normalized efforts', () {
      expect(shouldCountMachineCompletion(execution(PerceivedEffort.light)),
          isTrue);
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.adequate)),
        isTrue,
      );
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.highFatigue)),
        isTrue,
      );
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.reducedReps)),
        isFalse,
      );
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.reducedWeight)),
        isFalse,
      );
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.skippedFatigue)),
        isFalse,
      );
      expect(
        shouldCountMachineCompletion(execution(PerceivedEffort.skippedOther)),
        isFalse,
      );
      expect(shouldCountMachineCompletion(execution(null)), isFalse);
      expect(shouldCountMachineCompletion(execution('desconhecido')), isFalse);
    });

    test('does not count warmup or missing ids', () {
      expect(
        shouldCountMachineCompletion(
          ExerciseExecution(
            exerciseId: 'supino_simples',
            exerciseName: 'Aquecimento',
            sets: const [],
            completed: true,
            isWarmup: true,
          ),
        ),
        isFalse,
      );
      expect(
        shouldCountMachineCompletion(
            execution(PerceivedEffort.light, id: null)),
        isFalse,
      );
    });

    test('deduplicates exercise ids', () {
      final ids = eligibleMachineCompletionExerciseIds([
        execution(PerceivedEffort.light),
        execution(PerceivedEffort.adequate),
        execution(PerceivedEffort.highFatigue, id: 'remada_baixa'),
      ]);

      expect(ids, {'supino_simples', 'remada_baixa'});
    });
  });

  group('machine ids', () {
    test('catalog ids remain unique', () {
      final ids = exerciseCatalog.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('machine uses same id as exercise', () {
      final item = findExerciseCatalogItemById('supino_simples')!;
      final machine = MachineProfile(
        exerciseId: item.id,
        exerciseName: item.name,
        category: item.category,
        ownerUid: 'user-1',
      );

      expect(machine.exerciseId, item.id);
    });

    test('warmup does not have its own machine profile id', () {
      final warmup = createWarmupExecution(
        targetExerciseId: 'supino_simples',
        targetExerciseName: 'Supino Simples',
        completed: true,
      );

      expect(warmup.exerciseId, isNull);
      expect(shouldCountMachineCompletion(warmup), isFalse);
      expect(warmup.targetExerciseId, 'supino_simples');
    });

    test('legacy exercise resolves deterministic id', () {
      final first = legacyExerciseIdFor(' Exercicio legado ', 'Outros');
      final second = legacyExerciseIdFor('Exercicio legado', 'Outros');

      expect(first, second);
      expect(first, startsWith('legacy__'));
    });
  });

  group('latest machine modification for workout execution', () {
    MachineEvent event({
      required String type,
      required double previous,
      required double current,
      required DateTime date,
    }) {
      return MachineEvent(
        id: '$type-$date',
        exerciseId: 'supino',
        ownerUid: 'user-1',
        type: type,
        previousValue: previous,
        newValue: current,
        occurredAt: date,
      );
    }

    test('formats repetition, set and weight deltas', () {
      expect(
        formatLatestMachineModification(event(
          type: MachineEventType.repetitionsIncreased,
          previous: 10,
          current: 20,
          date: DateTime(2026, 7, 1),
        )),
        'Ul_Mod: rep | +10 | 01/07',
      );
      expect(
        formatLatestMachineModification(event(
          type: MachineEventType.setsIncreased,
          previous: 3,
          current: 4,
          date: DateTime(2026, 7, 15),
        )),
        'Ul_Mod: ser | +1 | 15/07',
      );
      expect(
        formatLatestMachineModification(event(
          type: MachineEventType.weightIncreased,
          previous: 40,
          current: 45,
          date: DateTime(2026, 7, 22),
        )),
        'Ul_Mod: peso | +5 | 22/07',
      );
    });

    test('preserves negative sign and compact decimal value', () {
      expect(
        formatLatestMachineModification(event(
          type: MachineEventType.weightIncreased,
          previous: 40,
          current: 38,
          date: DateTime(2026, 8, 3),
        )),
        'Ul_Mod: peso | -2 | 03/08',
      );
      expect(
        formatLatestMachineModification(event(
          type: MachineEventType.weightIncreased,
          previous: 40,
          current: 42.5,
          date: DateTime(2026, 8, 4),
        )),
        'Ul_Mod: peso | +2,5 | 04/08',
      );
    });

    test('ignores observations and reports absence discreetly', () {
      final observation = MachineEvent(
        id: 'observation',
        exerciseId: 'supino',
        ownerUid: 'user-1',
        type: MachineEventType.observationChanged,
        occurredAt: DateTime(2026, 8, 4),
      );
      final increase = event(
        type: MachineEventType.weightIncreased,
        previous: 40,
        current: 45,
        date: DateTime(2026, 8, 3),
      );

      expect(latestMachineModification([observation, increase]), increase);
      expect(latestMachineModification([observation]), isNull);
      expect(formatLatestMachineModification(null), 'Ul_Mod: --');
    });
  });

  group('current machine configuration resolution', () {
    test('complete machine resolves current configuration', () {
      final machine = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        observation: 'Banco 4',
        currentSets: 3,
        currentRepetitions: 12,
        currentWeightKg: 42.5,
      );
      final config = resolveExerciseConfiguration(machine: machine);

      expect(config.configuredSets, 3);
      expect(config.configuredRepetitions, 12);
      expect(config.configuredWeightKg, 42.5);
      expect(config.observation, 'Banco 4');
      expect(config.isComplete, isTrue);
    });

    test('missing machine keeps sets undefined and falls back safely', () {
      final config = resolveExerciseConfiguration();

      expect(config.configuredSets, isNull);
      expect(config.configuredRepetitions, 10);
      expect(config.configuredWeightKg, 10);
      expect(config.observation, '');
      expect(config.isComplete, isFalse);
    });

    test('new increases update current configuration value', () {
      final base = MachineProfile(
        exerciseId: 'supino_simples',
        exerciseName: 'Supino Simples',
        category: 'Peito',
        ownerUid: 'user-1',
        currentSets: 3,
        currentRepetitions: 12,
        currentWeightKg: 40,
      );

      expect(
        applyNewIncrease(
          base,
          MachineIncrease(
            type: MachineIncreaseType.weight,
            value: 45.5,
            date: DateTime(2026),
          ),
        ).currentWeightKg,
        45.5,
      );
      expect(
        applyNewIncrease(
          base,
          MachineIncrease(
            type: MachineIncreaseType.sets,
            value: 4,
            date: DateTime(2026),
          ),
        ).currentSets,
        4,
      );
      expect(
        applyNewIncrease(
          base,
          MachineIncrease(
            type: MachineIncreaseType.repetitions,
            value: 15,
            date: DateTime(2026),
          ),
        ).currentRepetitions,
        15,
      );
    });
  });
}
