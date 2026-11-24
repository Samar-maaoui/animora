import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/reports/services/geocoding_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Reverse geocoding rounds coordinates hides precise private address and caches', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((r) async {
        calls++;
        expect(r.url.queryParameters['lat'], '36.81');
        expect(r.url.queryParameters['zoom'], '12');
        expect(r.headers['User-Agent'], contains('Animora'));
        return http.Response(
          jsonEncode({
            'address': {
              'city': 'Tunis',
              'suburb': 'Centre',
              'road': 'Private road',
              'house_number': '12',
              'country': 'Tunisia',
            },
          }),
          200,
        );
      }),
    );
    final api = GeocodingApi(client);
    final result = await api.reverse(36.81234, 10.18987, consent: true);
    expect(result.value.city, 'Tunis');
    expect(result.value.area, isNot(contains('Private')));
    expect(
      (await api.reverse(36.81234, 10.18987, consent: true)).response.cached,
      true,
    );
    expect(calls, 1);
    client.close();
  });
  test('Invalid GPS and absent consent never send HTTP', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final api = GeocodingApi(client);
    await expectLater(
      api.reverse(91, 10, consent: true),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      api.reverse(36, 10, consent: false),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
    client.close();
  });
  test('Geocoder unavailable keeps manual location possible', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    await expectLater(
      GeocodingApi(client).reverse(36, 10, consent: true),
      throwsA(isA<ApiFailure>()),
    );
    client.close();
  });
}
