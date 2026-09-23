import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'model.dart';

class HealthPlatformAvailability {
  const HealthPlatformAvailability({
    required this.supported,
    required this.provider,
    required this.message,
    this.installRequired = false,
  });

  final bool supported;
  final String provider;
  final String message;
  final bool installRequired;
}

class HealthDailySample {
  const HealthDailySample({
    required this.date,
    required this.steps,
    required this.activeCalories,
    required this.basalCalories,
    required this.distanceMeters,
    required this.workoutMinutes,
    this.weightKg,
  });

  final String date;
  final int steps;
  final int activeCalories;
  final int basalCalories;
  final double distanceMeters;
  final int workoutMinutes;
  final double? weightKg;
}

class HealthMeasurement {
  const HealthMeasurement({
    required this.id,
    required this.marker,
    required this.value,
    required this.unit,
    required this.date,
    required this.source,
    this.needsAttention = false,
  });

  final String id;
  final String marker;
  final String value;
  final String unit;
  final String date;
  final String source;
  final bool needsAttention;
}

class HealthPlatformSyncResult {
  const HealthPlatformSyncResult({
    required this.provider,
    required this.samples,
    required this.sleepRecords,
    required this.measurements,
    required this.sourceNames,
    required this.pointCount,
  });

  final String provider;
  final List<HealthDailySample> samples;
  final List<SleepRecord> sleepRecords;
  final List<HealthMeasurement> measurements;
  final List<String> sourceNames;
  final int pointCount;
}

class HealthPlatformService {
  HealthPlatformService({Health? health}) : _health = health ?? Health();

  final Health _health;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  String get provider => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  Future<HealthPlatformAvailability> checkAvailability() async {
    if (!isSupported) {
      return const HealthPlatformAvailability(
        supported: false,
        provider: 'Health Connect / Apple Health',
        message: 'Платформенная синхронизация доступна на Android и iOS.',
      );
    }
    await _health.configure();
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      final available = status == HealthConnectSdkStatus.sdkAvailable;
      return HealthPlatformAvailability(
        supported: available,
        provider: provider,
        installRequired: !available,
        message: available
            ? 'Health Connect готов к запросу разрешений.'
            : 'Health Connect не установлен или недоступен на этом устройстве.',
      );
    }
    return HealthPlatformAvailability(
      supported: true,
      provider: provider,
      message: 'Apple Health готов к запросу разрешений.',
    );
  }

  Future<void> installHealthConnect() async {
    if (Platform.isAndroid) await _health.installHealthConnect();
  }

  Future<HealthPlatformSyncResult> synchronize({int days = 7}) async {
    final availability = await checkAvailability();
    if (!availability.supported) {
      throw StateError(availability.message);
    }

    final types = _readTypes;
    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.request();
      if (!activityPermission.isGranted) {
        throw StateError(
          'Для синхронизации шагов требуется системное разрешение «Физическая активность».',
        );
      }
    }
    final permissions = List<HealthDataAccess>.filled(
      types.length,
      HealthDataAccess.READ,
    );
    final authorized = await _health.requestAuthorization(
      types,
      permissions: permissions,
    );
    if (!authorized) {
      throw StateError(
        'Доступ к данным не предоставлен. Разрешения можно изменить в системных настройках здоровья.',
      );
    }

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final raw = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: now,
    );
    final points = _health.removeDuplicates(raw);
    final builders = <String, _DailySampleBuilder>{};
    for (var offset = 0; offset < days; offset++) {
      final day = start.add(Duration(days: offset));
      final dayEnd = day.add(const Duration(days: 1));
      final effectiveEnd = dayEnd.isAfter(now) ? now : dayEnd;
      var steps = 0;
      if (effectiveEnd.isAfter(day)) {
        steps = await _health.getTotalStepsInInterval(day, effectiveEnd) ?? 0;
      }
      builders[todayKey(day)] = _DailySampleBuilder(steps: steps);
    }

    final sourceNames = <String>{};
    final latestMeasurements = <HealthDataType, HealthDataPoint>{};
    final sleepByDate = <String, _SleepBuilder>{};
    for (final point in points) {
      sourceNames.add(point.sourceName);
      final key = todayKey(point.dateTo.toLocal());
      final day = builders.putIfAbsent(key, _DailySampleBuilder.new);
      final numeric = _numericValue(point);
      switch (point.type) {
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          day.activeCalories += numeric.round();
        case HealthDataType.BASAL_ENERGY_BURNED:
          day.basalCalories += numeric.round();
        case HealthDataType.DISTANCE_DELTA:
        case HealthDataType.DISTANCE_WALKING_RUNNING:
          day.distanceMeters += numeric;
        case HealthDataType.WORKOUT:
          day.workoutMinutes += point.dateTo
              .difference(point.dateFrom)
              .inMinutes
              .clamp(0, 24 * 60);
        case HealthDataType.WEIGHT:
          if (day.weightAt == null || point.dateTo.isAfter(day.weightAt!)) {
            day.weightKg = numeric;
            day.weightAt = point.dateTo;
          }
        case HealthDataType.SLEEP_SESSION:
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_DEEP:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
          final sleep = sleepByDate.putIfAbsent(key, _SleepBuilder.new);
          sleep.include(point.dateFrom.toLocal(), point.dateTo.toLocal());
        case HealthDataType.HEART_RATE:
        case HealthDataType.RESTING_HEART_RATE:
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        case HealthDataType.BLOOD_OXYGEN:
        case HealthDataType.BODY_TEMPERATURE:
        case HealthDataType.BLOOD_GLUCOSE:
        case HealthDataType.BODY_FAT_PERCENTAGE:
        case HealthDataType.LEAN_BODY_MASS:
        case HealthDataType.BODY_MASS_INDEX:
        case HealthDataType.BODY_WATER_MASS:
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        case HealthDataType.RESPIRATORY_RATE:
        case HealthDataType.INSULIN_DELIVERY:
          final previous = latestMeasurements[point.type];
          if (previous == null || point.dateTo.isAfter(previous.dateTo)) {
            latestMeasurements[point.type] = point;
          }
        default:
          break;
      }
    }

    final samples =
        builders.entries
            .map((entry) => entry.value.build(entry.key))
            .where(
              (sample) =>
                  sample.steps > 0 ||
                  sample.activeCalories > 0 ||
                  sample.basalCalories > 0 ||
                  sample.distanceMeters > 0 ||
                  sample.workoutMinutes > 0 ||
                  sample.weightKg != null,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final sleeps =
        sleepByDate.entries
            .map((entry) => entry.value.build(entry.key, provider))
            .where((record) => record.durationMinutes > 0)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final measurements =
        latestMeasurements.values.map(_measurementFromPoint).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return HealthPlatformSyncResult(
      provider: provider,
      samples: samples,
      sleepRecords: sleeps,
      measurements: measurements,
      sourceNames:
          sourceNames.where((value) => value.trim().isNotEmpty).toList()
            ..sort(),
      pointCount: points.length,
    );
  }

  List<HealthDataType> get _readTypes {
    final common = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.WEIGHT,
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.LEAN_BODY_MASS,
      HealthDataType.BODY_MASS_INDEX,
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.WORKOUT,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
    ];
    if (Platform.isAndroid) {
      return [
        ...common,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.BODY_WATER_MASS,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      ];
    }
    return [
      ...common,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.INSULIN_DELIVERY,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    ];
  }
}

class _DailySampleBuilder {
  _DailySampleBuilder({this.steps = 0});

  int steps;
  int activeCalories = 0;
  int basalCalories = 0;
  double distanceMeters = 0;
  int workoutMinutes = 0;
  double? weightKg;
  DateTime? weightAt;

  HealthDailySample build(String date) => HealthDailySample(
    date: date,
    steps: steps,
    activeCalories: activeCalories,
    basalCalories: basalCalories,
    distanceMeters: distanceMeters,
    workoutMinutes: workoutMinutes,
    weightKg: weightKg,
  );
}

class _SleepBuilder {
  DateTime? start;
  DateTime? end;

  void include(DateTime from, DateTime to) {
    if (start == null || from.isBefore(start!)) start = from;
    if (end == null || to.isAfter(end!)) end = to;
  }

  SleepRecord build(String date, String provider) {
    final from = start;
    final to = end;
    final duration = from == null || to == null
        ? 0
        : to.difference(from).inMinutes;
    return SleepRecord(
      id: 'health-sleep-$date',
      date: date,
      bedTime: from == null ? '' : _clock(from),
      wakeTime: to == null ? '' : _clock(to),
      durationMinutes: duration.clamp(0, 24 * 60),
      quality: duration >= 7 * 60 && duration <= 9 * 60 ? 4 : 3,
      source: provider,
      timeZone: DateTime.now().timeZoneName,
      notes: 'Импортировано из $provider.',
    );
  }
}

HealthMeasurement _measurementFromPoint(HealthDataPoint point) {
  final value = _numericValue(point);
  final marker = switch (point.type) {
    HealthDataType.HEART_RATE => 'Пульс',
    HealthDataType.RESTING_HEART_RATE => 'Пульс в покое',
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC => 'Давление систолическое',
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC => 'Давление диастолическое',
    HealthDataType.BLOOD_OXYGEN => 'Насыщение крови кислородом',
    HealthDataType.BODY_TEMPERATURE => 'Температура тела',
    HealthDataType.BLOOD_GLUCOSE => 'Глюкоза крови',
    HealthDataType.BODY_FAT_PERCENTAGE => 'Жировая масса',
    HealthDataType.LEAN_BODY_MASS => 'Безжировая масса',
    HealthDataType.BODY_MASS_INDEX => 'Индекс массы тела',
    HealthDataType.BODY_WATER_MASS => 'Вода в организме',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
    HealthDataType.HEART_RATE_VARIABILITY_SDNN => 'Вариабельность пульса',
    HealthDataType.RESPIRATORY_RATE => 'Частота дыхания',
    HealthDataType.INSULIN_DELIVERY => 'Введено инсулина',
    _ => point.type.name,
  };
  final unit = switch (point.type) {
    HealthDataType.HEART_RATE || HealthDataType.RESTING_HEART_RATE => 'уд/мин',
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC ||
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC => 'мм рт. ст.',
    HealthDataType.BLOOD_OXYGEN => '%',
    HealthDataType.BODY_TEMPERATURE => '°C',
    HealthDataType.BLOOD_GLUCOSE => 'ммоль/л',
    HealthDataType.BODY_FAT_PERCENTAGE => '%',
    HealthDataType.LEAN_BODY_MASS => 'кг',
    HealthDataType.BODY_MASS_INDEX => 'кг/м²',
    HealthDataType.BODY_WATER_MASS => 'кг',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD ||
    HealthDataType.HEART_RATE_VARIABILITY_SDNN => 'мс',
    HealthDataType.RESPIRATORY_RATE => 'дых/мин',
    HealthDataType.INSULIN_DELIVERY => 'Ед',
    _ => point.unitString,
  };
  final normalized = switch (point.type) {
    HealthDataType.BLOOD_OXYGEN when value <= 1 => value * 100,
    HealthDataType.BODY_FAT_PERCENTAGE when value <= 1 => value * 100,
    HealthDataType.BLOOD_GLUCOSE => value / 18.01559,
    _ => value,
  };
  final needsAttention = switch (point.type) {
    HealthDataType.HEART_RATE ||
    HealthDataType.RESTING_HEART_RATE => normalized < 40 || normalized > 140,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC =>
      normalized < 80 || normalized > 180,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC =>
      normalized < 45 || normalized > 120,
    HealthDataType.BLOOD_OXYGEN => normalized < 92,
    HealthDataType.BODY_TEMPERATURE => normalized < 34 || normalized >= 39,
    HealthDataType.BLOOD_GLUCOSE => normalized < 3.9 || normalized > 10,
    HealthDataType.RESPIRATORY_RATE => normalized < 8 || normalized > 30,
    _ => false,
  };
  return HealthMeasurement(
    id: 'health-${point.type.name}-${point.uuid.isEmpty ? point.dateTo.millisecondsSinceEpoch : point.uuid}',
    marker: marker,
    value: _formatNumber(normalized),
    unit: unit,
    date: todayKey(point.dateTo.toLocal()),
    source: point.sourceName.trim().isEmpty
        ? 'платформенное здоровье'
        : point.sourceName,
    needsAttention: needsAttention,
  );
}

double _numericValue(HealthDataPoint point) {
  final value = point.value;
  return switch (value) {
    NumericHealthValue(:final numericValue) => numericValue.toDouble(),
    InsulinDeliveryHealthValue(:final units) => units,
    _ => 0,
  };
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
