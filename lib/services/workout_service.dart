import "package:cloud_firestore/cloud_firestore.dart";
import '../models/workout.dart';

class WorkoutService {
  final CollectionReference _workouts =
  FirebaseFirestore.instance.collection('workouts');

  Future<void> createWorkout(Workout workout) async {
    await _workouts.add({
      'name': workout.name,
      'exercises': workout.exercises,
      'ownerUid': workout.ownerUid,
      'ownerName': workout.ownerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Stream<List<Workout>> getWorkoutsForUser(String ownerUid) {
    return _workouts
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => Workout.fromDocument(doc))
          .toList(),
    );
  }
}