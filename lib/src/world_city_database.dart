import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'location_catalog.dart';

const _localizedNameSeparator = '\u001f';
const _localizedCityLocales = <String>['ru', 'zh', 'ja', 'ko', 'ar', 'hi'];
Map<String, Map<String, String>> _localizedCountryNames = const {};

class WorldCityEntry {
  const WorldCityEntry({
    required this.country,
    required this.city,
    required this.ascii,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.timezone,
    required this.searchIndex,
    this.localizedNames = '',
  });

  final String country;
  final String city;
  final String ascii;
  final double latitude;
  final double longitude;
  final int population;
  final String timezone;
  final String searchIndex;
  final String localizedNames;

  String displayName(String localeCode) {
    final locale = _languageCode(localeCode);
    if (locale == 'ru') {
      final known =
          _ruCityNames['$country|$ascii'] ?? _ruCityNames['$country|$city'];
      if (known != null) return known;
    }
    final lookupLocale = locale == 'be' || locale == 'kk' ? 'ru' : locale;
    final index = _localizedCityLocales.indexOf(lookupLocale);
    if (index >= 0) {
      final names = localizedNames.split(_localizedNameSeparator);
      if (index < names.length && names[index].trim().isNotEmpty) {
        return names[index].trim();
      }
    }
    if (locale == 'ru') {
      return _ruCityNames['$country|$ascii'] ??
          _ruCityNames['$country|$city'] ??
          city;
    }
    return ascii.isNotEmpty ? ascii : city;
  }

  String displayCountry(String localeCode) {
    final locale = _languageCode(localeCode);
    final localized = _localizedCountryNames[country]?[locale];
    if (localized != null && localized.isNotEmpty) return localized;
    if (locale == 'ru') {
      return _ruCountryNames[country] ?? country;
    }
    return country;
  }

  CityClimate toCityClimate({String localeCode = 'ru'}) => CityClimate.derived(
    country: displayCountry(localeCode),
    city: displayName(localeCode),
    latitude: latitude,
    longitude: longitude,
  );
}

typedef CountryMapBounds = ({
  double south,
  double west,
  double north,
  double east,
  bool crossesAntimeridian,
});

class WorldCityDatabase {
  WorldCityDatabase._();

  static final instance = WorldCityDatabase._();

  List<WorldCityEntry>? _cities;
  Future<List<WorldCityEntry>>? _loading;

  Future<List<WorldCityEntry>> load() {
    final loaded = _cities;
    if (loaded != null) {
      return Future.value(loaded);
    }
    return _loading ??= _load();
  }

  Future<List<String>> countries() async {
    final cities = await load();
    final values = cities.map((item) => item.country).toSet().toList()..sort();
    return values;
  }

  String displayCountryName(String country, String localeCode) {
    final locale = _languageCode(localeCode);
    return _localizedCountryNames[country]?[locale] ??
        (locale == 'ru' ? _ruCountryNames[country] : null) ??
        country;
  }

  Future<CountryMapBounds?> countryMapBounds(String country) async {
    final cities = await load();
    final normalizedCountry = _normalize(_countrySearchName(country));
    final matches = cities
        .where((city) => _normalize(city.country) == normalizedCountry)
        .toList(growable: false);
    if (matches.isEmpty) return null;

    var south = matches.first.latitude;
    var north = matches.first.latitude;
    final longitudes = <double>[];
    for (final city in matches) {
      south = math.min(south, city.latitude);
      north = math.max(north, city.latitude);
      longitudes.add((city.longitude + 360) % 360);
    }
    longitudes.sort();
    var largestGap = -1.0;
    var gapIndex = 0;
    for (var index = 0; index < longitudes.length; index++) {
      final current = longitudes[index];
      final next = index + 1 < longitudes.length
          ? longitudes[index + 1]
          : longitudes.first + 360;
      final gap = next - current;
      if (gap > largestGap) {
        largestGap = gap;
        gapIndex = index;
      }
    }
    var west360 = longitudes[(gapIndex + 1) % longitudes.length];
    var east360 = longitudes[gapIndex];
    if (east360 < west360) east360 += 360;
    final latitudePadding = math.max(1.0, (north - south) * 0.06);
    final longitudePadding = math.max(1.0, (east360 - west360) * 0.04);
    south = (south - latitudePadding).clamp(-85.0, 85.0);
    north = (north + latitudePadding).clamp(-85.0, 85.0);
    west360 -= longitudePadding;
    east360 += longitudePadding;
    if (east360 - west360 >= 359) {
      return (
        south: south,
        west: -180.0,
        north: north,
        east: 180.0,
        crossesAntimeridian: false,
      );
    }
    final west = _normalizeLongitude(west360);
    final east = _normalizeLongitude(east360);
    return (
      south: south,
      west: west,
      north: north,
      east: east,
      crossesAntimeridian: west > east,
    );
  }

  Future<List<WorldCityEntry>> search(
    String query, {
    int limit = 40,
    String country = '',
  }) async {
    final cities = await load();
    final normalized = _normalize(query);
    final normalizedCountry = _normalize(_countrySearchName(country));
    final scored = <_ScoredCity>[];

    for (final city in cities) {
      if (normalizedCountry.isNotEmpty &&
          _normalize(city.country) != normalizedCountry) {
        continue;
      }
      if (normalized.isEmpty) {
        if (city.population > 500000) {
          scored.add(_ScoredCity(city, 10));
        }
        continue;
      }
      if (!city.searchIndex.contains(normalized)) {
        continue;
      }
      scored.add(_ScoredCity(city, _score(city, normalized)));
    }

    scored.sort((a, b) {
      final score = a.score.compareTo(b.score);
      if (score != 0) {
        return score;
      }
      return b.city.population.compareTo(a.city.population);
    });
    return scored.take(limit).map((item) => item.city).toList();
  }

  Future<List<WorldCityEntry>> citiesByCountry(
    String country, {
    String query = '',
    int limit = 80,
  }) async {
    return search(query, limit: limit, country: country);
  }

  Future<List<WorldCityEntry>> _load() async {
    final sources = await Future.wait([
      rootBundle.loadString('assets/world_cities.tsv'),
      rootBundle.loadString('assets/country_names.json'),
    ]);
    final raw = sources[0];
    final countryJson = jsonDecode(sources[1]);
    if (countryJson is Map<String, dynamic>) {
      _localizedCountryNames = countryJson.map(
        (country, names) => MapEntry(
          country,
          names is Map<String, dynamic>
              ? names.map((locale, name) => MapEntry(locale, '$name'))
              : const <String, String>{},
        ),
      );
    }
    final result = <WorldCityEntry>[];
    var first = true;
    for (final line in const LineSplitter().convert(raw)) {
      if (first) {
        first = false;
        continue;
      }
      final parts = line.split('\t');
      if (parts.length < 8) {
        continue;
      }
      final country = parts[0];
      final city = parts[1];
      final ascii = parts[2];
      final latitude = double.tryParse(parts[3]) ?? 0;
      final longitude = double.tryParse(parts[4]) ?? 0;
      final population = int.tryParse(parts[5]) ?? 0;
      final timezone = parts[6];
      final localizedNames = parts[7];
      result.add(
        WorldCityEntry(
          country: country,
          city: city,
          ascii: ascii,
          latitude: latitude,
          longitude: longitude,
          population: population,
          timezone: timezone,
          searchIndex: _normalize(
            '$city $ascii $country $timezone $localizedNames',
          ),
          localizedNames: localizedNames,
        ),
      );
    }
    result.sort((a, b) => b.population.compareTo(a.population));
    _cities = result;
    return result;
  }

  int _score(WorldCityEntry city, String query) {
    final cityName = _normalize(city.city);
    final asciiName = _normalize(city.ascii);
    final countryName = _normalize(city.country);
    if (cityName == query || asciiName == query) {
      return 0;
    }
    if (cityName.startsWith(query) || asciiName.startsWith(query)) {
      return 1;
    }
    if (countryName == query || countryName.startsWith(query)) {
      return 2;
    }
    if (city.searchIndex.contains(query)) {
      return 3;
    }
    return 10;
  }

  static String normalizeForSearch(String value) => _normalize(value);

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .trim();
  }
}

double _normalizeLongitude(double longitude) {
  var value = (longitude + 180) % 360;
  if (value < 0) value += 360;
  return value - 180;
}

String _countrySearchName(String value) {
  if (value.isEmpty) {
    return value;
  }
  final normalized = WorldCityDatabase._normalize(value);
  for (final entry in _localizedCountryNames.entries) {
    if (entry.value.values.any(
      (name) => WorldCityDatabase._normalize(name) == normalized,
    )) {
      return entry.key;
    }
  }
  return _ruCountryNames.entries
          .where((entry) => entry.value == value)
          .map((entry) => entry.key)
          .firstOrNull ??
      value;
}

String _languageCode(String localeCode) =>
    localeCode.toLowerCase().split(RegExp('[-_]')).first;

class _ScoredCity {
  const _ScoredCity(this.city, this.score);

  final WorldCityEntry city;
  final int score;
}

const _ruCountryNames = <String, String>{
  'Russia': 'Россия',
  'Belarus': 'Беларусь',
  'Kazakhstan': 'Казахстан',
  'Germany': 'Германия',
  'France': 'Франция',
  'Spain': 'Испания',
  'Italy': 'Италия',
  'Portugal': 'Португалия',
  'Turkey': 'Турция',
  'China': 'Китай',
  'Japan': 'Япония',
  'South Korea': 'Южная Корея',
  'United States': 'США',
  'United Kingdom': 'Великобритания',
  'India': 'Индия',
};

const _ruCityNames = <String, String>{
  'Russia|Moscow': 'Москва',
  'Russia|Saint Petersburg': 'Санкт-Петербург',
  'Russia|Murmansk': 'Мурманск',
  'Russia|Sochi': 'Сочи',
  'Russia|Kazan': 'Казань',
  'Russia|Novosibirsk': 'Новосибирск',
  'Russia|Yekaterinburg': 'Екатеринбург',
  'Russia|Nizhniy Novgorod': 'Нижний Новгород',
  'Russia|Samara': 'Самара',
  'Russia|Omsk': 'Омск',
  'Russia|Rostov-na-Donu': 'Ростов-на-Дону',
  'Russia|Ufa': 'Уфа',
  'Russia|Krasnoyarsk': 'Красноярск',
  'Russia|Perm': 'Пермь',
  'Russia|Voronezh': 'Воронеж',
  'Belarus|Minsk': 'Минск',
  'Kazakhstan|Almaty': 'Алматы',
  'Kazakhstan|Astana': 'Астана',
};
