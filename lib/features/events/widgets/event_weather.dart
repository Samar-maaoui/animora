import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_scope.dart';
import '../../../core/network/api_panel.dart';
import '../models/event.dart';
import '../services/weather_api.dart';

class EventWeatherPanel extends StatelessWidget {
  const EventWeatherPanel({super.key, required this.event});
  final Event event;
  @override
  Widget build(BuildContext c) => ApiPanel<EventWeather?>(
    key: ValueKey(
      event.id.toString() +
          calendarDate(event.startDate) +
          (event.latitude?.toString() ?? ''),
    ),
    title: 'Météo prévue pour cet événement',
    action: 'Consulter les prévisions pour la sortie',
    load: (refresh) {
      final client = apiClient(c);
      if (client == null) {
        throw const ApiFailure(
          ApiErrorKind.configuration,
          'Service météo non configuré.',
        );
      }
      return WeatherApi(client).forecast(
        event.latitude,
        event.longitude,
        event.startDate,
        refresh: refresh,
      );
    },
    builder: (c, weather) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weather == null)
          const Text('Prévisions pas encore disponibles')
        else ...[
          Text('${weather.date} • ${weather.timezone}'),
          Text(weather.conditions),
          Text(
            'Minimum ${weather.minimum.toStringAsFixed(1)} °C • Maximum ${weather.maximum.toStringAsFixed(1)} °C',
          ),
          Text(
            'Pluie : ${weather.rainProbability.toStringAsFixed(0)} % • Précipitations : ${weather.precipitation.toStringAsFixed(1)} mm',
          ),
          Text('Vent maximal : ${weather.wind.toStringAsFixed(1)} km/h'),
          for (final advice in weather.advice) Text(advice),
          const Text(
            'Conseils informatifs, sans valeur d’alerte officielle. Vérifiez les conditions avant la sortie.',
          ),
        ],
        TextButton(
          onPressed: () => launchUrl(Uri.parse('https://open-meteo.com/')),
          child: const Text('Weather data by Open-Meteo.com • CC BY 4.0'),
        ),
      ],
    ),
  );
}
