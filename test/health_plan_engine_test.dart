import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/health_plan_engine.dart';
import 'package:my_health/src/model.dart';

void main() {
  test('urgent symptoms override a normal training recommendation', () {
    final seed = HealthAppState.seed();
    const date = '2026-09-23';
    final state = seed.copyWith(
      today: seed.today.copyWith(date: date, sleepHours: 8),
      symptomEntries: const [
        SymptomEntry(
          id: 'urgent',
          symptom: 'сильная одышка',
          date: date,
          time: '09:00',
          intensity: 9,
          needsAttention: true,
        ),
      ],
    );

    final plan = buildIntegratedHealthPlan(
      state,
      now: DateTime(2026, 9, 23, 10),
    );

    expect(plan.hasUrgent, isTrue);
    expect(
      plan.recommendations.any(
        (item) =>
            item.section == 'symptoms' && item.severity == PlanSeverity.urgent,
      ),
      isTrue,
    );
    expect(
      plan.recommendations.any(
        (item) => item.detail.contains('обычную нагрузку'),
      ),
      isFalse,
    );
  });

  test(
    'links abnormal glucose and due medicine without calculating insulin',
    () {
      final seed = HealthAppState.seed();
      const date = '2026-09-23';
      final state = seed.copyWith(
        today: seed.today.copyWith(date: date),
        labResults: const [
          LabResult(
            id: 'glucose',
            marker: 'Глюкоза крови',
            value: '14.2',
            unit: 'ммоль/л',
            reference: '3.9-10.0',
            date: date,
            needsAttention: true,
            notes: '',
          ),
        ],
        medications: const [
          Medication(
            id: 'medicine',
            name: 'Назначенный препарат',
            dose: '1 таблетка',
            schedule: '08:00',
            takenToday: false,
            notes: '',
          ),
        ],
      );

      final plan = buildIntegratedHealthPlan(
        state,
        now: DateTime(2026, 9, 23, 12),
      );
      final details = plan.recommendations
          .map((item) => item.detail)
          .join('\n');

      expect(details, contains('не рассчитывает дозу инсулина'));
      expect(
        plan.recommendations.any((item) => item.section == 'medicines'),
        isTrue,
      );
    },
  );
}
