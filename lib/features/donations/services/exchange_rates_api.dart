import '../../../core/network/api_client.dart';

class ExchangeRates {
  const ExchangeRates(this.eur, this.usd, this.updatedAt);
  final double eur, usd;
  final DateTime? updatedAt;
  factory ExchangeRates.fromJson(Map<String, dynamic> j) {
    if (j['result'] != 'success' ||
        j['base_code'] != 'TND' ||
        j['rates'] is! Map) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Taux en TND indisponibles.',
      );
    }
    final eur = finiteNumber(j['rates']['EUR']),
        usd = finiteNumber(j['rates']['USD']);
    if (eur <= 0 || usd <= 0) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Taux de conversion invalides.',
      );
    }
    return ExchangeRates(
      eur,
      usd,
      j['time_last_update_unix'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['time_last_update_unix'] as num).toInt() * 1000,
              isUtc: true,
            )
          : null,
    );
  }
  double convert(double tnd, String currency) {
    if (!tnd.isFinite || tnd < 0) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Montant indicatif invalide.',
      );
    }
    return tnd *
        switch (currency) {
          'EUR' => eur,
          'USD' => usd,
          _ => throw const ApiFailure(
            ApiErrorKind.invalid,
            'Devise non prise en charge.',
          ),
        };
  }
}

class ExchangeRatesApi {
  ExchangeRatesApi(this.client);
  final ApiClient client;
  Future<ApiValue<ExchangeRates>> rates({bool refresh = false}) async {
    // Provider updates daily; the button also respects the daily cache.
    final response = await client.get(
      Uri.https('open.er-api.com', '/v6/latest/TND'),
      ttl: const Duration(hours: 24),
      stale: const Duration(days: 7),
      validate: (json) =>
          ExchangeRates.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    if (response.json is! Map) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Réponse de taux invalide.');
    }
    return ApiValue(
      ExchangeRates.fromJson(Map<String, dynamic>.from(response.json as Map)),
      response,
    );
  }
}
