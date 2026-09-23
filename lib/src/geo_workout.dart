import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'model.dart';
import 'unit_format.dart';
import 'widgets.dart';

class GeoWorkoutPanel extends StatefulWidget {
  const GeoWorkoutPanel({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final ValueChanged<HealthAppState> onChanged;

  @override
  State<GeoWorkoutPanel> createState() => _GeoWorkoutPanelState();
}

class _GeoWorkoutPanelState extends State<GeoWorkoutPanel> {
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  DateTime? _startedAt;
  Position? _lastPosition;
  String _mode = 'бег';
  String _status = 'готово';
  String _error = '';
  int _elapsedSeconds = 0;
  double _distanceMeters = 0;
  double _speedKmh = 0;
  double _maxSpeedKmh = 0;
  final List<GeoPoint> _path = [];

  bool get _running => _subscription != null;

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.state.settings.geolocationEnabled;
    final pathPoints = _path
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final offlinePack = widget.state.offlineMapPacks
        .where(
          (pack) =>
              pack.city == widget.state.profile.city ||
              pack.country == widget.state.profile.country,
        )
        .firstOrNull;
    final canShowMap =
        widget.state.settings.openStreetMapEnabled &&
        pathPoints.isNotEmpty &&
        (!widget.state.settings.offlineOnly || offlinePack != null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    'Геотренировка',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (value) {
                    if (!value && _running) {
                      _stop(save: false);
                    }
                    widget.onChanged(
                      widget.state.copyWith(
                        settings: widget.state.settings.copyWith(
                          geolocationEnabled: value,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            LocalizedDropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Режим'),
              items: const [
                DropdownMenuItem(value: 'бег', child: LocalizedText('бег')),
                DropdownMenuItem(
                  value: 'ходьба',
                  child: LocalizedText('ходьба'),
                ),
                DropdownMenuItem(
                  value: 'велосипед',
                  child: LocalizedText('велосипед'),
                ),
              ],
              onChanged: _running
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _mode = value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  label: _formatElapsed(_elapsedSeconds),
                  icon: Icons.timer_outlined,
                ),
                Pill(
                  label: formatDistance(_distanceMeters, widget.state.settings),
                  icon: Icons.route_outlined,
                ),
                Pill(
                  label: formatSpeed(_speedKmh, widget.state.settings),
                  icon: Icons.speed_outlined,
                ),
                Pill(
                  label:
                      'max ${formatSpeed(_maxSpeedKmh, widget.state.settings)}',
                  icon: Icons.trending_up_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LocalizedText(
              enabled
                  ? 'Статус: $_status'
                  : 'Геолокация отключена в настройках профиля.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 6),
              LocalizedText(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (canShowMap) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: pathPoints.last,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: offlinePack == null
                            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                            : '${offlinePack.storagePath}/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ru.thebestmks.my_health',
                        tileProvider: offlinePack == null
                            ? null
                            : FileTileProvider(),
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: pathPoints,
                            strokeWidth: 5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pathPoints.last,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.state.settings.openStreetMapEnabled &&
                pathPoints.isNotEmpty &&
                widget.state.settings.offlineOnly &&
                offlinePack == null)
              const InfoTile(
                icon: Icons.map_outlined,
                title: 'Карта маршрута недоступна офлайн',
                subtitle:
                    'Загрузите пакет города, региона или страны либо отключите режим «Полностью офлайн». Маршрут и дистанция продолжают записываться.',
              ),
            const SizedBox(height: 12),
            if (offlinePack != null)
              LocalizedText(
                'Карта: офлайн-пакет «${offlinePack.title}» (${offlinePack.tileCount} тайлов)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: enabled && !_running ? _start : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const LocalizedText('Старт'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _running ? () => _stop(save: true) : null,
                  icon: const Icon(Icons.stop),
                  label: const LocalizedText('Завершить и сохранить'),
                ),
                TextButton.icon(
                  onPressed: _running || _path.isNotEmpty
                      ? () => _stop(save: false)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const LocalizedText('Сбросить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _error = '';
      _status = 'проверка разрешений';
    });
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'геолокация недоступна';
        _error =
            'Включите GPS/геолокацию в системе или отключите режим геотренировки.';
      });
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _status = 'нет разрешения';
        _error = 'Приложению не выдано разрешение на геолокацию.';
      });
      return;
    }

    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _distanceMeters = 0;
    _speedKmh = 0;
    _maxSpeedKmh = 0;
    _lastPosition = null;
    _path.clear();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started != null && mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(started).inSeconds;
        });
      }
    });
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_handlePosition, onError: _handleLocationError);
    setState(() => _status = 'ожидание первой точки');
  }

  void _handlePosition(Position position) {
    final now = DateTime.now();
    final previous = _lastPosition;
    if (position.accuracy > 90) {
      setState(() {
        _status = 'ожидание точной координаты';
        _error =
            'Точность ${position.accuracy.toStringAsFixed(0)} м: точка не добавлена.';
      });
      return;
    }

    var accept = true;
    var segmentMeters = 0.0;
    var segmentSpeed = 0.0;
    if (previous != null) {
      final elapsed =
          position.timestamp.difference(previous.timestamp).inMilliseconds /
          1000;
      if (elapsed > 0) {
        segmentMeters = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        );
        segmentSpeed = segmentMeters / elapsed * 3.6;
        final maxSpeed = _maxHumanSpeedKmh(_mode);
        final maxSegment = maxSpeed / 3.6 * elapsed * 1.35;
        if (segmentSpeed > maxSpeed || segmentMeters > maxSegment) {
          accept = false;
          setState(() {
            _status = 'фильтрация скачка координаты';
            _error =
                'GPS/GLONASS дал невозможный скачок: ${segmentMeters.toStringAsFixed(0)} м за ${elapsed.toStringAsFixed(1)} с. Ждём следующую точку.';
          });
        }
      }
    }
    if (!accept) {
      return;
    }
    _lastPosition = position;
    _distanceMeters += segmentMeters;
    _speedKmh = position.speed > 0 ? position.speed * 3.6 : segmentSpeed;
    _maxSpeedKmh = _maxSpeedKmh < _speedKmh ? _speedKmh : _maxSpeedKmh;
    _path.add(
      GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: now.toIso8601String(),
        accuracyMeters: position.accuracy,
        speedKmh: _speedKmh,
      ),
    );
    setState(() {
      _status = 'запись маршрута';
      _error = '';
    });
  }

  void _handleLocationError(Object error) {
    setState(() {
      _status = 'ошибка геолокации';
      _error = '$error';
    });
  }

  Future<void> _stop({required bool save}) async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    final startedAt = _startedAt;
    if (!save || startedAt == null || _elapsedSeconds == 0) {
      setState(() {
        _startedAt = null;
        _lastPosition = null;
        _elapsedSeconds = 0;
        _distanceMeters = 0;
        _speedKmh = 0;
        _maxSpeedKmh = 0;
        _path.clear();
        _status = 'готово';
        _error = '';
      });
      return;
    }
    final minutes = (_elapsedSeconds / 60).ceil();
    final averageSpeed = _elapsedSeconds == 0
        ? 0.0
        : _distanceMeters / _elapsedSeconds * 3.6;
    final calories =
        (widget.state.profile.weightKg <= 0
                ? _distanceMeters / 1000 * 65
                : widget.state.profile.weightKg * _distanceMeters / 1000)
            .round();
    final workout = WorkoutSession(
      id: newId(),
      title: '${_mode[0].toUpperCase()}${_mode.substring(1)} по геолокации',
      focus: _mode == 'бег' ? 'кардио' : _mode,
      minutes: minutes,
      intensity: averageSpeed > 10 ? 'высокая' : 'средняя',
      scheduledDate: todayKey(startedAt),
      exerciseIds: const [],
      notes:
          'Автозапись GPS/GLONASS: ${formatDistance(_distanceMeters, widget.state.settings)}, средняя скорость ${formatSpeed(averageSpeed, widget.state.settings)}. Невозможные скачки координат отфильтрованы.',
      mode: _mode,
      distanceMeters: _distanceMeters,
      elapsedSeconds: _elapsedSeconds,
      averageSpeedKmh: averageSpeed,
      maxSpeedKmh: _maxSpeedKmh,
      caloriesBurned: calories,
      geoPath: List<GeoPoint>.from(_path),
      status: 'completed',
      completedAt: DateTime.now().toIso8601String(),
      perceivedEffort: averageSpeed > 10 ? 7 : 5,
      feedback: 'Автоматически завершена по геолокации.',
    );
    final metrics = widget.state.metricsFor(workout.scheduledDate);
    widget.onChanged(
      widget.state
          .updateMetricsFor(
            workout.scheduledDate,
            metrics.copyWith(
              workoutMinutes: metrics.workoutMinutes + minutes,
              activeCalories: metrics.activeCalories + calories,
            ),
          )
          .copyWith(workouts: [workout, ...widget.state.workouts]),
    );
    setState(() {
      _startedAt = null;
      _lastPosition = null;
      _status = 'сохранено';
    });
  }
}

double _maxHumanSpeedKmh(String mode) {
  return switch (mode) {
    'ходьба' => 9,
    'велосипед' => 65,
    _ => 28,
  };
}

String _formatElapsed(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
