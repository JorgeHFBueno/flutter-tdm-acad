import 'machine_catalog_item.dart';
import 'machine_history.dart';

enum MachineCatalogSort { popularName, scientificName }

enum MachineCatalogStatus { all, active, retired, pending }

class ResolvedMachineCatalogItem {
  final MachineCatalogItem catalog;
  final MachineProfile? profile;
  final int sourceIndex;

  const ResolvedMachineCatalogItem({
    required this.catalog,
    required this.profile,
    required this.sourceIndex,
  });

  bool get isRegistered => profile != null;
  int get group =>
      catalog.isRetired ? (isRegistered ? 2 : 3) : (isRegistered ? 0 : 1);
  String get popularName => catalog.popularName.isNotEmpty
      ? catalog.popularName
      : profile?.exerciseName ?? '';
  String get scientificName => catalog.scientificName;
  String get category => catalog.category.isNotEmpty
      ? catalog.category
      : profile?.category ?? MachineCatalogCategory.outros;
}

List<ResolvedMachineCatalogItem> combineMachineCatalog(
  Iterable<MachineCatalogItem> catalog,
  Iterable<MachineProfile> profiles,
) {
  final byId = {for (final profile in profiles) profile.exerciseId: profile};
  var index = 0;
  return [
    for (final item in catalog)
      ResolvedMachineCatalogItem(
        catalog: item,
        profile: byId[item.id],
        sourceIndex: index++,
      ),
  ];
}

List<ResolvedMachineCatalogItem> filterAndSortMachineCatalog(
  Iterable<ResolvedMachineCatalogItem> values, {
  String query = '',
  String? category,
  MachineCatalogStatus status = MachineCatalogStatus.all,
  MachineCatalogSort sort = MachineCatalogSort.popularName,
}) {
  final normalizedQuery = normalizeCatalogText(query);
  final result = values.where((item) {
    if (category != null && item.category != category) {
      return false;
    }
    if (status == MachineCatalogStatus.active && item.catalog.isRetired) {
      return false;
    }
    if (status == MachineCatalogStatus.retired && !item.catalog.isRetired) {
      return false;
    }
    if (status == MachineCatalogStatus.pending &&
        !item.catalog.isPendingReview) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;
    return normalizeCatalogText(item.popularName).contains(normalizedQuery) ||
        normalizeCatalogText(item.scientificName).contains(normalizedQuery);
  }).toList();
  result.sort((a, b) {
    var compared = a.group.compareTo(b.group);
    if (compared != 0) return compared;
    final aFirst = sort == MachineCatalogSort.popularName
        ? a.popularName
        : a.scientificName;
    final bFirst = sort == MachineCatalogSort.popularName
        ? b.popularName
        : b.scientificName;
    compared =
        normalizeCatalogText(aFirst).compareTo(normalizeCatalogText(bFirst));
    if (compared != 0) return compared;
    final aSecond = sort == MachineCatalogSort.popularName
        ? a.scientificName
        : a.popularName;
    final bSecond = sort == MachineCatalogSort.popularName
        ? b.scientificName
        : b.popularName;
    compared =
        normalizeCatalogText(aSecond).compareTo(normalizeCatalogText(bSecond));
    if (compared != 0) return compared;
    compared = a.catalog.id.compareTo(b.catalog.id);
    return compared != 0 ? compared : a.sourceIndex.compareTo(b.sourceIndex);
  });
  return result;
}

String normalizeCatalogText(String value) {
  final decomposed = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var result = decomposed;
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result;
}

String catalogDuplicateKey(String popular, String scientific) =>
    '${normalizeCatalogText(popular)}\u0000${normalizeCatalogText(scientific)}';

String? validateCatalogName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Campo obrigatório';
  if (text.runes.length > 120) return 'Use no máximo 120 caracteres';
  return null;
}

Map<String, MachineCatalogItem> indexMachineCatalog(
  Iterable<MachineCatalogItem> catalog,
) =>
    {for (final item in catalog) item.id: item};

List<MachineProfile> resolveProfilesFromCatalog(
  Iterable<MachineProfile> profiles,
  Map<String, MachineCatalogItem> catalogById, {
  bool activeOnly = false,
  Set<String> preserveIds = const {},
}) =>
    [
      for (final profile in profiles)
        if (catalogById[profile.exerciseId] case final catalog?)
          if ((!catalog.isRetired ||
                  preserveIds.contains(profile.exerciseId)) &&
              (!activeOnly ||
                  !catalog.isRetired ||
                  preserveIds.contains(profile.exerciseId)))
            profile.copyWith(
              exerciseName: catalog.popularName.isEmpty
                  ? profile.exerciseName
                  : catalog.popularName,
              category: catalog.category.isEmpty
                  ? profile.category
                  : catalog.category,
              catalogScientificName: catalog.scientificName,
              catalogType: catalog.type,
            ),
    ];
