class ExerciseCatalogItem {
  final String id;
  final String name;
  final String category;

  const ExerciseCatalogItem({
    required this.id,
    required this.name,
    required this.category,
  });
}

const String fallbackExerciseCategory = 'Outros';

const List<ExerciseCatalogItem> exerciseCatalog = [
  ExerciseCatalogItem(
      id: 'abdutor_abre', name: 'Abdutor (abre)', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'adutor_fecha', name: 'Adutor (fecha)', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'agachamento', name: 'Agachamento', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'aquecimento_esteira_1km',
      name: 'Aquecimento na esteira 1km',
      category: 'Perna'),
  ExerciseCatalogItem(id: 'extensora', name: 'Extensora', category: 'Perna'),
  ExerciseCatalogItem(id: 'leg_45', name: 'Leg 45Â°', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'leg_press_45', name: 'Leg press 45Âº', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'mesa_flexora', name: 'Mesa flexora', category: 'Perna'),
  ExerciseCatalogItem(
      id: 'panturrilha_cadeira',
      name: 'Panturrilha na cadeira',
      category: 'Perna'),
  ExerciseCatalogItem(
      id: 'abdominal_inclinado',
      name: 'Abdominal inclinado',
      category: 'Peito'),
  ExerciseCatalogItem(
      id: 'elevacao_lateral_halteres',
      name: 'ElevaÃ§Ã£o lateral com halteres',
      category: 'Peito'),
  ExerciseCatalogItem(
      id: 'ombro_maquina', name: 'Ombro mÃ¡quina', category: 'Peito'),
  ExerciseCatalogItem(
      id: 'peitoral_robo', name: 'Peitoral robÃ´', category: 'Peito'),
  ExerciseCatalogItem(
      id: 'supino_simples', name: 'Supino Simples', category: 'Peito'),
  ExerciseCatalogItem(
      id: 'supino_inclinado_halteres',
      name: 'Supino inclinado com halteres',
      category: 'Peito'),
  ExerciseCatalogItem(
      id: 'supino_reto_maquina',
      name: 'Supino reto (mÃ¡quina)',
      category: 'Peito'),
  ExerciseCatalogItem(
      id: 'triceps_barra', name: 'Triceps Barra', category: 'Peito'),
  ExerciseCatalogItem(
      id: 'triceps_corda', name: 'Triceps Corda', category: 'Peito'),
  ExerciseCatalogItem(id: 'voador', name: 'Voador', category: 'Peito'),
  ExerciseCatalogItem(
      id: 'abs_invertido', name: '"ABS Invertido"', category: 'Costas'),
  ExerciseCatalogItem(id: 'abs_perna', name: '"ABS Perna"', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'antebraco_barra', name: 'AntebraÃ§o barra', category: 'Costas'),
  ExerciseCatalogItem(id: 'barra_w', name: 'Barra W', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'biceps_halters', name: 'Biceps Halters', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'biceps_cadeira', name: 'Biceps cadeira', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'dorsal_maquina', name: 'Dorsal na mÃ¡quina', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'encolhimento', name: 'Encolhimento', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'puxada_alta_barra',
      name: 'Puxada alta com a barra',
      category: 'Costas'),
  ExerciseCatalogItem(
      id: 'puxada_frente', name: 'Puxada frente', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'remada_baixa', name: 'Remada baixa', category: 'Costas'),
  ExerciseCatalogItem(
      id: 'aquecimento',
      name: 'Aquecimento',
      category: fallbackExerciseCategory),
  ExerciseCatalogItem(
    id: 'desenvolvimento_ombro',
    name: 'Desenvolvimento ombro',
    category: fallbackExerciseCategory,
  ),
];

List<String> get exerciseCatalogCategories {
  final categories = <String>[];
  for (final item in exerciseCatalog) {
    if (!categories.contains(item.category)) {
      categories.add(item.category);
    }
  }
  return List.unmodifiable(categories);
}

Map<String, List<ExerciseCatalogItem>> get exercisesByCategory {
  final grouped = <String, List<ExerciseCatalogItem>>{};
  for (final ExerciseCatalogItem item in exerciseCatalog) {
    grouped.putIfAbsent(item.category, () => <ExerciseCatalogItem>[]).add(item);
  }
  return Map.unmodifiable(
    grouped.map(
      (String category, List<ExerciseCatalogItem> items) =>
          MapEntry<String, List<ExerciseCatalogItem>>(
        category,
        List<ExerciseCatalogItem>.unmodifiable(items),
      ),
    ),
  );
}

ExerciseCatalogItem? findExerciseCatalogItem(String name) {
  final normalizedName = name.trim();
  for (final ExerciseCatalogItem item in exerciseCatalog) {
    if (item.name == normalizedName) {
      return item;
    }
  }
  return null;
}

ExerciseCatalogItem? findExerciseCatalogItemById(String id) {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) return null;
  for (final ExerciseCatalogItem item in exerciseCatalog) {
    if (item.id == normalizedId) return item;
  }
  return null;
}

ExerciseCatalogItem? findExerciseCatalogItemByNameAndCategory(
  String name,
  String? category,
) {
  final normalizedName = name.trim();
  final normalizedCategory = category?.trim();
  for (final ExerciseCatalogItem item in exerciseCatalog) {
    if (item.name == normalizedName && item.category == normalizedCategory) {
      return item;
    }
  }
  return null;
}

String resolveExerciseCategory(String name, {String? savedCategory}) {
  final normalizedCategory = savedCategory?.trim();
  if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
    return normalizedCategory;
  }

  return findExerciseCatalogItem(name)?.category ?? fallbackExerciseCategory;
}

String normalizeExerciseIdPart(String value) {
  var text = value.trim().toLowerCase();
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'º': '',
    '°': '',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'\s+'), ' ');
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  text = text.replaceAll(RegExp(r'_+'), '_');
  text = text.replaceAll(RegExp(r'^_|_$'), '');
  return text.isEmpty ? 'sem_identificacao' : text;
}

String legacyExerciseIdFor(String name, String? category) {
  final normalizedName = normalizeExerciseIdPart(name);
  final normalizedCategory = normalizeExerciseIdPart(
    category?.trim().isNotEmpty == true ? category! : fallbackExerciseCategory,
  );
  return 'legacy__${normalizedName}__$normalizedCategory';
}

String resolveExerciseId({
  String? exerciseId,
  required String name,
  String? category,
}) {
  final savedId = exerciseId?.trim();
  if (savedId != null && savedId.isNotEmpty) return savedId;

  final byNameAndCategory = findExerciseCatalogItemByNameAndCategory(
    name,
    category,
  );
  if (byNameAndCategory != null) return byNameAndCategory.id;

  final matchesByName = exerciseCatalog
      .where((ExerciseCatalogItem item) => item.name == name.trim())
      .toList();
  if (matchesByName.length == 1) return matchesByName.single.id;

  return legacyExerciseIdFor(name, category);
}
