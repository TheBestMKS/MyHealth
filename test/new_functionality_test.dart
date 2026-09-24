import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/app.dart';
import 'package:my_health/src/model.dart';
import 'package:my_health/src/notification_service.dart';
import 'package:my_health/src/repository.dart';
import 'package:my_health/src/unit_format.dart';
import 'package:my_health/src/wakefulness_monitor_service.dart';

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

  test('wakefulness checks cover the configured window at fixed intervals', () {
    final target = DateTime(2026, 9, 24, 7);

    expect(wakefulnessCheckTimes(target, 20, 5), [
      DateTime(2026, 9, 24, 7, 5),
      DateTime(2026, 9, 24, 7, 10),
      DateTime(2026, 9, 24, 7, 15),
      DateTime(2026, 9, 24, 7, 20),
    ]);
    expect(motionConfirmsWakefulness(0.8, 0), isTrue);
    expect(motionConfirmsWakefulness(0.1, 0), isFalse);
    expect(
      wakefulnessMonitorCheckTimes(
        DateTime(2026, 9, 24, 7, 6),
        DateTime(2026, 9, 24, 7, 20),
        5,
      ),
      [DateTime(2026, 9, 24, 7, 11), DateTime(2026, 9, 24, 7, 16)],
    );
  });

  test('persists active calories in daily metrics', () {
    final metric = DailyMetrics.empty(
      '2026-07-13',
    ).copyWith(activeCalories: 486, steps: 8120);

    final restored = DailyMetrics.fromJsonSafe(metric.toJson());

    expect(restored.activeCalories, 486);
    expect(restored.steps, 8120);
  });

  test('fills missed days with resting calories and keeps prior entries', () {
    final seed = HealthAppState.seed();
    final oldDay = DailyMetrics.empty(
      '2026-09-20',
    ).copyWith(steps: 4321, waterLiters: 1.4, activeCalories: 220);
    final state = seed.copyWith(
      profile: seed.profile.copyWith(
        birthDate: '1990-05-12',
        heightCm: 180,
        weightKg: 80,
        gender: 'мужчина',
      ),
      today: oldDay,
      dailyHistory: [oldDay],
    );

    final rolled = state.rollForwardDailyTimeline(DateTime(2026, 9, 24, 12));
    final dates = rolled.dailyHistory.map((item) => item.date).toSet();

    expect(
      dates,
      containsAll(<String>{
        '2026-09-20',
        '2026-09-21',
        '2026-09-22',
        '2026-09-23',
        '2026-09-24',
      }),
    );
    expect(rolled.metricsFor('2026-09-20').steps, 4321);
    expect(
      rolled.metricsFor('2026-09-21').restingCalories,
      rolled.basalCaloriesForDate(DateTime(2026, 9, 21)),
    );
    expect(
      rolled.today.restingCalories,
      closeTo(rolled.basalCaloriesForDate(DateTime(2026, 9, 24)) / 2, 1),
    );
  });

  test('edits and serializes a previous day without changing today', () {
    final seed = HealthAppState.seed();
    final today = DailyMetrics.empty('2026-09-24').copyWith(steps: 9000);
    final yesterday = DailyMetrics.empty(
      '2026-09-23',
    ).copyWith(restingCalories: 1700);
    final state = seed.copyWith(today: today, dailyHistory: [today, yesterday]);
    final edited = state.updateMetricsFor(
      '2026-09-23',
      yesterday.copyWith(waterLiters: 2.1, calories: 2050),
    );
    final restored = HealthAppState.fromJson(edited.toJson());

    expect(restored.today.steps, 9000);
    expect(restored.metricsFor('2026-09-23').waterLiters, 2.1);
    expect(restored.metricsFor('2026-09-23').calories, 2050);
    expect(restored.metricsFor('2026-09-23').restingCalories, 1700);
  });

  test('date parser rejects impossible dates instead of rolling them over', () {
    expect(parseDateKey('29.02.2024'), DateTime(2024, 2, 29));
    expect(parseDateKey('2024-02-29'), DateTime(2024, 2, 29));
    expect(parseDateKey('31.02.2026'), isNull);
    expect(parseDateKey('2026-13-01'), isNull);
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
      wakefulnessCheckEnabled: true,
      wakefulnessWindowMinutes: 45,
      wakefulnessInactivityMinutes: 6,
      lastWakefulnessConfirmedDate: '2026-07-13',
      wakefulnessMonitorStartedAt: '2026-07-13T07:00:00.000',
      wakefulnessLastActivityAt: '2026-07-13T07:08:00.000',
    );

    final restored = AlarmGroup.fromJson(alarm.toJson());

    expect(restored.vibrationEnabled, isFalse);
    expect(restored.gradualWakeEnabled, isTrue);
    expect(restored.gradualWakeMinutes, 7);
    expect(restored.wakefulnessCheckEnabled, isTrue);
    expect(restored.wakefulnessWindowMinutes, 45);
    expect(restored.wakefulnessInactivityMinutes, 6);
    expect(restored.lastWakefulnessConfirmedDate, '2026-07-13');
    expect(restored.wakefulnessMonitorStartedAt, '2026-07-13T07:00:00.000');
    expect(restored.wakefulnessLastActivityAt, '2026-07-13T07:08:00.000');
  });

  test('keeps completed day resting calories stable after profile changes', () {
    final seed = HealthAppState.seed();
    final first = seed
        .copyWith(
          profile: seed.profile.copyWith(
            birthDate: '1990-01-01',
            heightCm: 180,
            weightKg: 80,
            gender: 'мужской',
          ),
        )
        .rollForwardDailyTimeline(DateTime(2026, 7, 13, 23, 59));
    final nextDay = first.rollForwardDailyTimeline(DateTime(2026, 7, 14, 12));
    final completedCalories = nextDay.metricsFor('2026-07-13').restingCalories;
    final changedProfile = nextDay
        .copyWith(profile: nextDay.profile.copyWith(weightKg: 120))
        .rollForwardDailyTimeline(DateTime(2026, 7, 14, 13));

    expect(
      changedProfile.metricsFor('2026-07-13').restingCalories,
      completedCalories,
    );
    expect(changedProfile.today.date, '2026-07-14');
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
