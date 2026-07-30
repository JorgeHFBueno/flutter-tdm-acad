import "package:cloud_firestore/cloud_firestore.dart";

import '../models/workout.dart';

class WorkoutService {
  const WorkoutService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _workoutsForUser(String ownerUid) {
    return _firestore.collection('users').doc(ownerUid).collection('workouts');
  }

  Future<void> createWorkout(Workout workout) async {
    validateWorkoutFields(
      name: workout.name,
      ownerUid: workout.ownerUid,
      machineIds: workout.machineIds,
    );
    final now = FieldValue.serverTimestamp();
    await _workoutsForUser(workout.ownerUid).add({
      'name': workout.name.trim(),
      'ownerUid': workout.ownerUid,
      'machineIds': normalizeMachineIds(workout.machineIds),
      'schemaVersion': workoutSchemaVersion,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> deleteWorkout(String ownerUid, String id) async {
    if (ownerUid.trim().isEmpty || id.trim().isEmpty) {
      throw ArgumentError('ownerUid and workout id are required');
    }
    await _workoutsForUser(ownerUid).doc(id).delete();
  }

  Future<void> updateWorkout(Workout workout) async {
    if (workout.id == null) {
      throw ArgumentError('Workout ID cannot be null for update');
    }
    validateWorkoutFields(
      name: workout.name,
      ownerUid: workout.ownerUid,
      machineIds: workout.machineIds,
    );

    await _workoutsForUser(workout.ownerUid).doc(workout.id).update({
      'name': workout.name.trim(),
      'ownerUid': workout.ownerUid,
      'machineIds': normalizeMachineIds(workout.machineIds),
      'schemaVersion': workoutSchemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Workout>> getWorkoutsForUser(String ownerUid) {
    return _workoutsForUser(ownerUid)
        .where('schemaVersion', isEqualTo: workoutSchemaVersion)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Workout.fromDocument(doc)).toList(),
        );
  }

  Future<List<Workout>> listWorkoutsForUser(String ownerUid) async {
    final snapshot = await _workoutsForUser(ownerUid)
        .where('schemaVersion', isEqualTo: workoutSchemaVersion)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Workout.fromDocument(doc)).toList();
  }

  Future<Workout?> getWorkoutById(String ownerUid, String id) async {
    final doc = await _workoutsForUser(ownerUid).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final workout = Workout.fromDocument(doc);
    return workout.schemaVersion == workoutSchemaVersion ? workout : null;
  }
}
