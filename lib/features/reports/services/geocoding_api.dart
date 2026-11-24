import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

class ApproximateAddress {
  const ApproximateAddress(this.city, this.area);
  final String city, area;
  factory ApproximateAddress.fromJson(Map<String, dynamic> j) {
    final address = j['address'];
    if (address is! Map) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Adresse approximative indisponible.',
      );
    }
    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'] ??
                '')
            .toString();
    final area = [
      address['suburb'],
      address['state'],
      address['country'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');
    return ApproximateAddress(city, area);
  }
}

class GeocodingApi {
  GeocodingApi(
    this.client, {
    this.endpoint = const String.fromEnvironment(
      'NOMINATIM_ENDPOINT',
      defaultValue: 'https://nominatim.openstreetmap.org/reverse',
    ),
  });
  final ApiClient client;
  String endpoint;
  static final _instances = Expando<GeocodingApi>();
  static GeocodingApi forClient(ApiClient c) =>
      _instances[c] ??= GeocodingApi(c);
  static Future<void> _tail = Future.value();
  static DateTime? _last;
  Future<void> setEndpoint(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery) {
      throw const ApiFailure(
        ApiErrorKind.configuration,
        'Indiquez une URL HTTPS de géocodage inverse, sans paramètres ni identifiants.',
      );
    }
    endpoint = value;
    try {
      await (await SharedPreferences.getInstance()).setString(
        'animora.external.geocoder',
        value,
      );
    } catch (_) {}
  }

  Future<ApiValue<ApproximateAddress>> reverse(
    double latitude,
    double longitude, {
    required bool consent,
    bool refresh = false,
  }) async {
    validCoordinates(latitude, longitude);
    if (!consent) {
      throw const ApiFailure(
        ApiErrorKind.configuration,
        'La recherche externe nécessite votre action et votre consentement.',
      );
    }
    final lat = (latitude * 100).round() / 100,
        lon = (longitude * 100).round() / 100;
    final task = _tail.then((_) async {
      try {
        endpoint =
            (await SharedPreferences.getInstance()).getString(
              'animora.external.geocoder',
            ) ??
            endpoint;
      } catch (_) {}
      final before = _last;
      if (before != null) {
        final delay =
            const Duration(milliseconds: 1100) -
            DateTime.now().difference(before);
        if (delay > Duration.zero) await Future<void>.delayed(delay);
      }
      _last = DateTime.now();
      final response = await client.get(
        Uri.parse(endpoint).replace(
          queryParameters: {
            'lat': lat.toStringAsFixed(2),
            'lon': lon.toStringAsFixed(2),
            'format': 'jsonv2',
            'zoom': '12',
            'addressdetails': '1',
            'accept-language': 'fr',
          },
        ),
        headers: kIsWeb
            ? {}
            : {
                'User-Agent': 'AnimoraAcademic/1.0 (animal protection student application)',
              },
        ttl: const Duration(days: 7),
        refresh: refresh,
      );
      if (response.json is! Map) {
        throw const ApiFailure(
          ApiErrorKind.invalid,
          'Réponse géographique invalide.',
        );
      }
      return ApiValue(
        ApproximateAddress.fromJson(
          Map<String, dynamic>.from(response.json as Map),
        ),
        response,
      );
    });
    _tail = task.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return task;
  }
}
