import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_panel.dart';
import '../../../core/network/api_scope.dart';
import '../../reports/services/report_location_service.dart';
import '../../events/widgets/event_widgets.dart' show EventMap;
import '../services/clinics_api.dart';

class NearbyClinics extends StatefulWidget {
  const NearbyClinics({super.key, this.location});
  final ReportLocationService? location;
  @override
  State<NearbyClinics> createState() => _NearbyClinicsState();
}

class _NearbyClinicsState extends State<NearbyClinics> {
  final lat = TextEditingController(), lon = TextEditingController();
  String? error;
  bool gps = false;
  @override
  void dispose() {
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ExpansionTile(
    title: const Text('Cliniques vétérinaires à proximité — OSM'),
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cliniques vétérinaires à proximité',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Annuaire externe OpenStreetMap • données parfois incomplètes. Ces établissements ne sont pas des comptes Animora : aucune réservation ici.',
          ),
          TextField(
            controller: lat,
            decoration: const InputDecoration(
              labelText: 'Latitude du lieu (saisie manuelle possible)',
            ),
          ),
          TextField(
            controller: lon,
            decoration: const InputDecoration(
              labelText: 'Longitude du lieu (saisie manuelle possible)',
            ),
          ),
          OutlinedButton(
            onPressed: gps
                ? null
                : () async {
                    setState(() => gps = true);
                    try {
                      final p =
                          await (widget.location ??
                                  DeviceReportLocationService())
                              .locate();
                      if (mounted) {
                        setState(() {
                          lat.text = p.latitude.toStringAsFixed(2);
                          lon.text = p.longitude.toStringAsFixed(2);
                          error = null;
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error = 'Position indisponible ou refusée. Saisissez une position manuellement.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => gps = false);
                    }
                  },
            child: const Text('Utiliser ma position pour les cliniques'),
          ),
          if (error != null) Text(error!),
          ApiPanel<List<ExternalClinic>>(
            title: 'Recherche OSM — rayon limité à 5 km',
            action:
                'Rechercher les cliniques (envoi de la position approximative)',
            load: (refresh) {
              final a = double.tryParse(lat.text.replaceAll(',', '.')),
                  b = double.tryParse(lon.text.replaceAll(',', '.'));
              if (a == null || b == null) {
                throw const ApiFailure(
                  ApiErrorKind.invalid,
                  'Saisissez latitude et longitude, ou utilisez le GPS.',
                );
              }
              final client = apiClient(c);
              if (client == null) {
                throw const ApiFailure(
                  ApiErrorKind.configuration,
                  'Service externe non configuré.',
                );
              }
              return ClinicsApi(client).nearby(a, b, refresh: refresh);
            },
            empty: (rows) => rows.isEmpty,
            builder: (c, rows) => Column(
              children: [
                for (final clinic in rows)
                  ListTile(
                    title: Text(clinic.name),
                    subtitle: Text(
                      clinic.address.isEmpty
                          ? 'Adresse non renseignée'
                          : clinic.address,
                    ),
                    trailing: clinic.latitude == null
                        ? const Text('Position absente')
                        : IconButton(
                            tooltip: 'Voir la clinique sur la carte',
                            icon: const Icon(Icons.map_outlined),
                            onPressed: () => showDialog<void>(
                              context: c,
                              builder: (d) => AlertDialog(
                                title: Text(clinic.name),
                                content: SizedBox(
                                  width: 440,
                                  child: EventMap(
                                    latitude: clinic.latitude!,
                                    longitude: clinic.longitude!,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const Text(
            '© OpenStreetMap contributors • ODbL • Overpass API. Recherche déclenchée uniquement par vous.',
          ),
        ],
      ),
    ],
  );
}
