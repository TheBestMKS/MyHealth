import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/expanded_catalog.dart';

void main() {
  testWidgets('bundles real attributed food and workout catalogs', (
    tester,
  ) async {
    final repository = ExpandedCatalogRepository.instance;
    final result = await tester.runAsync(() async {
      return (await repository.foods(), await repository.workouts());
    });
    final (foods, workouts) = result!;

    expect(foods, hasLength(10000));
    expect(workouts, hasLength(1000));
    expect(foods.map((item) => item.id).toSet(), hasLength(10000));
    expect(foods.map((item) => item.titleRu).toSet(), hasLength(10000));
    expect(workouts.map((item) => item.id).toSet(), hasLength(1000));
    expect(workouts.map((item) => item.titleRu).toSet(), hasLength(1000));
    expect(foods.every((item) => item.id.startsWith('off-')), isTrue);
    expect(workouts.every((item) => item.id.startsWith('wger-')), isTrue);
    expect(
      foods.every(
        (item) =>
            item.image.startsWith('https://') &&
            item.sourceUrl.startsWith('http') &&
            item.dataLicense.isNotEmpty &&
            item.doctorReview.contains('не персональный отзыв врача'),
      ),
      isTrue,
    );
    expect(
      workouts.every(
        (item) =>
            item.image.startsWith('https://') &&
            item.sourceUrl.startsWith('http') &&
            item.dataLicense.isNotEmpty &&
            item.description.isNotEmpty &&
            item.steps.isNotEmpty &&
            item.warnings.isNotEmpty &&
            item.doctorReview.contains('не персональное заключение врача'),
      ),
      isTrue,
    );
    expect(
      foods
          .where((item) => item.kind == 'meal')
          .every((item) => item.preparation.isNotEmpty),
      isTrue,
    );
  });
}
