import 'package:firebased/data/exercise_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared exercise catalog is available to widget tests', () {
    expect(exerciseCatalog, isNotEmpty);
  });
}
