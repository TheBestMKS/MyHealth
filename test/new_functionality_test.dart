import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/app.dart';
import 'package:my_health/src/model.dart';
import 'package:my_health/src/notification_service.dart';
import 'package:my_health/src/repository.dart';
import 'package:my_health/src/unit_format.dart';

void main() {
  test('persists the detailed climate profile without losing UTF-8 text', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      profile: seed.profile.copyWith(
        timeZone: 'Europe/Moscow',
        typicalTemperatureC: -12.5,
        humidityPercent: 84,
        altitudeMeters: 51,
        airQuality: 'умеренное',
        regionalAllergens: const ['пыльца берёзы'],
        climateReactions: const ['чувствительность к холоду'],
      ),
    );

    final restored = HealthAppState.fromJson(state.toJson());

    expect(restored.profile.timeZone, 'Europe/Moscow');
    expect(restored.profile.typicalTemperatureC, -12.5);
    expect(restored.profile.humidityPercent, 84);
    expect(restored.profile.airQuality, 'умеренное');
    expect(restored.profile.regionalAllergens, ['пыльца берёзы']);
    expect(restored.profile.climateReactions, ['чувствительность к холоду']);
  });

  test('gradual alarm ramps before and ends at the target time', () {
    final target = DateTime(2026, 7, 13, 7, 30);
    final stages = gradualAlarmStageTimes(target, 6);

    expect(stages, [
      DateTime(2026, 7, 13, 7, 24),
      DateTime(2026, 7, 13, 7, 27),
      target,
    ]);
  });

  test('persists active calories in daily metrics', () {
    final metric = DailyMetrics.empty(
      '2026-07-13',
    ).copyWith(activeCalories: 486, steps: 8120);

    final restored = DailyMetrics.fromJsonSafe(metric.toJson());

    expect(restored.activeCalories, 486);
    expect(restored.steps, 8120);
  });

  test('formats configured imperial units without changing stored values', () {
    const settings = AppSettings(
      bodyWeightUnit: 'lb',
      heightUnit: 'ft',
      distanceUnit: 'mi',
      temperatureUnit: 'fahrenheit',
      dateDisplayFormat: 'mm/dd/yyyy',
      timeFormat: '12h',
    );

    expect(formatWeight(70, settings), '154.3 lb');
    expect(formatHeight(180, settings), '5′ 11″');
    expect(formatDistance(1609.344, settings), '1.00 mi');
    expect(formatTemperature(0, settings), '32.0 °F');
    expect(formatDisplayDate('2026-07-13', settings), '07/13/2026');
    expect(formatTimeValue('18:05', settings), '6:05 PM');
  });

  test('softens motivation when an alarming symptom is present', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      settings: seed.settings.copyWith(motivationStrictness: 4),
      symptomEntries: [
        SymptomEntry(
          id: 'danger',
          symptom: 'сильная слабость',
          date: seed.today.date,
          time: '10:00',
          intensity: 9,
          temperatureC: 38.5,
          needsAttention: true,
        ),
      ],
    );

    expect(state.motivationMessage, contains('восстановление'));
    expect(state.motivationMessage, isNot(contains('Хватит откладывать')));
  });

  testWidgets('first setup allows only one predefined goal', (tester) async {
    await tester.pumpWidget(
      MyHealthApp(
        repository: InMemoryHealthRepository(),
        initialState: HealthAppState.seed(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('снижение веса'));
    await tester.pump();
    await tester.tap(find.text('набор силы'));
    await tester.pump();

    final first = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'снижение веса'),
    );
    final second = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'набор силы'),
    );
    expect(first.selected, isFalse);
    expect(second.selected, isTrue);
  });

  test('persists gradual alarm and vibration settings', () {
    const alarm = AlarmGroup(
      id: 'alarm',
      title: 'Work',
      wakeTime: '07:00',
      bedTime: '23:00',
      days: 'по сменам',
      adaptive: true,
      vibrationEnabled: false,
      gradualWakeEnabled: true,
      gradualWakeMinutes: 7,
    );

    final restored = AlarmGroup.fromJson(alarm.toJson());

    expect(restored.vibrationEnabled, isFalse);
    expect(restored.gradualWakeEnabled, isTrue);
    expect(restored.gradualWakeMinutes, 7);
  });

  test('shift alarm follows a structured work and rest cycle', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      workSchedule: seed.workSchedule.copyWith(
        pattern: 'shift',
        shiftAnchorDate: '2026-07-13',
        shiftWorkDays: 1,
        shiftRestDays: 3,
      ),
    );
    const alarm = AlarmGroup(
      id: 'shift',
      title: 'Shift',
      wakeTime: '07:00',
      bedTime: '23:00',
      days: 'по сменам',
      adaptive: false,
      context: 'рабочий',
    );

    expect(alarmAppliesOnDate(state, alarm, DateTime(2026, 7, 13)), isTrue);
    expect(alarmAppliesOnDate(state, alarm, DateTime(2026, 7, 14)), isFalse);
    expect(alarmAppliesOnDate(state, alarm, DateTime(2026, 7, 17)), isTrue);
  });

  test('work alarms stop for duties and trip alarms stay inside trips', () {
    final seed = HealthAppState.seed();
    final state = seed.copyWith(
      workSchedule: seed.workSchedule.copyWith(
        duties: const [
          WorkDuty(
            id: 'duty',
            date: '2026-07-13',
            startTime: '08:00',
            endTime: '08:00',
          ),
        ],
      ),
      trips: const [
        TripPlan(
          id: 'trip',
          title: 'Trip',
          startDate: '2026-07-20',
          endDate: '2026-07-22',
          climate: '',
          timeZoneShift: 0,
          adjustment: '',
        ),
      ],
    );
    const workAlarm = AlarmGroup(
      id: 'work',
      title: 'Work',
      wakeTime: '07:00',
      bedTime: '23:00',
      days: 'каждый день',
      adaptive: false,
      context: 'рабочий',
      specificDate: '2026-07-13',
    );
    const tripAlarm = AlarmGroup(
      id: 'trip-alarm',
      title: 'Trip',
      wakeTime: '07:00',
      bedTime: '23:00',
      days: 'каждый день',
      adaptive: false,
      context: 'командировка',
    );

    expect(
      alarmAppliesOnDate(state, workAlarm, DateTime(2026, 7, 13)),
      isFalse,
    );
    expect(
      alarmAppliesOnDate(state, tripAlarm, DateTime(2026, 7, 19)),
      isFalse,
    );
    expect(alarmAppliesOnDate(state, tripAlarm, DateTime(2026, 7, 21)), isTrue);
  });
}
