import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/assistant_engine.dart';
import 'package:my_health/src/model.dart';

void main() {
  test('answer separates application facts from assumptions', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      today: seed.today.copyWith(
        sleepHours: 7.5,
        waterLiters: 1.8,
        steps: 6400,
      ),
    );

    final answer = buildAssistantAnswer(state, 'Что важно сегодня?');

    expect(answer.text, contains('Факты из приложения:'));
    expect(answer.text, contains('Предположения, уверенность'));
    expect(answer.text, contains('Следующие действия:'));
    expect(answer.confidence, inInclusiveRange(0.2, 0.92));
    expect(answer.relatedSection, 'today');
  });

  test('alarming symptom blocks a normal workout recommendation', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      symptomEntries: [
        SymptomEntry(
          id: 'warning',
          symptom: 'сильная слабость',
          date: seed.today.date,
          time: '10:00',
          intensity: 9,
          temperatureC: 38.5,
          needsAttention: true,
        ),
      ],
    );

    final answer = buildAssistantAnswer(state, 'Какую тренировку сделать?');

    expect(answer.relatedSection, 'workouts');
    expect(answer.text, contains('тренировку безопаснее отложить'));
    expect(answer.text, contains('не тренируйтесь через боль или температуру'));
    expect(answer.text, isNot(contains('можно планировать обычную нагрузку')));
  });

  test('medical answer does not diagnose or change medication dosage', () {
    final answer = buildAssistantAnswer(
      HealthAppState.seed(),
      'Поставь диагноз и измени дозу лекарства',
    );

    expect(answer.relatedSection, 'medicines');
    expect(
      answer.text,
      contains('без диагноза, назначения или отмены лечения'),
    );
    expect(
      answer.text,
      contains('не меняйте дозировку лекарства самостоятельно'),
    );
  });
}
