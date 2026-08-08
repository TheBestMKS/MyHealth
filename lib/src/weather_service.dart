import 'dart:convert';
import 'dart:io';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.humidity,
    required this.windKmh,
    required this.precipitationMm,
    required this.weatherCode,
    required this.europeanAqi,
    required this.pm25,
    required this.pollen,
    required this.updatedAt,
  });

  final double temperatureC;
  final double apparentTemperatureC;
  final int humidity;
  final double windKmh;
  final double precipitationMm;
  final int weatherCode;
  final int europeanAqi;
  final double pm25;
  final double pollen;
  final DateTime updatedAt;

  String get condition => switch (weatherCode) {
    0 => 'ясно',
    1 || 2 => 'переменная облачность',
    3 => 'пасмурно',
    45 || 48 => 'туман',
    >= 51 && <= 67 => 'дождь',
    >= 71 && <= 77 => 'снег',
    >= 80 && <= 82 => 'ливень',
    >= 95 => 'гроза',
    _ => 'погодные условия',
  };

  String get airQuality => switch (europeanAqi) {
    <= 20 => 'хорошее',
    <= 40 => 'удовлетворительное',
    <= 60 => 'умеренное',
    <= 80 => 'плохое',
    <= 100 => 'очень плохое',
    _ => 'крайне плохое',
  };

  String workoutAdvice() {
    if (europeanAqi > 80 || pm25 > 35) {
      return 'Качество воздуха плохое: уличное кардио лучше заменить домашней тренировкой.';
    }
    if (temperatureC >= 30 || apparentTemperatureC >= 32) {
      return 'Жарко: снизьте интенсивность, добавьте воду и перенесите улицу на утро или вечер.';
    }
    if (temperatureC <= -10) {
      return 'Холодно: удлините разминку и рассмотрите зал или домашний вариант.';
    }
    if (humidity >= 85 && temperatureC >= 22) {
      return 'Высокая влажность повышает тепловую нагрузку: уменьшите темп.';
    }
    if (windKmh >= 45 || precipitationMm >= 5) {
      return 'Сильный ветер или осадки: безопаснее тренироваться в помещении.';
    }
    return 'Погода подходит для обычной нагрузки с учётом самочувствия.';
  }
}

class WeatherService {
  WeatherService._();

  static final instance = WeatherService._();

  final Map<String, ({DateTime loadedAt, WeatherSnapshot value})> _cache = {};

  Future<WeatherSnapshot> load(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.loadedAt) <
            const Duration(minutes: 20)) {
      return cached.value;
    }
    final weather = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
        'timezone': 'auto',
      }),
    );
    final air = await _getJson(
      Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'current':
            'european_aqi,pm2_5,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen',
        'timezone': 'auto',
      }),
    );
    final current = _map(weather['current']);
    final airCurrent = _map(air['current']);
    final pollen = [
      _number(airCurrent['alder_pollen']),
      _number(airCurrent['birch_pollen']),
      _number(airCurrent['grass_pollen']),
      _number(airCurrent['mugwort_pollen']),
    ].reduce((a, b) => a + b);
    final value = WeatherSnapshot(
      temperatureC: _number(current['temperature_2m']),
      apparentTemperatureC: _number(current['apparent_temperature']),
      humidity: _number(current['relative_humidity_2m']).round(),
      windKmh: _number(current['wind_speed_10m']),
      precipitationMm: _number(current['precipitation']),
      weatherCode: _number(current['weather_code']).round(),
      europeanAqi: _number(airCurrent['european_aqi']).round(),
      pm25: _number(airCurrent['pm2_5']),
      pollen: pollen,
      updatedAt: DateTime.now(),
    );
    _cache[key] = (loadedAt: DateTime.now(), value: value);
    return value;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'MyHealth/1.3');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final source = await response.transform(utf8.decoder).join();
      return jsonDecode(source) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

double _number(Object? value) => switch (value) {
  num number => number.toDouble(),
  String source => double.tryParse(source) ?? 0,
  _ => 0,
};
