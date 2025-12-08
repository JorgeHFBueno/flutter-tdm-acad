import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_analysis_log.dart';

class WorkoutAnalysisLogService {
  final _collection =
  FirebaseFirestore.instance.collection('workout_analysis_logs');

  Future<void> saveLog(WorkoutAnalysisLog log) async {
    await _collection.add(log.toMap());
  }

  Stream<List<WorkoutAnalysisLog>> getLogsForUser(String ownerUid) {
    return _collection
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => WorkoutAnalysisLog.fromDocument(doc))
          .toList(),
    );
  }
}