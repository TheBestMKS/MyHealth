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

  test(
    'water commands understand milliliters, glasses and status questions',
    () {
      var state = HealthAppState.seed();
      state = engine.execute(state, 'Добавь воды 300 миллилитров')!.state;
      state = engine.execute(state, 'Я выпил 2 стакана воды')!.state;
      state = engine.execute(state, '250 мл воды я выпил')!.state;

      expect(state.today.waterLiters, closeTo(1.05, 0.001));
      final status = engine.execute(state, 'Сколько воды я выпил сегодня?');
      expect(status, isNotNull);
      expect(status!.message, contains('1.05'));
    },
  );

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

  test('Russian alarm command creates a smart math alarm', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Поставь важный будильник на 06:45 по будням с математической задачей',
    );

    expect(result, isNotNull);
    expect(result!.state.alarmGroups.single.wakeTime, '06:45');
    expect(result.state.alarmGroups.single.days, 'пн, вт, ср, чт, пт');
    expect(result.state.alarmGroups.single.priority, 3);
    expect(result.state.alarmGroups.single.unlockMode, 'math_easy');
  });

  test('alarm command enables the post-wake activity check', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Поставь будильник в 7 с контролем активности, не дай уснуть',
    );

    expect(result, isNotNull);
    final alarm = result!.state.alarmGroups.single;
    expect(alarm.wakeTime, '07:00');
    expect(alarm.wakefulnessCheckEnabled, isTrue);
    expect(alarm.specificDate, isNotEmpty);
    expect(alarm.title, 'Будильник');
  });

  test('food without nutrition is saved for later confirmation', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Я съел яблоко и творог',
    );

    expect(result, isNotNull);
    expect(result!.state.meals.single.title, 'Яблоко и творог');
    expect(result.state.meals.single.confirmed, isFalse);
    expect(result.state.meals.single.calories, 0);
  });

  test('generic medicine reminder supports a daily repeat', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Напомни принять витамин в 8 каждый день',
    );

    expect(result, isNotNull);
    final reminder = result!.state.reminders.single;
    expect(reminder.time, '08:00');
    expect(reminder.repeat, 'daily');
    expect(reminder.category, 'лекарства');
    expect(reminder.title.toLowerCase(), contains('витамин'));
  });

  test('known medicine reminder extends its medication schedule', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      medications: const [
        Medication(
          id: 'metformin',
          name: 'Метформин',
          dose: '500 мг',
          schedule: '08:00',
          takenToday: false,
          notes: '',
        ),
      ],
    );

    final result = engine.execute(state, 'Напомни принять метформин в 20:30');

    expect(result, isNotNull);
    expect(result!.state.medications.single.schedule, contains('08:00'));
    expect(result.state.medications.single.schedule, contains('20:30'));
    expect(result.state.reminders, isEmpty);
  });

  test('generic Russian lab command stores value, unit and reference', () {
    final state = HealthAppState.seed();
    final result = const AssistantToolEngine().execute(
      state,
      'Запиши анализ гемоглобин 108 г/л, норма 120-160',
    );

    expect(result, isNotNull);
    expect(result!.relatedSection, 'labs');
    expect(result.state.labResults.single.marker, 'Гемоглобин');
    expect(result.state.labResults.single.value, '108');
    expect(result.state.labResults.single.unit, 'г/л');
    expect(result.state.labResults.single.reference, '120-160');
    expect(result.state.labResults.single.needsAttention, isTrue);
  });

  test('voice activity command updates the day and completed sessions', () {
    final state = HealthAppState.seed();
    final result = const AssistantToolEngine().execute(
      state,
      'Запиши активность 35 минут',
    );

    expect(result, isNotNull);
    expect(result!.relatedSection, 'workouts');
    expect(result.state.today.workoutMinutes, 35);
    expect(result.state.today.activeCalories, 140);
    expect(result.state.workouts.single.status, 'completed');
    expect(result.state.workouts.single.mode, 'manual-activity');
  });

  test('Russian completed workout command updates activity totals', () {
    final result = engine.execute(
      HealthAppState.seed(),
      'Запиши: пробежал 5 км, тренировка 30 минут, 320 ккал',
    );

    expect(result, isNotNull);
    expect(result!.state.workouts.single.status, 'completed');
    expect(result.state.workouts.single.distanceMeters, 5000);
    expect(result.state.workouts.single.caloriesBurned, 320);
    expect(result.state.today.workoutMinutes, 30);
    expect(result.state.today.activeCalories, 320);
  });

  test(
    'Russian prescription command queues confirmation before scheduling',
    () {
      final result = engine.execute(
        HealthAppState.seed(),
        'Врач назначил метформин 500 мг 2 раза в день после еды',
      );

      expect(result, isNotNull);
      expect(result!.state.confirmationQueue, isNotEmpty);
      expect(
        result.state.confirmationQueue.first.requiresMedicalReview,
        isTrue,
      );
      expect(result.state.confirmationQueue.first.kind, 'voice-prescription');
      expect(result.relatedSection, 'medicines');
    },
  );
}
