import 'package:firebased/models/cardio.dart';
import 'package:firebased/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExerciseExecution cardio(String id, {ExerciseSet? set}) => ExerciseExecution(
        exerciseId: id,
        exerciseName: id,
        category: 'cardio',
        sets: [if (set != null) set],
      );
  ExerciseSet entry(double? minutes, double? km) => ExerciseSet(
        setNumber: 1,
        reps: 0,
        weightKg: 0,
        durationMinutes: minutes,
        distanceKm: km,
      );

  test('parses decimals with comma or dot', () {
    expect(parseDecimal('5,5'), 5.5);
    expect(parseDecimal(' 30 '), 30);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('-1'), isNull);
  });

  test('formats minutes, km and pace', () {
    expect(formatCardioSet(entry(30, 5)), '30 min · 5 km · 6:00 min/km');
    expect(
        formatCardioSet(entry(42.5, 6.8)), '42,5 min · 6,8 km · 6:15 min/km');
    expect(formatCardioSet(entry(20, null)), '20 min');
    expect(formatPace(30, 0), isNull);
  });

  test('cardio set round trip keeps minutes and km, no volume', () {
    final restored = ExerciseSet.fromMap(entry(30, 5.2).toMap());
    expect(restored.durationMinutes, 30);
    expect(restored.distanceKm, 5.2);
    expect(ExerciseSet.fromMap(const {'reps': 10}).durationMinutes, isNull);
    expect(cardio('a_pe', set: entry(30, 5)).volume, 0);
  });

  test('unused cardio options become replaced when one was done', () {
    final reasons = autoReplacedCardio([
      (originalIndex: 0, execution: cardio('a_pe', set: entry(30, 5))),
      (originalIndex: 1, execution: cardio('bicicleta')),
      (
        originalIndex: 2,
        execution: ExerciseExecution(exerciseName: 'supino', sets: []),
      ),
    ]);
    expect(reasons, {1: PerceivedEffort.skippedReplaced});
    expect(
      autoReplacedCardio([(originalIndex: 0, execution: cardio('a_pe'))]),
      isEmpty,
    );
  });
}
