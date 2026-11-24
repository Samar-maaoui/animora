import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/users/services/countries_api.dart';
import 'package:animora/features/adoption/services/breeds_api.dart';
import 'package:animora/features/reports/services/geocoding_api.dart';
import 'package:animora/features/veterinary/services/clinics_api.dart';
import 'package:animora/features/donations/services/exchange_rates_api.dart';
import 'package:animora/features/events/services/weather_api.dart';

void main() {
  test(
    'Live API availability report, distinct from mocked assertions',
    () async {
      final client = ApiClient(
        cache: MemoryApiCache(),
        timeout: const Duration(seconds: 25),
      );
      final results = <String, dynamic>{
        'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'usesRealHttp': true,
      };
      Future<void> check(String name, Future<dynamic> Function() action) async {
        try {
          final value = await action();
          results[name] = {'status': 'success', 'summary': value};
        } catch (e) {
          results[name] = {
            'status': e is ApiFailure && e.kind == ApiErrorKind.configuration
                ? 'configuration_required'
                : 'failed',
            'error': e.toString(),
          };
        }
      }

      await check(
        'REST Countries',
        () async => (await CountriesApi(client).countries()).value.length,
      );
      await check(
        'The Dog API',
        () async => (await BreedsApi(client).breeds('Chien')).value.length,
      );
      await check(
        'The Cat API',
        () async => (await BreedsApi(client).breeds('Chat')).value.length,
      );
      await check('Nominatim', () async {
        final value = await GeocodingApi(client)
            .reverse(36.8, 10.18, consent: true);
        return {'city': value.value.city, 'area': value.value.area};
      });
      await check(
        'Overpass',
        () async => (await ClinicsApi(client).nearby(36.8, 10.18)).value
            .map(
              (e) => {
                'id': e.id,
                'name': e.name,
                'latitude': e.latitude,
                'longitude': e.longitude,
              },
            )
            .toList(),
      );
      await check('ExchangeRate-API', () async {
        final v = (await ExchangeRatesApi(client).rates()).value;
        return {
          'EUR': v.eur,
          'USD': v.usd,
          'updatedAt': v.updatedAt?.toIso8601String(),
        };
      });
      await check('Open-Meteo', () async {
        final v = (await WeatherApi(
          client,
        ).forecast(36.8, 10.18, DateTime.now())).value;
        return v == null
            ? null
            : {
                'date': v.date,
                'minimum': v.minimum,
                'maximum': v.maximum,
                'timezone': v.timezone,
              };
      });
      await Directory('output/api').create(recursive: true);
      await File('output/api/live-results.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      client.close();
      // Passing means the report was generated; inspect every status for availability.
      expect(results.length, 9);
      stdout.writeln(jsonEncode(results));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
