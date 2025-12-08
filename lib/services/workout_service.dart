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
}