import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animora/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Persistent cache reuse stale offline notice and expiry', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 11, 10);
    var online = true, calls = 0;
    final client = ApiClient(
      cache: PreferencesApiCache(),
      clock: () => now,
      client: MockClient((_) async {
        calls++;
        if (!online) throw http.ClientException('offline');
        return http.Response('{"real":1}', 200);
      }),
    );
    final uri = Uri.https('example.com', '/data');
    await client.get(uri, ttl: const Duration(hours: 1));
    online = false;
    now = now.add(const Duration(hours: 2));
    final cached = await client.get(uri, ttl: const Duration(hours: 1));
    expect(cached.offline, true);
    expect(cached.cached, true);
    expect(cached.json, {'real': 1});
    now = now.add(const Duration(days: 8));
    await expectLater(client.get(uri), throwsA(isA<ApiFailure>()));
    expect(calls, 3);
    client.close();
  });
  test(
    'In flight deduplication completes and does not await its own future',
    () async {
      var calls = 0;
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return http.Response('[]', 200);
        }),
      );
      await Future.wait([
        client.get(Uri.https('example.com', '/list')),
        client.get(Uri.https('example.com', '/list')),
      ]).timeout(const Duration(seconds: 1));
      expect(calls, 1);
      client.close();
    },
  );
  test('HTTP authorization JSON and timeout errors are explicit', () async {
    for (final code in [401, 403, 429, 503]) {
      final client = ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((_) async => http.Response('{}', code)),
      );
      await expectLater(
        client.get(Uri.https('example.com', '/data')),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', code)),
      );
      client.close();
    }
    final bad = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async => http.Response('not JSON', 200)),
    );
    await expectLater(
      bad.get(Uri.https('example.com', '/data')),
      throwsA(
        isA<ApiFailure>().having((e) => e.kind, 'kind', ApiErrorKind.invalid),
      ),
    );
    bad.close();
  });
  test(
    'Cache survives a new client and labels only actually received data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final uri = Uri.https('example.com', '/persist');
      final first = ApiClient(
        cache: PreferencesApiCache(),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'value': 7}), 200),
        ),
      );
      await first.get(uri);
      first.close();
      final next = ApiClient(
        cache: PreferencesApiCache(),
        client: MockClient((_) async => throw StateError('must not call')),
      );
      expect((await next.get(uri)).cached, true);
      next.close();
    },
  );
}
