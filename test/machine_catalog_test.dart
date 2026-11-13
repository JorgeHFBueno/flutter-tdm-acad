import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firebased/data/machine_catalog_seed.dart';
import 'package:firebased/models/machine_catalog_item.dart';
import 'package:firebased/models/machine_catalog_view.dart';
import 'package:firebased/models/machine_history.dart';
import 'package:firebased/models/workout_execution_flow.dart';
import 'package:firebased/models/workout_session.dart';

void main() {
  group('MachineCatalogItem', () {
    test('maps complete Portuguese Firestore document and preserves id', () {
      final created = DateTime(2026, 8, 1);
      final item = MachineCatalogItem.fromMap({
        'nome_popular': 'Supino',
        'nome_cientifico': 'Supino reto',
        'categoria': 'peito',
        'criado_por': 'uid-1',
        'tipo': 'barra',
        'aposentada': true,
        'criado_em': Timestamp.fromDate(created),
        'atualizado_em': Timestamp.fromDate(created),
        'atualizado_por': 'uid-2',
        'aposentado_em': Timestamp.fromDate(created),
        'aposentado_por': 'uid-2',
        'schema_version': 2,
        'origem': 'manual',
        'nome_cientifico_pendente': false,
      }, id: 'stable-id');

      expect(item.id, 'stable-id');
      expect(item.popularName, 'Supino');
      expect(item.isRetired, isTrue);
      expect(item.createdAt, created);
      expect(item.schemaVersion, 2);
      expect(item.isComplete, isTrue);
      expect(item.toMap(), containsPair('nome_cientifico', 'Supino reto'));
      expect(item.toMap(), containsPair('criado_por', 'uid-1'));
    });

    test('reads incomplete document defensively with safe defaults', () {
      final item = MachineCatalogItem.fromMap({
        'nome_popular': 42,
        'categoria': 'desconhecida',
      }, id: 'x');
      expect(item.popularName, '42');
      expect(item.scientificName, isEmpty);
      expect(item.isRetired, isFalse);
      expect(item.schemaVersion, 1);
      expect(item.createdAt, isNull);
      expect(item.isComplete, isFalse);
    });

    test('serializes all required exact fields', () {
      const item = MachineCatalogItem(
        id: 'id',
        popularName: 'Popular',
        scientificName: 'Científico',
        category: 'costas',
        type: 'polia',
        createdByUid: 'uid',
      );
      expect(
          item.toMap().keys,
          containsAll(<String>[
            'nome_popular',
            'nome_cientifico',
            'categoria',
            'criado_por',
            'tipo',
            'aposentada',
            'schema_version',
            'origem',
            'nome_cientifico_pendente',
          ]));
    });
  });

  group('local seed planning', () {
    test('preserves every local stable id and marks scientific name pending',
        () {
      expect(localMachineCatalogSeed, hasLength(31));
      expect(localMachineCatalogSeed.map((e) => e.id).toSet(), hasLength(31));
      for (final item in localMachineCatalogSeed) {
        expect(item.id, isNotEmpty);
        expect(item.scientificName, item.popularName);
        expect(item.scientificNamePending, isTrue);
      }
    });

    test(
        'empty, partial, complete and repeated imports select only missing ids',
        () {
      final empty = missingMachineCatalogSeeds(localMachineCatalogSeed, {});
      expect(empty, hasLength(31));
      final partialIds =
          localMachineCatalogSeed.take(10).map((e) => e.id).toSet();
      expect(missingMachineCatalogSeeds(localMachineCatalogSeed, partialIds),
          hasLength(21));
      final allIds = localMachineCatalogSeed.map((e) => e.id).toSet();
      expect(
          missingMachineCatalogSeeds(localMachineCatalogSeed, allIds), isEmpty);
      expect(
          missingMachineCatalogSeeds(localMachineCatalogSeed, allIds), isEmpty);
    });

    test('partial failure can resume by retaining successfully created ids',
        () {
      final first = localMachineCatalogSeed.first;
      final second = localMachineCatalogSeed[1];
      final remaining = missingMachineCatalogSeeds(
        [first, second],
        {first.id},
      );
      expect(remaining.single.id, second.id);
    });
  });

  group('catalog and profile projection', () {
    final catalog = [
      _catalog('a', 'Árvore', retired: false),
      _catalog('b', 'bola', retired: false),
      _catalog('c', 'Casa', retired: true),
      _catalog('d', 'dado', retired: true),
    ];
    final profiles = [_profile('a', name: 'Nome antigo'), _profile('c')];

    test(
        'orders registered active, unregistered active, registered retired, unregistered retired',
        () {
      final sorted =
          filterAndSortMachineCatalog(combineMachineCatalog(catalog, profiles));
      expect(sorted.map((e) => e.catalog.id), ['a', 'b', 'c', 'd']);
      expect(sorted.map((e) => e.group), [0, 1, 2, 3]);
    });

    test('catalog wins names/category and profile wins personal configuration',
        () {
      final resolved = combineMachineCatalog(catalog, profiles).first;
      expect(resolved.popularName, 'Árvore');
      expect(resolved.category, 'peito');
      expect(resolved.profile!.currentSets, 3);
      expect(resolved.profile!.completionCount, 7);
    });

    test(
        'search ignores case, accents, supports partial scientific and filters',
        () {
      var result = filterAndSortMachineCatalog(
        combineMachineCatalog(catalog, profiles),
        query: 'ARV',
      );
      expect(result.single.catalog.id, 'a');
      result = filterAndSortMachineCatalog(
        combineMachineCatalog(catalog, profiles),
        query: 'cientifico bola',
        category: 'peito',
        status: MachineCatalogStatus.active,
      );
      expect(result.single.catalog.id, 'b');
      expect(
          filterAndSortMachineCatalog(
            combineMachineCatalog(catalog, profiles),
            query: '   ',
          ),
          hasLength(4));
    });

    test('pending filter keeps only unreviewed quick-added items', () {
      MachineCatalogItem quick(String id, {required bool pending}) =>
          MachineCatalogItem(
            id: id,
            popularName: id,
            scientificName: id,
            category: 'peito',
            type: 'outro',
            createdByUid: 'uid',
            origin: machineCatalogOriginQuickAdd,
            scientificNamePending: pending,
          );
      const seed = MachineCatalogItem(
        id: 'seed',
        popularName: 'Seed',
        scientificName: 'Seed',
        category: 'peito',
        type: 'maquina',
        createdByUid: 'uid',
        origin: machineCatalogOriginLocalSeed,
        scientificNamePending: true,
      );

      final visible = filterAndSortMachineCatalog(
        combineMachineCatalog([
          quick('nova', pending: true),
          quick('revisada', pending: false),
          seed,
        ], const []),
        status: MachineCatalogStatus.pending,
      );

      expect(visible.map((item) => item.catalog.id), ['nova']);
    });

    test('scientific sort uses secondary name then stable id', () {
      final tied = [
        _catalog('z', 'Beta', scientific: 'Mesmo'),
        _catalog('a', 'alfa', scientific: 'mesmo'),
        _catalog('b', 'Álfa', scientific: 'Mesmo'),
      ];
      final result = filterAndSortMachineCatalog(
        combineMachineCatalog(tied, []),
        sort: MachineCatalogSort.scientificName,
      );
      expect(result.map((e) => e.catalog.id), ['a', 'b', 'z']);
    });

    test(
        'retired profile is preserved only for existing workout and cannot be re-added',
        () {
      final index = indexMachineCatalog(catalog);
      expect(
          resolveProfilesFromCatalog(profiles, index, activeOnly: true)
              .map((e) => e.exerciseId),
          ['a']);
      expect(
          resolveProfilesFromCatalog(profiles, index,
              activeOnly: true, preserveIds: {'c'}).map((e) => e.exerciseId),
          ['a', 'c']);
    });
  });

  test(
      'new session snapshot carries current catalog data and old snapshot remains readable',
      () {
    final machine = _profile('x').copyWith(
      exerciseName: 'Atual',
      category: 'costas',
      catalogScientificName: 'Nome científico',
      catalogType: 'polia',
    );
    final execution =
        createPendingEntriesFromMachines([machine]).single.execution;
    final map = execution.toMap();
    expect(map['scientificName'], 'Nome científico');
    expect(map['category'], 'costas');
    expect(map['type'], 'polia');
    final old = ExerciseExecution.fromMap({
      'exerciseId': 'x',
      'exerciseName': 'Antigo',
      'sets': <Object>[],
    });
    expect(old.exerciseName, 'Antigo');
    expect(old.scientificName, isNull);
  });
}

MachineCatalogItem _catalog(String id, String popular,
        {String? scientific, bool retired = false}) =>
    MachineCatalogItem(
      id: id,
      popularName: popular,
      scientificName: scientific ?? 'Científico $popular',
      category: 'peito',
      type: 'maquina',
      createdByUid: 'uid',
      isRetired: retired,
    );

MachineProfile _profile(String id, {String name = 'Legado'}) => MachineProfile(
      exerciseId: id,
      exerciseName: name,
      category: 'antiga',
      ownerUid: 'uid',
      currentSets: 3,
      currentRepetitions: 10,
      currentWeightKg: 20,
      completionCount: 7,
      observation: 'OBS',
    );
