import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FoodCatalogItem {
  const FoodCatalogItem({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.category,
    required this.kind,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.sugar,
    required this.carbType,
    required this.fiber,
    required this.alcohol,
    required this.salt,
    required this.healthLevel,
    required this.composition,
    required this.ingredients,
    required this.preparation,
    required this.minutes,
    required this.cost,
    required this.image,
    required this.video,
    required this.history,
    required this.doctorReview,
    required this.sourceUrl,
    required this.dataLicense,
  });

  final String id;
  final String titleRu;
  final String titleEn;
  final String category;
  final String kind;
  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final int sugar;
  final String carbType;
  final int fiber;
  final String alcohol;
  final double salt;
  final int healthLevel;
  final String composition;
  final String ingredients;
  final String preparation;
  final int minutes;
  final int cost;
  final String image;
  final String video;
  final String history;
  final String doctorReview;
  final String sourceUrl;
  final String dataLicense;

  String titleFor(String locale) => locale.startsWith('ru') ? titleRu : titleEn;
}

class WorkoutCatalogItem {
  const WorkoutCatalogItem({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.focus,
    required this.equipment,
    required this.level,
    required this.minutes,
    required this.calories,
    required this.sets,
    required this.description,
    required this.requirements,
    required this.steps,
    required this.warnings,
    required this.image,
    required this.video,
    required this.history,
    required this.doctorReview,
    required this.sourceUrl,
    required this.dataLicense,
  });

  final String id;
  final String titleRu;
  final String titleEn;
  final String focus;
  final String equipment;
  final String level;
  final int minutes;
  final int calories;
  final int sets;
  final String description;
  final String requirements;
  final String steps;
  final String warnings;
  final String image;
  final String video;
  final String history;
  final String doctorReview;
  final String sourceUrl;
  final String dataLicense;

  String titleFor(String locale) => locale.startsWith('ru') ? titleRu : titleEn;
}

class ExpandedCatalogRepository {
  ExpandedCatalogRepository._();

  static final instance = ExpandedCatalogRepository._();

  Future<List<FoodCatalogItem>>? _foods;
  Future<List<WorkoutCatalogItem>>? _workouts;

  Future<List<FoodCatalogItem>> foods() =>
      _foods ??= _loadFoods('assets/catalog/food_catalog.csv');

  Future<List<WorkoutCatalogItem>> workouts() =>
      _workouts ??= _loadWorkouts('assets/catalog/workout_catalog.csv');

  Future<List<FoodCatalogItem>> _loadFoods(String asset) async {
    final rows = await _loadRows(asset);
    return rows
        .map((row) {
          return FoodCatalogItem(
            id: row['id'] ?? '',
            titleRu: row['title_ru'] ?? '',
            titleEn: row['title_en'] ?? '',
            category: row['category'] ?? '',
            kind: row['kind'] ?? '',
            calories: _int(row['calories']),
            protein: _int(row['protein']),
            fat: _int(row['fat']),
            carbs: _int(row['carbs']),
            sugar: _int(row['sugar']),
            carbType: row['carb_type'] ?? '',
            fiber: _int(row['fiber']),
            alcohol: row['alcohol'] ?? '',
            salt: _double(row['salt']),
            healthLevel: _int(row['health_level']),
            composition: row['composition'] ?? '',
            ingredients: row['ingredients'] ?? '',
            preparation: row['preparation'] ?? '',
            minutes: _int(row['minutes']),
            cost: _int(row['cost']),
            image: row['image'] ?? '',
            video: row['video'] ?? '',
            history: row['history'] ?? '',
            doctorReview: row['doctor_review'] ?? '',
            sourceUrl: row['source_url'] ?? '',
            dataLicense: row['data_license'] ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<List<WorkoutCatalogItem>> _loadWorkouts(String asset) async {
    final rows = await _loadRows(asset);
    return rows
        .map((row) {
          return WorkoutCatalogItem(
            id: row['id'] ?? '',
            titleRu: row['title_ru'] ?? '',
            titleEn: row['title_en'] ?? '',
            focus: row['focus'] ?? '',
            equipment: row['equipment'] ?? '',
            level: row['level'] ?? '',
            minutes: _int(row['minutes']),
            calories: _int(row['calories']),
            sets: _int(row['sets']),
            description: row['description'] ?? '',
            requirements: row['requirements'] ?? '',
            steps: row['steps'] ?? '',
            warnings: row['warnings'] ?? '',
            image: row['image'] ?? '',
            video: row['video'] ?? '',
            history: row['history'] ?? '',
            doctorReview: row['doctor_review'] ?? '',
            sourceUrl: row['source_url'] ?? '',
            dataLicense: row['data_license'] ?? '',
          );
        })
        .toList(growable: false);
  }

  Future<List<Map<String, String>>> _loadRows(String asset) async {
    final raw = await rootBundle.loadString(asset);
    return compute(_parseCatalogRows, raw);
  }
}

List<Map<String, String>> _parseCatalogRows(String raw) {
  final table = const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(raw);
  if (table.isEmpty) return const [];
  final headers = table.first.map((item) => '$item').toList();
  return table
      .skip(1)
      .map((row) {
        final map = <String, String>{};
        for (
          var index = 0;
          index < headers.length && index < row.length;
          index++
        ) {
          map[headers[index]] = '${row[index]}'.replaceAll(r'\n', '\n');
        }
        return map;
      })
      .toList(growable: false);
}

int _int(String? value) => int.tryParse(value ?? '') ?? 0;

double _double(String? value) =>
    double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0;
