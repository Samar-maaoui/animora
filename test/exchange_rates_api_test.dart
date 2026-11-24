import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/donations/services/exchange_rates_api.dart';

void main() {
  test('TND rates EUR USD zero date and daily cache', () async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((r) async {
        calls++;
        expect(r.url.path, '/v6/latest/TND');
        return http.Response(
          '{"result":"success","base_code":"TND","rates":{"EUR":0.3,"USD":0.32},"time_last_update_unix":1794268800}',
          200,
        );
      }),
    );
    final api = ExchangeRatesApi(client);
    final result = await api.rates();
    expect(result.value.convert(100, 'EUR'), 30);
    expect(result.value.convert(100, 'USD'), 32);
    expect(result.value.convert(0, 'USD'), 0);
    expect(result.value.updatedAt, isNotNull);
    await api.rates(refresh: true);
    expect(calls, 1);
    client.close();
  });
  test('Missing rate is never replaced by a fictitious one', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient(
        (_) async => http.Response(
          '{"result":"success","base_code":"TND","rates":{"EUR":0.3}}',
          200,
        ),
      ),
    );
    await expectLater(
      ExchangeRatesApi(client).rates(),
      throwsA(isA<ApiFailure>()),
    );
    client.close();
  });
  test('Rates network error explicit', () async {
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      ExchangeRatesApi(client).rates(),
      throwsA(isA<ApiFailure>()),
    );
    client.close();
  });
}
