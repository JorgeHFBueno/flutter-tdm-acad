import '../models/machine_catalog_item.dart';
import 'exercise_catalog.dart';

class MachineCatalogSeedItem {
  final String id;
  final String popularName;
  final String scientificName;
  final String category;
  final String type;
  final bool scientificNamePending;

  const MachineCatalogSeedItem({
    required this.id,
    required this.popularName,
    required this.scientificName,
    required this.category,
    required this.type,
    required this.scientificNamePending,
  });
}

List<MachineCatalogSeedItem> get localMachineCatalogSeed => [
      for (final item in exerciseCatalog)
        MachineCatalogSeedItem(
          id: item.id,
          popularName: item.name,
          scientificName: item.name,
          category: _canonicalCategory(item.category, item.id),
          type: _inferredType(item.id, item.name),
          scientificNamePending: true,
        ),
    ];

List<MachineCatalogSeedItem> missingMachineCatalogSeeds(
  Iterable<MachineCatalogSeedItem> seed,
  Set<String> existingIds,
) =>
    seed.where((item) => !existingIds.contains(item.id)).toList();

String _canonicalCategory(String legacy, String id) {
  final value = legacy.toLowerCase();
  if (id.contains('panturrilha')) {
    return MachineCatalogCategory.panturrilhas;
  }
  if (id.contains('ombro') || id.contains('elevacao_lateral')) {
    return MachineCatalogCategory.ombros;
  }
  if (id.contains('triceps')) return MachineCatalogCategory.triceps;
  if (id.contains('biceps') || id == 'barra_w') {
    return MachineCatalogCategory.biceps;
  }
  if (value.contains('abdomin')) return MachineCatalogCategory.core;
  if (value.contains('perna')) return MachineCatalogCategory.pernas;
  if (value.contains('peito')) return MachineCatalogCategory.peito;
  if (value.contains('costa')) return MachineCatalogCategory.costas;
  return MachineCatalogCategory.outros;
}

String _inferredType(String id, String name) {
  final value = '$id $name'.toLowerCase();
  if (value.contains('halter')) return MachineCatalogType.halteres;
  if (value.contains('barra')) return MachineCatalogType.barra;
  if (value.contains('esteira')) return MachineCatalogType.maquina;
  if (value.contains('agachamento') || value.contains('abdominal')) {
    return MachineCatalogType.pesoCorporal;
  }
  if (value.contains('maquina') ||
      value.contains('máquina') ||
      value.contains('press') ||
      value.contains('flexora') ||
      value.contains('extensora') ||
      value.contains('voador') ||
      value.contains('adutor') ||
      value.contains('abdutor')) {
    return MachineCatalogType.maquina;
  }
  return MachineCatalogType.equipamentoLivre;
}
