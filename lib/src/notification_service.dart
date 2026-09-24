import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'error_log_service.dart';
import 'model.dart';

class HealthNotificationService {
  HealthNotificationService._();

  static final instance = HealthNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String lastError = '';
  final ValueNotifier<String?> activePayload = ValueNotifier(null);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Открыть «Моё здоровье»',
        ),
        windows: WindowsInitializationSettings(
          appName: 'Моё здоровье',
          appUserModelId: 'Ru.TheBestMks.MyHealth',
          guid: '4c41c4da-79bc-4a8e-8cd3-d6605ba7df14',
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          activePayload.value = response.payload;
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        activePayload.value = launch?.notificationResponse?.payload;
      }
      _initialized = true;
      lastError = '';
    } catch (error, stackTrace) {
      lastError = '$error';
      debugPrint('Notification initialization failed: $error');
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Notification initialization',
      );
    }
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (!_initialized) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationAllowed =
          await android?.requestNotificationsPermission() ?? true;
      await android?.requestExactAlarmsPermission();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosAllowed = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final macAllowed = await mac?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return notificationAllowed &&
          (iosAllowed ?? true) &&
          (macAllowed ?? true);
    } catch (error, stackTrace) {
      lastError = '$error';
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Notification permissions',
      );
      return false;
    }
  }

  Future<void> sync(HealthAppState state) async {
    if (!state.settings.notificationsEnabled) {
      if (_initialized) await _plugin.cancelAll();
      return;
    }
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      if (state.settings.medicationNotifications) {
        await _scheduleMedicationNotifications(state, now);
      }
      await _scheduleUserReminders(state, now);
      if (state.settings.alarmNotifications) {
        await _scheduleAlarmGroups(state, now);
      }
      if (state.settings.activityNotifications) {
        await _scheduleActivityReminders(state, now);
      }
      lastError = '';
    } catch (error, stackTrace) {
      lastError = '$error';
      debugPrint('Notification sync failed: $error');
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Notification synchronization',
      );
    }
  }

  Future<int> pendingCount() async {
    await initialize();
    if (!_initialized) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Pending notifications',
      );
      return 0;
    }
  }

  Future<void> showTest() async {
    await initialize();
    if (!_initialized) return;
    await _plugin.show(
      id: 990001,
      title: 'Моё здоровье',
      body: 'Системные уведомления работают.',
      notificationDetails: _details('service', 'Служебные уведомления'),
    );
  }

  Future<void> dismissAlarmOccurrence(
    AlarmGroup alarm, {
    String? dateKey,
  }) async {
    await initialize();
    if (!_initialized) return;
    final key = dateKey == null || parseDateKey(dateKey) == null
        ? todayKey()
        : dateKey;
    await _plugin.cancel(id: _stableId('alarm:${alarm.id}:$key'));
    for (var stage = 0; stage < 3; stage++) {
      await _plugin.cancel(
        id: _stableId('alarm:${alarm.id}:$key:stage:$stage'),
      );
    }
  }

  Future<void> _scheduleMedicationNotifications(
    HealthAppState state,
    DateTime now,
  ) async {
    for (final medication in state.medications) {
      final times = _timesFromText(medication.schedule);
      if (times.isEmpty) continue;
      final courseStart = parseDateKey(medication.courseStart);
      final courseEnd = parseDateKey(medication.courseEnd);
      for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
        final date = DateTime(now.year, now.month, now.day + dayOffset);
        if (courseStart != null && date.isBefore(courseStart)) continue;
        if (courseEnd != null && date.isAfter(courseEnd)) continue;
        for (final time in times) {
          final scheduled = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          if (!scheduled.isAfter(now)) continue;
          await _schedule(
            id: _stableId(
              'medicine:${medication.id}:${todayKey(date)}:${time.hour}:${time.minute}',
            ),
            date: scheduled,
            title: medication.name,
            body:
                '${medication.dose}${medication.foodRule.isEmpty ? '' : ' · ${medication.foodRule}'}',
            channelId: 'medicines',
            channelName: 'Лекарства',
            payload: 'medicine:${medication.id}',
          );
        }
      }
      if (medication.stockIsLow) {
        await _schedule(
          id: _stableId('stock:${medication.id}'),
          date: now.add(const Duration(minutes: 2)),
          title: 'Пора пополнить запас',
          body: '${medication.name}: осталось ${medication.remainingUnits}',
          channelId: 'medicines',
          channelName: 'Лекарства',
          payload: 'medicine:${medication.id}',
        );
      }
    }
  }

  Future<void> _scheduleUserReminders(
    HealthAppState state,
    DateTime now,
  ) async {
    for (final reminder in state.reminders.where((item) => !item.done)) {
      final date = parseDateKey(reminder.date);
      final time = _parseTime(reminder.time);
      if (date == null || time == null) continue;
      final scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!scheduled.isAfter(now)) continue;
      await _schedule(
        id: _stableId('reminder:${reminder.id}'),
        date: scheduled,
        title: reminder.title,
        body: reminder.category,
        channelId: 'reminders',
        channelName: 'Напоминания',
        payload: 'reminder:${reminder.id}',
      );
    }
  }

  Future<void> _scheduleAlarmGroups(HealthAppState state, DateTime now) async {
    for (final alarm in state.alarmGroups) {
      final wakeTime = _parseTime(alarm.wakeTime);
      if (wakeTime == null) continue;
      for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
        final date = DateTime(now.year, now.month, now.day + dayOffset);
        if (!_alarmApplies(state, alarm, date)) continue;
        var scheduled = DateTime(
          date.year,
          date.month,
          date.day,
          wakeTime.hour,
          wakeTime.minute,
        );
        if (alarm.adaptive && alarm.smartWakeWindowMinutes > 0) {
          scheduled = _smartAlarmTime(state, alarm, date, scheduled);
        }
        if (!scheduled.isAfter(now)) continue;
        final body = alarm.unlockMode == 'simple'
            ? alarm.useWearableSleepCycle
                  ? 'Умное окно подъёма до ${alarm.wakeTime}; выбран ближайший расчётный конец цикла сна.'
                  : 'Время подъёма ${alarm.wakeTime}'
            : 'Для отключения откройте приложение и решите задачу.';
        if (!alarm.gradualWakeEnabled) {
          await _schedule(
            id: _stableId('alarm:${alarm.id}:${todayKey(date)}'),
            date: scheduled,
            title: alarm.title,
            body: body,
            channelId: 'alarms_full',
            channelName: 'Будильники',
            payload: 'alarm:${alarm.id}:${todayKey(date)}',
            alarm: true,
            vibrationEnabled: alarm.vibrationEnabled,
          );
          continue;
        }
        final rampMinutes = alarm.gradualWakeMinutes.clamp(1, 15);
        final stageTimes = gradualAlarmStageTimes(scheduled, rampMinutes);
        final stages = <({bool sound, String suffix})>[
          (sound: false, suffix: 'Тихое начало'),
          (sound: true, suffix: 'Мягкий сигнал'),
          (sound: true, suffix: 'Полный сигнал'),
        ];
        for (var stage = 0; stage < stages.length; stage++) {
          final item = stages[stage];
          final stageDate = stageTimes[stage];
          if (!stageDate.isAfter(now)) continue;
          await _schedule(
            id: _stableId('alarm:${alarm.id}:${todayKey(date)}:stage:$stage'),
            date: stageDate,
            title: alarm.title,
            body: '${item.suffix}. $body',
            channelId: stage == 0
                ? 'alarms_quiet'
                : stage == 1
                ? 'alarms_gentle'
                : 'alarms_full',
            channelName: 'Будильники',
            payload: 'alarm:${alarm.id}:${todayKey(date)}',
            alarm: true,
            soundEnabled: item.sound,
            vibrationEnabled: alarm.vibrationEnabled,
          );
        }
      }
    }
  }

  Future<void> _scheduleActivityReminders(
    HealthAppState state,
    DateTime now,
  ) async {
    final settings = state.activityReminders;
    for (var dayOffset = 0; dayOffset < 3; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      if (settings.warmupEnabled) {
        await _scheduleIntervalForDay(
          date: date,
          now: now,
          intervalMinutes: settings.warmupIntervalMinutes,
          quietStart: settings.quietStart,
          quietEnd: settings.quietEnd,
          key: 'warmup',
          title: 'Пора размяться',
          body: 'Сделайте короткую разминку или немного пройдитесь.',
        );
      }
      if (settings.waterEnabled) {
        await _scheduleIntervalForDay(
          date: date,
          now: now,
          intervalMinutes: settings.waterIntervalMinutes,
          quietStart: settings.quietStart,
          quietEnd: settings.quietEnd,
          key: 'water',
          title: 'Вода',
          body: 'Проверьте питьевой режим и добавьте небольшой стакан воды.',
        );
      }
    }
  }

  Future<void> _scheduleIntervalForDay({
    required DateTime date,
    required DateTime now,
    required int intervalMinutes,
    required String quietStart,
    required String quietEnd,
    required String key,
    required String title,
    required String body,
  }) async {
    if (intervalMinutes < 15) return;
    final start = _parseTime(quietEnd) ?? const _ClockTime(7, 0);
    final end = _parseTime(quietStart) ?? const _ClockTime(22, 0);
    var minute = start.hour * 60 + start.minute + intervalMinutes;
    final endMinute = end.hour * 60 + end.minute;
    while (minute < endMinute) {
      final scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        minute ~/ 60,
        minute % 60,
      );
      if (scheduled.isAfter(now)) {
        await _schedule(
          id: _stableId('$key:${todayKey(date)}:$minute'),
          date: scheduled,
          title: title,
          body: body,
          channelId: 'activity',
          channelName: 'Активность и вода',
          payload: key,
        );
      }
      minute += intervalMinutes;
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime date,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String payload,
    bool alarm = false,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
      ),
      notificationDetails: _details(
        channelId,
        channelName,
        alarm: alarm,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      ),
      androidScheduleMode: alarm
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  NotificationDetails _details(
    String channelId,
    String channelName, {
    bool alarm = false,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Уведомления приложения «Моё здоровье»',
      importance: alarm ? Importance.max : Importance.high,
      priority: alarm ? Priority.max : Priority.high,
      category: alarm ? AndroidNotificationCategory.alarm : null,
      visibility: NotificationVisibility.private,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
    ),
    iOS: DarwinNotificationDetails(presentSound: soundEnabled),
    macOS: DarwinNotificationDetails(presentSound: soundEnabled),
    linux: const LinuxNotificationDetails(),
    windows: WindowsNotificationDetails(
      scenario: alarm ? WindowsNotificationScenario.alarm : null,
    ),
  );
}

DateTime _smartAlarmTime(
  HealthAppState state,
  AlarmGroup alarm,
  DateTime date,
  DateTime target,
) {
  final windowStart = target.subtract(
    Duration(minutes: alarm.smartWakeWindowMinutes.clamp(0, 180)),
  );
  if (alarm.useWearableSleepCycle && state.sleepRecords.isNotEmpty) {
    final records = [...state.sleepRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    final bedtime = _parseTime(
      records.where((item) => item.bedTime.isNotEmpty).firstOrNull?.bedTime ??
          '',
    );
    if (bedtime != null) {
      var cycle = DateTime(
        date.year,
        date.month,
        date.day - 1,
        bedtime.hour,
        bedtime.minute,
      ).add(const Duration(minutes: 90));
      DateTime? candidate;
      while (!cycle.isAfter(target)) {
        if (!cycle.isBefore(windowStart)) candidate = cycle;
        cycle = cycle.add(const Duration(minutes: 90));
      }
      if (candidate != null) return candidate;
    }
  }
  return target.subtract(Duration(minutes: alarm.smartWakeWindowMinutes ~/ 2));
}

@visibleForTesting
List<DateTime> gradualAlarmStageTimes(DateTime target, int rampMinutes) {
  final bounded = rampMinutes.clamp(1, 15);
  return [
    target.subtract(Duration(minutes: bounded)),
    target.subtract(Duration(minutes: (bounded / 2).floor())),
    target,
  ];
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

_ClockTime? _parseTime(String source) {
  final match = RegExp(
    r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)',
  ).firstMatch(source);
  if (match == null) return null;
  return _ClockTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
}

List<_ClockTime> _timesFromText(String source) {
  return RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)')
      .allMatches(source)
      .map(
        (match) =>
            _ClockTime(int.parse(match.group(1)!), int.parse(match.group(2)!)),
      )
      .toList();
}

bool _alarmApplies(HealthAppState state, AlarmGroup alarm, DateTime date) {
  final key = todayKey(date);
  if (alarm.specificDate.isNotEmpty && alarm.specificDate != key) return false;
  final duty = state.workSchedule.duties.any((item) => item.date == key);
  final activeVacations = state.workSchedule.vacations.where(
    (item) =>
        key.compareTo(item.startDate) >= 0 && key.compareTo(item.endDate) <= 0,
  );
  final vacation = activeVacations.isNotEmpty;
  final trip = state.trips.any(
    (item) =>
        key.compareTo(item.startDate) >= 0 && key.compareTo(item.endDate) <= 0,
  );
  if (alarm.context == 'рабочий' && (duty || vacation)) return false;
  if (alarm.context == 'дежурство' && !duty) return false;
  if (alarm.context == 'отпуск') {
    if (!vacation) return false;
    final linked = activeVacations.where(
      (item) => item.alarmGroupId.isNotEmpty,
    );
    if (linked.isNotEmpty &&
        linked.every((item) => item.alarmGroupId != alarm.id)) {
      return false;
    }
  }
  if (alarm.context == 'командировка' && !trip) return false;
  if (alarm.dutyAware && duty && alarm.context == 'обычный') return false;
  if (alarm.vacationAware && vacation && alarm.context == 'обычный') {
    return false;
  }
  if (alarm.specificDate.isNotEmpty) return true;
  final source = alarm.days.toLowerCase();
  const aliases = [
    ['пн', 'mon', 'понедель'],
    ['вт', 'tue', 'вторник'],
    ['ср', 'wed', 'сред'],
    ['чт', 'thu', 'четвер'],
    ['пт', 'fri', 'пятниц'],
    ['сб', 'sat', 'суббот'],
    ['вс', 'sun', 'воскрес'],
  ];
  if (source.contains('ежеднев') ||
      source.contains('кажд') ||
      source.contains('every day')) {
    return true;
  }
  if (source.contains('будн') || source.contains('workday')) {
    return date.weekday <= DateTime.friday;
  }
  if (source.contains('по смен') || source.contains('плавающ')) {
    return _isScheduledWorkDay(state.workSchedule, date);
  }
  return aliases[date.weekday - 1].any(source.contains);
}

bool _isScheduledWorkDay(WorkSchedule schedule, DateTime date) {
  if (schedule.pattern == 'shift') {
    final anchor = parseDateKey(schedule.shiftAnchorDate);
    final workDays = schedule.shiftWorkDays.clamp(1, 31);
    final restDays = schedule.shiftRestDays.clamp(0, 31);
    final cycle = workDays + restDays;
    if (anchor == null || cycle <= 0) return false;
    final normalizedAnchor = DateTime.utc(
      anchor.year,
      anchor.month,
      anchor.day,
    );
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final delta = normalizedDate.difference(normalizedAnchor).inDays;
    if (delta < 0) return false;
    return delta % cycle < workDays;
  }
  const dayCodes = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  return schedule.workDays.contains(dayCodes[date.weekday - 1]);
}

@visibleForTesting
bool alarmAppliesOnDate(
  HealthAppState state,
  AlarmGroup alarm,
  DateTime date,
) => _alarmApplies(state, alarm, date);

int _stableId(String source) {
  var hash = 0x811c9dc5;
  for (final value in source.codeUnits) {
    hash ^= value;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
