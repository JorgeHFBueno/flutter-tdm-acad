import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_session.dart';

class WorkoutHistoryService {
  final CollectionReference _history =
  FirebaseFirestore.instance.collection('workout_history');

  Future<void> saveSession(WorkoutSession session) async {
    await _history.add({
      'workoutId': session.workoutId,
      'workoutName': session.workoutName,
      'ownerUid': session.ownerUid,
      'performedAt': session.performedAt != null
          ? Timestamp.fromDate(session.performedAt!)
          : FieldValue.serverTimestamp(),
      'startAt': session.startAt != null
          ? Timestamp.fromDate(session.startAt!)
          : FieldValue.serverTimestamp(),
      'endAt': session.endAt != null
          ? Timestamp.fromDate(session.endAt!)
          : FieldValue.serverTimestamp(),
      'exercises': session.exercises.map((e) => e.toMap()).toList(),
    });
  }
}