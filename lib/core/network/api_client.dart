import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiErrorKind { offline, timeout, http, configuration, invalid }

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.status});
  final ApiErrorKind kind;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse(
    this.json,
    this.receivedAt, {
    this.cached = false,
    this.offline = false,
    this.remote = true,
  });
  final dynamic json;
  final DateTime receivedAt;
  final bool cached, offline, remote;
  String get notice => !remote
      ? 'Aucun appel réseau nécessaire pour cette période.'
      : offline
      ? 'Hors ligne ou service inaccessible • réponse précédemment reçue, conservée en cache'
      : cached
      ? 'Réponse en cache'
      : 'Réponse du service externe';
}

abstract interface class ApiCache {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
}

class MemoryApiCache implements ApiCache {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }
}

class PreferencesApiCache implements ApiCache {
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        'animora.external.v1.$key',
      );
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        'animora.external.v1.$key',
        jsonEncode(value),
      );
    } catch (_) {
      /* Storage failure must not prevent use of the received response. */
    }
  }
}

class ApiClient {
  ApiClient({
    http.Client? client,
    ApiCache? cache,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 15),
  }) : client = client ?? http.Client(),
       cache = cache ?? PreferencesApiCache(),
       clock = clock ?? DateTime.now;
  final http.Client client;
  final ApiCache cache;
  final DateTime Function() clock;
  final Duration timeout;
  final _pending = <String, Future<ApiResponse>>{};
  Future<ApiResponse> post(
    Uri uri, {
    required Map<String, String> form,
    Duration ttl = const Duration(hours: 1),
    bool refresh = false,
  }) => get(uri, form: form, ttl: ttl, refresh: refresh);
  Future<ApiResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    Duration ttl = const Duration(hours: 24),
    Duration stale = const Duration(days: 7),
    bool refresh = false,
    Map<String, String>? form,
    void Function(dynamic)? validate,
  }) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return Future.error(
        const ApiFailure(
          ApiErrorKind.configuration,
          'Une URL HTTPS valide est nécessaire.',
        ),
      );
    }
    final key =
        uri.toString() +
        (form == null ? '' : '|${Uri(queryParameters: form).query}');
    return _pending[key] ??=
        _get(
          uri,
          key,
          headers,
          ttl,
          stale,
          refresh,
          form,
          validate,
        ).whenComplete(() {
          _pending.remove(key);
        });
  }

  Future<ApiResponse> _get(
    Uri uri,
    String key,
    Map<String, String> headers,
    Duration ttl,
    Duration stale,
    bool refresh,
    Map<String, String>? form,
    void Function(dynamic)? validate,
  ) async {
    final saved = await cache.read(key);
    DateTime? at;
    try {
      at = DateTime.parse(saved?['at'] as String);
    } catch (_) {}
    final age = at == null ? null : clock().difference(at);
    if (!refresh && age != null && !age.isNegative && age < ttl) {
      validate?.call(saved!['json']);
      return ApiResponse(saved!['json'], at!, cached: true);
    }
    try {
      final requestHeaders = {
        'Accept': 'application/json',
        if (!kIsWeb)
          'User-Agent':
              'AnimoraAcademic/1.0 (student animal protection application)',
        ...headers,
      };
      final response =
          await (form == null
                  ? client.get(uri, headers: requestHeaders)
                  : client.post(uri, headers: requestHeaders, body: form))
              .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiFailure(
          ApiErrorKind.http,
          response.statusCode == 401 || response.statusCode == 403
              ? 'Accès refusé : vérifiez la clé et les droits du fournisseur.'
              : response.statusCode == 429
              ? 'Limite du fournisseur atteinte. Réessayez plus tard.'
              : 'Service indisponible (HTTP ${response.statusCode}).',
          status: response.statusCode,
        );
      }
      dynamic json;
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw const ApiFailure(ApiErrorKind.invalid, 'Réponse JSON invalide.');
      }
      try {
        validate?.call(json);
      } on ApiFailure {
        rethrow;
      } catch (_) {
        throw const ApiFailure(
          ApiErrorKind.invalid,
          'Réponse externe incomplète ou invalide.',
        );
      }
      final now = clock();
      await cache.write(key, {'at': now.toIso8601String(), 'json': json});
      return ApiResponse(json, now);
    } catch (e) {
      final failure = e is ApiFailure
          ? e
          : e is TimeoutException
          ? const ApiFailure(ApiErrorKind.timeout, 'Délai dépassé. Réessayez.')
          : const ApiFailure(
              ApiErrorKind.offline,
              'Connexion ou accès au service indisponible. Vous pouvez continuer sans cette API.',
            );
      if (age != null &&
          !age.isNegative &&
          age < stale &&
          (failure.kind == ApiErrorKind.offline ||
              failure.kind == ApiErrorKind.timeout ||
              failure.status == 429 ||
              (failure.status ?? 0) >= 500)) {
        return ApiResponse(saved!['json'], at!, cached: true, offline: true);
      }
      throw failure;
    }
  }

  void close() => client.close();
}

double finiteNumber(dynamic n) {
  if (n is! num || !n.isFinite) {
    throw const ApiFailure(
      ApiErrorKind.invalid,
      'Valeur numérique absente ou invalide.',
    );
  }
  return n.toDouble();
}

void validCoordinates(double lat, double lon) {
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
    throw const ApiFailure(ApiErrorKind.invalid, 'Coordonnées invalides.');
  }
}

class ApiValue<T> {
  const ApiValue(this.value, this.response);
  final T value;
  final ApiResponse response;
}
