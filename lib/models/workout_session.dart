import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseExecution {
  final String exerciseName;
  final int sets;
  final int reps;
  final int weightKg;

  ExerciseExecution({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() => {
    'exerciseName': exerciseName,
    'sets': sets,
    'reps': reps,
    'weightKg': weightKg,
  };

  factory ExerciseExecution.fromMap(Map<String, dynamic> map) {
    return ExerciseExecution(
      exerciseName: map['exerciseName']?.toString() ?? '',
      sets: (map['sets'] ?? 0) as int,
      reps: (map['reps'] ?? 0) as int,
      weightKg: (map['weightKg'] ?? 0) as int,
    );
  }
}

class WorkoutSession {
  final String? id;
  final String workoutId;
  final String workoutName;
  final String ownerUid;
  final DateTime? performedAt;
  final List<ExerciseExecution> exercises;

  WorkoutSession({
    this.id,
    required this.workoutId,
    required this.workoutName,
    required this.ownerUid,
    this.performedAt,
    required this.exercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'workoutName': workoutName,
      'ownerUid': ownerUid,
      'performedAt': performedAt != null
          ? Timestamp.fromDate(performedAt!)
          : FieldValue.serverTimestamp(),
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}