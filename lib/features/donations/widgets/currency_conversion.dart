import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_panel.dart';
import '../../../core/network/api_scope.dart';
import '../services/exchange_rates_api.dart';

class CurrencyConversion extends StatelessWidget {
  const CurrencyConversion({super.key, required this.amount});
  final TextEditingController amount;
  @override
  Widget build(BuildContext c) => ApiPanel<ExchangeRates>(
    title: 'Équivalent indicatif EUR / USD',
    action: 'Consulter les équivalents en devises',
    load: (refresh) {
      final client = apiClient(c);
      if (client == null) {
        throw const ApiFailure(
          ApiErrorKind.configuration,
          'Service de conversion non configuré.',
        );
      }
      return ExchangeRatesApi(client).rates(refresh: refresh);
    },
    builder: (c, rates) => ValueListenableBuilder(
      valueListenable: amount,
      builder: (c, value, _) {
        final tnd = double.tryParse(value.text.replaceAll(',', '.'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tnd == null || !tnd.isFinite || tnd < 0)
              const Text('Saisissez un montant TND valide.')
            else
              Text(
                '${rates.convert(tnd, 'EUR').toStringAsFixed(2)} EUR • ${rates.convert(tnd, 'USD').toStringAsFixed(2)} USD',
              ),
            if (rates.updatedAt != null)
              Text('Taux mis à jour : ${rates.updatedAt!.toUtc()}'),
            const Text(
              'Conversion informative uniquement. Le don enregistré reste en TND. Aucun paiement réel.',
            ),
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse('https://www.exchangerate-api.com')),
              child: const Text('Rates By Exchange Rate API'),
            ),
          ],
        );
      },
    ),
  );
}
