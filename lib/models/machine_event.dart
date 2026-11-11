// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

import 'machine_history.dart';
import 'workout_session.dart';

const int machineEventSchemaVersion = 1;

class MachineEventType {
  static const completion = 'completion';
  static const weightIncreased = 'weight_increased';
  static const setsIncreased = 'sets_increased';
  static const repetitionsIncreased = 'repetitions_increased';
  static const observationChanged = 'observation_changed';
  static const unknown = 'unknown';

  static const values = <String>{
    completion,
    weightIncreased,
    setsIncreased,
    repetitionsIncreased,
    observationChanged,
  };
}

class MachineEventSource {
  static const manual = 'manual';
  static const session = 'session';
  static const legacyCache = 'legacy_cache';
}

class MachineEventIncreaseType {
  static const weight = MachineIncreaseType.weight;
  static const sets = MachineIncreaseType.sets;
  static const repetitions = MachineIncreaseType.repetitions;
}

class MachineEvent {
  final String id;
  final String exerciseId;
  final String ownerUid;
  final String type;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final int schemaVersion;
  final String source;
  final String? sessionId;
  final String? workoutId;
  final String? workoutName;
  final String? perception;
  final int? configuredSets;
  final int? configuredRepetitions;
  final double? configuredWeightKg;
  final int? performedSetCount;
  final int? performedTotalRepetitions;
  final double? performedVolume;
  final bool? completed;
  final String? increaseType;
  final double? previousValue;
  final double? newValue;
  final String? previousObservation;
  final String? newObservation;
  final bool isDeleted;
  final DateTime? voidedAt;

  const MachineEvent({
    required this.id,
    required this.exerciseId,
    required this.ownerUid,
    required this.type,
    this.occurredAt,
    this.createdAt,
    this.schemaVersion = machineEventSchemaVersion,
    this.source = MachineEventSource.manual,
    this.sessionId,
    this.workoutId,
    this.workoutName,
    this.perception,
    this.configuredSets,
    this.configuredRepetitions,
    this.configuredWeightKg,
    this.performedSetCount,
    this.performedTotalRepetitions,
    this.performedVolume,
    this.completed,
    this.increaseType,
    this.previousValue,
    this.newValue,
    this.previousObservation,
    this.newObservation,
    this.isDeleted = false,
    this.voidedAt,
  });

  bool get isCompletion => type == MachineEventType.completion;

  bool get isIncrease =>
      type == MachineEventType.weightIncreased ||
      type == MachineEventType.setsIncreased ||
      type == MachineEventType.repetitionsIncreased;

  bool get isObservation => type == MachineEventType.observationChanged;

  String get completionSymbol => symbolForMachinePerception(perception);

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'ownerUid': ownerUid,
      'type': type,
      'schemaVersion': schemaVersion,
      'source': source,
      if (occurredAt != null) 'occurredAt': Timestamp.fromDate(occurredAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (sessionId != null) 'sessionId': sessionId,
      if (workoutId != null) 'workoutId': workoutId,
      if (workoutName != null) 'workoutName': workoutName,
      if (perception != null) 'perception': perception,
      if (configuredSets != null) 'configuredSets': configuredSets,
      if (configuredRepetitions != null)
        'configuredRepetitions': configuredRepetitions,
      if (configuredWeightKg != null) 'configuredWeightKg': configuredWeightKg,
      if (performedSetCount != null) 'performedSetCount': performedSetCount,
      if (performedTotalRepetitions != null)
        'performedTotalRepetitions': performedTotalRepetitions,
      if (performedVolume != null) 'performedVolume': performedVolume,
      if (completed != null) 'completed': completed,
      if (increaseType != null) 'increaseType': increaseType,
      if (previousValue != null) 'previousValue': previousValue,
      if (newValue != null) 'newValue': newValue,
      if (previousObservation != null)
        'previousObservation': previousObservation,
      if (newObservation != null) 'newObservation': newObservation,
      if (isDeleted) 'isDeleted': isDeleted,
      if (voidedAt != null) 'voidedAt': Timestamp.fromDate(voidedAt!),
    };
  }

  factory MachineEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    final type = _readKnownType(map['type']);
    return MachineEvent(
      id: id ?? map['id']?.toString() ?? '',
      exerciseId: map['exerciseId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      type: type,
      occurredAt: _readDate(map['occurredAt']),
      createdAt: _readDate(map['createdAt']),
      schemaVersion: readMachineInt(
        map['schemaVersion'],
        fallback: machineEventSchemaVersion,
      ),
      source: map['source']?.toString() ?? MachineEventSource.manual,
      sessionId: _readOptionalString(map['sessionId']),
      workoutId: _readOptionalString(map['workoutId']),
      workoutName: _readOptionalString(map['workoutName']),
      perception: PerceivedEffort.normalize(map['perception']?.toString()) ??
          _readOptionalString(map['perception']),
      configuredSets: _readOptionalPositiveInt(map['configuredSets']),
      configuredRepetitions:
          _readOptionalPositiveInt(map['configuredRepetitions']),
      configuredWeightKg:
          _readOptionalPositiveDouble(map['configuredWeightKg']),
      performedSetCount: _readOptionalNonNegativeInt(
        map['performedSetCount'],
      ),
      performedTotalRepetitions: _readOptionalNonNegativeInt(
        map['performedTotalRepetitions'],
      ),
      performedVolume: _readOptionalNonNegativeDouble(map['performedVolume']),
      completed: _readOptionalBool(map['completed']),
      increaseType: _readOptionalString(map['increaseType']),
      previousValue: _readOptionalDouble(map['previousValue']),
      newValue: _readOptionalDouble(map['newValue']),
      previousObservation: map.containsKey('previousObservation')
          ? map['previousObservation']?.toString()
          : null,
      newObservation: map.containsKey('newObservation')
          ? map['newObservation']?.toString()
          : null,
      isDeleted: _readBool(map['isDeleted']),
      voidedAt: _readDate(map['voidedAt']),
    );
  }
}

class MachineCompletionEventInput {
  final String exerciseId;
  final String exerciseName;
  final String category;
  final ExerciseExecution execution;

  const MachineCompletionEventInput({
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.execution,
  });
}

String machineEventTypeForIncrease(String increaseType) {
  switch (increaseType) {
    case MachineIncreaseType.weight:
      return MachineEventType.weightIncreased;
    case MachineIncreaseType.sets:
      return MachineEventType.setsIncreased;
    case MachineIncreaseType.repetitions:
      return MachineEventType.repetitionsIncreased;
    default:
      return MachineEventType.unknown;
  }
}

String symbolForMachinePerception(String? perception) {
  switch (PerceivedEffort.normalize(perception)) {
    case PerceivedEffort.light:
    case PerceivedEffort.adequate:
    case PerceivedEffort.highFatigue:
      return '|';
    case PerceivedEffort.reducedReps:
      return '!';
    case PerceivedEffort.reducedWeight:
      return '¡';
    case PerceivedEffort.skippedFatigue:
    case PerceivedEffort.skippedOther:
      return 'i';
    default:
      return '?';
  }
}

bool shouldCreateMachineCompletionEvent(ExerciseExecution execution) {
  if (execution.isWarmup || !execution.completed) return false;
  if (execution.status != ExerciseExecutionStatus.completed) return false;
  if ((execution.exerciseId ?? '').trim().isEmpty) return false;
  return PerceivedEffort.normalize(execution.perceivedEffort) != null;
}

bool shouldIncrementMachineCompletionCount(String? perception) {
  switch (PerceivedEffort.normalize(perception)) {
    case PerceivedEffort.light:
    case PerceivedEffort.adequate:
    case PerceivedEffort.highFatigue:
      return true;
    default:
      return false;
  }
}

int performedSetCount(ExerciseExecution execution) {
  if (PerceivedEffort.isSkipped(execution.perceivedEffort)) return 0;
  return execution.sets.length;
}

int performedTotalRepetitions(ExerciseExecution execution) {
  if (PerceivedEffort.isSkipped(execution.perceivedEffort)) return 0;
  return execution.sets.fold<int>(0, (total, set) => total + set.reps);
}

double performedVolume(ExerciseExecution execution) {
  if (PerceivedEffort.isSkipped(execution.perceivedEffort)) return 0;
  return calculateSetsVolume(execution.sets);
}

String deterministicIncreaseEventId(
  String exerciseId,
  MachineIncrease increase, {
  String prefix = 'increase',
}) {
  final fingerprint = [
    exerciseId.trim(),
    increase.type,
    _normalizeNumber(increase.value),
    increase.date.toUtc().toIso8601String(),
  ].join('|');
  return '${prefix}_${stableMachineEventFingerprint(fingerprint)}';
}

int compareMachineEventsDescending(MachineEvent a, MachineEvent b) {
  final occurred = _compareNullableDatesDescending(a.occurredAt, b.occurredAt);
  if (occurred != 0) return occurred;
  final created = _compareNullableDatesDescending(a.createdAt, b.createdAt);
  if (created != 0) return created;
  return b.id.compareTo(a.id);
}

List<MachineEvent> activeMachineEventsInHistoryOrder(
  Iterable<MachineEvent> events,
) {
  return events.where((event) => !event.isDeleted).toList()
    ..sort(compareMachineEventsDescending);
}

MachineEvent? latestMachineModification(Iterable<MachineEvent> events) {
  for (final event in activeMachineEventsInHistoryOrder(events)) {
    if (event.isIncrease &&
        event.previousValue != null &&
        event.newValue != null &&
        event.occurredAt != null) {
      return event;
    }
  }
  return null;
}

String formatLatestMachineModification(MachineEvent? event) {
  if (event == null || event.previousValue == null || event.newValue == null) {
    return 'Ul_Mod: --';
  }
  final type = switch (event.type) {
    MachineEventType.repetitionsIncreased => 'rep',
    MachineEventType.setsIncreased => 'ser',
    MachineEventType.weightIncreased => 'peso',
    _ => null,
  };
  final date = event.occurredAt;
  if (type == null || date == null) return 'Ul_Mod: --';
  final difference = event.newValue! - event.previousValue!;
  final sign = difference >= 0 ? '+' : '';
  final value = _normalizeNumber(difference).replaceAll('.', ',');
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return 'Ul_Mod: $type | $sign$value | $day/$month';
}

int eligibleCompletionEventCount(Iterable<MachineEvent> events) {
  return events.where((event) {
    if (event.isDeleted || !event.isCompletion) return false;
    return shouldIncrementMachineCompletionCount(event.perception);
  }).length;
}

bool hasConsistentCompletionBaseline({
  required MachineProfile machine,
  required Iterable<MachineEvent> events,
}) {
  final baseline = machine.eventTrackingBaselineCount ?? 0;
  return machine.completionCount ==
      baseline + eligibleCompletionEventCount(events);
}

String stableMachineEventFingerprint(String value) {
  const int fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int _compareNullableDatesDescending(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

String _normalizeNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  var text = value.toStringAsFixed(6);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

String _readKnownType(Object? value) {
  final type = value?.toString() ?? '';
  return MachineEventType.values.contains(type)
      ? type
      : MachineEventType.unknown;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String? _readOptionalString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _readOptionalPositiveInt(Object? value) {
  final parsed = readMachineInt(value, fallback: -1);
  return parsed > 0 ? parsed : null;
}

int? _readOptionalNonNegativeInt(Object? value) {
  if (value == null) return null;
  final parsed = readMachineInt(value, fallback: -1);
  return parsed >= 0 ? parsed : null;
}

double? _readOptionalPositiveDouble(Object? value) {
  if (value == null) return null;
  final parsed = readMachineDouble(value, fallback: -1);
  return parsed > 0 ? parsed : null;
}

double? _readOptionalNonNegativeDouble(Object? value) {
  if (value == null) return null;
  final parsed = readMachineDouble(value, fallback: -1);
  return parsed >= 0 ? parsed : null;
}

double? _readOptionalDouble(Object? value) {
  if (value == null) return null;
  return readMachineDouble(value);
}

bool? _readOptionalBool(Object? value) {
  if (value == null) return null;
  return _readBool(value);
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}
