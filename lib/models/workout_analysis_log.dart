import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutAnalysisLog {
  final String id;
  final String ownerUid;
  final String? workoutId;
  final String? workoutName;
  final String type; // "history" ou "session"
  final String prompt;
  final String response;
  final DateTime? createdAt;

  WorkoutAnalysisLog({
    required this.id,
    required this.ownerUid,
    required this.type,
    required this.prompt,
    required this.response,
    this.workoutId,
    this.workoutName,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'ownerUid': ownerUid,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'type': type,
    'prompt': prompt,
    'response': response,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  factory WorkoutAnalysisLog.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['createdAt'];

    DateTime? createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return WorkoutAnalysisLog(
      id: doc.id,
      ownerUid: data['ownerUid']?.toString() ?? '',
      workoutId: data['workoutId']?.toString(),
      workoutName: data['workoutName']?.toString(),
      type: data['type']?.toString() ?? 'unknown',
      prompt: data['prompt']?.toString() ?? '',
      response: data['response']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}