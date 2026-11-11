// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/machine_event.dart';
import '../models/machine_history.dart';
import '../models/workout_session.dart';
import '../data/exercise_catalog.dart';

const String canonicalMachinesCollection = 'machines';

class MachineCompletion {
  final String exerciseId;
  final String exerciseName;
  final String category;

  const MachineCompletion({
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
  });
}

class MachineEventPage {
  final List<MachineEvent> events;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const MachineEventPage({
    required this.events,
    required this.lastDocument,
    required this.hasMore,
  });
}

class MachineService {
  const MachineService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _canonicalCollection(
    String ownerUid,
  ) {
    return _firestore
        .collection('users')
        .doc(ownerUid)
        .collection(canonicalMachinesCollection);
  }

  CollectionReference<Map<String, dynamic>> _eventCollection(
    String ownerUid,
    String exerciseId,
  ) {
    return _canonicalCollection(ownerUid).doc(exerciseId).collection('events');
  }

  Stream<List<MachineProfile>> watchForUser(String ownerUid) {
    return _canonicalCollection(ownerUid)
        .orderBy('exerciseName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MachineProfile.fromMap(doc.data(), id: doc.id))
              .where((machine) => !isSyntheticWarmupExercise(
                    exerciseId: machine.exerciseId,
                    exerciseName: machine.exerciseName,
                    category: machine.category,
                  ))
              .toList(),
        );
  }

  Future<List<MachineProfile>> listForUser(String ownerUid) async {
    final snapshot =
        await _canonicalCollection(ownerUid).orderBy('exerciseName').get();
    final machines = <MachineProfile>[];
    for (final doc in snapshot.docs) {
      final machine = MachineProfile.fromMap(doc.data(), id: doc.id);
      if (isSyntheticWarmupExercise(
        exerciseId: machine.exerciseId,
        exerciseName: machine.exerciseName,
        category: machine.category,
      )) {
        await doc.reference.delete();
        continue;
      }
      machines.add(machine);
    }
    return machines;
  }

  Future<MachineProfile?> getByExerciseId(
    String ownerUid,
    String exerciseId,
  ) async {
    final canonicalDoc =
        await _canonicalCollection(ownerUid).doc(exerciseId).get();
    final canonical = canonicalDoc.exists && canonicalDoc.data() != null
        ? MachineProfile.fromMap(canonicalDoc.data()!, id: canonicalDoc.id)
        : null;
    return canonical;
  }

  Stream<MachineProfile?> watchByExerciseId(
    String ownerUid,
    String exerciseId,
  ) {
    return _canonicalCollection(ownerUid).doc(exerciseId).snapshots().map(
          (doc) => doc.exists && doc.data() != null
              ? MachineProfile.fromMap(doc.data()!, id: doc.id)
              : null,
        );
  }

  Future<void> createMachine(MachineProfile machine) async {
    if (isSyntheticWarmupExercise(
      exerciseId: machine.exerciseId,
      exerciseName: machine.exerciseName,
      category: machine.category,
    )) {
      return;
    }
    final ref = _canonicalCollection(machine.ownerUid).doc(machine.exerciseId);
    final now = FieldValue.serverTimestamp();
    await ref.set({
      ...machine.toMap(),
      'createdAt': now,
      'updatedAt': now,
      'eventTrackingStartedAt': now,
      'eventTrackingBaselineCount': machine.eventTrackingBaselineCount ?? 0,
      'eventSchemaVersion': machineEventSchemaVersion,
    }, SetOptions(merge: false));
  }

  Future<void> ensureMachine({
    required String ownerUid,
    required String exerciseId,
    required String exerciseName,
    required String category,
    String? observation,
    int initialCompletionCount = 0,
    int? currentSets,
    int? currentRepetitions,
    double? currentWeightKg,
  }) async {
    if (isSyntheticWarmupExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      category: category,
    )) {
      return;
    }
    final canonicalCategory =
        findExerciseCatalogItemById(exerciseId)?.category ??
            findExerciseCatalogItem(exerciseName)?.category ??
            category;
    final ref = _canonicalCollection(ownerUid).doc(exerciseId);
    final existing = await ref.get();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'category': canonicalCategory,
      'ownerUid': ownerUid,
      'schemaVersion': 1,
      if (!existing.exists) 'completionCount': initialCompletionCount,
      if (!existing.exists) 'eventTrackingStartedAt': now,
      if (!existing.exists) 'eventTrackingBaselineCount': 0,
      if (!existing.exists) 'eventSchemaVersion': machineEventSchemaVersion,
      if (observation != null) 'observation': observation,
      if (currentSets != null) 'currentSets': currentSets,
      if (currentRepetitions != null) 'currentRepetitions': currentRepetitions,
      if (currentWeightKg != null) 'currentWeightKg': currentWeightKg,
      if (!existing.exists) 'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> ensureEventTrackingInitialized({
    required String ownerUid,
    required String exerciseId,
  }) async {
    final fallback = await getByExerciseId(ownerUid, exerciseId);
    if (fallback == null) return;
    final ref = _canonicalCollection(ownerUid).doc(exerciseId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = snapshot.exists && snapshot.data() != null
          ? MachineProfile.fromMap(snapshot.data()!, id: snapshot.id)
          : fallback;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final baselineMissing = !data.containsKey('eventTrackingBaselineCount');
      final trackingMissing = !data.containsKey('eventTrackingStartedAt');
      final increasesMissing = !data.containsKey('increaseEventsInitializedAt');
      if (!baselineMissing &&
          !trackingMissing &&
          !increasesMissing &&
          data['eventSchemaVersion'] == machineEventSchemaVersion) {
        return;
      }

      final legacyIncreases = <MachineIncrease>[
        if (increasesMissing && current.previousIncrease != null)
          current.previousIncrease!,
        if (increasesMissing && current.lastIncrease != null)
          current.lastIncrease!,
      ];
      final legacyEventRefs =
          <DocumentReference<Map<String, dynamic>>, MachineIncrease>{};
      for (final increase in legacyIncreases) {
        final eventId = deterministicIncreaseEventId(
          current.exerciseId,
          increase,
          prefix: 'legacy_increase',
        );
        legacyEventRefs[_eventCollection(ownerUid, current.exerciseId).doc(
          eventId,
        )] = increase;
      }
      final existingEventSnapshots =
          <DocumentReference<Map<String, dynamic>>, bool>{};
      for (final eventRef in legacyEventRefs.keys) {
        existingEventSnapshots[eventRef] =
            (await transaction.get(eventRef)).exists;
      }

      final now = FieldValue.serverTimestamp();

      transaction.set(
        ref,
        {
          if (!snapshot.exists) ..._baseMachineData(current),
          if (baselineMissing)
            'eventTrackingBaselineCount': current.completionCount,
          if (trackingMissing) 'eventTrackingStartedAt': now,
          if (increasesMissing) 'increaseEventsInitializedAt': now,
          'eventSchemaVersion': machineEventSchemaVersion,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      for (final entry in legacyEventRefs.entries) {
        if (existingEventSnapshots[entry.key] == true) continue;
        transaction.set(
          entry.key,
          _increaseEventData(
            ownerUid: ownerUid,
            exerciseId: current.exerciseId,
            increase: entry.value,
            source: MachineEventSource.legacyCache,
            createdAt: now,
          ),
          SetOptions(merge: true),
        );
      }
    });
  }

  Stream<List<MachineEvent>> watchEvents({
    required String ownerUid,
    required String exerciseId,
    int limit = 50,
  }) {
    return _eventCollection(ownerUid, exerciseId)
        .orderBy('occurredAt', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MachineEvent.fromMap(doc.data(), id: doc.id))
            .where((event) => !event.isDeleted)
            .toList());
  }

  Future<MachineEventPage> getEvents({
    required String ownerUid,
    required String exerciseId,
    int limit = 50,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _eventCollection(ownerUid, exerciseId)
        .orderBy('occurredAt', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit + 1);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    final docs = snapshot.docs;
    final pageDocs = docs.take(limit).toList();
    return MachineEventPage(
      events: pageDocs
          .map((doc) => MachineEvent.fromMap(doc.data(), id: doc.id))
          .where((event) => !event.isDeleted)
          .toList(),
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: docs.length > limit,
    );
  }

  Future<MachineEventPage> loadMoreEvents({
    required String ownerUid,
    required String exerciseId,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 50,
  }) {
    return getEvents(
      ownerUid: ownerUid,
      exerciseId: exerciseId,
      limit: limit,
      startAfter: startAfter,
    );
  }

  Future<void> updateObservation({
    required String ownerUid,
    required String exerciseId,
    required String exerciseName,
    required String category,
    required String observation,
  }) async {
    await ensureEventTrackingInitialized(
      ownerUid: ownerUid,
      exerciseId: exerciseId,
    );
    final ref = _canonicalCollection(ownerUid).doc(exerciseId);
    final fallback = await getByExerciseId(ownerUid, exerciseId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.exists && snapshot.data() != null
          ? MachineProfile.fromMap(snapshot.data()!, id: snapshot.id)
          : fallback;
      final previousObservation = existing?.observationText ?? '';
      final newObservation = observation.trim();
      final now = FieldValue.serverTimestamp();
      transaction.set(
        ref,
        {
          'exerciseId': exerciseId,
          'exerciseName': exerciseName,
          'category': category,
          'ownerUid': ownerUid,
          'schemaVersion': existing?.schemaVersion ?? 1,
          'completionCount': existing?.completionCount ?? 0,
          if (!snapshot.exists && existing?.lastIncrease != null)
            'lastIncrease': existing!.lastIncrease!.toMap(),
          if (!snapshot.exists && existing?.previousIncrease != null)
            'previousIncrease': existing!.previousIncrease!.toMap(),
          if (!snapshot.exists && existing?.currentSets != null)
            'currentSets': existing!.currentSets,
          if (!snapshot.exists && existing?.currentRepetitions != null)
            'currentRepetitions': existing!.currentRepetitions,
          if (!snapshot.exists && existing?.currentWeightKg != null)
            'currentWeightKg': existing!.currentWeightKg,
          if (!snapshot.exists)
            'eventTrackingBaselineCount': existing?.completionCount ?? 0,
          if (!snapshot.exists) 'eventTrackingStartedAt': now,
          'eventSchemaVersion': machineEventSchemaVersion,
          'observation': newObservation,
          if (!snapshot.exists) 'createdAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      if (previousObservation == newObservation) return;
      final eventId = 'observation_${stableMachineEventFingerprint([
        exerciseId.trim(),
        existing?.updatedAt?.toUtc().toIso8601String() ?? 'new',
        previousObservation,
        newObservation,
      ].join('|'))}';
      transaction.set(
        _eventCollection(ownerUid, exerciseId).doc(eventId),
        {
          'exerciseId': exerciseId,
          'ownerUid': ownerUid,
          'type': MachineEventType.observationChanged,
          'occurredAt': now,
          'createdAt': now,
          'schemaVersion': machineEventSchemaVersion,
          'source': MachineEventSource.manual,
          'previousObservation': previousObservation,
          'newObservation': newObservation,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateCurrentConfiguration({
    required String ownerUid,
    required String exerciseId,
    String? exerciseName,
    String? category,
    Object? currentSets = _notProvided,
    Object? currentRepetitions = _notProvided,
    Object? currentWeightKg = _notProvided,
  }) async {
    final sets = currentSets == _notProvided ? null : currentSets as int?;
    final repetitions =
        currentRepetitions == _notProvided ? null : currentRepetitions as int?;
    final weight =
        currentWeightKg == _notProvided ? null : currentWeightKg as double?;
    if (currentSets != _notProvided) {
      _validateOptionalPositiveInt(sets, 'currentSets');
    }
    if (currentRepetitions != _notProvided) {
      _validateOptionalPositiveInt(repetitions, 'currentRepetitions');
    }
    if (currentWeightKg != _notProvided && weight != null && weight <= 0) {
      throw ArgumentError('currentWeightKg must be positive');
    }
    final existing = await getByExerciseId(ownerUid, exerciseId);
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      if (existing != null) ..._baseMachineData(existing),
      if (existing == null) 'exerciseId': exerciseId,
      if (existing == null) 'exerciseName': exerciseName ?? '',
      if (existing == null) 'category': category ?? '',
      if (existing == null) 'ownerUid': ownerUid,
      if (existing == null) 'completionCount': 0,
      'schemaVersion': existing?.schemaVersion ?? 1,
      if (existing == null) 'createdAt': now,
      'updatedAt': now,
    };
    if (currentSets != _notProvided) {
      data['currentSets'] = sets ?? FieldValue.delete();
    }
    if (currentRepetitions != _notProvided) {
      data['currentRepetitions'] = repetitions ?? FieldValue.delete();
    }
    if (currentWeightKg != _notProvided) {
      data['currentWeightKg'] = weight ?? FieldValue.delete();
    }
    await _canonicalCollection(ownerUid)
        .doc(exerciseId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateCurrentConfig({
    required String ownerUid,
    required String exerciseId,
    String? exerciseName,
    String? category,
    int? currentSets,
    int? currentRepetitions,
    double? currentWeightKg,
  }) {
    return updateCurrentConfiguration(
      ownerUid: ownerUid,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      category: category,
      currentSets: currentSets,
      currentRepetitions: currentRepetitions,
      currentWeightKg: currentWeightKg,
    );
  }

  Future<void> registerIncrease({
    required String ownerUid,
    required String exerciseId,
    required String exerciseName,
    required String category,
    required MachineIncrease increase,
  }) async {
    if (!increase.isValid) {
      throw ArgumentError('Aumento invalido');
    }
    await ensureEventTrackingInitialized(
      ownerUid: ownerUid,
      exerciseId: exerciseId,
    );
    final ref = _canonicalCollection(ownerUid).doc(exerciseId);
    final eventId = deterministicIncreaseEventId(exerciseId, increase);
    final increaseWithEventId = increase.copyWith(eventId: eventId);
    final eventRef = _eventCollection(ownerUid, exerciseId).doc(eventId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      MachineProfile? current;
      if (snapshot.exists && snapshot.data() != null) {
        current = MachineProfile.fromMap(snapshot.data()!, id: snapshot.id);
      } else {
        current = await getByExerciseId(ownerUid, exerciseId);
      }
      final now = FieldValue.serverTimestamp();
      final previousValue = _currentValueForIncrease(current, increase.type);
      transaction.set(
        ref,
        {
          'exerciseId': exerciseId,
          'exerciseName': exerciseName,
          'category': category,
          'ownerUid': ownerUid,
          'schemaVersion': current?.schemaVersion ?? 1,
          if (!snapshot.exists)
            'completionCount': current?.completionCount ?? 0,
          if (!snapshot.exists && current?.observation != null)
            'observation': current!.observation,
          'lastIncrease': increaseWithEventId.toMap(),
          'previousIncrease': current?.lastIncrease?.toMap(),
          ..._currentConfigDataForIncrease(increaseWithEventId),
          if (!snapshot.exists)
            'eventTrackingBaselineCount': current?.completionCount ?? 0,
          if (!snapshot.exists) 'eventTrackingStartedAt': now,
          'eventSchemaVersion': machineEventSchemaVersion,
          if (!snapshot.exists)
            'createdAt': current?.createdAt == null
                ? now
                : Timestamp.fromDate(current!.createdAt!),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      transaction.set(
        eventRef,
        _increaseEventData(
          ownerUid: ownerUid,
          exerciseId: exerciseId,
          increase: increaseWithEventId,
          source: MachineEventSource.manual,
          previousValue: previousValue,
          createdAt: now,
        ),
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateIncreaseSlot({
    required String ownerUid,
    required String exerciseId,
    required String slot,
    MachineIncrease? increase,
  }) async {
    if (increase != null && !increase.isValid) {
      throw ArgumentError('Aumento invalido');
    }
    if (slot != 'lastIncrease' && slot != 'previousIncrease') {
      throw ArgumentError('Slot de aumento invalido');
    }
    await ensureEventTrackingInitialized(
      ownerUid: ownerUid,
      exerciseId: exerciseId,
    );
    final ref = _canonicalCollection(ownerUid).doc(exerciseId);
    final fallback = await getByExerciseId(ownerUid, exerciseId);
    final now = FieldValue.serverTimestamp();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = snapshot.exists && snapshot.data() != null
          ? MachineProfile.fromMap(snapshot.data()!, id: snapshot.id)
          : fallback;
      final currentIncrease = slot == 'lastIncrease'
          ? existing?.lastIncrease
          : existing?.previousIncrease;
      final eventRef = _eventReferenceForSlotCorrection(
        ownerUid: ownerUid,
        exerciseId: exerciseId,
        current: currentIncrease,
        replacement: increase,
      );
      final replacementWithEventId = increase == null || eventRef == null
          ? increase
          : increase.copyWith(eventId: eventRef.id);
      transaction.set(
        ref,
        {
          if (existing != null) ..._baseMachineData(existing),
          if (existing == null) 'exerciseId': exerciseId,
          if (existing == null) 'exerciseName': '',
          if (existing == null) 'category': '',
          if (existing == null) 'ownerUid': ownerUid,
          if (existing == null) 'completionCount': 0,
          'schemaVersion': existing?.schemaVersion ?? 1,
          slot: replacementWithEventId?.toMap(),
          if (existing == null) 'eventTrackingBaselineCount': 0,
          if (existing == null) 'eventTrackingStartedAt': now,
          'eventSchemaVersion': machineEventSchemaVersion,
          if (existing == null) 'createdAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      if (eventRef == null) return;
      if (replacementWithEventId == null) {
        transaction.set(
          eventRef,
          {
            'isDeleted': true,
            'voidedAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      } else {
        transaction.set(
          eventRef,
          _increaseEventData(
            ownerUid: ownerUid,
            exerciseId: exerciseId,
            increase: replacementWithEventId,
            source: MachineEventSource.manual,
            createdAt: now,
          ),
          SetOptions(merge: true),
        );
      }
    });
  }

  DocumentReference<Map<String, dynamic>> newSessionRef() {
    return _firestore.collection('workout_history').doc();
  }

  Stream<WorkoutSession?> watchActiveSession(String ownerUid) {
    return _firestore
        .collection('workout_history')
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', isEqualTo: WorkoutSessionStatus.inProgress)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return WorkoutSession.fromMap(doc.data(), id: doc.id);
    });
  }

  Future<WorkoutSession?> getActiveSession(String ownerUid) async {
    final snapshot = await _firestore
        .collection('workout_history')
        .where('ownerUid', isEqualTo: ownerUid)
        .where('status', isEqualTo: WorkoutSessionStatus.inProgress)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return WorkoutSession.fromMap(doc.data(), id: doc.id);
  }

  Future<void> saveInProgressSession({
    required DocumentReference<Map<String, dynamic>> sessionRef,
    required WorkoutSession session,
  }) async {
    final data = session.toMap();
    final existing = await sessionRef.get();
    await sessionRef.set({
      ...data,
      'status': WorkoutSessionStatus.inProgress,
      'schemaVersion': workoutSessionSchemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> abandonSession({
    required String sessionId,
    required String ownerUid,
  }) async {
    await _firestore.collection('workout_history').doc(sessionId).set({
      'ownerUid': ownerUid,
      'status': WorkoutSessionStatus.abandoned,
      'updatedAt': FieldValue.serverTimestamp(),
      'abandonedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveSessionAndApplyMachineCounts({
    required DocumentReference<Map<String, dynamic>> sessionRef,
    required Map<String, dynamic> sessionData,
    required String ownerUid,
    required Iterable<MachineCompletion> completions,
    Iterable<MachineCompletionEventInput> completionEvents = const [],
  }) async {
    final sessionId = sessionRef.id;
    final uniqueCompletions = <String, MachineCompletion>{};
    for (final completion in completions) {
      final id = completion.exerciseId.trim();
      if (id.isEmpty) continue;
      uniqueCompletions[id] = completion;
    }
    final uniqueCompletionEvents = <String, MachineCompletionEventInput>{};
    for (final completion in completionEvents) {
      final id = completion.exerciseId.trim();
      if (id.isEmpty) continue;
      if (!shouldCreateMachineCompletionEvent(completion.execution)) continue;
      uniqueCompletionEvents.putIfAbsent(id, () => completion);
      if (shouldIncrementMachineCompletionCount(
        completion.execution.perceivedEffort,
      )) {
        uniqueCompletions[id] = MachineCompletion(
          exerciseId: completion.exerciseId,
          exerciseName: completion.exerciseName,
          category: completion.category,
        );
      }
    }

    final fallbackMachines = <String, MachineProfile?>{};
    final allEventMachineIds = {
      ...uniqueCompletions.keys,
      ...uniqueCompletionEvents.keys,
    };
    for (final exerciseId in allEventMachineIds) {
      await ensureEventTrackingInitialized(
        ownerUid: ownerUid,
        exerciseId: exerciseId,
      );
    }
    for (final exerciseId in allEventMachineIds) {
      fallbackMachines[exerciseId] =
          await getByExerciseId(ownerUid, exerciseId);
    }

    await _firestore.runTransaction((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      if (sessionSnapshot.exists) {
        final data = sessionSnapshot.data() ?? const <String, dynamic>{};
        if (data['machineHistoryCountApplied'] == true ||
            data['machineCountApplied'] == true) {
          return;
        }
      }

      final machineSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final exerciseId in allEventMachineIds) {
        final ref = _canonicalCollection(ownerUid).doc(exerciseId);
        machineSnapshots[exerciseId] = await transaction.get(ref);
      }

      final now = FieldValue.serverTimestamp();

      transaction.set(
        sessionRef,
        {
          ...sessionData,
          'status': WorkoutSessionStatus.completed,
          'completedAt': sessionData['completedAt'] ?? now,
          'updatedAt': now,
          'machineHistoryCountApplied': true,
          'machineCountApplied': true,
        },
        SetOptions(merge: true),
      );

      for (final completion in uniqueCompletionEvents.values) {
        final ref = _canonicalCollection(ownerUid).doc(completion.exerciseId);
        final snapshot = machineSnapshots[completion.exerciseId];
        final exists = snapshot?.exists ?? false;
        final fallback = fallbackMachines[completion.exerciseId];
        if (!exists && fallback == null) continue;
        transaction.set(
          ref,
          {
            'exerciseId': completion.exerciseId,
            'exerciseName': completion.exerciseName,
            'category': completion.category,
            'ownerUid': ownerUid,
            'schemaVersion': fallback?.schemaVersion ?? 1,
            if (!exists) 'completionCount': fallback?.completionCount ?? 0,
            if (!exists && fallback?.observation != null)
              'observation': fallback!.observation,
            if (!exists && fallback?.lastIncrease != null)
              'lastIncrease': fallback!.lastIncrease!.toMap(),
            if (!exists && fallback?.previousIncrease != null)
              'previousIncrease': fallback!.previousIncrease!.toMap(),
            if (!exists && fallback?.currentSets != null)
              'currentSets': fallback!.currentSets,
            if (!exists && fallback?.currentRepetitions != null)
              'currentRepetitions': fallback!.currentRepetitions,
            if (!exists && fallback?.currentWeightKg != null)
              'currentWeightKg': fallback!.currentWeightKg,
            if (!exists)
              'eventTrackingBaselineCount': fallback?.completionCount ?? 0,
            if (!exists || fallback?.eventTrackingStartedAt == null)
              'eventTrackingStartedAt': now,
            'eventSchemaVersion': machineEventSchemaVersion,
            if (!exists) 'createdAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
        transaction.set(
          _eventCollection(ownerUid, completion.exerciseId)
              .doc('completion_$sessionId'),
          _completionEventData(
            ownerUid: ownerUid,
            sessionId: sessionId,
            completion: completion,
            sessionData: sessionData,
            createdAt: now,
          ),
          SetOptions(merge: true),
        );
      }
      for (final completion in uniqueCompletions.values) {
        final ref = _canonicalCollection(ownerUid).doc(completion.exerciseId);
        final snapshot = machineSnapshots[completion.exerciseId];
        final exists = snapshot?.exists ?? false;
        final fallback = fallbackMachines[completion.exerciseId];
        if (uniqueCompletionEvents.containsKey(completion.exerciseId)) {
          if (exists) {
            transaction.set(
              ref,
              {
                'completionCount': FieldValue.increment(1),
                'updatedAt': now,
              },
              SetOptions(merge: true),
            );
          } else {
            transaction.set(
              ref,
              {
                'completionCount': (fallback?.completionCount ?? 0) + 1,
                'updatedAt': now,
              },
              SetOptions(merge: true),
            );
          }
          continue;
        }
        transaction.set(
          ref,
          {
            'exerciseId': completion.exerciseId,
            'exerciseName': completion.exerciseName,
            'category': completion.category,
            'ownerUid': ownerUid,
            'schemaVersion': fallback?.schemaVersion ?? 1,
            'completionCount': exists
                ? FieldValue.increment(1)
                : (fallback?.completionCount ?? 0) + 1,
            if (!exists && fallback?.observation != null)
              'observation': fallback!.observation,
            if (!exists && fallback?.lastIncrease != null)
              'lastIncrease': fallback!.lastIncrease!.toMap(),
            if (!exists && fallback?.previousIncrease != null)
              'previousIncrease': fallback!.previousIncrease!.toMap(),
            if (!exists && fallback?.currentSets != null)
              'currentSets': fallback!.currentSets,
            if (!exists && fallback?.currentRepetitions != null)
              'currentRepetitions': fallback!.currentRepetitions,
            if (!exists && fallback?.currentWeightKg != null)
              'currentWeightKg': fallback!.currentWeightKg,
            if (!exists)
              'eventTrackingBaselineCount': fallback?.completionCount ?? 0,
            if (!exists) 'eventTrackingStartedAt': now,
            'eventSchemaVersion': machineEventSchemaVersion,
            if (!exists) 'createdAt': now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  void _validateOptionalPositiveInt(int? value, String field) {
    if (value != null && value <= 0) {
      throw ArgumentError('$field must be positive');
    }
  }

  Map<String, dynamic> _baseMachineData(MachineProfile machine) {
    return {
      'exerciseId': machine.exerciseId,
      'exerciseName': machine.exerciseName,
      'category': machine.category,
      'ownerUid': machine.ownerUid,
      'completionCount': machine.completionCount,
      'schemaVersion': machine.schemaVersion,
      if (machine.observation != null) 'observation': machine.observation,
      if (machine.lastIncrease != null)
        'lastIncrease': machine.lastIncrease!.toMap(),
      if (machine.previousIncrease != null)
        'previousIncrease': machine.previousIncrease!.toMap(),
      if (machine.currentSets != null) 'currentSets': machine.currentSets,
      if (machine.currentRepetitions != null)
        'currentRepetitions': machine.currentRepetitions,
      if (machine.currentWeightKg != null)
        'currentWeightKg': machine.currentWeightKg,
      if (machine.createdAt != null)
        'createdAt': Timestamp.fromDate(machine.createdAt!),
      if (machine.eventTrackingStartedAt != null)
        'eventTrackingStartedAt':
            Timestamp.fromDate(machine.eventTrackingStartedAt!),
      if (machine.eventTrackingBaselineCount != null)
        'eventTrackingBaselineCount': machine.eventTrackingBaselineCount,
      if (machine.increaseEventsInitializedAt != null)
        'increaseEventsInitializedAt':
            Timestamp.fromDate(machine.increaseEventsInitializedAt!),
      if (machine.eventSchemaVersion != null)
        'eventSchemaVersion': machine.eventSchemaVersion,
    };
  }

  Map<String, dynamic> _currentConfigDataForIncrease(MachineIncrease increase) {
    switch (increase.type) {
      case MachineIncreaseType.weight:
        return {'currentWeightKg': increase.value};
      case MachineIncreaseType.sets:
        return {'currentSets': increase.value.round()};
      case MachineIncreaseType.repetitions:
        return {'currentRepetitions': increase.value.round()};
      default:
        return const {};
    }
  }

  double? _currentValueForIncrease(
    MachineProfile? machine,
    String increaseType,
  ) {
    if (machine == null) return null;
    switch (increaseType) {
      case MachineIncreaseType.weight:
        return machine.currentWeightKg;
      case MachineIncreaseType.sets:
        return machine.currentSets?.toDouble();
      case MachineIncreaseType.repetitions:
        return machine.currentRepetitions?.toDouble();
      default:
        return null;
    }
  }

  DocumentReference<Map<String, dynamic>>? _eventReferenceForSlotCorrection({
    required String ownerUid,
    required String exerciseId,
    required MachineIncrease? current,
    required MachineIncrease? replacement,
  }) {
    final increaseForId = current ?? replacement;
    if (increaseForId == null) return null;
    final existingEventId = current?.eventId;
    if (existingEventId != null && existingEventId.trim().isNotEmpty) {
      return _eventCollection(ownerUid, exerciseId).doc(existingEventId);
    }
    return _eventCollection(ownerUid, exerciseId).doc(
      deterministicIncreaseEventId(
        exerciseId,
        increaseForId,
        prefix: 'legacy_increase',
      ),
    );
  }

  Map<String, dynamic> _increaseEventData({
    required String ownerUid,
    required String exerciseId,
    required MachineIncrease increase,
    required String source,
    required Object createdAt,
    double? previousValue,
  }) {
    return {
      'exerciseId': exerciseId,
      'ownerUid': ownerUid,
      'type': machineEventTypeForIncrease(increase.type),
      'occurredAt': Timestamp.fromDate(increase.date),
      'createdAt': createdAt,
      'schemaVersion': machineEventSchemaVersion,
      'source': source,
      'increaseType': increase.type,
      if (previousValue != null) 'previousValue': previousValue,
      'newValue': increase.value,
      'isDeleted': false,
    };
  }

  Map<String, dynamic> _completionEventData({
    required String ownerUid,
    required String sessionId,
    required MachineCompletionEventInput completion,
    required Map<String, dynamic> sessionData,
    required Object createdAt,
  }) {
    final execution = completion.execution;
    final occurredAt = sessionData['performedAt'];
    return {
      'exerciseId': completion.exerciseId,
      'ownerUid': ownerUid,
      'type': MachineEventType.completion,
      'occurredAt': occurredAt is Timestamp ? occurredAt : createdAt,
      'createdAt': createdAt,
      'schemaVersion': machineEventSchemaVersion,
      'source': MachineEventSource.session,
      'sessionId': sessionId,
      'workoutId': sessionData['workoutId']?.toString(),
      'workoutName': sessionData['workoutName']?.toString(),
      'perception': PerceivedEffort.normalize(execution.perceivedEffort),
      if (execution.configuredSets != null)
        'configuredSets': execution.configuredSets,
      if (execution.configuredRepetitions != null)
        'configuredRepetitions': execution.configuredRepetitions,
      if (execution.configuredWeightKg != null)
        'configuredWeightKg': execution.configuredWeightKg,
      'performedSetCount': performedSetCount(execution),
      'performedTotalRepetitions': performedTotalRepetitions(execution),
      'performedVolume': performedVolume(execution),
      'completed': execution.completed,
      'isDeleted': false,
    };
  }
}

const Object _notProvided = Object();
