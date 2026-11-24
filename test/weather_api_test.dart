import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/events/services/weather_api.dart';

Map<String, dynamic> weatherJson() => {
  'timezone': 'Africa/Tunis',
  'daily': {
    'time': ['2026-11-10'],
    'temperature_2m_min': [20],
    'temperature_2m_max': [35],
    'precipitation_probability_max': [70],
    'precipitation_sum': [6],
    'wind_speed_10m_max': [45],
    'weather_code': [61],
  },
};
void main() {
  test('Event forecast uses actual requested date fields timezone advice and cache', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((r) async {
        calls++;
        expect(r.url.queryParameters['timezone'], 'auto');
        expect(r.url.queryParameters['forecast_days'], '16');
        return http.Response(jsonEncode(weatherJson()), 200);
      }),
    );
    final api = WeatherApi(client, clock: () => DateTime(2026, 11, 10));
    final result = await api.forecast(36.8, 10.1, DateTime(2026, 11, 10));
    expect(result.value!.maximum, 35);
    expect(result.value!.advice.length, 3);
    expect(result.value!.conditions, 'Pluie ou averses');
    await api.forecast(36.8, 10.1, DateTime(2026, 11, 10));
    expect(calls, 1);
    client.close();
  });
  test(
    'Missing coordinates past and beyond horizon never request current weather',
    () async {
      var calls = 0;
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final api = WeatherApi(client, clock: () => DateTime(2026, 11, 10));
      await expectLater(
        api.forecast(null, null, DateTime(2026, 11, 10)),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        api.forecast(36, 10, DateTime(2026, 11, 9)),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        (await api.forecast(36, 10, DateTime(2026, 12, 10))).value,
        isNull,
      );
      expect(calls, 0);
      client.close();
    },
  );
  test('Missing daily values and HTTP failure explicit', () async {
    expect(
      () => EventWeather.fromDaily({
        'daily': {
          'time': ['2026-11-10'],
        },
      }, '2026-11-10'),
      throwsA(isA<ApiFailure>()),
    );
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    await expectLater(
      WeatherApi(
        client,
        clock: () => DateTime(2026, 11, 10),
      ).forecast(36, 10, DateTime(2026, 11, 10)),
      throwsA(isA<ApiFailure>()),
    );
    client.close();
  });
}
