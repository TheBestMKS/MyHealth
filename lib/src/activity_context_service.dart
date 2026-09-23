import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'model.dart';

class ActivityContextSnapshot {
  const ActivityContextSnapshot({
    required this.capturedAt,
    required this.motion,
    required this.place,
    required this.phoneState,
    this.latitude,
    this.longitude,
    this.motionScore = 0,
    this.locationAccuracyMeters,
    this.notes = const [],
  });

  final DateTime capturedAt;
  final String motion;
  final String place;
  final String phoneState;
  final double? latitude;
  final double? longitude;
  final double motionScore;
  final double? locationAccuracyMeters;
  final List<String> notes;

  String get summary {
    final parts = <String>[
      'Место: $place',
      'Движение: $motion',
      'Телефон: $phoneState',
      if (locationAccuracyMeters != null)
        'точность GPS ${locationAccuracyMeters!.round()} м',
    ];
    return parts.join(' · ');
  }
}

class ActivityContextService {
  const ActivityContextService();

  Future<ActivityContextSnapshot> capture(
    UserProfile profile, {
    required bool geolocationEnabled,
  }) async {
    final notes = <String>[];
    final motion = await _captureMotion(notes);
    Position? position;
    if (geolocationEnabled) {
      position = await _capturePosition(notes);
    } else {
      notes.add('Геолокация отключена в настройках.');
    }

    final place = position == null
        ? 'не определено'
        : _classifyPlace(profile, position);
    return ActivityContextSnapshot(
      capturedAt: DateTime.now(),
      motion: motion.label,
      place: place,
      phoneState: motion.phoneState,
      latitude: position?.latitude,
      longitude: position?.longitude,
      motionScore: motion.score,
      locationAccuracyMeters: position?.accuracy,
      notes: notes,
    );
  }

  Future<Position?> currentPosition() => _capturePosition(<String>[]);

  Future<_MotionResult> _captureMotion(List<String> notes) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      notes.add('Акселерометр доступен только на Android и iOS.');
      return const _MotionResult('нет датчика', 'приложение открыто', 0);
    }
    try {
      final events = await userAccelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).take(24).toList().timeout(const Duration(seconds: 5));
      if (events.isEmpty) {
        return const _MotionResult('нет данных', 'приложение открыто', 0);
      }
      final magnitudes = events
          .map((e) => math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z))
          .toList(growable: false);
      final score =
          magnitudes.reduce((a, b) => a + b) / magnitudes.length.toDouble();
      if (score >= 1.4) {
        return _MotionResult('активное движение', 'вероятно в руках', score);
      }
      if (score >= 0.25) {
        return _MotionResult('лёгкое движение', 'вероятно используется', score);
      }
      return _MotionResult(
        'неподвижно',
        'лежит или удерживается спокойно',
        score,
      );
    } catch (error) {
      notes.add('Датчик движения недоступен: $error');
      return const _MotionResult('нет данных', 'приложение открыто', 0);
    }
  }

  Future<Position?> _capturePosition(List<String> notes) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        notes.add('Службы геолокации выключены.');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        notes.add('Разрешение геолокации не предоставлено.');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (error) {
      notes.add('Позиция не получена: $error');
      return null;
    }
  }

  String _classifyPlace(UserProfile profile, Position position) {
    final radius = profile.placeRadiusMeters.toDouble();
    final homeDistance = _distance(
      position,
      profile.homeLatitude,
      profile.homeLongitude,
    );
    final workDistance = _distance(
      position,
      profile.workLatitude,
      profile.workLongitude,
    );
    if (homeDistance != null && homeDistance <= radius) return 'дома';
    if (workDistance != null && workDistance <= radius) return 'на работе';
    return 'другое место';
  }

  double? _distance(Position position, double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }
}

class _MotionResult {
  const _MotionResult(this.label, this.phoneState, this.score);

  final String label;
  final String phoneState;
  final double score;
}
