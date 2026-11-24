import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/veterinary/services/clinics_api.dart';

void main() {
  test(
    'Overpass bounded query nodes ways relations and missing coordinates',
    () async {
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((r) async {
          expect(r.url.queryParameters['data'], contains('around:5000'));
          expect(r.url.queryParameters['data'], contains('amenity'));
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 1,
                  'lat': 36.8,
                  'lon': 10.1,
                  'tags': {'name': 'Clinic'},
                },
                {
                  'type': 'way',
                  'id': 2,
                  'center': {'lat': 36.9, 'lon': 10.2},
                  'tags': {},
                },
                {'type': 'relation', 'id': 3, 'tags': {}},
              ],
            }),
            200,
          );
        }),
      );
      final result = await ClinicsApi(client).nearby(36.8, 10.1);
      expect(result.value.length, 3);
      expect(result.value[1].latitude, 36.9);
      expect(result.value[2].latitude, isNull);
      client.close();
    },
  );
  test('Empty Overpass result remains empty', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => http.Response('{"elements":[]}', 200)),
    );
    expect((await ClinicsApi(client).nearby(36, 10)).value, isEmpty);
    client.close();
  });
  test('Overpass timeout and invalid coordinates', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      ClinicsApi(client).nearby(36, 10),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'timeout',
          ApiErrorKind.timeout,
        ),
      ),
    );
    expect(() => ClinicsApi.query(100, 10), throwsA(isA<ApiFailure>()));
    client.close();
  });
}
