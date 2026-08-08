import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/model.dart';

void main() {
  test('migrates legacy takenToday medication to dated intake log', () {
    final state = HealthAppState.fromJson({
      'today': DailyMetrics.empty('2026-06-14').toJson(),
      'medications': [
        {
          'id': 'med-1',
          'name': 'Магний',
          'dose': '200 мг',
          'schedule': 'вечером',
          'takenToday': true,
          'notes': '',
        },
      ],
    });

    expect(state.medicationIntakes, hasLength(1));
    expect(state.medicationIntakes.single.medicationName, 'Магний');
    expect(state.medicationIntakes.single.date, '2026-06-14');
    expect(state.medicationTakenCount('2026-06-14'), 1);
  });
}
