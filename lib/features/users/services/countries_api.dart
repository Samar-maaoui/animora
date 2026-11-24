import '../../../core/network/api_client.dart';

class CountryInfo {
  const CountryInfo(this.name, this.iso, this.flag, this.dialCodes);
  final String name, iso, flag;
  final List<String> dialCodes;
  factory CountryInfo.fromJson(Map<String, dynamic> j) {
    final name = j['names']?['common'], iso = j['codes']?['alpha_2'];
    final codes = j['calling_codes'];
    if (name is! String || iso is! String || codes is! List) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Pays incomplet dans la réponse.',
      );
    }
    return CountryInfo(
      name,
      iso,
      j['flag']?['emoji'] as String? ?? '',
      codes
          .map((x) => '+${x.toString().replaceAll('+', '')}')
          .where((x) => RegExp(r'^\+[0-9]{1,7}$').hasMatch(x))
          .toList(),
    );
  }
}

/// Flag emoji built from an ISO alpha-2 code (regional indicator letters).
String flagEmoji(String iso) {
  final code = iso.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
  return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

String internationalPhone(String input, String dial) {
  final raw = input.trim();
  if (raw.startsWith('+')) return raw;
  return dial + raw;
}

class CountriesApi {
  CountriesApi(
    this.client, {
    this.key = const String.fromEnvironment('REST_COUNTRIES_KEY'),
  });
  final ApiClient client;
  final String key;

  /// Free source used when no REST Countries key is configured.
  static final countriesNowUri = Uri.https(
    'countriesnow.space',
    '/api/v0.1/countries/codes',
  );

  /// REST Countries v5 with a key; otherwise CountriesNow (free, no key).
  Future<ApiValue<List<CountryInfo>>> countries({bool refresh = false}) =>
      key.isEmpty ? _countriesNow(refresh) : _restCountries(refresh);

  Future<ApiValue<List<CountryInfo>>> _countriesNow(bool refresh) async {
    final response = await client.get(
      countriesNowUri,
      ttl: const Duration(days: 7),
      refresh: refresh,
    );
    final json = response.json;
    if (json is! Map || json['error'] == true || json['data'] is! List) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Liste de pays indisponible (réponse inattendue).',
      );
    }
    final countries = <CountryInfo>[];
    for (final row in json['data'] as List) {
      if (row is! Map) continue;
      final name = row['name'], iso = row['code'], dial = row['dial_code'];
      if (name is! String || iso is! String || iso.length != 2) continue;
      // « +1 684 » → « +1684 »
      final code = dial is String ? dial.replaceAll(RegExp(r'[\s-]'), '') : '';
      countries.add(
        CountryInfo(
          name,
          iso.toUpperCase(),
          flagEmoji(iso),
          RegExp(r'^\+[0-9]{1,7}$').hasMatch(code) ? [code] : const [],
        ),
      );
    }
    if (countries.isEmpty) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Aucun pays reçu.');
    }
    countries.sort((a, b) => a.name.compareTo(b.name));
    return ApiValue(countries, response);
  }

  Future<ApiValue<List<CountryInfo>>> _restCountries(bool refresh) async {
    final countries = <CountryInfo>[];
    ApiResponse? last;
    for (var offset = 0; offset < 1000; offset += 100) {
      last = await client.get(
        Uri.https('api.restcountries.com', '/countries/v5', {
          'limit': '100',
          'offset': offset.toString(),
          'response_fields':
              'names.common,codes.alpha_2,flag.emoji,calling_codes',
        }),
        headers: {'Authorization': 'Bearer $key'},
        ttl: const Duration(days: 7),
        refresh: refresh,
      );
      final data = last.json['data'];
      if (data is! Map || data['objects'] is! List || data['_demo'] != null) {
        throw const ApiFailure(
          ApiErrorKind.invalid,
          'Liste complète de pays indisponible ; réponse de démonstration refusée.',
        );
      }
      final rows = data['objects'] as List;
      countries.addAll(
        rows.map(
          (x) => CountryInfo.fromJson(Map<String, dynamic>.from(x as Map)),
        ),
      );
      if (rows.length < 100) break;
      if (offset == 900) {
        throw const ApiFailure(
          ApiErrorKind.invalid,
          'Pagination de pays incomplète.',
        );
      }
    }
    countries.sort((a, b) => a.name.compareTo(b.name));
    return ApiValue(countries, last!);
  }
}
