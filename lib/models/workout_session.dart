import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseSet {
  final int setNumber;
  final int reps;
  final int weightKg;

  ExerciseSet({
    required this.setNumber,
    required this.reps,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() => {
    'setNumber': setNumber,
    'reps': reps,
    'weightKg': weightKg,
  };

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      setNumber: (map['setNumber'] ?? 0) as int,
      reps: (map['reps'] ?? 0) as int,
      weightKg: (map['weightKg'] ?? 0) as int,
    );
  }
}

class ExerciseExecution {
  final String exerciseName;
  final List<ExerciseSet> sets;
  final String? perceivedEffort; // "certo", "leve" ou "fadiga"
  final bool completed;

  ExerciseExecution({
    required this.exerciseName,
    required this.sets,
    this.perceivedEffort,
    this.completed = false,
  });

  ExerciseExecution copyWith({
    List<ExerciseSet>? sets,
    String? perceivedEffort,
    bool? completed,
  }) {
    return ExerciseExecution(
      exerciseName: exerciseName,
      sets: sets ?? this.sets,
      perceivedEffort: perceivedEffort ?? this.perceivedEffort,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toMap() => {
    'exerciseName': exerciseName,
    'sets': sets.map((s) => s.toMap()).toList(),
    'perceivedEffort': perceivedEffort,
    'completed': completed,
  };

  factory ExerciseExecution.fromMap(Map<String, dynamic> map) {
    final rawSets = map['sets'];
    final List<dynamic> setsList;
    if (rawSets is List) {
      setsList = rawSets;
    } else if (map.containsKey('sets') || map.containsKey('reps')) {
      setsList = [
        {
          'setNumber': (map['sets'] ?? 1) as int,
          'reps': (map['reps'] ?? 0) as int,
          'weightKg': (map['weightKg'] ?? 0) as int,
        }
      ];
    } else {
      setsList = [];
    }
    return ExerciseExecution(
      exerciseName: map['exerciseName']?.toString() ?? '',
      sets: setsList
          .map((s) => ExerciseSet.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      perceivedEffort: map['perceivedEffort']?.toString(),
      completed: (map['completed'] ?? false) as bool,
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
  factory WorkoutSession.fromMap(Map<String, dynamic> map, {String? id}) {
    final timestamp = map['performedAt'] as Timestamp?;
    final rawExercises = map['exercises'] as List<dynamic>? ?? [];
    return WorkoutSession(
      id: id,
      workoutId: map['workoutId']?.toString() ?? '',
      workoutName: map['workoutName']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      performedAt: timestamp?.toDate(),
      exercises: rawExercises
          .map((e) => ExerciseExecution.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}