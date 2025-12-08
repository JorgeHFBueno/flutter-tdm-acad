import "package:cloud_firestore/cloud_firestore.dart";

class Workout {
  final String? id;
  final String name;
  final List<String> exercises;
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
      'exercises': exercises,
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

    return Workout(
      id: doc.id,
      name: data['name'] as String? ?? '',
      exercises: List<String>.from(data['exercises'] ?? const []),
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      createdAt: timestamp?.toDate(),
    );
  }
}