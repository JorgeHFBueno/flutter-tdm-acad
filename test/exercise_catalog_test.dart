import 'package:firebased/data/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('exerciseCatalog', () {
    test('does not contain duplicate names', () {
      final List<String> names =
          exerciseCatalog.map((ExerciseCatalogItem item) => item.name).toList();

      expect(names.toSet(), hasLength(names.length));
    });

    test('has non-empty names and categories', () {
      for (final ExerciseCatalogItem item in exerciseCatalog) {
        expect(item.id.trim(), isNotEmpty);
        expect(item.name.trim(), isNotEmpty);
        expect(item.category.trim(), isNotEmpty);
      }
    });

    test('has unique stable ids', () {
      final ids = exerciseCatalog.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('finds exercise by id', () {
      final item = findExerciseCatalogItemById('remada_baixa');
      expect(item, isNotNull);
      expect(item!.name, 'Remada baixa');
    });

    test('finds category by exercise name', () {
      expect(resolveExerciseCategory('Remada baixa'), 'Costas');
      expect(resolveExerciseCategory('Supino Simples'), 'Peito');
      expect(resolveExerciseCategory('Triceps Barra'), armExerciseCategory);
      expect(resolveExerciseCategory('"ABS Perna"'), absExerciseCategory);
    });

    test('uses fallback category for unknown exercise', () {
      expect(
        resolveExerciseCategory('Exercicio legado'),
        fallbackExerciseCategory,
      );
    });

    test('groups exercises by category with explicit catalog item lists', () {
      final Map<String, List<ExerciseCatalogItem>> grouped =
          exercisesByCategory;

      expect(grouped, isA<Map<String, List<ExerciseCatalogItem>>>());

      for (final MapEntry<String, List<ExerciseCatalogItem>> entry
          in grouped.entries) {
        expect(entry.value, isA<List<ExerciseCatalogItem>>());
        for (final ExerciseCatalogItem item in entry.value) {
          expect(item.category, entry.key);
        }
      }
    });

    test('builds creation screen catalog data without TypeError', () {
      final String selectedCategory = exerciseCatalogCategories.first;

      expect(
        () {
          final List<ExerciseCatalogItem> visibleExercises =
              exercisesByCategory[selectedCategory] ??
                  const <ExerciseCatalogItem>[];
          return visibleExercises.map((ExerciseCatalogItem item) => item.name);
        },
        returnsNormally,
      );
    });

    test('builds edit screen catalog data without TypeError', () {
      final String selectedCategory = fallbackExerciseCategory;
      final selectedMachineIds = <String>['legacy__exercicio_legado__outros'];

      expect(
        () {
          final List<ExerciseCatalogItem> catalogItems =
              exercisesByCategory[selectedCategory] ??
                  const <ExerciseCatalogItem>[];
          return List<ExerciseCatalogItem>.unmodifiable(
            catalogItems.where((item) => selectedMachineIds.contains(item.id)),
          ).length;
        },
        returnsNormally,
      );
    });

    test('groups exercises under canonical categories without warmup machine',
        () {
      final Map<String, List<ExerciseCatalogItem>> grouped =
          exercisesByCategory;

      expect(
        grouped['Perna']?.map((ExerciseCatalogItem item) => item.name),
        contains('Agachamento'),
      );
      expect(
        grouped['Peito']?.map((ExerciseCatalogItem item) => item.name),
        contains('Supino Simples'),
      );
      expect(
        grouped['Costas']?.map((ExerciseCatalogItem item) => item.name),
        contains('Remada baixa'),
      );
      expect(
        grouped[fallbackExerciseCategory]
            ?.map((ExerciseCatalogItem item) => item.name),
        isNot(contains('Aquecimento')),
      );
      expect(
        grouped[armExerciseCategory]
            ?.map((ExerciseCatalogItem item) => item.id),
        containsAll([
          'triceps_barra',
          'triceps_corda',
          'barra_w',
          'biceps_halters',
          'biceps_cadeira',
        ]),
      );
      expect(
        grouped[absExerciseCategory]
            ?.map((ExerciseCatalogItem item) => item.id),
        containsAll([
          'abdominal_inclinado',
          'abs_invertido',
          'abs_perna',
        ]),
      );
      expect(
        exerciseCatalog.map((ExerciseCatalogItem item) => item.id),
        isNot(contains(syntheticWarmupExerciseId)),
      );
    });

    test('resolves id by name and category', () {
      expect(
        resolveExerciseId(name: 'Remada baixa', category: 'Costas'),
        'remada_baixa',
      );
    });

    test('builds deterministic legacy id without hashCode', () {
      final first = legacyExerciseIdFor(' Exercício  legado ', 'Outros');
      final second = legacyExerciseIdFor('Exercício legado', 'Outros');

      expect(first, second);
      expect(first, startsWith('legacy__'));
      expect(first, isNot(contains('hashCode')));
    });
  });
}
