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
}
