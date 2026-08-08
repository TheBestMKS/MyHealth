import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as image_lib;

class FoodClassEstimate {
  const FoodClassEstimate({
    required this.label,
    required this.titleRu,
    required this.servingGrams,
    required this.caloriesPer100Grams,
    required this.proteinPer100Grams,
    required this.fatPer100Grams,
    required this.carbsPer100Grams,
  });

  final String label;
  final String titleRu;
  final int servingGrams;
  final int caloriesPer100Grams;
  final int proteinPer100Grams;
  final int fatPer100Grams;
  final int carbsPer100Grams;

  String titleFor(String localeCode) =>
      localeCode.startsWith('ru') ? titleRu : label.replaceAll('_', ' ');

  Map<String, String> toRecognitionMetadata(double confidence) => {
    'visualLabel': label,
    'visualTitle': titleRu,
    'visualConfidence': confidence.toStringAsFixed(4),
    'portionGrams': '$servingGrams',
    'nutritionBasisGrams': '100',
    'calories': '$caloriesPer100Grams',
    'protein': '$proteinPer100Grams',
    'fat': '$fatPer100Grams',
    'carbs': '$carbsPer100Grams',
    'nutritionEstimate': 'true',
  };
}

class FoodVisualPrediction {
  const FoodVisualPrediction({
    required this.label,
    required this.confidence,
    required this.estimate,
  });

  final String label;
  final double confidence;
  final FoodClassEstimate estimate;

  Map<String, dynamic> toJson() => {
    'label': label,
    'titleRu': estimate.titleRu,
    'confidence': confidence,
    'servingGrams': estimate.servingGrams,
    'calories': estimate.caloriesPer100Grams,
    'protein': estimate.proteinPer100Grams,
    'fat': estimate.fatPer100Grams,
    'carbs': estimate.carbsPer100Grams,
  };
}

class FoodRecognitionService {
  FoodRecognitionService._();

  static final instance = FoodRecognitionService._();

  static const modelAsset = 'assets/models/food101_efficientnet_b0.onnx';
  static const labelsAsset = 'assets/models/food101_labels.json';
  static const nutritionAsset = 'assets/models/food101_nutrition.json';

  final OnnxRuntime _runtime = OnnxRuntime();
  Future<OrtSession>? _session;
  Future<List<String>>? _labels;
  Future<Map<String, FoodClassEstimate>>? _estimates;

  Future<List<FoodVisualPrediction>> classifyFile(String path) async {
    final extension = path.split('.').last.toLowerCase();
    if (!const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'bmp',
      'tif',
      'tiff',
    }.contains(extension)) {
      return const [];
    }
    final bytes = await File(path).readAsBytes();
    final input = await compute(preprocessFoodImageBytes, bytes);
    final session = await (_session ??= _createSession());
    final labels = await (_labels ??= _loadLabels());
    final estimates = await (_estimates ??= _loadEstimates());
    final tensor = await OrtValue.fromList(input, const [1, 3, 128, 128]);
    Map<String, OrtValue> outputs = const {};
    try {
      outputs = await session.run({session.inputNames.first: tensor});
      final logits = await outputs[session.outputNames.first]!
          .asFlattenedList();
      final scores = logits.map((value) => (value as num).toDouble()).toList();
      final top = softmaxTopK(scores, 3);
      return [
        for (final item in top)
          if (item.index < labels.length &&
              estimates.containsKey(labels[item.index]))
            FoodVisualPrediction(
              label: labels[item.index],
              confidence: item.probability,
              estimate: estimates[labels[item.index]]!,
            ),
      ];
    } finally {
      await tensor.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }
    }
  }

  Future<FoodClassEstimate?> estimateForLabel(String label) async =>
      (await (_estimates ??= _loadEstimates()))[label];

  Future<OrtSession> _createSession() => _runtime.createSessionFromAsset(
    modelAsset,
    options: OrtSessionOptions(
      intraOpNumThreads: math.max(1, math.min(4, Platform.numberOfProcessors)),
      interOpNumThreads: 1,
    ),
  );

  Future<List<String>> _loadLabels() async {
    final raw = jsonDecode(await rootBundle.loadString(labelsAsset)) as List;
    return raw.map((item) => '$item').toList(growable: false);
  }

  Future<Map<String, FoodClassEstimate>> _loadEstimates() async {
    final raw =
        jsonDecode(await rootBundle.loadString(nutritionAsset))
            as Map<String, dynamic>;
    return raw.map((label, value) {
      final data = value as Map<String, dynamic>;
      int number(String key) => (data[key] as num?)?.round() ?? 0;
      return MapEntry(
        label,
        FoodClassEstimate(
          label: label,
          titleRu: '${data['ru'] ?? label.replaceAll('_', ' ')}',
          servingGrams: number('serving'),
          caloriesPer100Grams: number('kcal'),
          proteinPer100Grams: number('protein'),
          fatPer100Grams: number('fat'),
          carbsPer100Grams: number('carbs'),
        ),
      );
    });
  }
}

@visibleForTesting
Float32List preprocessFoodImageBytes(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Не удалось декодировать изображение.');
  }
  final oriented = image_lib.bakeOrientation(decoded);
  final targetShortSide = 160;
  final widthIsShorter = oriented.width <= oriented.height;
  final resizedWidth = widthIsShorter
      ? targetShortSide
      : (oriented.width * targetShortSide / oriented.height).round();
  final resizedHeight = widthIsShorter
      ? (oriented.height * targetShortSide / oriented.width).round()
      : targetShortSide;
  final resized = image_lib.copyResize(
    oriented,
    width: resizedWidth,
    height: resizedHeight,
    interpolation: image_lib.Interpolation.linear,
  );
  const cropSize = 128;
  final cropped = image_lib.copyCrop(
    resized,
    x: (resized.width - cropSize) ~/ 2,
    y: (resized.height - cropSize) ~/ 2,
    width: cropSize,
    height: cropSize,
  );
  const means = [0.485, 0.456, 0.406];
  const deviations = [0.229, 0.224, 0.225];
  final result = Float32List(3 * cropSize * cropSize);
  for (var channel = 0; channel < 3; channel++) {
    final channelOffset = channel * cropSize * cropSize;
    for (var y = 0; y < cropSize; y++) {
      for (var x = 0; x < cropSize; x++) {
        final pixel = cropped.getPixel(x, y);
        final raw = switch (channel) {
          0 => pixel.r,
          1 => pixel.g,
          _ => pixel.b,
        };
        result[channelOffset + y * cropSize + x] =
            (raw / 255.0 - means[channel]) / deviations[channel];
      }
    }
  }
  return result;
}

class FoodProbability {
  const FoodProbability(this.index, this.probability);

  final int index;
  final double probability;
}

@visibleForTesting
List<FoodProbability> softmaxTopK(List<double> logits, int count) {
  if (logits.isEmpty || count <= 0) return const [];
  final maximum = logits.reduce(math.max);
  final exponents = logits.map((value) => math.exp(value - maximum)).toList();
  final total = exponents.fold<double>(0, (sum, value) => sum + value);
  final ranked = [
    for (var index = 0; index < exponents.length; index++)
      FoodProbability(index, total == 0 ? 0 : exponents[index] / total),
  ]..sort((a, b) => b.probability.compareTo(a.probability));
  return ranked.take(math.min(count, ranked.length)).toList(growable: false);
}

Map<String, String> foodVisualMetadata(List<FoodVisualPrediction> predictions) {
  if (predictions.isEmpty) return const {};
  final top = predictions.first;
  return {
    ...top.estimate.toRecognitionMetadata(top.confidence),
    'visualModel': 'EfficientNet-B0 Food-101',
    'visualAlternatives': jsonEncode(
      predictions.map((item) => item.toJson()).toList(growable: false),
    ),
  };
}
