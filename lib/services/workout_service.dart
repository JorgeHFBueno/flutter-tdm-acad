import "package:cloud_firestore/cloud_firestore.dart";
import '../models/workout.dart';

class WorkoutService {
  final CollectionReference _workouts =
  FirebaseFirestore.instance.collection('workouts');

  Future<void> createWorkout(Workout workout) async {
    await _workouts.add({
      'name': workout.name,
      'exercises': workout.exercises.map((e) => e.toMap()).toList(),
      'ownerUid': workout.ownerUid,
      'ownerName': workout.ownerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWorkout(String id) async {
    await _workouts.doc(id).delete();
  }

  Future<void> updateWorkout(Workout workout) async {
    if (workout.id == null) {
      throw ArgumentError('Workout ID não pode ser nulo para atualização');
    }

    await _workouts.doc(workout.id).update({
      'name': workout.name,
      'exercises': workout.exercises.map((e) => e.toMap()).toList(),
      'ownerUid': workout.ownerUid,
      'ownerName': workout.ownerName,
    });
  }

  Stream<List<Workout>> getWorkoutsForUser(String ownerUid) {
    return _workouts
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs.map((doc) => Workout.fromDocument(doc)).toList(),
    );
  }
}