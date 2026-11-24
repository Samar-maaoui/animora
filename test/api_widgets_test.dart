import 'package:animora/features/reports/widgets/reports_widgets.dart'
    show LocationFields;
import 'package:animora/features/reports/services/report_location_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:animora/core/network/api_client.dart';
import 'package:animora/features/users/widgets/country_picker.dart';
import 'package:animora/features/users/services/countries_api.dart';
import 'package:animora/features/adoption/widgets/breed_information.dart';
import 'package:animora/features/adoption/services/breeds_api.dart';
import 'package:animora/features/donations/widgets/currency_conversion.dart';
import 'package:animora/features/veterinary/widgets/nearby_clinics.dart';
import 'package:animora/features/events/widgets/event_weather.dart';
import 'package:animora/features/events/models/event.dart';
import 'package:animora/core/enums/event_type.dart';
import 'package:animora/core/enums/event_status.dart';

class ApiLocation9 implements ReportLocationService {
  @override
  Future<ReportPoint> locate() async => const ReportPoint(36.81234, 10.189);
}

Future<void> mount(WidgetTester t, ApiClient client, Widget child) async {
  await t.pumpWidget(
    Provider<ApiClient>.value(
      value: client,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label);
  await t.ensureVisible(f);
  await t.tap(f);
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump();
  }
  await t.pumpAndSettle();
}

ApiClient api(dynamic json) => ApiClient(
  cache: MemoryApiCache(),
  client: MockClient(
    (_) async => http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);
void main() {
  testWidgets(
    'GPS action invokes approximate reverse geocoding and displays city',
    (t) async {
      final client = api({
        'address': {
          'city': 'Tunis',
          'state': 'Tunis',
          'country': 'Tunisia',
          'road': 'Private road',
        },
      });
      addTearDown(client.close);
      final lat = TextEditingController(), lon = TextEditingController();
      addTearDown(lat.dispose);
      addTearDown(lon.dispose);
      await mount(
        t,
        client,
        Provider<ReportLocationService>.value(
          value: ApiLocation9(),
          child: LocationFields(
            latitude: lat,
            longitude: lon,
            onConsent: (_) {},
            showMap: false,
          ),
        ),
      );
      await tap(t, 'Utiliser ma position GPS');
      expect(lat.text, '36.81');
      expect(lon.text, '10.19');
      expect(find.text('Tunis'), findsOneWidget);
      expect(find.textContaining('Private road'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Country list searches selects country and shows its phone code',
    (t) async {
      final client = api({
        'data': {
          'objects': [
            {
              'names': {'common': 'Tunisia'},
              'codes': {'alpha_2': 'TN'},
              'flag': {'emoji': '🇹🇳'},
              'calling_codes': ['216'],
            },
            {
              'names': {'common': 'France'},
              'codes': {'alpha_2': 'FR'},
              'flag': {'emoji': '🇫🇷'},
              'calling_codes': ['33'],
            },
          ],
        },
      });
      addTearDown(client.close);
      var dial = '';
      await mount(
        t,
        client,
        CountryPicker(
          service: CountriesApi(client, key: 'test'),
          onDial: (v) => dial = v,
        ),
      );
      expect(find.textContaining('choix local par défaut'), findsOneWidget);
      await tap(t, 'Choisir un pays');
      await tap(t, 'Rechercher dans les pays reçus');
      await t.enterText(find.byType(TextField), 'France');
      await t.pump();
      await tap(t, '🇫🇷 France (FR) +33');
      expect(dial, '+33');
      expect(find.text('🇫🇷 France (FR) +33'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Breed selection searches returned breeds and manual fallback remains explicit',
    (t) async {
      final client = api([
        {'id': 1, 'name': 'Beagle', 'temperament': 'Curious'},
      ]);
      addTearDown(client.close);
      var selected = '';
      await mount(
        t,
        client,
        BreedInformation(
          species: 'Chien',
          service: BreedsApi(client, dogKey: 'test'),
          onSelected: (v) => selected = v,
        ),
      );
      await tap(t, 'Rechercher une race externe');
      await tap(t, 'Choisir dans la liste des races');
      await t.enterText(find.byType(TextField), 'Bea');
      await t.pump();
      await tap(t, 'Beagle');
      expect(selected, 'Beagle');
      expect(find.text('Curious'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Currency equivalent updates after amount edits without changing controller',
    (t) async {
      final client = api({
        'result': 'success',
        'base_code': 'TND',
        'rates': {'EUR': 0.3, 'USD': 0.32},
      });
      addTearDown(client.close);
      final amount = TextEditingController(text: '100');
      addTearDown(amount.dispose);
      await mount(t, client, CurrencyConversion(amount: amount));
      await tap(t, 'Consulter les équivalents en devises');
      expect(find.text('30.00 EUR • 32.00 USD'), findsOneWidget);
      expect(amount.text, '100');
      amount.text = '0';
      await t.pump();
      expect(find.text('0.00 EUR • 0.00 USD'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('External clinics are collapsible and show an OSM location map', (
    t,
  ) async {
    final client = api({
      'elements': [
        {
          'type': 'node',
          'id': 1,
          'lat': 36.8,
          'lon': 10.18,
          'tags': {'name': 'OSM Clinic'},
        },
      ],
    });
    addTearDown(client.close);
    await mount(t, client, const NearbyClinics());
    await tap(t, 'Cliniques vétérinaires à proximité — OSM');
    await t.enterText(find.byType(TextField).first, '36.8');
    await t.enterText(find.byType(TextField).last, '10.18');
    await tap(
      t,
      'Rechercher les cliniques (envoi de la position approximative)',
    );
    expect(find.text('OSM Clinic'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('Voir la clinique sur la carte'));
    await t.tap(find.byTooltip('Voir la clinique sur la carte'));
    await t.pumpAndSettle();
    expect(
      find.text('Afficher la carte (connexion nécessaire)'),
      findsOneWidget,
    );
    expect(find.text('Prendre rendez-vous'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Far future event reports unavailable without an HTTP request', (
    t,
  ) async {
    var calls = 0;
    final client = ApiClient(
      cache: MemoryApiCache(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final event = Event(
      id: 1,
      title: 'Outdoor',
      description: 'Activity',
      type: EventType.OTHER,
      location: 'Parc',
      city: 'Tunis',
      latitude: 36.8,
      longitude: 10.18,
      startDate: DateTime.now().add(const Duration(days: 100)),
      endDate: DateTime.now().add(const Duration(days: 101)),
      capacity: 10,
      status: EventStatus.PUBLISHED,
      organizerUserId: 'admin',
    );
    await mount(t, client, EventWeatherPanel(event: event));
    await tap(t, 'Consulter les prévisions pour la sortie');
    expect(find.text('Prévisions pas encore disponibles'), findsOneWidget);
    expect(calls, 0);
    expect(find.textContaining('Aucun appel réseau'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
