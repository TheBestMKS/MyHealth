import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'error_log_service.dart';
import 'model.dart';
import 'notification_service.dart';

class WakefulnessMonitorStatus {
  const WakefulnessMonitorStatus({
    this.active = false,
    this.alarmTitle = '',
    this.activityConfirmed = false,
  });

  final bool active;
  final String alarmTitle;
  final bool activityConfirmed;
}

class WakefulnessMonitorService {
  WakefulnessMonitorService._();

  static final instance = WakefulnessMonitorService._();

  final ValueNotifier<WakefulnessMonitorStatus> status = ValueNotifier(
    const WakefulnessMonitorStatus(),
  );

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  Timer? _stopTimer;
  AlarmGroup? _alarm;
  String? _dateKey;
  int _activeSamples = 0;
  int _motionBursts = 0;
  DateTime? _firstMotionAt;
  DateTime? _lastMotionBurstAt;
  DateTime? _lastRecordedActivityAt;
  bool _recordingActivity = false;
  HealthAppState Function()? _readState;
  void Function(HealthAppState)? _writeState;

  void bind({
    required HealthAppState Function() readState,
    required void Function(HealthAppState) writeState,
  }) {
    _readState = readState;
    _writeState = writeState;
  }

  void unbind() {
    _readState = null;
    _writeState = null;
  }

  Future<void> start(
    AlarmGroup alarm, {
    String? dateKey,
    bool resetWindow = true,
  }) async {
    await stop(cancelChecks: false);
    if (!alarm.wakefulnessCheckEnabled) return;
    final now = DateTime.now();
    final key = dateKey ?? todayKey(now);
    final latestAlarm = _readState
        ?.call()
        .alarmGroups
        .where((item) => item.id == alarm.id)
        .firstOrNull;
    alarm = latestAlarm ?? alarm;
    var monitorStarted = resetWindow
        ? null
        : DateTime.tryParse(alarm.wakefulnessMonitorStartedAt)?.toLocal();
    if (monitorStarted == null || todayKey(monitorStarted) != key) {
      monitorStarted = now;
    }
    final monitoredAlarm = alarm.copyWith(
      lastWakefulnessConfirmedDate: '',
      wakefulnessMonitorStartedAt: monitorStarted.toIso8601String(),
      wakefulnessLastActivityAt: now.toIso8601String(),
    );
    _alarm = monitoredAlarm;
    _dateKey = key;
    _lastRecordedActivityAt = now;
    _activeSamples = 0;
    _motionBursts = 0;
    _firstMotionAt = null;
    _lastMotionBurstAt = null;
    _recordingActivity = false;
    status.value = WakefulnessMonitorStatus(
      active: true,
      alarmTitle: monitoredAlarm.title,
    );
    _writeAlarm(monitoredAlarm);
    final windowEnd = monitorStarted.add(
      Duration(minutes: monitoredAlarm.wakefulnessWindowMinutes.clamp(5, 120)),
    );
    final remaining = windowEnd.difference(now);
    if (remaining <= Duration.zero) {
      await _completeMonitoring();
      return;
    }
    _stopTimer = Timer(remaining, () => unawaited(_completeMonitoring()));
    if (!Platform.isAndroid && !Platform.isIOS) {
      await ErrorLogService.instance.recordInfo(
        'Акселерометр недоступен на этой платформе; проверки бодрствования оставлены по расписанию.',
        source: 'Wakefulness monitor',
      );
      return;
    }
    try {
      _subscription =
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.normalInterval,
          ).listen(
            _handleEvent,
            onError: (Object error, StackTrace stackTrace) {
              unawaited(
                ErrorLogService.instance.recordError(
                  error,
                  stackTrace,
                  source: 'Wakefulness accelerometer stream',
                ),
              );
            },
            cancelOnError: false,
          );
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Wakefulness monitor start',
      );
    }
  }

  void _handleEvent(UserAccelerometerEvent event) {
    final score = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _activeSamples = motionConfirmsWakefulness(score, _activeSamples)
        ? _activeSamples + 1
        : math.max(0, _activeSamples - 1);
    if (_activeSamples >= 3) {
      final now = DateTime.now();
      if (_lastMotionBurstAt != null &&
          now.difference(_lastMotionBurstAt!) > const Duration(seconds: 15)) {
        _motionBursts = 0;
        _firstMotionAt = now;
      }
      _firstMotionAt ??= now;
      if (_lastMotionBurstAt == null ||
          now.difference(_lastMotionBurstAt!) >= const Duration(seconds: 3)) {
        _motionBursts++;
        _lastMotionBurstAt = now;
      }
    }
    final firstMotion = _firstMotionAt;
    if (_motionBursts >= 4 &&
        firstMotion != null &&
        DateTime.now().difference(firstMotion) >= const Duration(seconds: 9)) {
      _motionBursts = 0;
      _firstMotionAt = null;
      _lastMotionBurstAt = null;
      _recordActivity();
    }
  }

  void _recordActivity() {
    final alarm = _alarm;
    if (alarm == null || _recordingActivity) return;
    final now = DateTime.now();
    final debounceSeconds = (alarm.wakefulnessInactivityMinutes * 20).clamp(
      20,
      60,
    );
    final previous = _lastRecordedActivityAt;
    if (previous != null &&
        now.difference(previous) < Duration(seconds: debounceSeconds)) {
      return;
    }
    _recordingActivity = true;
    final updated = alarm.copyWith(
      wakefulnessLastActivityAt: now.toIso8601String(),
    );
    _alarm = updated;
    _lastRecordedActivityAt = now;
    status.value = WakefulnessMonitorStatus(
      active: true,
      alarmTitle: updated.title,
      activityConfirmed: true,
    );
    _writeAlarm(updated);
    _recordingActivity = false;
  }

  Future<void> _completeMonitoring() async {
    final alarm = _alarm;
    if (alarm == null) return;
    await HealthNotificationService.instance.cancelWakefulnessChecks(
      alarm,
      dateKey: _dateKey,
    );
    final confirmedDate = _dateKey;
    if (confirmedDate != null) {
      _writeAlarm(
        alarm.copyWith(
          lastWakefulnessConfirmedDate: confirmedDate,
          wakefulnessMonitorStartedAt: '',
          wakefulnessLastActivityAt: '',
        ),
      );
    }
    status.value = WakefulnessMonitorStatus(
      alarmTitle: alarm.title,
      activityConfirmed: true,
    );
    await ErrorLogService.instance.recordInfo(
      'Период контроля бодрствования завершён; повторные сигналы отменены.',
      source: 'Wakefulness monitor',
    );
    await stop(cancelChecks: false, preserveStatus: true);
  }

  void _writeAlarm(AlarmGroup alarm) {
    final read = _readState;
    final write = _writeState;
    if (read == null || write == null) return;
    final state = read();
    write(
      state.copyWith(
        alarmGroups: state.alarmGroups
            .map((item) => item.id == alarm.id ? alarm : item)
            .toList(),
      ),
    );
  }

  Future<void> stop({
    bool cancelChecks = false,
    bool preserveStatus = false,
  }) async {
    _stopTimer?.cancel();
    _stopTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final alarm = _alarm;
    final dateKey = _dateKey;
    _alarm = null;
    _dateKey = null;
    _lastRecordedActivityAt = null;
    _activeSamples = 0;
    _motionBursts = 0;
    _firstMotionAt = null;
    _lastMotionBurstAt = null;
    _recordingActivity = false;
    if (cancelChecks && alarm != null) {
      await HealthNotificationService.instance.cancelWakefulnessChecks(
        alarm,
        dateKey: dateKey,
      );
    }
    if (!preserveStatus) {
      status.value = const WakefulnessMonitorStatus();
    }
  }
}

@visibleForTesting
bool motionConfirmsWakefulness(double acceleration, int activeSamples) {
  return acceleration >= 0.7 || (activeSamples >= 3 && acceleration >= 0.35);
}
