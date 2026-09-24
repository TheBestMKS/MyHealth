import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/location_catalog.dart';
import 'package:my_health/src/world_city_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'searches GeoNames world city asset and derives polar phenomena',
    () async {
      final results = await WorldCityDatabase.instance.search('Murmansk');
      final murmansk = results.firstWhere(
        (item) => item.city == 'Murmansk' || item.ascii == 'Murmansk',
      );

      expect(murmansk.country, 'Russia');
      expect(murmansk.latitude, greaterThan(68));
      expect(murmansk.displayName('ru'), 'Мурманск');
      expect(murmansk.displayName('en'), 'Murmansk');
      expect(murmansk.displayCountry('de'), 'Russland');

      final climate = murmansk.toCityClimate();
      expect(climate.solarPhenomena, contains('полярный день'));
      expect(climate.solarPhenomena, contains('полярная ночь'));
      expect(daylightHours(murmansk.latitude, 172), 24);
    },
  );

  test(
    'lists countries and filters cities within a selected country',
    () async {
      final countries = await WorldCityDatabase.instance.countries();
      expect(countries, contains('Russia'));

      final russianCities = await WorldCityDatabase.instance.citiesByCountry(
        'Russia',
        limit: 120,
      );
      expect(russianCities.map((item) => item.country).toSet(), {'Russia'});
      expect(
        russianCities.map((item) => item.ascii),
        anyOf(contains('Moscow'), contains('Moskva')),
      );

      final petersburg = await WorldCityDatabase.instance.citiesByCountry(
        'Russia',
        query: 'Saint Petersburg',
        limit: 10,
      );
      expect(
        petersburg.map((item) => item.ascii),
        contains('Saint Petersburg'),
      );
    },
  );

  test('derives compact country bounds including the antimeridian', () async {
    final russia = await WorldCityDatabase.instance.countryMapBounds('Россия');
    expect(russia, isNotNull);
    expect(russia!.south, lessThan(45));
    expect(russia.north, greaterThan(70));

    final unitedStates = await WorldCityDatabase.instance.countryMapBounds(
      'United States',
    );
    expect(unitedStates, isNotNull);
    final span = unitedStates!.crossesAntimeridian
        ? 360 - unitedStates.west + unitedStates.east
        : unitedStates.east - unitedStates.west;
    expect(span, lessThan(300));
  });

  test('finds and displays localized city names offline', () async {
    final russian = await WorldCityDatabase.instance.search('Мурманск');
    expect(russian.map((city) => city.ascii), contains('Murmansk'));

    final tokyo = (await WorldCityDatabase.instance.search(
      'Tokyo',
    )).firstWhere((city) => city.ascii == 'Tokyo');
    expect(tokyo.displayName('ja'), anyOf('東京', '東京都'));
    expect(tokyo.displayCountry('fr'), 'Japon');
  });
}
