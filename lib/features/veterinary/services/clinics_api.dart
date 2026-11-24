import '../../../core/network/api_client.dart';

class ExternalClinic {
  const ExternalClinic(
    this.id,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
  );
  final String id, name, address;
  final double? latitude, longitude;
  factory ExternalClinic.fromJson(Map<String, dynamic> j) {
    final tags = j['tags'] is Map ? j['tags'] as Map : const {};
    final center = j['center'] is Map ? j['center'] as Map : const {};
    final lat = j['lat'] ?? center['lat'], lon = j['lon'] ?? center['lon'];
    double? a, b;
    if (lat is num &&
        lon is num &&
        lat.isFinite &&
        lon.isFinite &&
        lat.abs() <= 90 &&
        lon.abs() <= 180) {
      a = lat.toDouble();
      b = lon.toDouble();
    }
    return ExternalClinic(
      '${j['type'] ?? ''}/${j['id']}',
      (tags['name'] ?? tags['name:fr'] ?? tags['name:en']) as String? ??
          'Établissement sans nom renseigné',
      [tags['addr:street'], tags['addr:city']].whereType<String>().join(', '),
      a,
      b,
    );
  }
}

class ClinicsApi {
  ClinicsApi(
    this.client, {
    this.endpoint = const String.fromEnvironment(
      'OVERPASS_ENDPOINT',
      defaultValue: 'https://overpass-api.de/api/interpreter',
    ),
  });
  final String endpoint;
  final ApiClient client;
  static final _blockedUntil = <String, DateTime>{};
  static String query(double lat, double lon) {
    validCoordinates(lat, lon);
    return '[out:json][timeout:20];nwr["amenity"="veterinary"](around:5000,${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)});out center;';
  }

  Future<ApiValue<List<ExternalClinic>>> nearby(
    double lat,
    double lon, {
    bool refresh = false,
  }) async {
    final blocked = _blockedUntil[endpoint];
    if (blocked != null && blocked.isAfter(DateTime.now())) {
      throw const ApiFailure(
        ApiErrorKind.http,
        'Serveur Overpass temporairement indisponible. Attendez au moins 30 secondes avant une nouvelle tentative.',
      );
    }
    late final ApiResponse response;
    try {
      response = await client.get(
        Uri.parse(endpoint).replace(queryParameters: {'data': query(lat, lon)}),
        ttl: const Duration(hours: 1),
        refresh: refresh,
      );
    } on ApiFailure {
      _blockedUntil[endpoint] = DateTime.now().add(const Duration(seconds: 30));
      rethrow;
    }
    if (response.json is! Map || response.json['elements'] is! List) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Réponse Overpass invalide.',
      );
    }
    if (response.json['remark'] != null) {
      throw const ApiFailure(
        ApiErrorKind.http,
        'Overpass n’a pas terminé la recherche. Réessayez plus tard.',
      );
    }
    final clinics = (response.json['elements'] as List)
        .whereType<Map>()
        .map((j) => ExternalClinic.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    return ApiValue(clinics, response);
  }
}
