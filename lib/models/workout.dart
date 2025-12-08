import "package:cloud_firestore/cloud_firestore.dart";

class WorkoutExercise {
  final String name;
  final int defaultWeightKg;

  WorkoutExercise({
    required this.name,
    required this.defaultWeightKg,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'defaultWeightKg': defaultWeightKg,
  };

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      name: map['name']?.toString() ?? '',
      defaultWeightKg: (map['defaultWeightKg'] ?? 0) as int,
    );
  }
}

class Workout {
  final String? id;
  final String name;
  final List<WorkoutExercise> exercises;
  final String ownerUid;
  final String ownerName;
  final DateTime? createdAt;

  Workout({
    this.id,
    required this.name,
    required this.exercises,
    required this.ownerUid,
    required this.ownerName,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
  factory Workout.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['createdAt'] as Timestamp?;
    final exercisesData = data['exercises'] as List<dynamic>? ?? const [];

    final exercises = exercisesData.map((exercise) {
      if (exercise is Map<String, dynamic>) {
        return WorkoutExercise.fromMap(exercise);
      }
      // Backward compatibility with old format (list of strings)
      if (exercise is String) {
        return WorkoutExercise(name: exercise, defaultWeightKg: 10);
      }
      return WorkoutExercise(name: exercise.toString(), defaultWeightKg: 10);
    }).toList();

    return Workout(
      id: doc.id,
      name: data['name'] as String? ?? '',
      exercises: exercises,
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      createdAt: timestamp?.toDate(),
    );
  }
}