import 'workout_session.dart';

/// Cardio is logged as one entry with minutes and km (one activity per day).

/// "5,5" or "5.5" -> 5.5; empty or invalid -> null.
double? parseDecimal(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value == null || value < 0 ? null : value;
}

String _decimal(double value) {
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return text.replaceAll('.', ',');
}

/// Pace in min/km ("6:05 min/km"), or null without both values.
String? formatPace(double? minutes, double? km) {
  if (minutes == null || km == null || minutes <= 0 || km <= 0) return null;
  final totalSeconds = (minutes * 60 / km).round();
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '${totalSeconds ~/ 60}:$seconds min/km';
}

/// "30 min · 5 km · 6:00 min/km".
String formatCardioSet(ExerciseSet set) {
  final parts = <String>[
    if (set.durationMinutes != null) '${_decimal(set.durationMinutes!)} min',
    if (set.distanceKm != null) '${_decimal(set.distanceKm!)} km',
  ];
  final pace = formatPace(set.durationMinutes, set.distanceKm);
  if (pace != null) parts.add(pace);
  return parts.isEmpty ? 'sem dados' : parts.join(' · ');
}

/// Entries the workout finish does not need to ask about: when a cardio
/// activity was done, the other cardio options were replaced by it.
/// Returns originalIndex -> skip reason.
Map<int, String> autoReplacedCardio(
  Iterable<({int originalIndex, ExerciseExecution execution})> entries,
) {
  final list = entries.toList();
  final didCardio = list.any(
    (e) => e.execution.isCardio && e.execution.hasRegisteredWork,
  );
  if (!didCardio) return const {};
  return {
    for (final e in list)
      if (e.execution.isCardio && !e.execution.hasRegisteredWork)
        e.originalIndex: PerceivedEffort.skippedReplaced,
  };
}
