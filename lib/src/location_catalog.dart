import 'dart:math' as math;

class ClimateProfile {
  const ClimateProfile({
    required this.climate,
    required this.summer,
    required this.winter,
    required this.solarPhenomena,
    required this.longestDay,
    required this.shortestDay,
  });

  final String climate;
  final String summer;
  final String winter;
  final List<String> solarPhenomena;
  final String longestDay;
  final String shortestDay;
}

class CityClimate {
  const CityClimate({
    required this.country,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.climate,
    required this.summer,
    required this.winter,
    required this.solarPhenomena,
  });

  final String country;
  final String city;
  final double latitude;
  final double longitude;
  final String climate;
  final String summer;
  final String winter;
  final List<String> solarPhenomena;

  String get key => '$country|$city';

  factory CityClimate.derived({
    required String country,
    required String city,
    required double latitude,
    required double longitude,
    String? climate,
    String? summer,
    String? winter,
    List<String>? solarPhenomena,
  }) {
    final profile = climateProfileFor(latitude);
    return CityClimate(
      country: country,
      city: city,
      latitude: latitude,
      longitude: longitude,
      climate: _nonEmpty(climate) ?? profile.climate,
      summer: _nonEmpty(summer) ?? profile.summer,
      winter: _nonEmpty(winter) ?? profile.winter,
      solarPhenomena: solarPhenomena == null || solarPhenomena.isEmpty
          ? profile.solarPhenomena
          : solarPhenomena,
    );
  }
}

ClimateProfile climateProfileFor(double latitude) {
  final absLat = latitude.abs();
  final longest = daylightDescription(latitude, 172);
  final shortest = daylightDescription(latitude, 355);
  final phenomena = <String>[];

  if (absLat >= 66.56) {
    phenomena.addAll(['полярный день', 'полярная ночь']);
  } else if (absLat >= 59) {
    phenomena.addAll(['белые ночи', 'очень длинные летние сумерки']);
  } else if (absLat >= 50) {
    phenomena.addAll(['длинный летний день', 'короткий зимний день']);
  } else if (absLat <= 23.44) {
    phenomena.addAll([
      'высокое солнце',
      'малый сезонный перепад светового дня',
    ]);
  } else {
    phenomena.add('выраженная сезонность светового дня');
  }

  if (absLat >= 66.56) {
    return ClimateProfile(
      climate: 'полярный/субарктический по широте',
      summer: 'короткое прохладное лето, возможен полярный день',
      winter: 'долгая холодная зима, возможна полярная ночь',
      solarPhenomena: phenomena,
      longestDay: longest,
      shortestDay: shortest,
    );
  }
  if (absLat >= 55) {
    return ClimateProfile(
      climate: 'умеренный северный по широте',
      summer: 'прохладное или умеренно тёплое лето, длинный световой день',
      winter: 'холодная тёмная зима, короткий световой день',
      solarPhenomena: phenomena,
      longestDay: longest,
      shortestDay: shortest,
    );
  }
  if (absLat >= 35) {
    return ClimateProfile(
      climate: 'умеренный/субтропический по широте',
      summer: 'тёплое или жаркое лето, заметная инсоляция',
      winter: 'мягкая или прохладная зима',
      solarPhenomena: phenomena,
      longestDay: longest,
      shortestDay: shortest,
    );
  }
  if (absLat >= 23.44) {
    return ClimateProfile(
      climate: 'субтропический/сухой по широте',
      summer: 'жаркое лето, высокая тепловая нагрузка',
      winter: 'мягкая зима, умеренная инсоляция',
      solarPhenomena: phenomena,
      longestDay: longest,
      shortestDay: shortest,
    );
  }
  return ClimateProfile(
    climate: 'тропический по широте',
    summer: 'жаркий сезон, высокая инсоляция и риск перегрева',
    winter: 'тёплый сезон без резкого сокращения светового дня',
    solarPhenomena: phenomena,
    longestDay: longest,
    shortestDay: shortest,
  );
}

String daylightDescription(double latitude, int dayOfYear) {
  final hours = daylightHours(latitude, dayOfYear);
  if (hours >= 24) {
    return '24 ч';
  }
  if (hours <= 0) {
    return '0 ч';
  }
  final wholeHours = hours.floor();
  final minutes = ((hours - wholeHours) * 60).round();
  return '$wholeHours ч ${minutes.toString().padLeft(2, '0')} мин';
}

double daylightHours(double latitude, int dayOfYear) {
  final latRad = latitude * math.pi / 180;
  final declination =
      23.44 * math.pi / 180 * math.sin((2 * math.pi / 365) * (dayOfYear - 81));
  final value = -math.tan(latRad) * math.tan(declination);
  if (value <= -1) {
    return 24;
  }
  if (value >= 1) {
    return 0;
  }
  final hourAngle = math.acos(value);
  return 24 * hourAngle / math.pi;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

const cityClimateCatalog = <CityClimate>[
  CityClimate(
    country: 'Россия',
    city: 'Москва',
    latitude: 55.7558,
    longitude: 37.6173,
    climate: 'умеренно-континентальный',
    summer: 'тёплое лето, умеренная влажность, длинный световой день',
    winter: 'холодная зима, короткий световой день, снег',
    solarPhenomena: ['длинные летние сумерки', 'короткий зимний день'],
  ),
  CityClimate(
    country: 'Россия',
    city: 'Санкт-Петербург',
    latitude: 59.9343,
    longitude: 30.3351,
    climate: 'влажный умеренный морской',
    summer: 'прохладное влажное лето, белые ночи в июне-июле',
    winter: 'пасмурная влажная зима, мало солнца',
    solarPhenomena: ['белые ночи', 'длинные сумерки'],
  ),
  CityClimate(
    country: 'Россия',
    city: 'Мурманск',
    latitude: 68.9585,
    longitude: 33.0827,
    climate: 'субарктический морской',
    summer: 'короткое прохладное лето, полярный день',
    winter: 'долгая холодная зима, полярная ночь',
    solarPhenomena: ['полярный день', 'полярная ночь'],
  ),
  CityClimate(
    country: 'Россия',
    city: 'Сочи',
    latitude: 43.5855,
    longitude: 39.7231,
    climate: 'влажный субтропический',
    summer: 'жаркое влажное лето, высокая тепловая нагрузка',
    winter: 'мягкая влажная зима',
    solarPhenomena: ['высокая летняя инсоляция'],
  ),
  CityClimate(
    country: 'Казахстан',
    city: 'Алматы',
    latitude: 43.2220,
    longitude: 76.8512,
    climate: 'континентальный предгорный',
    summer: 'жаркое сухое лето, выраженная инсоляция',
    winter: 'прохладная снежная зима',
    solarPhenomena: ['горная инсоляция', 'резкие суточные перепады'],
  ),
  CityClimate(
    country: 'Беларусь',
    city: 'Минск',
    latitude: 53.9006,
    longitude: 27.5590,
    climate: 'умеренно-континентальный влажный',
    summer: 'мягкое влажное лето',
    winter: 'холодная пасмурная зима',
    solarPhenomena: ['короткий зимний день'],
  ),
  CityClimate(
    country: 'Германия',
    city: 'Берлин',
    latitude: 52.5200,
    longitude: 13.4050,
    climate: 'умеренный переходный',
    summer: 'тёплое лето, умеренная влажность',
    winter: 'прохладная пасмурная зима',
    solarPhenomena: ['короткий зимний день'],
  ),
  CityClimate(
    country: 'Франция',
    city: 'Париж',
    latitude: 48.8566,
    longitude: 2.3522,
    climate: 'умеренный океанический',
    summer: 'тёплое лето, возможны волны жары',
    winter: 'мягкая влажная зима',
    solarPhenomena: ['летние волны жары'],
  ),
  CityClimate(
    country: 'Испания',
    city: 'Мадрид',
    latitude: 40.4168,
    longitude: -3.7038,
    climate: 'сухой континентально-средиземноморский',
    summer: 'очень жаркое сухое лето',
    winter: 'прохладная сухая зима',
    solarPhenomena: ['очень высокая летняя инсоляция'],
  ),
  CityClimate(
    country: 'Турция',
    city: 'Стамбул',
    latitude: 41.0082,
    longitude: 28.9784,
    climate: 'влажный субтропический переходный',
    summer: 'жаркое влажное лето',
    winter: 'мягкая влажная зима',
    solarPhenomena: ['морская влажность'],
  ),
  CityClimate(
    country: 'США',
    city: 'Нью-Йорк',
    latitude: 40.7128,
    longitude: -74.0060,
    climate: 'влажный субтропический/континентальный',
    summer: 'жаркое влажное лето',
    winter: 'холодная ветреная зима',
    solarPhenomena: ['городской тепловой остров'],
  ),
  CityClimate(
    country: 'Япония',
    city: 'Токио',
    latitude: 35.6762,
    longitude: 139.6503,
    climate: 'влажный субтропический',
    summer: 'жаркое очень влажное лето',
    winter: 'мягкая сухая зима',
    solarPhenomena: ['высокая влажность летом'],
  ),
  CityClimate(
    country: 'Китай',
    city: 'Пекин',
    latitude: 39.9042,
    longitude: 116.4074,
    climate: 'муссонный континентальный',
    summer: 'жаркое влажное лето',
    winter: 'холодная сухая зима',
    solarPhenomena: ['сезонные пылевые нагрузки'],
  ),
  CityClimate(
    country: 'ОАЭ',
    city: 'Дубай',
    latitude: 25.2048,
    longitude: 55.2708,
    climate: 'пустынный жаркий',
    summer: 'экстремально жаркое лето, высокая тепловая нагрузка',
    winter: 'тёплая сухая зима',
    solarPhenomena: ['экстремальная инсоляция', 'близость к тропикам'],
  ),
];

List<String> countries({List<CityClimate> extra = const []}) {
  final values = {
    ...cityClimateCatalog.map((item) => item.country),
    ...extra.map((item) => item.country),
  };
  final list = values.toList()..sort();
  return list;
}

List<CityClimate> citiesForCountry(
  String country, {
  List<CityClimate> extra = const [],
}) {
  final list =
      [
          ...cityClimateCatalog,
          ...extra,
        ].where((item) => item.country == country).toList()
        ..sort((a, b) => a.city.compareTo(b.city));
  return list;
}

CityClimate? cityByKey(
  String country,
  String city, {
  List<CityClimate> extra = const [],
}) {
  for (final item in [...cityClimateCatalog, ...extra]) {
    if (item.country == country && item.city == city) {
      return item;
    }
  }
  return null;
}
