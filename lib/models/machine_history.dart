// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/exercise_catalog.dart';

class MachineIncreaseType {
  static const weight = 'weight';
  static const sets = 'sets';
  static const repetitions = 'repetitions';

  static const values = <String>{weight, sets, repetitions};

  static String labelFor(String type) {
    switch (type) {
      case weight:
        return 'Peso';
      case sets:
        return 'Serie';
      case repetitions:
        return 'Repeticoes';
      default:
        return type;
    }
  }
}

class MachineIncrease {
  final String type;
  final double value;
  final DateTime date;
  final String? eventId;

  const MachineIncrease({
    required this.type,
    required this.value,
    required this.date,
    this.eventId,
  });

  bool get isValid {
    if (!MachineIncreaseType.values.contains(type) || value <= 0) return false;
    if (type == MachineIncreaseType.sets ||
        type == MachineIncreaseType.repetitions) {
      return value == value.roundToDouble();
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'value': value,
        'date': Timestamp.fromDate(date),
        if (eventId != null) 'eventId': eventId,
      };

  factory MachineIncrease.fromMap(Map<String, dynamic> map) {
    final timestamp = map['date'];
    return MachineIncrease(
      type: map['type']?.toString() ?? '',
      value: readMachineDouble(map['value']),
      date: timestamp is Timestamp ? timestamp.toDate() : DateTime(1970),
      eventId: map['eventId']?.toString(),
    );
  }

  MachineIncrease copyWith({String? eventId}) {
    return MachineIncrease(
      type: type,
      value: value,
      date: date,
      eventId: eventId ?? this.eventId,
    );
  }
}

class MachineProfile {
  final String exerciseId;
  final String exerciseName;
  final String category;
  final String ownerUid;
  final String? catalogScientificName;
  final String? catalogType;
  final String? observation;
  final int completionCount;
  final MachineIncrease? lastIncrease;
  final MachineIncrease? previousIncrease;
  final int? currentSets;
  final int? currentRepetitions;
  final double? currentWeightKg;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;
  final DateTime? eventTrackingStartedAt;
  final int? eventTrackingBaselineCount;
  final DateTime? increaseEventsInitializedAt;
  final int? eventSchemaVersion;

  const MachineProfile({
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.ownerUid,
    this.catalogScientificName,
    this.catalogType,
    this.observation,
    this.completionCount = 0,
    this.lastIncrease,
    this.previousIncrease,
    this.currentSets,
    this.currentRepetitions,
    this.currentWeightKg,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = 1,
    this.eventTrackingStartedAt,
    this.eventTrackingBaselineCount,
    this.increaseEventsInitializedAt,
    this.eventSchemaVersion,
  });

  String get observationText => observation ?? '';

  MachineProfile copyWith({
    String? exerciseName,
    String? category,
    String? ownerUid,
    Object? catalogScientificName = _notProvided,
    Object? catalogType = _notProvided,
    Object? observation = _notProvided,
    int? completionCount,
    MachineIncrease? lastIncrease,
    MachineIncrease? previousIncrease,
    bool clearLastIncrease = false,
    bool clearPreviousIncrease = false,
    Object? currentSets = _notProvided,
    Object? currentRepetitions = _notProvided,
    Object? currentWeightKg = _notProvided,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
    Object? eventTrackingStartedAt = _notProvided,
    Object? eventTrackingBaselineCount = _notProvided,
    Object? increaseEventsInitializedAt = _notProvided,
    Object? eventSchemaVersion = _notProvided,
  }) {
    return MachineProfile(
      exerciseId: exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      category: category ?? this.category,
      ownerUid: ownerUid ?? this.ownerUid,
      catalogScientificName: catalogScientificName == _notProvided
          ? this.catalogScientificName
          : catalogScientificName as String?,
      catalogType: catalogType == _notProvided
          ? this.catalogType
          : catalogType as String?,
      observation: observation == _notProvided
          ? this.observation
          : observation as String?,
      completionCount: completionCount ?? this.completionCount,
      lastIncrease:
          clearLastIncrease ? null : lastIncrease ?? this.lastIncrease,
      previousIncrease: clearPreviousIncrease
          ? null
          : previousIncrease ?? this.previousIncrease,
      currentSets:
          currentSets == _notProvided ? this.currentSets : currentSets as int?,
      currentRepetitions: currentRepetitions == _notProvided
          ? this.currentRepetitions
          : currentRepetitions as int?,
      currentWeightKg: currentWeightKg == _notProvided
          ? this.currentWeightKg
          : currentWeightKg as double?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      eventTrackingStartedAt: eventTrackingStartedAt == _notProvided
          ? this.eventTrackingStartedAt
          : eventTrackingStartedAt as DateTime?,
      eventTrackingBaselineCount: eventTrackingBaselineCount == _notProvided
          ? this.eventTrackingBaselineCount
          : eventTrackingBaselineCount as int?,
      increaseEventsInitializedAt: increaseEventsInitializedAt == _notProvided
          ? this.increaseEventsInitializedAt
          : increaseEventsInitializedAt as DateTime?,
      eventSchemaVersion: eventSchemaVersion == _notProvided
          ? this.eventSchemaVersion
          : eventSchemaVersion as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'category': category,
        'ownerUid': ownerUid,
        'completionCount': completionCount,
        'schemaVersion': schemaVersion,
        if (observation != null) 'observation': observation,
        if (lastIncrease != null) 'lastIncrease': lastIncrease!.toMap(),
        if (previousIncrease != null)
          'previousIncrease': previousIncrease!.toMap(),
        if (currentSets != null) 'currentSets': currentSets,
        if (currentRepetitions != null)
          'currentRepetitions': currentRepetitions,
        if (currentWeightKg != null) 'currentWeightKg': currentWeightKg,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (eventTrackingStartedAt != null)
          'eventTrackingStartedAt': Timestamp.fromDate(eventTrackingStartedAt!),
        if (eventTrackingBaselineCount != null)
          'eventTrackingBaselineCount': eventTrackingBaselineCount,
        if (increaseEventsInitializedAt != null)
          'increaseEventsInitializedAt':
              Timestamp.fromDate(increaseEventsInitializedAt!),
        if (eventSchemaVersion != null)
          'eventSchemaVersion': eventSchemaVersion,
      };

  factory MachineProfile.fromMap(Map<String, dynamic> map, {String? id}) {
    final exerciseId = map['exerciseId']?.toString() ?? id ?? '';
    final exerciseName = map['exerciseName']?.toString() ?? '';
    final catalogItem = findExerciseCatalogItemById(exerciseId) ??
        findExerciseCatalogItem(exerciseName);
    return MachineProfile(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      category: catalogItem?.category ?? map['category']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      completionCount: readMachineInt(map['completionCount']),
      observation: map.containsKey('observation')
          ? map['observation']?.toString()
          : null,
      lastIncrease: _readIncrease(map['lastIncrease']),
      previousIncrease: _readIncrease(map['previousIncrease']),
      currentSets: _readOptionalPositiveInt(map['currentSets']),
      currentRepetitions: _readOptionalPositiveInt(map['currentRepetitions']),
      currentWeightKg: _readOptionalPositiveDouble(map['currentWeightKg']),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      schemaVersion: readMachineInt(map['schemaVersion'], fallback: 1),
      eventTrackingStartedAt: _readDate(map['eventTrackingStartedAt']),
      eventTrackingBaselineCount: map.containsKey('eventTrackingBaselineCount')
          ? readMachineInt(map['eventTrackingBaselineCount'])
          : null,
      increaseEventsInitializedAt: _readDate(
        map['increaseEventsInitializedAt'],
      ),
      eventSchemaVersion: map.containsKey('eventSchemaVersion')
          ? readMachineInt(map['eventSchemaVersion'], fallback: 1)
          : null,
    );
  }
}

MachineProfile applyNewIncrease(
  MachineProfile machine,
  MachineIncrease increase,
) {
  return applyIncreaseToCurrentConfiguration(machine, increase).copyWith(
    lastIncrease: increase,
    previousIncrease: machine.lastIncrease,
    clearPreviousIncrease: machine.lastIncrease == null,
  );
}

MachineProfile applyIncreaseToCurrentConfiguration(
  MachineProfile machine,
  MachineIncrease increase,
) {
  switch (increase.type) {
    case MachineIncreaseType.weight:
      return machine.copyWith(currentWeightKg: increase.value);
    case MachineIncreaseType.sets:
      return machine.copyWith(currentSets: increase.value.round());
    case MachineIncreaseType.repetitions:
      return machine.copyWith(currentRepetitions: increase.value.round());
    default:
      return machine;
  }
}

Map<String, dynamic> applyObservationPatch(
  Map<String, dynamic> existing, {
  required String exerciseId,
  required String exerciseName,
  required String category,
  required String ownerUid,
  required String observation,
  Object? updatedAt,
}) {
  return {
    ...existing,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'category': category,
    'ownerUid': ownerUid,
    'completionCount': readMachineInt(existing['completionCount']),
    'schemaVersion': readMachineInt(existing['schemaVersion'], fallback: 1),
    'observation': observation,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

Map<String, dynamic> applyCurrentConfigPatch(
  Map<String, dynamic> existing, {
  int? currentSets,
  int? currentRepetitions,
  double? currentWeightKg,
  Object? updatedAt,
}) {
  return {
    ...existing,
    'currentSets': currentSets,
    'currentRepetitions': currentRepetitions,
    'currentWeightKg': currentWeightKg,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

Map<String, dynamic> applyIncreasePatch(
  Map<String, dynamic> existing,
  MachineIncrease increase, {
  Object? updatedAt,
}) {
  final patch = {
    ...existing,
    'lastIncrease': increase.toMap(),
    'previousIncrease': existing['lastIncrease'],
    'completionCount': readMachineInt(existing['completionCount']),
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
  switch (increase.type) {
    case MachineIncreaseType.weight:
      patch['currentWeightKg'] = increase.value;
      break;
    case MachineIncreaseType.sets:
      patch['currentSets'] = increase.value.round();
      break;
    case MachineIncreaseType.repetitions:
      patch['currentRepetitions'] = increase.value.round();
      break;
  }
  return patch;
}

Map<String, dynamic> applyCompletionIncrementPatch(
  Map<String, dynamic> existing, {
  required String exerciseId,
  required String exerciseName,
  required String category,
  required String ownerUid,
  Object? updatedAt,
}) {
  return {
    ...existing,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'category': category,
    'ownerUid': ownerUid,
    'completionCount': readMachineInt(existing['completionCount']) + 1,
    'schemaVersion': readMachineInt(existing['schemaVersion'], fallback: 1),
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

String buildCompletionMarks(int count) {
  if (count <= 0) return '';
  final blocks = <String>[];
  var remaining = count;
  while (remaining > 0) {
    final blockSize = remaining >= 5 ? 5 : remaining;
    blocks.add('|' * blockSize);
    remaining -= blockSize;
  }
  return blocks.join(' ');
}

String buildMachineEventHistoryLine(
  int baselineCount,
  Iterable<String> eventSymbols,
) {
  final parts = <String>[];
  final baseline = buildCompletionMarks(baselineCount);
  if (baseline.isNotEmpty) parts.add(baseline);
  parts.addAll(eventSymbols.where((symbol) => symbol.trim().isNotEmpty));
  return parts.join(' ');
}

String formatMachineIncrease(MachineIncrease? increase,
    {bool includeYear = false}) {
  if (increase == null) return 'Nao informado';
  final date = includeYear
      ? '${_twoDigits(increase.date.day)}/${_twoDigits(increase.date.month)}/${increase.date.year}'
      : '${_twoDigits(increase.date.day)}/${_twoDigits(increase.date.month)}';
  return '$date - Aumentou para ${formatIncreaseValue(increase)}';
}

String formatIncreaseValue(MachineIncrease increase) {
  switch (increase.type) {
    case MachineIncreaseType.weight:
      return '${_formatPtNumber(increase.value)} kg';
    case MachineIncreaseType.sets:
      final value = increase.value.round();
      return '$value ${value == 1 ? 'serie' : 'series'}';
    case MachineIncreaseType.repetitions:
      final value = increase.value.round();
      return '$value ${value == 1 ? 'repeticao' : 'repeticoes'}';
    default:
      return _formatPtNumber(increase.value);
  }
}

MachineIncrease? latestValidMachineIncrease(MachineProfile machine) {
  final increases = [
    machine.lastIncrease,
    machine.previousIncrease,
  ].whereType<MachineIncrease>().where((increase) => increase.isValid).toList();
  if (increases.isEmpty) return null;
  increases.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final aSlot = identical(a, machine.lastIncrease) ? 0 : 1;
    final bSlot = identical(b, machine.lastIncrease) ? 0 : 1;
    return aSlot.compareTo(bSlot);
  });
  return increases.first;
}

String formatLatestMachineIncrease(MachineIncrease? increase) {
  if (increase == null) return 'Ul_Mod: --';
  final date =
      '${_twoDigits(increase.date.day)}/${_twoDigits(increase.date.month)}';
  final type = switch (increase.type) {
    MachineIncreaseType.repetitions => 'rep',
    MachineIncreaseType.sets => 'ser',
    MachineIncreaseType.weight => 'peso',
    _ => null,
  };
  if (type == null) return 'Ul_Mod: --';
  final sign = increase.value >= 0 ? '+' : '';
  return 'Ul_Mod: $type | $sign${_formatPtNumber(increase.value)} | $date';
}

String _formatPtNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  var text = value.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.replaceAll('.', ',');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

MachineIncrease? _readIncrease(Object? value) {
  if (value is Map) {
    return MachineIncrease.fromMap(Map<String, dynamic>.from(value));
  }
  return null;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

int readMachineInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double readMachineDouble(Object? value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ??
      fallback;
}

int? _readOptionalPositiveInt(Object? value) {
  if (value == null) return null;
  final parsed = readMachineInt(value, fallback: -1);
  return parsed > 0 ? parsed : null;
}

double? _readOptionalPositiveDouble(Object? value) {
  if (value == null) return null;
  final parsed = readMachineDouble(value, fallback: -1);
  return parsed > 0 ? parsed : null;
}

const Object _notProvided = Object();
