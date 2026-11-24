import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CitySuggestion {
  const CitySuggestion({required this.name, this.region, this.country});
  final String name;
  final String? region, country;

  /// « Gouvernorat de Sousse, Tunisie »
  String get details => [
    region,
    country,
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  @override
  bool operator ==(Object other) =>
      other is CitySuggestion &&
      other.name == name &&
      other.region == region &&
      other.country == country;
  @override
  int get hashCode => Object.hash(name, region, country);
}

/// City autocompletion with Photon (komoot, OpenStreetMap data): free,
/// no API key. Results are biased towards Tunisia and returned in French.
class CitySearchApi {
  CitySearchApi({
    http.Client? client,
    this.timeout = const Duration(seconds: 6),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  final _cache = <String, List<CitySuggestion>>{};

  static const _placeTypes = [
    'place:city',
    'place:town',
    'place:village',
    'place:municipality',
  ];

  /// Never throws: an empty list means « no suggestion » (offline included).
  Future<List<CitySuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final key = q.toLowerCase();
    final cached = _cache[key];
    if (cached != null) return cached;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '8',
      'lang': 'fr',
      'lat': '34.5',
      'lon': '9.6',
      'osm_tag': _placeTypes,
    });
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) return const [];
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final features = (json is Map ? json['features'] : null);
      if (features is! List) return const [];
      final results = <CitySuggestion>[];
      for (final f in features) {
        final p = f is Map ? f['properties'] : null;
        if (p is! Map || p['name'] is! String) continue;
        final s = CitySuggestion(
          name: p['name'] as String,
          region: p['state'] as String?,
          country: p['country'] as String?,
        );
        if (!results.contains(s)) results.add(s);
        if (results.length == 5) break;
      }
      return _cache[key] = results;
    } catch (_) {
      return const [];
    }
  }
}
