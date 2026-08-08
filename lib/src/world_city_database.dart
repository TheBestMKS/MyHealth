import 'dart:convert';

import 'package:flutter/services.dart';

import 'location_catalog.dart';

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
  });

  final String country;
  final String city;
  final String ascii;
  final double latitude;
  final double longitude;
  final int population;
  final String timezone;
  final String searchIndex;

  String displayName(String localeCode) {
    if (localeCode.toLowerCase().startsWith('ru')) {
      return _ruCityNames['$country|$ascii'] ??
          _ruCityNames['$country|$city'] ??
          city;
    }
    return ascii.isNotEmpty ? ascii : city;
  }

  String displayCountry(String localeCode) {
    if (localeCode.toLowerCase().startsWith('ru')) {
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
    final raw = await rootBundle.loadString('assets/world_cities.tsv');
    final result = <WorldCityEntry>[];
    var first = true;
    for (final line in const LineSplitter().convert(raw)) {
      if (first) {
        first = false;
        continue;
      }
      final parts = line.split('\t');
      if (parts.length < 7) {
        continue;
      }
      final country = parts[0];
      final city = parts[1];
      final ascii = parts[2];
      final latitude = double.tryParse(parts[3]) ?? 0;
      final longitude = double.tryParse(parts[4]) ?? 0;
      final population = int.tryParse(parts[5]) ?? 0;
      final timezone = parts[6];
      result.add(
        WorldCityEntry(
          country: country,
          city: city,
          ascii: ascii,
          latitude: latitude,
          longitude: longitude,
          population: population,
          timezone: timezone,
          searchIndex: _normalize('$city $ascii $country $timezone'),
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

String _countrySearchName(String value) {
  if (value.isEmpty) {
    return value;
  }
  return _ruCountryNames.entries
          .where((entry) => entry.value == value)
          .map((entry) => entry.key)
          .firstOrNull ??
      value;
}

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
