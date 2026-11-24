import '../../../core/network/api_client.dart';

String calendarDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class EventWeather {
  const EventWeather(
    this.date,
    this.minimum,
    this.maximum,
    this.rainProbability,
    this.precipitation,
    this.wind,
    this.code,
    this.timezone,
  );
  final String date, timezone;
  final double minimum, maximum, rainProbability, precipitation, wind;
  final int code;
  String get conditions => switch (code) {
    0 => 'Ciel dégagé',
    1 || 2 || 3 => 'Ciel partiellement nuageux à couvert',
    45 || 48 => 'Brouillard',
    51 || 53 || 55 || 56 || 57 => 'Bruine',
    61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => 'Pluie ou averses',
    71 || 73 || 75 || 77 || 85 || 86 => 'Neige',
    95 || 96 || 99 => 'Orage',
    _ => 'Code météo WMO $code',
  };
  List<String> get advice => [
    if (rainProbability >= 50 || precipitation >= 5)
      'Prévoir un abri sec et protéger le matériel.',
    if (maximum >= 30) 'Prévoir ombre, eau et pauses pour les animaux.',
    if (wind >= 40)
      'Fixer les installations légères et prévoir un espace abrité.',
  ];
  factory EventWeather.fromDaily(Map<String, dynamic> j, String day) {
    final daily = j['daily'];
    if (daily is! Map || daily['time'] is! List) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Prévisions quotidiennes absentes.',
      );
    }
    final i = (daily['time'] as List).indexOf(day);
    if (i < 0) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Prévisions pas encore disponibles',
      );
    }
    double number(String field) {
      final values = daily[field];
      if (values is! List || values.length <= i) {
        throw const ApiFailure(ApiErrorKind.invalid, 'Champ météo absent.');
      }
      return finiteNumber(values[i]);
    }

    final min = number('temperature_2m_min'),
        max = number('temperature_2m_max'),
        rain = number('precipitation_probability_max'),
        precip = number('precipitation_sum'),
        wind = number('wind_speed_10m_max'),
        code = number('weather_code');
    if (max < min ||
        rain < 0 ||
        rain > 100 ||
        precip < 0 ||
        wind < 0 ||
        code != code.roundToDouble()) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Valeurs météo incohérentes.',
      );
    }
    return EventWeather(
      day,
      min,
      max,
      rain,
      precip,
      wind,
      code.toInt(),
      j['timezone'] as String? ?? 'auto',
    );
  }
}

class WeatherApi {
  WeatherApi(this.client, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ApiClient client;
  final DateTime Function() clock;
  Future<ApiValue<EventWeather?>> forecast(
    double? latitude,
    double? longitude,
    DateTime date, {
    bool refresh = false,
  }) async {
    if (latitude == null || longitude == null) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Coordonnées de l’événement absentes. Prévisions indisponibles.',
      );
    }
    validCoordinates(latitude, longitude);
    final today = DateTime(clock().year, clock().month, clock().day),
        day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Événement passé : aucune prévision actuelle affichée comme météo historique.',
      );
    }
    if (day.difference(today).inDays > 15) {
      return ApiValue(null, ApiResponse(null, clock(), remote: false));
    }
    final response = await client.get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'daily': 'temperature_2m_min,temperature_2m_max,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,weather_code',
        'timezone': 'auto',
        'forecast_days': '16',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'precipitation_unit': 'mm',
      }),
      ttl: const Duration(hours: 1),
      stale: const Duration(hours: 6),
      refresh: refresh,
    );
    if (response.json is! Map) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Réponse météo invalide.');
    }
    final json = Map<String, dynamic>.from(response.json as Map);
    if (json['daily']?['time'] is List &&
        !(json['daily']['time'] as List).contains(calendarDate(date))) {
      return ApiValue(null, response);
    }
    return ApiValue(EventWeather.fromDaily(json, calendarDate(date)), response);
  }
}
