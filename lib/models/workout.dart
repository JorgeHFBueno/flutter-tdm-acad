import "package:cloud_firestore/cloud_firestore.dart";

import '../data/exercise_catalog.dart';

const int workoutSchemaVersion = 2;

List<String> normalizeMachineIds(Iterable<String> ids) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final rawId in ids) {
    final id = rawId.trim();
    if (id.isEmpty || isSyntheticWarmupExerciseId(id) || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    normalized.add(id);
  }
  return normalized;
}

void validateWorkoutFields({
  required String name,
  required String ownerUid,
  required Iterable<String> machineIds,
}) {
  if (name.trim().isEmpty) {
    throw ArgumentError('Workout name cannot be empty');
  }
  if (ownerUid.trim().isEmpty) {
    throw ArgumentError('Workout ownerUid cannot be empty');
  }
  if (normalizeMachineIds(machineIds).isEmpty) {
    throw ArgumentError('Workout must reference at least one machine');
  }
}

class Workout {
  final String? id;
  final String name;
  final String ownerUid;
  final List<String> machineIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  Workout({
    this.id,
    required this.name,
    required this.ownerUid,
    required List<String> machineIds,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = workoutSchemaVersion,
  }) : machineIds = normalizeMachineIds(machineIds);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'machineIds': machineIds,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Workout.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Workout.fromMap(data, id: doc.id);
  }

  factory Workout.fromMap(Map<String, dynamic> data, {String? id}) {
    return Workout(
      id: id,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      machineIds: (data['machineIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      schemaVersion: _readInt(
        data['schemaVersion'],
        fallback: workoutSchemaVersion,
      ),
    );
  }
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
