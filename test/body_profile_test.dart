import 'package:firebased/models/body_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('age counts whole years until the birthday', () {
    final birth = DateTime(2000, 11, 5);
    expect(ageOn(birth, DateTime(2026, 11, 4)), 25);
    expect(ageOn(birth, DateTime(2026, 11, 5)), 26);
  });

  test('profile round trip keeps the birth date as a plain date', () {
    final profile = BodyProfile(
      birthDate: DateTime(2000, 11, 5),
      heightM: 1.77,
      sex: 'masculino',
      goal: 'hipertrofia',
    );
    final map = profile.toMap();
    expect(map['nascimento'], '2000-11-05');
    final restored = BodyProfile.fromMap(map);
    expect(restored.birthDate, DateTime(2000, 11, 5));
    expect(restored.heightM, 1.77);
    expect(restored.goal, 'hipertrofia');
    expect(BodyProfile.fromMap({'sexo': 'x'}).sex, isNull);
  });

  test('summary text and BMI', () {
    final profile = BodyProfile(
      birthDate: DateTime(2000, 11, 5),
      heightM: 1.77,
      goal: 'hipertrofia',
    );
    final weight = BodyWeightEntry(date: DateTime(2026, 11, 27), weightKg: 71);
    expect(
      profileSummaryText(profile, weight, DateTime(2026, 11, 27)),
      '71 kg · 1,77 m · 26 anos · Hipertrofia',
    );
    expect(
      profileSummaryText(const BodyProfile(), null, DateTime(2026)),
      'Perfil não preenchido',
    );
    expect(bodyMassIndex(71, 1.77)!.toStringAsFixed(1), '22.7');
  });
}
