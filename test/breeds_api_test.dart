import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/adoption/services/breeds_api.dart';

void main() {
  for (final species in ['Chien', 'Chat']) {
    test('Real request shape and JSON parsing $species', () async {
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((r) async {
          expect(
            r.url.host,
            species == 'Chien' ? 'api.thedogapi.com' : 'api.thecatapi.com',
          );
          expect(r.headers['x-api-key'], 'test');
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Breed',
                'life_span': '10 - 12',
                'weight': {'metric': '3 - 6'},
                'temperament': 'Calm',
              },
            ]),
            200,
          );
        }),
      );
      final result = await BreedsApi(
        client,
        dogKey: 'test',
        catKey: 'test',
      ).breeds(species);
      expect(result.value.single.name, 'Breed');
      expect(result.value.single.weight, '3 - 6');
      client.close();
    });
  }
  test('No key leaves manual fallback and sends no request', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => throw StateError('no network')),
    );
    await expectLater(
      BreedsApi(client, dogKey: '', catKey: '').breeds('Chien'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'configuration',
          ApiErrorKind.configuration,
        ),
      ),
    );
    client.close();
  });
  test('Breed network error and malformed JSON', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      BreedsApi(client, dogKey: 'test').breeds('Chien'),
      throwsA(isA<ApiFailure>()),
    );
    client.close();
  });
}
