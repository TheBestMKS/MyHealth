import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/catalog.dart';

void main() {
  test('localizes exercise and recipe catalog to English', () {
    final exercise = exerciseCatalog.first;
    final recipe = recipeCatalog.first;

    expect(exercise.titleFor('ru'), 'Присед с гантелью у груди');
    expect(exercise.titleFor('en'), 'Goblet squat');
    expect(exercise.instructionsFor('en'), contains('neutral spine'));

    expect(recipe.titleFor('ru'), 'Овсянка с ягодами и греческим йогуртом');
    expect(recipe.titleFor('en'), 'Oats with berries and Greek yogurt');
    expect(recipe.stepsFor('en'), contains('Cook the oats in water or milk.'));
  });

  test(
    'uses English catalog fallback for languages without full catalog copy',
    () {
      final exercise = exerciseCatalog.first;
      final recipe = recipeCatalog.first;

      expect(exercise.titleFor('de'), 'Goblet squat');
      expect(recipe.ingredientsFor('ja'), contains('Greek yogurt'));
    },
  );
}
