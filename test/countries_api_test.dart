import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/users/services/countries_api.dart';

void main() {
  test('Countries v5 paging parsing dialing and cached response', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((r) async {
        calls++;
        expect(r.headers['Authorization'], 'Bearer test');
        return http.Response(
          jsonEncode({
            'data': {
              'objects': [
                {
                  'names': {'common': 'Tunisia'},
                  'codes': {'alpha_2': 'TN'},
                  'flag': {'emoji': '🇹🇳'},
                  'calling_codes': ['216'],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final api = CountriesApi(client, key: 'test');
    final result = await api.countries();
    expect(result.value.single.iso, 'TN');
    expect(result.value.single.dialCodes, ['+216']);
    expect((await api.countries()).response.cached, true);
    expect(calls, 1);
    expect(internationalPhone('20123456', '+216'), '+21620123456');
    expect(internationalPhone('+33123456789', '+216'), '+33123456789');
    client.close();
  });
  test('Without key, CountriesNow is used (no Authorization header)', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((r) async {
        calls++;
        expect(r.url.host, 'countriesnow.space');
        expect(r.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'error': false,
            'data': [
              {'name': 'Tunisia', 'code': 'TN', 'dial_code': '+216'},
              {'name': 'Bahamas', 'code': 'BS', 'dial_code': '+1 242'},
              {'name': 'Nowhere', 'code': 'XX', 'dial_code': null},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final api = CountriesApi(client, key: '');
    final result = (await api.countries()).value;
    expect(result.map((c) => c.iso), ['BS', 'XX', 'TN']);
    expect(result.first.dialCodes, ['+1242']);
    expect(result.last.flag, '🇹🇳');
    expect(result[1].dialCodes, isEmpty);
    expect((await api.countries()).response.cached, true);
    expect(calls, 1);
    client.close();
  });
  test(
    'Offline country request explicitly fails without invented country list',
    () async {
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        CountriesApi(client, key: 'test').countries(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'offline',
            ApiErrorKind.offline,
          ),
        ),
      );
      client.close();
    },
  );
}
