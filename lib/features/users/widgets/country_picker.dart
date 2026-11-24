import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_scope.dart';
import '../../../core/network/api_panel.dart';
import '../services/countries_api.dart';

class CountryPicker extends StatefulWidget {
  const CountryPicker({super.key, required this.onDial, this.service});
  final CountriesApi? service;
  final ValueChanged<String> onDial;
  @override
  State<CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<CountryPicker> {
  String selected = '🇹🇳 Tunisie (TN) +216 — choix local par défaut';
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(selected),
      ApiPanel<List<CountryInfo>>(
        title: 'Pays et indicatif',
        action: 'Choisir un pays',
        load: (refresh) {
          if (widget.service != null) {
            return widget.service!.countries(refresh: refresh);
          }
          final client = apiClient(c);
          if (client == null) {
            throw const ApiFailure(
              ApiErrorKind.configuration,
              'Service externe non configuré.',
            );
          }
          return CountriesApi(client).countries(refresh: refresh);
        },
        empty: (items) => items.isEmpty,
        builder: (c, items) => OutlinedButton(
          onPressed: () async {
            final country = await searchableApiChoice(
              c,
              title: 'Choisir un pays',
              items: items,
              label: (x) =>
                  '${x.flag} ${x.name} (${x.iso}) ${x.dialCodes.join(', ')}',
            );
            if (country == null || !mounted || !c.mounted) return;
            if (country.dialCodes.isEmpty) {
              setState(
                () => selected =
                    '${country.name} — indicatif non fourni, saisissez un numéro international.',
              );
              widget.onDial('');
              return;
            }
            var dial = country.dialCodes.first;
            if (country.dialCodes.length > 1) {
              final chosen = await searchableApiChoice(
                c,
                title: 'Indicatif téléphonique',
                items: country.dialCodes,
                label: (x) => x,
              );
              if (chosen == null || !mounted) return;
              dial = chosen;
            }
            setState(
              () => selected =
                  '${country.flag} ${country.name} (${country.iso}) $dial',
            );
            widget.onDial(dial);
          },
          child: const Text('Rechercher dans les pays reçus'),
        ),
      ),
      const Text(
        'Sans API : numéro international possible avec +. Un numéro déjà international conserve son indicatif.',
      ),
    ],
  );
}
