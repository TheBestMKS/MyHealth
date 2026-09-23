import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/assistant_tools.dart';
import 'package:my_health/src/model.dart';

void main() {
  const engine = AssistantToolEngine();

  test('Russian voice-style water command updates the daily diary', () {
    final seed = HealthAppState.seed();
    final result = engine.execute(seed, 'Я выпил 250 мл воды');

    expect(result, isNotNull);
    expect(result!.state.today.waterLiters, closeTo(0.25, 0.001));
    expect(result.relatedSection, 'nutrition');
  });

  test('glucose in mg/dL is converted and stored as a lab result', () {
    final result = engine.execute(HealthAppState.seed(), 'Глюкоза 180 мг/дл');

    expect(result, isNotNull);
    expect(result!.state.labResults, hasLength(1));
    expect(result.state.labResults.single.marker, 'Глюкоза крови');
    expect(result.state.labResults.single.value, '10.0');
    expect(result.state.labResults.single.unit, contains('пересчитано'));
  });

  test('assistant only marks a medicine that already exists', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      medications: const [
        Medication(
          id: 'medicine',
          name: 'Метформин',
          dose: '500 мг',
          schedule: '08:00',
          takenToday: false,
          notes: '',
          remainingUnits: 10,
        ),
      ],
    );
    final result = engine.execute(state, 'Я принял метформин');

    expect(result, isNotNull);
    expect(result!.state.medicationIntakes.single.status, 'принято');
    expect(result.state.medications.single.remainingUnits, 9);
    expect(engine.execute(state, 'Я принял неизвестный препарат'), isNull);
  });

  test('Russian sleep command creates a record and updates today', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Я спал с 23:30 до 07:00, качество сна 4',
    );

    expect(result, isNotNull);
    expect(result!.state.sleepRecords.single.durationMinutes, 450);
    expect(result.state.sleepRecords.single.quality, 4);
    expect(result.state.today.sleepHours, 7.5);
  });

  test('Russian symptom command links the symptom to daily metrics', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Запиши симптом головная боль 6 из 10',
    );

    expect(result, isNotNull);
    expect(result!.state.symptomEntries.single.symptom, 'Головная боль');
    expect(result.state.symptomEntries.single.intensity, 6);
    expect(result.state.today.symptoms, contains('Головная боль'));
  });

  test('Russian meal command records calories and explicit macros', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Я съел овсяную кашу 350 ккал белки 12 жиры 9 углеводы 55',
    );

    expect(result, isNotNull);
    expect(result!.state.meals.single.title, 'Овсяную кашу');
    expect(result.state.meals.single.protein, 12);
    expect(result.state.meals.single.fat, 9);
    expect(result.state.meals.single.carbs, 55);
    expect(result.state.today.calories, 350);
  });
}
