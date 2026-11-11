import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseSet {
  final int setNumber;
  final int reps;
  final double weightKg;

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
      setNumber: _readInt(map['setNumber']),
      reps: _readInt(map['reps']),
      weightKg: _readDouble(map['weightKg']),
    );
  }
}

class PerceivedEffortOption {
  final String value;
  final String label;
  final bool allowsEmptySets;

  const PerceivedEffortOption({
    required this.value,
    required this.label,
    required this.allowsEmptySets,
  });
}

class PerceivedEffort {
  static const light = 'light';
  static const adequate = 'adequate';
  static const highFatigue = 'high_fatigue';
  static const reducedReps = 'reduced_reps';
  static const reducedWeight = 'reduced_weight';
  static const skippedFatigue = 'skipped_fatigue';
  static const skippedOther = 'skipped_other';

  static const legacyAdequate = 'certo';
  static const legacyLight = 'leve';
  static const legacyFatigue = 'fadiga';

  static const options = <PerceivedEffortOption>[
    PerceivedEffortOption(
      value: light,
      label: 'Leve',
      allowsEmptySets: false,
    ),
    PerceivedEffortOption(
      value: adequate,
      label: 'Adequado',
      allowsEmptySets: false,
    ),
    PerceivedEffortOption(
      value: highFatigue,
      label: 'Fadiga intensa',
      allowsEmptySets: false,
    ),
    PerceivedEffortOption(
      value: reducedReps,
      label: 'Concluído com menos repetições',
      allowsEmptySets: false,
    ),
    PerceivedEffortOption(
      value: reducedWeight,
      label: 'Concluído com menos carga',
      allowsEmptySets: false,
    ),
    PerceivedEffortOption(
      value: skippedFatigue,
      label: 'Não realizado por fadiga',
      allowsEmptySets: true,
    ),
    PerceivedEffortOption(
      value: skippedOther,
      label: 'Não realizado por outro motivo',
      allowsEmptySets: true,
    ),
  ];

  static String labelFor(String? value) {
    switch (value) {
      case light:
      case legacyLight:
        return 'Leve';
      case adequate:
      case legacyAdequate:
        return 'Adequado';
      case highFatigue:
      case legacyFatigue:
        return 'Fadiga intensa';
      case reducedReps:
        return 'Concluído com menos repetições';
      case reducedWeight:
        return 'Concluído com menos carga';
      case skippedFatigue:
        return 'Não realizado por fadiga';
      case skippedOther:
        return 'Não realizado por outro motivo';
      case null:
        return 'Sem percepção';
      default:
        return value;
    }
  }

  static bool allowsEmptySets(String? value) {
    return value == skippedFatigue || value == skippedOther;
  }

  static bool isSkipped(String? value) {
    return value == skippedFatigue || value == skippedOther;
  }

  static String? normalize(String? value) {
    switch (value) {
      case legacyLight:
        return light;
      case legacyAdequate:
        return adequate;
      case legacyFatigue:
        return highFatigue;
      case light:
      case adequate:
      case highFatigue:
      case reducedReps:
      case reducedWeight:
      case skippedFatigue:
      case skippedOther:
        return value;
      default:
        return null;
    }
  }
}

class ExerciseExecutionStatus {
  static const pending = 'pending';
  static const completed = 'completed';
  static const partial = 'partial';
  static const skipped = 'skipped';

  static const values = <String>{pending, completed, partial, skipped};

  static String normalize(String? value, {required bool completed}) {
    if (value != null && values.contains(value)) return value;
    return completed ? ExerciseExecutionStatus.completed : pending;
  }
}

class ExerciseExecution {
  final String? exerciseId;
  final String exerciseName;
  final String? scientificName;
  final String? category;
  final String? type;
  final List<ExerciseSet> sets;
  final String? perceivedEffort;
  final bool completed;
  final bool isWarmup;
  final String? targetExerciseId;
  final String? targetExerciseName;
  final int? configuredSets;
  final int? configuredRepetitions;
  final double? configuredWeightKg;
  final String? observationSnapshot;
  final String status;

  ExerciseExecution({
    this.exerciseId,
    required this.exerciseName,
    this.scientificName,
    this.category,
    this.type,
    required this.sets,
    this.perceivedEffort,
    this.completed = false,
    this.isWarmup = false,
    this.targetExerciseId,
    this.targetExerciseName,
    this.configuredSets,
    this.configuredRepetitions,
    this.configuredWeightKg,
    this.observationSnapshot,
    String? status,
  }) : status = ExerciseExecutionStatus.normalize(
          status,
          completed: completed,
        );

  ExerciseExecution copyWith({
    String? exerciseId,
    String? exerciseName,
    Object? scientificName = _notProvided,
    Object? category = _notProvided,
    Object? type = _notProvided,
    List<ExerciseSet>? sets,
    String? perceivedEffort,
    bool? completed,
    bool? isWarmup,
    String? targetExerciseId,
    String? targetExerciseName,
    Object? configuredSets = _notProvided,
    Object? configuredRepetitions = _notProvided,
    Object? configuredWeightKg = _notProvided,
    Object? observationSnapshot = _notProvided,
    String? status,
  }) {
    return ExerciseExecution(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      scientificName: scientificName == _notProvided
          ? this.scientificName
          : scientificName as String?,
      category: category == _notProvided ? this.category : category as String?,
      type: type == _notProvided ? this.type : type as String?,
      sets: sets ?? this.sets,
      perceivedEffort: perceivedEffort ?? this.perceivedEffort,
      completed: completed ?? this.completed,
      isWarmup: isWarmup ?? this.isWarmup,
      targetExerciseId: targetExerciseId ?? this.targetExerciseId,
      targetExerciseName: targetExerciseName ?? this.targetExerciseName,
      configuredSets: configuredSets == _notProvided
          ? this.configuredSets
          : configuredSets as int?,
      configuredRepetitions: configuredRepetitions == _notProvided
          ? this.configuredRepetitions
          : configuredRepetitions as int?,
      configuredWeightKg: configuredWeightKg == _notProvided
          ? this.configuredWeightKg
          : configuredWeightKg as double?,
      observationSnapshot: observationSnapshot == _notProvided
          ? this.observationSnapshot
          : observationSnapshot as String?,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        if (scientificName != null) 'scientificName': scientificName,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        'sets': sets.map((s) => s.toMap()).toList(),
        'perceivedEffort': perceivedEffort,
        'completed': completed,
        'isWarmup': isWarmup,
        'targetExerciseId': targetExerciseId,
        'targetExerciseName': targetExerciseName,
        if (configuredSets != null) 'configuredSets': configuredSets,
        if (configuredRepetitions != null)
          'configuredRepetitions': configuredRepetitions,
        if (configuredWeightKg != null)
          'configuredWeightKg': configuredWeightKg,
        if (observationSnapshot != null)
          'observationSnapshot': observationSnapshot,
        'status': status,
      };

  factory ExerciseExecution.fromMap(Map<String, dynamic> map) {
    final rawSets = map['sets'];
    final List<dynamic> setsList;
    if (rawSets is List) {
      setsList = rawSets;
    } else if (map.containsKey('sets') || map.containsKey('reps')) {
      final setNumber = _readInt(map['sets']);
      setsList = [
        {
          'setNumber': setNumber == 0 ? 1 : setNumber,
          'reps': _readInt(map['reps']),
          'weightKg': _readDouble(map['weightKg']),
        }
      ];
    } else {
      setsList = [];
    }
    return ExerciseExecution(
      exerciseId: _readOptionalString(map['exerciseId']),
      exerciseName: map['exerciseName']?.toString() ?? '',
      scientificName: _readOptionalString(map['scientificName']),
      category: _readOptionalString(map['category']),
      type: _readOptionalString(map['type']),
      sets: setsList
          .map((s) => ExerciseSet.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      perceivedEffort: map['perceivedEffort']?.toString(),
      completed: _readBool(map['completed']),
      isWarmup: _readBool(map['isWarmup']),
      targetExerciseId: _readOptionalString(map['targetExerciseId']),
      targetExerciseName: _readOptionalString(map['targetExerciseName']),
      configuredSets: _readOptionalPositiveInt(map['configuredSets']),
      configuredRepetitions:
          _readOptionalPositiveInt(map['configuredRepetitions']),
      configuredWeightKg:
          _readOptionalPositiveDouble(map['configuredWeightKg']),
      observationSnapshot: _readOptionalString(map['observationSnapshot']),
      status: _readOptionalString(map['status']),
    );
  }

  double get volume => calculateSetsVolume(sets);

  bool get hasRegisteredWork => sets.isNotEmpty;

  bool get isGoalReached => isExerciseGoalReached(this);
}

class WorkoutSessionStatus {
  static const inProgress = 'inProgress';
  static const completed = 'completed';
  static const abandoned = 'abandoned';

  static const values = <String>{inProgress, completed, abandoned};

  static String normalize(String? value, {DateTime? completedAt}) {
    if (value != null && values.contains(value)) return value;
    return completedAt != null ? completed : '';
  }
}

const int workoutSessionSchemaVersion = 2;

class WorkoutSession {
  final String? id;
  final String workoutId;
  final String workoutName;
  final String ownerUid;
  final DateTime? performedAt;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final List<ExerciseExecution> exercises;
  final bool machineHistoryCountApplied;
  final String status;
  final String executionPhase;
  final String? activeExerciseId;
  final int? activeOriginalIndex;
  final int schemaVersion;

  WorkoutSession({
    this.id,
    required this.workoutId,
    required this.workoutName,
    required this.ownerUid,
    this.performedAt,
    this.startAt,
    this.endAt,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    required this.exercises,
    this.machineHistoryCountApplied = false,
    String? status,
    this.executionPhase = 'warmup',
    this.activeExerciseId,
    this.activeOriginalIndex,
    this.schemaVersion = workoutSessionSchemaVersion,
  }) : status = status ?? '';

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'workoutName': workoutName,
      'ownerUid': ownerUid,
      if (performedAt != null) 'performedAt': Timestamp.fromDate(performedAt!),
      'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
      'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'machineHistoryCountApplied': machineHistoryCountApplied,
      if (status.isNotEmpty) 'status': status,
      'executionPhase': executionPhase,
      if (activeExerciseId != null) 'activeExerciseId': activeExerciseId,
      if (activeOriginalIndex != null)
        'activeOriginalIndex': activeOriginalIndex,
      'schemaVersion': schemaVersion,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map, {String? id}) {
    final timestamp = map['performedAt'] as Timestamp?;
    final startAtTimestamp = map['startAt'] as Timestamp?;
    final endAtTimestamp = map['endAt'] as Timestamp?;
    final createdAtTimestamp = map['createdAt'] as Timestamp?;
    final updatedAtTimestamp = map['updatedAt'] as Timestamp?;
    final completedAtTimestamp = map['completedAt'] as Timestamp?;
    final rawExercises = map['exercises'] as List<dynamic>? ?? [];
    final completedAt =
        completedAtTimestamp?.toDate() ?? endAtTimestamp?.toDate();
    return WorkoutSession(
      id: id,
      workoutId: map['workoutId']?.toString() ?? '',
      workoutName: map['workoutName']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      performedAt: timestamp?.toDate(),
      startAt: startAtTimestamp?.toDate(),
      endAt: endAtTimestamp?.toDate(),
      createdAt: createdAtTimestamp?.toDate(),
      updatedAt: updatedAtTimestamp?.toDate(),
      completedAt: completedAt,
      exercises: rawExercises
          .whereType<Map>()
          .map((e) => ExerciseExecution.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      machineHistoryCountApplied: _readBool(map['machineHistoryCountApplied']),
      status: WorkoutSessionStatus.normalize(
        map['status']?.toString(),
        completedAt: completedAt,
      ),
      executionPhase: map['executionPhase']?.toString() ?? 'warmup',
      activeExerciseId: _readOptionalString(map['activeExerciseId']),
      activeOriginalIndex: _readOptionalPositiveOrZeroInt(
        map['activeOriginalIndex'],
      ),
      schemaVersion: _readIntWithFallback(
        map['schemaVersion'],
        workoutSessionSchemaVersion,
      ),
    );
  }

  bool get isInProgress => status == WorkoutSessionStatus.inProgress;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0;
}

int? _readOptionalPositiveInt(Object? value) {
  final parsed = _readInt(value);
  return parsed > 0 ? parsed : null;
}

int? _readOptionalPositiveOrZeroInt(Object? value) {
  final parsed = _readInt(value);
  return parsed >= 0 ? parsed : null;
}

int _readIntWithFallback(Object? value, int fallback) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double? _readOptionalPositiveDouble(Object? value) {
  final parsed = _readDouble(value);
  return parsed > 0 ? parsed : null;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

String? _readOptionalString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

double calculateSetsVolume(Iterable<ExerciseSet> sets) {
  return sets.fold<double>(
    0,
    (total, set) => total + set.reps * set.weightKg,
  );
}

double calculateSessionVolume(WorkoutSession session) {
  return session.exercises.fold<double>(
    0,
    (total, exercise) => total + exercise.volume,
  );
}

bool isExerciseGoalReached(ExerciseExecution execution) {
  final targetSets = execution.configuredSets;
  final targetRepetitions = execution.configuredRepetitions;
  final targetWeight = execution.configuredWeightKg;
  if (targetSets == null ||
      targetSets <= 0 ||
      targetRepetitions == null ||
      targetRepetitions <= 0 ||
      targetWeight == null ||
      targetWeight <= 0) {
    return false;
  }
  final qualifyingSets = execution.sets.where((set) {
    return set.reps >= targetRepetitions && set.weightKg >= targetWeight;
  }).length;
  return qualifyingSets >= targetSets;
}

const Object _notProvided = Object();
