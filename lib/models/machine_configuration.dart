import 'machine_history.dart';

class ResolvedExerciseConfiguration {
  final int? configuredSets;
  final int configuredRepetitions;
  final double configuredWeightKg;
  final String observation;
  final bool hasMachine;
  final bool isComplete;

  const ResolvedExerciseConfiguration({
    required this.configuredSets,
    required this.configuredRepetitions,
    required this.configuredWeightKg,
    required this.observation,
    required this.hasMachine,
    required this.isComplete,
  });

  String get compactLabel {
    final setsText = configuredSets == null ? 'Sem meta' : '$configuredSets';
    return '$setsText x $configuredRepetitions - ${formatKg(configuredWeightKg)}';
  }
}

ResolvedExerciseConfiguration resolveExerciseConfiguration({
  MachineProfile? machine,
  double safeDefaultWeightKg = 10,
  int safeDefaultRepetitions = 10,
}) {
  final rawWeight = machine?.currentWeightKg;
  final resolvedWeight =
      rawWeight == null || rawWeight < 0 ? safeDefaultWeightKg : rawWeight;
  final resolvedRepetitions =
      machine?.currentRepetitions ?? safeDefaultRepetitions;

  return ResolvedExerciseConfiguration(
    configuredSets: machine?.currentSets,
    configuredRepetitions: resolvedRepetitions,
    configuredWeightKg: resolvedWeight,
    observation: machine?.observationText ?? '',
    hasMachine: machine != null,
    isComplete: machine?.currentSets != null &&
        machine?.currentRepetitions != null &&
        machine?.currentWeightKg != null,
  );
}

String formatKg(num value) => '${formatCompactNumber(value)} kg';

String formatCompactNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble == asDouble.roundToDouble()) {
    return asDouble.round().toString();
  }
  var text = asDouble.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.replaceAll('.', ',');
}

double? parsePositiveDecimal(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

int? parsePositiveInt(String value) {
  final trimmed = value.trim();
  if (trimmed.contains(',') || trimmed.contains('.')) return null;
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
