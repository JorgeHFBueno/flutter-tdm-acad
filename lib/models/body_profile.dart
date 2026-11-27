import 'package:cloud_firestore/cloud_firestore.dart';

/// Body profile kept in users/{uid}.perfil; weighings live in
/// users/{uid}/pesagens so each workout can use the weight of its time.
class BodyProfile {
  final DateTime? birthDate;
  final double? heightM;
  final String? sex;
  final String? goal;

  const BodyProfile({this.birthDate, this.heightM, this.sex, this.goal});

  static const sexes = <String, String>{
    'masculino': 'Masculino',
    'feminino': 'Feminino',
  };

  static const goals = <String, String>{
    'hipertrofia': 'Hipertrofia',
    'forca': 'Força',
    'emagrecimento': 'Emagrecimento',
    'condicionamento': 'Condicionamento',
  };

  bool get isEmpty =>
      birthDate == null && heightM == null && sex == null && goal == null;

  factory BodyProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BodyProfile();
    final height = map['alturaM'];
    return BodyProfile(
      birthDate: DateTime.tryParse(map['nascimento']?.toString() ?? ''),
      heightM: height is num ? height.toDouble() : null,
      sex: sexes.containsKey(map['sexo']) ? map['sexo'] as String : null,
      goal:
          goals.containsKey(map['objetivo']) ? map['objetivo'] as String : null,
    );
  }

  /// Stored as "AAAA-MM-DD" so the date never shifts with the time zone.
  Map<String, dynamic> toMap() => {
        'nascimento': birthDate == null ? null : dateKey(birthDate!),
        'alturaM': heightM,
        'sexo': sex,
        'objetivo': goal,
      };
}

class BodyWeightEntry {
  final String? id;
  final DateTime date;
  final double weightKg;

  const BodyWeightEntry({this.id, required this.date, required this.weightKg});

  factory BodyWeightEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final date = map['data'];
    final weight = map['pesoKg'];
    return BodyWeightEntry(
      id: id,
      date: date is Timestamp ? date.toDate() : DateTime.now(),
      weightKg: weight is num ? weight.toDouble() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'data': Timestamp.fromDate(date),
        'pesoKg': weightKg,
      };
}

String dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Whole years on [today].
int ageOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  final beforeBirthday = today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day);
  if (beforeBirthday) age -= 1;
  return age;
}

double? bodyMassIndex(double? weightKg, double? heightM) {
  if (weightKg == null || heightM == null || heightM <= 0) return null;
  return weightKg / (heightM * heightM);
}

/// "71 kg · 1,77 m · 26 anos · Hipertrofia" (only what is known).
String profileSummaryText(
  BodyProfile profile,
  BodyWeightEntry? latest,
  DateTime today,
) {
  String decimal(double v, int digits) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');
  final parts = <String>[
    if (latest != null)
      '${decimal(latest.weightKg, latest.weightKg % 1 == 0 ? 0 : 1)} kg',
    if (profile.heightM != null) '${decimal(profile.heightM!, 2)} m',
    if (profile.birthDate != null) '${ageOn(profile.birthDate!, today)} anos',
    if (profile.goal != null) BodyProfile.goals[profile.goal]!,
  ];
  return parts.isEmpty ? 'Perfil não preenchido' : parts.join(' · ');
}
