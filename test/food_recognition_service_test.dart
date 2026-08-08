import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:my_health/src/food_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Food-101 model metadata and profiles are complete', () async {
    final labels =
        jsonDecode(
              await File('assets/models/food101_labels.json').readAsString(),
            )
            as List;
    final profiles =
        jsonDecode(
              await File('assets/models/food101_nutrition.json').readAsString(),
            )
            as Map<String, dynamic>;
    final info =
        jsonDecode(
              await File(
                'assets/models/food101_model_info.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final model = File('assets/models/food101_efficientnet_b0.onnx');

    expect(labels, hasLength(101));
    expect(profiles, hasLength(101));
    expect(profiles.keys.toSet(), labels.cast<String>().toSet());
    expect(info['license'], 'MIT');
    expect(info['classCount'], 101);
    expect(await model.length(), greaterThan(10 * 1024 * 1024));
  });

  test('image preprocessing returns normalized NCHW tensor', () {
    final image = image_lib.Image(width: 240, height: 180);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    final tensor = preprocessFoodImageBytes(image_lib.encodePng(image));

    expect(tensor, hasLength(3 * 128 * 128));
    expect(tensor.every((value) => value.isFinite), isTrue);
    expect(tensor.toSet().length, greaterThan(100));
  });

  test('softmax returns ordered stable probabilities', () {
    final values = softmaxTopK([1001, 1003, 1002, -5000], 3);

    expect(values.map((item) => item.index), [1, 2, 0]);
    expect(
      values.fold<double>(0, (sum, item) => sum + item.probability),
      closeTo(1, 0.000001),
    );
  });

  test('visual metadata keeps estimates explicitly marked', () {
    const estimate = FoodClassEstimate(
      label: 'pizza',
      titleRu: 'Пицца',
      servingGrams: 250,
      caloriesPer100Grams: 266,
      proteinPer100Grams: 11,
      fatPer100Grams: 10,
      carbsPer100Grams: 33,
    );
    final metadata = foodVisualMetadata(const [
      FoodVisualPrediction(
        label: 'pizza',
        confidence: 0.82,
        estimate: estimate,
      ),
    ]);

    expect(metadata['visualLabel'], 'pizza');
    expect(metadata['nutritionEstimate'], 'true');
    expect(metadata['portionGrams'], '250');
    expect(metadata['nutritionBasisGrams'], '100');
    expect(metadata['visualAlternatives'], contains('pizza'));
  });
}
