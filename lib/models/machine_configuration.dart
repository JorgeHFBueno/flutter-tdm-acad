import 'machine_catalog_item.dart';
import 'machine_history.dart';

class ResolvedExerciseConfiguration {
  final int? configuredSets;
  final int configuredRepetitions;
  final double configuredWeightKg;
  final String observation;
  final bool hasMachine;
  final bool isComplete;
  final bool loadPerSide;
  final bool bodyweight;
  final bool cardio;

  const ResolvedExerciseConfiguration({
    required this.configuredSets,
    required this.configuredRepetitions,
    required this.configuredWeightKg,
    required this.observation,
    required this.hasMachine,
    required this.isComplete,
    this.loadPerSide = false,
    this.bodyweight = false,
    this.cardio = false,
  });

  String get compactLabel {
    if (cardio) return cardioLabel;
    final setsText = configuredSets == null ? 'Sem meta' : '$configuredSets';
    return '$setsText x $configuredRepetitions - '
        '${bodyweight ? bodyweightLabel : formatKg(configuredWeightKg, perSide: loadPerSide)}';
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
    loadPerSide: machine?.catalogLoadPerSide ?? false,
    bodyweight: isBodyweightType(machine?.catalogType),
    cardio: machine?.category == MachineCatalogCategory.cardio,
  );
}

const cardioLabel = 'cardio - minutos e km';

const bodyweightLabel = 'peso do corpo';

/// Bodyweight exercises (catalog type peso_corporal) record reps only.
bool isBodyweightType(String? type) => type == MachineCatalogType.pesoCorporal;

/// "peso do corpo" for bodyweight sets without extra load, else [formatKg].
String formatSetLoad(num value,
        {bool perSide = false, bool bodyweight = false}) =>
    bodyweight && value <= 0
        ? bodyweightLabel
        : formatKg(value, perSide: perSide);

/// "15 kg", or "15 kg/lado" when the load is entered per side.
String formatKg(num value, {bool perSide = false}) =>
    '${formatCompactNumber(value)} kg${perSide ? '/lado' : ''}';

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
